function tests=test_report_synthesis
tests=functiontests(localfunctions);
end

function testTimeWeightedHeatSharesAndConductiveDirection(testCase)
[bundle,report]=fixture;
s=leotherm.buildThermalReportSynthesis(bundle,report);
% Irregular epochs: mean solar=15 W, IR=10 W, not the sample mean of solar.
verifyEqual(testCase,metric(s,'external_share_directSolarW'),60,'AbsTol',1e-10);
verifyEqual(testCase,metric(s,'external_share_earthIRW'),40,'AbsTol',1e-10);
verifyEqual(testCase,metric(s,'response_mean_net_conduction_outward'),-5,'AbsTol',1e-10);
verifyEqual(testCase,metric(s,'response_link_from_node'),1);
verifyEqual(testCase,metric(s,'response_link_to_node'),2);
verifyEqual(testCase,metric(s,'response_to_largest_nodal_range'),50);
verifyTrue(testCase,contains(strjoin(s.overview.linesZh),'60.0%'));
verifyTrue(testCase,contains(strjoin(s.conclusion.linesEn),'Custom node: Panel / Custom node: Receiver'));
end

function testReverseHeatFlowChangesDirection(testCase)
[bundle,report]=fixture;
bundle.scenario.temperatureK(:,2)=bundle.scenario.temperatureK(:,1)+10;
s=leotherm.buildThermalReportSynthesis(bundle,report);
verifyEqual(testCase,metric(s,'response_link_from_node'),2);
verifyEqual(testCase,metric(s,'response_link_to_node'),1);
verifyEqual(testCase,metric(s,'response_mean_net_conduction_outward'),20);
end

function testZeroForcingAndConstantTemperatureDoNotInventRatios(testCase)
[bundle,report]=fixture;
bundle.scenario.temperatureK(:)=300;
bundle.scenario.loads.directSolarW(:)=0;
bundle.scenario.loads.earthIRW(:)=0;
s=leotherm.buildThermalReportSynthesis(bundle,report);
verifyFalse(testCase,any(strcmp(s.evidence.metric,'external_share_directSolarW')));
verifyFalse(testCase,any(strcmp(s.evidence.metric,'response_to_largest_nodal_range')));
verifyFalse(testCase,contains(strjoin(s.overview.linesEn),'NaN'));
end

function testMissingRolesDoNotSelectAnArbitraryNode(testCase)
[bundle,report]=fixture;
bundle.scenario.network=rmfield(bundle.scenario.network,'roles');
s=leotherm.buildThermalReportSynthesis(bundle,report);
verifyFalse(testCase,any(strcmp(s.evidence.metric,'response_to_largest_nodal_range')));
end

function testNegativePhaseIsDescribedAsLead(testCase)
[bundle,report]=fixture;
bundle.scenario.orbit.periodS=100;
report.harmonicResponse=struct('available',true,'phaseDelayS',-20);
s=leotherm.buildThermalReportSynthesis(bundle,report);
verifyEqual(testCase,metric(s,'orbital_phase_fraction'),20);
verifyTrue(testCase,contains(strjoin(s.conclusion.linesZh),'超前'));
verifyTrue(testCase,contains(strjoin(s.conclusion.linesEn),'leads'));
end

function testOptionalStageFindingsAndHeldOutResultsSurvive(testCase)
[~,report]=fixture;
stages={'sweep','geometry','calibration','telemetry'};
for k=1:numel(stages)
    report.analysis(k)=struct('stage',stages{k},'titleZh',stages{k}, ...
        'titleEn',stages{k},'linesZh',{{'测量结果','第二条结果','留出集结果'}}, ...
        'linesEn',{{'measured result','second finding','held-out result'}});
end
s=leotherm.buildThermalReportSynthesis(struct,report);
verifyEqual(testCase,numel(s.conclusion.linesEn),4);
verifyTrue(testCase,contains(strjoin(s.conclusion.linesEn),'held-out result'));
verifyEmpty(testCase,s.evidence);
end

function testAbsentStagesDoNotGenerateSections(testCase)
s=leotherm.buildThermalReportSynthesis(struct,struct);
verifyEmpty(testCase,s.overview.linesEn);
verifyEmpty(testCase,s.conclusion.linesZh);
end

function testCalibrationDoesNotHideHeldOutDegradation(testCase)
metrics=table(["train";"test"],[10;10],[4;2],[2;3], ...
    'VariableNames',{'role','used_samples','baseline_rmse_k','calibrated_rmse_k'});
bundle=struct('calibration',struct('stageMetrics',metrics));
s=leotherm.buildThermalReportSynthesis(bundle,struct);
verifyEqual(testCase,metric(s,'calibration_train_rmse_change'),-2);
verifyEqual(testCase,metric(s,'calibration_test_rmse_change'),1);
verifyTrue(testCase,contains(strjoin(s.conclusion.linesZh),'测试集 RMSE 增加'));
end

function testZeroBaselineCalibrationUsesAbsoluteChange(testCase)
metrics=table("test",10,0,1, ...
    'VariableNames',{'role','used_samples','baseline_rmse_k','calibrated_rmse_k'});
s=leotherm.buildThermalReportSynthesis(struct('calibration',struct('stageMetrics',metrics)),struct);
verifyEqual(testCase,metric(s,'calibration_test_rmse_change'),1);
verifyFalse(testCase,contains(strjoin(s.conclusion.linesEn),'Inf'));
verifyFalse(testCase,contains(strjoin(s.conclusion.linesEn),'%'));
end

function testMalformedHistoriesAreRejected(testCase)
[bundle,report]=fixture;
bundle.scenario.timeS=[0;0;120];
verifyError(testCase,@() leotherm.buildThermalReportSynthesis(bundle,report),'leotherm:ReportHistory');
end

function [bundle,report]=fixture
r=struct('timeS',[0;30;120],'temperatureK',[300 300;310 305;300 300]);
r.network=struct('nodeNames',{{'Panel','Receiver'}},'roles',struct('response',2), ...
    'conductanceWK',[0 2;2 0]);
r.loads=struct('directSolarW',[0;30;0],'albedoW',zeros(3,1),'earthIRW',10*ones(3,1));
bundle=struct('scenario',r); report=struct;
end

function value=metric(s,key)
at=strcmp(s.evidence.metric,key); value=s.evidence.value(at);
if iscell(value), value=cell2mat(value); end
end
