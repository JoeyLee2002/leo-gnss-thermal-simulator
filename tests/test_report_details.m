function tests = test_report_details
tests = functiontests(localfunctions);
end

function testStatisticsUseTimeWeightingAndFullRange(testCase)
r = fixture;
r.timeS = [0;20;120];
r.temperatureK(:,:) = repmat([290;300;310],1,size(r.temperatureK,2));
[d,n] = leotherm.buildThermalReportDetails(struct('scenario',r));
verifyEqual(testCase,numel(d),11);
verifyEqual(testCase,n.time_mean_k,repmat(303.333333333333,height(n),1),'AbsTol',1e-9);
verifyEqual(testCase,n.peak_to_peak_k,repmat(20,height(n),1));
verifyEqual(testCase,n.end_minus_start_k,repmat(20,height(n),1));
end

function testNoFabricatedNodalChapters(testCase)
[d,n] = leotherm.buildThermalReportDetails(struct('scenario',struct('scenario',struct)));
verifyEmpty(testCase,d); verifyEmpty(testCase,n);
end

function testInvalidEpochsAreRejected(testCase)
r = fixture; r.timeS(2) = r.timeS(1);
verifyError(testCase,@() leotherm.buildThermalReportDetails(struct('scenario',r)), ...
    'leotherm:ReportHistory');
end

function testUndefinedLagIsNotZero(testCase)
r = fixture;
d = leotherm.buildThermalReportDetails(struct('scenario',r));
item = d(strcmp({d.stage},'lag_detail'));
verifyTrue(testCase,contains(strjoin(item.linesEn),'no cycle covers'));
verifyFalse(testCase,contains(strjoin(item.linesEn),'NaN'));
verifyEmpty(testCase,item.charts.y);
end

function testConstantSpacingDoesNotCreateFillerFigure(testCase)
r=fixture;
d=leotherm.buildThermalReportDetails(struct('scenario',r));
verifyFalse(testCase,any(strcmp({d.stage},'coverage')));
verifyEqual(testCase,numel(d),10);
end

function testNamesZeroValuesAndTopologyArePreserved(testCase)
r=fixture;
d=leotherm.buildThermalReportDetails(struct('scenario',r));
item=d(strcmp({d.stage},'optics'));
verifyTrue(testCase,contains(strjoin(item.linesZh),'卫星主体结构'));
verifyTrue(testCase,contains(strjoin(item.linesEn),'zero projected'));
verifyEqual(testCase,item.charts(2).y([7 9 10 11]),zeros(4,1));
verifyTrue(testCase,contains(item.charts(2).nodeLabelsEn{9},'GNSS RF'));
item=d(strcmp({d.stage},'conductance'));
verifyEqual(testCase,item.charts.kind,'network');
verifyEqual(testCase,item.charts.y,r.network.conductanceWK);
end

function testWarmupLedgersAlignAndRebase(testCase)
s = leotherm.defaultScenario; s.durationS = 120; s.timeStepS = 60;
s.warmupOrbits = 0.03; s.convergence.enabled = false;
r = leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
fields = {'integratedNetHeatJ','integratedExternalHeatJ','integratedInternalHeatJ', ...
    'integratedRadiatedHeatJ','integratedBoundaryHeatJ','energyClosureResidualJ'};
for k = 1:numel(fields), verifySize(testCase,r.numerics.(fields{k}),size(r.timeS)); end
d = leotherm.buildThermalReportDetails(struct('scenario',r));
item = d(strcmp({d.stage},'energy_balance'));
verifyEqual(testCase,item.charts.y(1,:),[0 0],'AbsTol',1e-12);
verifyLessThan(testCase,max(abs(diff(item.charts.y,1,2))),1e-6);
end

function r = fixture
s = leotherm.defaultScenario; s.durationS = 120; s.timeStepS = 60;
s.warmupOrbits = 0; s.convergence.enabled = false;
r = leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
end
