function tests = test_thermal_boundaries
tests = functiontests(localfunctions);
end

function testHeatingAndCoolingAnalytical(testCase)
[net,env,limits,t] = fixture;
for boundary = [260 320]
    forcing = boundaryForcing(t,net,boundary,0.5);
    actual = leotherm.solveThermalNetwork(t,zeros(numel(t),11),net,env,limits,forcing);
    expected = boundary + (280-boundary)*exp(-0.5*t/100);
    verifyEqual(testCase,actual(:,1),expected,'AbsTol',2e-6);
    verifyEqual(testCase,actual(:,2:end),280*ones(numel(t),10));
end
end

function testTimeVaryingBoundaryUsesLeftSample(testCase)
[net,env,limits,t] = fixture;
forcing = boundaryForcing(t,net,320,0.5);
forcing.boundaryTemperatureK(t>=100,1)=260;
forcing.boundaryConductanceWK(t>=100,1)=1;
actual = leotherm.solveThermalNetwork(t,zeros(numel(t),11),net,env,limits,forcing);
expected = zeros(size(t)); expected(1)=280;
for k=1:numel(t)-1
    b=forcing.boundaryTemperatureK(k,1); g=forcing.boundaryConductanceWK(k,1);
    expected(k+1)=b+(expected(k)-b)*exp(-g*(t(k+1)-t(k))/100);
end
verifyEqual(testCase,actual(:,1),expected,'AbsTol',2e-5);
end

function testZeroLinkIsExactlyLegacy(testCase)
[net,env,limits,t] = fixture;
power = 2*ones(numel(t),11);
old = leotherm.solveThermalNetwork(t,power,net,env,limits);
forcing = boundaryForcing(t,net,320,0);
actual = leotherm.solveThermalNetwork(t,power,net,env,limits,forcing);
verifyEqual(testCase,old,actual);
end

function testStrongBoundaryAutomaticallySubsteps(testCase)
[net,env,limits,t] = fixture;
forcing = boundaryForcing(t,net,320,100);
actual = leotherm.solveThermalNetwork(t,zeros(numel(t),11),net,env,limits,forcing);
verifyEqual(testCase,actual(end,1),320,'AbsTol',1e-8);
verifyGreaterThanOrEqual(testCase,min(actual(:,1)),280);
verifyLessThanOrEqual(testCase,max(actual(:,1)),320);
end

function testInvalidBoundaryCoreInputs(testCase)
[net,env,limits,t] = fixture;
forcing = boundaryForcing(t,net,320,0.5);
for bad = [NaN -1 Inf]
    badForcing = forcing; badForcing.boundaryConductanceWK(2,1)=bad;
    verifyError(testCase,@()leotherm.solveThermalNetwork(t,zeros(numel(t),11), ...
        net,env,limits,badForcing),'leotherm:InvalidThermalBoundary');
end
forcing = rmfield(forcing,'boundaryTemperatureK');
verifyError(testCase,@()leotherm.solveThermalNetwork(t,zeros(numel(t),11), ...
    net,env,limits,forcing),'leotherm:InvalidThermalBoundary');
end

function testBadBoundaryNeverFilled(testCase)
[raw,net,scenario,options,key] = telemetryFixture;
raw.(['boundary_temperature_c_' key])(3)=NaN;
result=leotherm.simulateTelemetry(leotherm.readTelemetry(raw,[],net),scenario,net,options);
verifyEqual(testCase,result.segmentId,[1;1;0;2;2;2]);
verifyEqual(testCase,result.audit.reason(3),"invalid_thermal_boundary");
verifyTrue(testCase,all(isnan(result.temperatureK(3,:))));
verifyEqual(testCase,result.temperatureK(4,:),280*ones(1,11));
end

function testNegativeConductanceRejectsRow(testCase)
[raw,net,scenario,options,key] = telemetryFixture;
raw.(['boundary_conductance_wk_' key])(3)=-1;
result=leotherm.simulateTelemetry(leotherm.readTelemetry(raw,[],net),scenario,net,options);
verifyEqual(testCase,result.segmentId,[1;1;0;2;2;2]);
end

function testIncompleteBoundaryPairRejected(testCase)
[raw,net,~,~,key] = telemetryFixture;
raw.(['boundary_conductance_wk_' key])=[];
verifyError(testCase,@()leotherm.readTelemetry(raw,[],net),'leotherm:TelemetryBoundary');
end

function testBoundaryDoesNotUseValidationTemperature(testCase)
[raw,net,scenario,options,key] = telemetryFixture;
raw.(['temperature_k_' key])=300*ones(6,1);
data=leotherm.readTelemetry(raw,[],net);
first=leotherm.simulateTelemetry(data,scenario,net,options);
report=leotherm.validateTelemetry(first,data,options);
raw.(['temperature_k_' key])=310*ones(6,1);
second=leotherm.simulateTelemetry(leotherm.readTelemetry(raw,[],net),scenario,net,options);
verifyEqual(testCase,first.temperatureK,second.temperatureK);
verifyTrue(testCase,report.boundaryConditioning);
verifyEqual(testCase,report.independence,'conditioned_on_prescribed_boundary_not_whole_spacecraft_validation');
verifyGreaterThan(testCase,first.boundaryHeatW(1,1),0);
verifyEqual(testCase,first.boundaryTemperatureK(:,1),320*ones(6,1),'AbsTol',1e-10);
end

function testTemplateAndBoundaryExport(testCase)
[raw,net,scenario,options,key] = telemetryFixture;
raw.(['temperature_k_' key])=300*ones(6,1);
folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
template=leotherm.writeTelemetryTemplate(fullfile(folder,'template.csv'),net,'heat',true);
verifyTrue(testCase,ismember(['boundary_conductance_wk_' key],template.Properties.VariableNames));
data=leotherm.readTelemetry(raw,[],net);
result=leotherm.simulateTelemetry(data,scenario,net,options);
report=leotherm.validateTelemetry(result,data,options);
output=fullfile(folder,'export');
leotherm.writeTelemetryResults(result,report,data,output,'en');
verifyTrue(testCase,isfile(fullfile(output,'thermal_boundaries.csv')));
metadata=jsondecode(fileread(fullfile(output,'manifest.json')));
verifyTrue(testCase,metadata.simulationProvenance.boundaryConditioning);
end

function [net,env,limits,t] = fixture
net=leotherm.defaultReceiverNetwork;
net.capacityJK(:)=100; net.initialTemperatureK(:)=280;
net.internalPowerW(:)=0; net.conductanceWK(:)=0; net.irEmissivity(:)=0;
env.deepSpaceK=3;
limits.minimumTemperatureK=1; limits.maximumTemperatureK=1000;
t=(0:10:400)';
end

function forcing = boundaryForcing(t,net,temperature,conductance)
forcing.boundaryTemperatureK=280*ones(numel(t),numel(net.nodeNames));
forcing.boundaryConductanceWK=zeros(size(forcing.boundaryTemperatureK));
forcing.boundaryTemperatureK(:,1)=temperature;
forcing.boundaryConductanceWK(:,1)=conductance;
end

function [raw,net,scenario,options,key] = telemetryFixture
[net,~,~,~]=fixture;
scenario=leotherm.defaultScenario;
epoch=scenario.startEpoch+seconds((0:10:50)');
raw=table(string(epoch,'yyyy-MM-dd''T''HH:mm:ss''Z'''),ones(6,1), ...
    'VariableNames',{'epoch_utc','quality'});
for k=1:numel(net.nodeNames)
    raw.(['external_power_w_' matlab.lang.makeValidName(net.nodeNames{k})])=zeros(6,1);
end
key=matlab.lang.makeValidName(net.nodeNames{1});
raw.(['boundary_temperature_c_' key])=ones(6,1)*(320-273.15);
raw.(['boundary_conductance_wk_' key])=0.5*ones(6,1);
options=leotherm.telemetryOptions(struct('mode','heat','maxGapS',10,'maxStepS',5,'excludeInitialS',0));
end
