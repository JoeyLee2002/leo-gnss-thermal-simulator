function tests = test_report_result_audit
tests = functiontests(localfunctions);
end

function testMixedPhaseSignsCannotBeSelectedIntoPositiveDelay(testCase)
t = (0:300)'; x = cos(2*pi*t/100); y = cos(2*pi*(t-20)/100);
y(t>=100) = cos(2*pi*(t(t>=100)+10)/100);
p = leotherm.orbitalPeakLagMetrics(t,x,y,100);
verifyTrue(testCase,p.mixedPhaseSigns);
verifyFalse(testCase,p.identifiable);
verifyTrue(testCase,isnan(p.peakToPeakLagMedianS));
verifyEqual(testCase,p.signedPeakPhaseByCycleS,[20;-10;-10],'AbsTol',1e-12);
end

function testActualTransitionsNotNumberOfPairs(testCase)
r = fixture; r.loads.visibleFraction = [1;0;1]; r.metrics.eclipseTransitionCount = 1;
a = leotherm.buildThermalReportAnalysis(struct('scenario',r));
verifyTrue(testCase,contains(strjoin(a.linesEn),'2 illumination transitions'));
end

function testConvergedInitializationNotClaimedAsNoWarmup(testCase)
r = fixture; r.scenario.warmupOrbits = 0; r.convergence.enabled = true;
a = leotherm.buildThermalReportAnalysis(struct('scenario',r));
verifyFalse(testCase,contains(strjoin(a.linesEn),'No warmup was used'));
end

function testSweepPeakKeepsOriginalRowPairing(testCase)
data = table(repmat("complete",3,1),[10;20;NaN], [NaN;9;1], ...
    'VariableNames',{'status','beta_deg','code_bias_span_m'});
a = leotherm.buildThermalReportAnalysis(struct('sweep',data));
verifyTrue(testCase,contains(strjoin(a.linesEn),'9 m at beta 20 deg'));
verifyFalse(testCase,contains(strjoin(a.linesEn),'9 m at beta 10 deg'));
end

function testCachedLagDoesNotOverrideRawHistory(testCase)
r = fixture; r.metrics.forcingToRfLagS = 1980;
a = leotherm.buildThermalReportAnalysis(struct('scenario',r));
verifyTrue(testCase,contains(strjoin(a.linesEn),'no cycle covers'));
verifyFalse(testCase,contains(strjoin(a.linesEn),'1980 s'));
end

function r = fixture
s = leotherm.defaultScenario; s.durationS = 120; s.timeStepS = 60;
s.warmupOrbits = 0; s.convergence.enabled = false;
r = leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
end

function testGridStudyUsesExactEpochs(testCase)
[a,b] = gridFixture;
bundle = struct('scenario',a,'gridRefinement',{{a,b}});
[item,rows] = leotherm.buildThermalGridReport(bundle);
verifyEqual(testCase,item.stage,'grid_refinement');
verifyEqual(testCase,rows.shared_epochs,numel(a.timeS));
[~,i] = ismember(a.timeS,b.timeS);
verifyEqual(testCase,rows.maximum_temperature_difference_k,max(abs(a.temperatureK-b.temperatureK(i,:)),[],'all'));
end

function testGridStudyRejectsMissingEpochAndChangedModel(testCase)
[a,b] = gridFixture; b.timeS(3) = [];
b.temperatureK(3,:) = [];
verifyError(testCase,@() leotherm.buildThermalGridReport(struct('scenario',a,'gridRefinement',{{a,b}})), ...
    'leotherm:ReportGridStudy');
[a,b] = gridFixture; b.network.capacityJK(1) = b.network.capacityJK(1)*2;
verifyError(testCase,@() leotherm.buildThermalGridReport(struct('scenario',a,'gridRefinement',{{a,b}})), ...
    'leotherm:ReportGridStudy');
end

function [a,b] = gridFixture
a = fixture; s = a.scenario; s.timeStepS = 30;
b = leotherm.simulateScenario(s,a.network);
end
