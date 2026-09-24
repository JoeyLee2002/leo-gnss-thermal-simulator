function tests = test_hardening
tests = functiontests(localfunctions);
end

function testStiffConductionMatchesAnalyticSolution(testCase)
[net,scenario] = conductionFixture;
time = [0;1.3]; q = zeros(2,numel(net.nodeNames));
[temperature,d] = leotherm.solveThermalNetwork(time,q,net,scenario.environment,scenario.integration);
exact = 305-5*exp(-2*time);
verifyEqual(testCase,temperature(:,1),exact,'AbsTol',1e-4);
verifyLessThanOrEqual(testCase,d.maximumAcceptedErrorRatio,1);
verifyLessThan(testCase,d.maximumEnergyClosureJ,1e-8);
verifyGreaterThan(testCase,d.acceptedSteps,1);
verifyEqual(testCase,sum(temperature(:,1:2),2),[610;610],'AbsTol',1e-10);
end

function testCoarseOutputDoesNotForceCoarseIntegration(testCase)
[net,s] = conductionFixture;
time = [0;20;40]; q = zeros(3,numel(net.nodeNames));
temperature = leotherm.solveThermalNetwork(time,q,net,s.environment,s.integration);
verifyEqual(testCase,temperature(2:3,1:2),305*ones(2),'AbsTol',1e-4);
end

function testInternalBudgetFailsExplicitly(testCase)
[net,s] = conductionFixture;
s.integration.maximumInternalSteps = 1;
verifyError(testCase,@()leotherm.solveThermalNetwork([0;20],zeros(2,11), ...
    net,s.environment,s.integration),'leotherm:ThermalNumerics');
end

function testToleranceRejectsInvalidValue(testCase)
[net,s] = conductionFixture;
s.integration.absoluteToleranceK = NaN;
verifyError(testCase,@()leotherm.solveThermalNetwork([0;1],zeros(2,11), ...
    net,s.environment,s.integration),'leotherm:InvalidThermalInput');
end

function testHeldPowerJumpIsNotSmoothed(testCase)
[net,s] = conductionFixture;
net.conductanceWK(:) = 0;
q = zeros(3,11); q(2:end,1) = 100;
t = leotherm.solveThermalNetwork([0;10;20],q,net,s.environment,s.integration,struct('holdPrevious',true));
verifyEqual(testCase,t(:,1),[300;300;310],'AbsTol',1e-10);
end

function testConstantSignalHasNoIdentifiableLag(testCase)
t = (0:300)';
m = leotherm.orbitalPeakLagMetrics(t,ones(size(t)),300*ones(size(t)),100);
verifyFalse(testCase,m.identifiable);
verifyTrue(testCase,isnan(m.peakToPeakLagMedianS));
verifyEqual(testCase,m.rejectedPeakCycles,3);
end

function testAdvanceNotReportedAsLongThermalDelay(testCase)
t = (0:300)';
m = leotherm.orbitalPeakLagMetrics(t,cos(2*pi*t/100),cos(2*pi*(t+10)/100),100);
verifyEqual(testCase,m.signedPeakPhaseMedianS,-10);
verifyFalse(testCase,m.identifiable);
verifyTrue(testCase,isnan(m.peakToPeakLagMedianS));
end

function testKnownDelayPreserved(testCase)
t = (0:300)';
m = leotherm.orbitalPeakLagMetrics(t,cos(2*pi*t/100),cos(2*pi*(t-20)/100),100);
verifyTrue(testCase,m.identifiable);
verifyEqual(testCase,m.peakToPeakLagMedianS,20);
end

function testPlateauAndTinyVariationAreNotIdentified(testCase)
t = (0:300)'; x = double(mod(t,100)<50);
m = leotherm.orbitalPeakLagMetrics(t,x,circshift(x,10),100);
verifyFalse(testCase,m.identifiable);
m = leotherm.orbitalPeakLagMetrics(t,cos(2*pi*t/100),300+1e-6*cos(2*pi*(t-20)/100),100);
verifyFalse(testCase,m.identifiable);
end

function testFiniteEarthDiskAnalyticOrientations(testCase)
c = leotherm.constants;
r = c.radiusEarth+[200;600;2000]*1e3; alpha = asin(c.radiusEarth./r);
f = leotherm.earthDiskViewFactor(repmat([1 0 -1],3,1),r);
verifyEqual(testCase,f(:,1),(c.radiusEarth./r).^2,'AbsTol',1e-12);
verifyEqual(testCase,f(:,2),(alpha-sin(alpha).*cos(alpha))/pi,'AbsTol',2e-6);
verifyEqual(testCase,f(:,3),zeros(3,1),'AbsTol',1e-14);
verifyGreaterThan(testCase,f(:,2),0);
end

function testFiniteDiskQuadratureConverges(testCase)
c = leotherm.constants; r = c.radiusEarth+600e3; mu = linspace(-1,1,25);
coarse = leotherm.earthDiskViewFactor(mu,r,48);
fine = leotherm.earthDiskViewFactor(mu,r,192);
verifyLessThan(testCase,max(abs(coarse-fine)),1e-4);
verifyGreaterThanOrEqual(testCase,diff(coarse),-1e-12);
end

function testLegacyInfraredModeRemainsAvailable(testCase)
s = leotherm.defaultScenario; n = leotherm.defaultReceiverNetwork;
o = leotherm.propagateCircularOrbit(s.startEpoch,[0;10],s.orbit);
frame = leotherm.bodyFrame(o.positionM,o.velocityMps,o.sunPositionM,s.attitude);
s.environment.earthIRModel = 'legacy_cosine';
a = leotherm.environmentHeatLoads(o,frame,n,s.environment);
s.environment = rmfield(s.environment,'earthIRModel');
b = leotherm.environmentHeatLoads(o,frame,n,s.environment);
verifyEqual(testCase,a,b);
end

function testCoverageDoesNotCountGapsOrConstantTemperature(testCase)
settings = leotherm.deviceCalibrationOptions;
settings.minimumScoredSamples = 3; settings.minimumCoverageS = 100;
settings.minimumContinuousS = 50;
split = table(["2024-01-01";"2024-01-02";"2024-01-03"], ...
    ["train";"validation";"test"],'VariableNames',{'day_utc','role'});
reports = cell(1,3);
for k = 1:3
    reports{k}.metrics = table("device",'VariableNames',{'node'});
    reports{k}.samples = table([1;2;3;100;101;102], ...
        datetime(2024,1,k,'TimeZone','UTC')+seconds([0;10;20;3600;3610;3620]), ...
        repmat("device",6,1),true(6,1),300*ones(6,1),[1;1;1;2;2;2], ...
        'VariableNames',{'source_row','epoch_utc','node','used','observed_k','segment_id'});
end
coverage = leotherm.calibrationCoverage(reports,split,settings);
verifyEqual(testCase,coverage.scored_duration_s,40*ones(3,1));
verifyEqual(testCase,coverage.longest_continuous_s,20*ones(3,1));
verifyFalse(testCase,any(coverage.sufficient));
end

function testMultinodeMissingTargetDoesNotDiscardOtherSensors(testCase)
network = leotherm.defaultReceiverNetwork;
[raw,scenario,options] = leotherm.telemetryDemo(network);
data = leotherm.readTelemetry(raw,[],network);
node = find(data.hasTemperature,1);
before = leotherm.simulateTelemetry(data,scenario,network,options);
data.temperatureK(50,node) = NaN;
after = leotherm.simulateTelemetry(data,scenario,network,options);
verifyEqual(testCase,after.temperatureK,before.temperatureK);
r = leotherm.validateTelemetry(after,data,options);
missing = r.samples.source_row == 50 & r.samples.node == string(data.nodeNames{node});
verifyFalse(testCase,any(r.samples.used(missing)));
others = r.samples.source_row == 50 & r.samples.node ~= string(data.nodeNames{node});
verifyTrue(testCase,all(r.samples.used(others)));
end

function [net,s] = conductionFixture
s = leotherm.defaultScenario; net = leotherm.defaultReceiverNetwork;
net.capacityJK(:) = 100; net.conductanceWK(:) = 0;
net.conductanceWK(1,2) = 100; net.conductanceWK(2,1) = 100;
net.internalPowerW(:) = 0; net.radiatingAreaM2(:) = 0;
net.initialTemperatureK(:) = 300; net.initialTemperatureK(2) = 310;
end
