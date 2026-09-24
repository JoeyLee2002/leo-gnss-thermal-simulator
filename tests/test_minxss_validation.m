function tests = test_minxss_validation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'studies','minxss'));
testCase.TestData.protocol=minxss_protocol;
end

function testRadiativeCooling(testCase)
p=testCase.TestData.protocol;
input=exampleInput; input.incidenceCosine(:)=0;
pars=p.one.initial; pars(3:4)=0;
t=minxss_panel_predict(input,pars,'one_node',p);
verifyLessThan(testCase,max(diff(t(:,1))),0);
verifyEqual(testCase,t(:,1),t(:,2),'AbsTol',1e-12);
end

function testElectricalExtractionRemovesHeat(testCase)
p=testCase.TestData.protocol; input=exampleInput;
reference=minxss_panel_predict(input,p.one.initial,'one_node',p);
input.electricalW(:,1)=5;
extracted=minxss_panel_predict(input,p.one.initial,'one_node',p);
verifyLessThan(testCase,extracted(end,1),reference(end,1));
verifyEqual(testCase,extracted(:,2),reference(:,2),'AbsTol',1e-12);
end

function testGreaterCapacitySlowsHeating(testCase)
p=testCase.TestData.protocol; input=exampleInput;
pars=p.one.initial; pars(1)=30;
fast=minxss_panel_predict(input,pars,'one_node',p);
pars(1)=200;
slow=minxss_panel_predict(input,pars,'one_node',p);
verifyGreaterThan(testCase,fast(6,1),slow(6,1));
end

function testNoTemperatureSeriesFeedback(testCase)
p=testCase.TestData.protocol; input=exampleInput;
first=minxss_panel_predict(input,p.two.initial,'two_node',p);
input.targetTemperatureK=999*ones(numel(input.elapsedS),2);
second=minxss_panel_predict(input,p.two.initial,'two_node',p);
verifyEqual(testCase,first,second);
end

function testTwoNodeHasPhysicalGradient(testCase)
p=testCase.TestData.protocol; input=exampleInput;
[~,details]=minxss_panel_predict(input,p.two.initial,'two_node',p);
verifyGreaterThan(testCase,details.trajectoryK(6,1),details.trajectoryK(6,2));
verifyEqual(testCase,details.network.conductanceWK,details.network.conductanceWK');
verifyGreaterThan(testCase,min(details.network.capacityJK),0);
end

function testTimestepConvergence(testCase)
p=testCase.TestData.protocol; input=exampleInput;
coarse=minxss_panel_predict(input,p.two.initial,'two_node',p);
p.maximumStepS=1;
fine=minxss_panel_predict(input,p.two.initial,'two_node',p);
verifyLessThan(testCase,max(abs(coarse-fine),[],'all'),0.01);
end

function testRejectedRowsSplitArcs(testCase)
p=testCase.TestData.protocol; p.minimumArcS=60;
t=(0:30:600)'; jd=p.trainBeforeJD-2+t/86400;
valid=true(size(t)); valid(10)=false;
[a,id]=minxss_segments(t,jd,valid,p);
verifyEqual(testCase,numel(a),2);
verifyEqual(testCase,id(10),0);
verifyFalse(testCase,any(a(1).rows>9));
verifyFalse(testCase,any(a(2).rows<11));
end

function testGapNeverBridged(testCase)
p=testCase.TestData.protocol; p.minimumArcS=60;
t=[(0:30:120)';(300:30:420)']; jd=p.trainBeforeJD-2+t/86400;
[a,~]=minxss_segments(t,jd,true(size(t)),p);
verifyEqual(testCase,numel(a),2);
end

function testDateBoundaryExcluded(testCase)
p=testCase.TestData.protocol; p.minimumArcS=60;
t=(0:30:600)'; jd=p.testFromJD+(t-300)/86400;
[a,~]=minxss_segments(t,jd,true(size(t)),p);
verifyEmpty(testCase,a);
end

function testFixedChronologicalAssignment(testCase)
p=testCase.TestData.protocol; p.minimumArcS=60;
t=(0:30:600)';
[train,~]=minxss_segments(t,p.trainBeforeJD-2+t/86400,true(size(t)),p);
[validation,~]=minxss_segments(t,p.trainBeforeJD+2+t/86400,true(size(t)),p);
[test,~]=minxss_segments(t,p.testFromJD+2+t/86400,true(size(t)),p);
verifyEqual(testCase,train.split,'train');
verifyEqual(testCase,validation.split,'validation');
verifyEqual(testCase,test.split,'test');
end

function testOptimizerCheckpointAndSerialization(testCase)
bounds.lower=[0 0]; bounds.upper=[2 2]; bounds.initial=[0.5 0.5];
settings.maximumIterations=100; settings.maximumEvaluations=180; settings.starts=1;
prefix=tempname;
cleanup=onCleanup(@()deleteIfPresent([prefix '_start1.mat']));
fit=minxss_fit_bounded(@(x)sum((x-[1 1]).^2),bounds,settings,prefix);
verifyLessThan(testCase,fit.objective,1e-5);
verifyEqual(testCase,numel(fit.starts),1);
verifyTrue(testCase,isfile([prefix '_start1.mat']));
verifyNotEmpty(testCase,jsonencode(fit));
end

function deleteIfPresent(path)
if isfile(path),delete(path);end
end

function testPhysicalBoundaryHooks(testCase)
p=testCase.TestData.protocol; input=exampleInput; input.incidenceCosine(:)=0;
pars=p.two.initial; pars(3:4)=0;
reference=minxss_panel_predict(input,pars,'two_node',p);
input.environmentPowerW=zeros(numel(input.elapsedS),2);
input.boundaryTemperatureK=300*ones(numel(input.elapsedS),2);
input.hingeConductanceWK=0.2*ones(numel(input.elapsedS),2);
[actual,details]=minxss_panel_predict(input,pars,'two_node',p);
verifyGreaterThan(testCase,actual(end,1),reference(end,1));
verifyTrue(testCase,details.prescribedBodyBoundary);
verifyEqual(testCase,details.environmentSource,'prescribed_time_varying_environment');
verifyGreaterThan(testCase,details.hingeHeatW(1,1),0);
end

function testEnvironmentCannotBeDoubleCounted(testCase)
p=testCase.TestData.protocol; input=exampleInput;
input.environmentPowerW=ones(numel(input.elapsedS),2);
verifyError(testCase,@()minxss_panel_predict(input,p.one.initial,'one_node',p),'minxss:BoundaryInput');
end

function testBoundaryHookRejectsBadRowsAndMissingPairs(testCase)
p=testCase.TestData.protocol; input=exampleInput;
input.boundaryTemperatureK=300*ones(numel(input.elapsedS),2);
verifyError(testCase,@()minxss_panel_predict(input,p.two.initial,'two_node',p),'minxss:BoundaryInput');
input.hingeConductanceWK=0.2*ones(numel(input.elapsedS),2);
input.boundaryTemperatureK(4,1)=NaN;
verifyError(testCase,@()minxss_panel_predict(input,p.two.initial,'two_node',p),'minxss:BoundaryInput');
end

function testSourceChecksum(testCase)
path=tempname;
cleanup=onCleanup(@()deleteIfPresent(path));
fid=fopen(path,'wb'); fwrite(fid,uint8('abc')); fclose(fid);
verifyEqual(testCase,minxss_hash_file(path), ...
    'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD');
end

function input=exampleInput
input.elapsedS=(0:30:1800)';
input.incidenceCosine=ones(size(input.elapsedS));
input.electricalW=zeros(numel(input.elapsedS),2);
input.initialTemperatureK=[280 280];
end
