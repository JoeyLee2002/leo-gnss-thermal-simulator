function tests=test_report_scalar_lag
tests=functiontests(localfunctions);
end

function testSingleCycleUsesTextInBothLanguages(testCase)
r=history(1,10); original=r;
d=leotherm.buildThermalReportDetails(struct('scenario',r));
verifyFalse(testCase,any(strcmp({d.stage},'lag_detail')));
item=d(strcmp({d.stage},'temperatures'));
verifyTrue(testCase,contains(strjoin(item.linesZh),'10 s（1 个有效周期）'));
verifyTrue(testCase,contains(strjoin(item.linesEn),'10 s (1 eligible cycle)'));
verifyEqual(testCase,r,original);
end

function testNegativeSingleCycleRetainsSignedValue(testCase)
r=history(1,-10);
d=leotherm.buildThermalReportDetails(struct('scenario',r));
verifyFalse(testCase,any(strcmp({d.stage},'lag_detail')));
item=d(strcmp({d.stage},'temperatures'));
verifyTrue(testCase,contains(strjoin(item.linesZh),'-10 s'));
verifyTrue(testCase,contains(strjoin(item.linesEn),'-10 s'));
verifyFalse(testCase,contains(strjoin(item.linesZh),'见图'));
end

function testMultipleCyclesKeepOriginalIdsAndSigns(testCase)
r=history(3,10);
r.loads.totalExternalW(r.timeS>=100 & r.timeS<200,:)=0;
last=r.timeS>=200;
r.temperatureK(last,r.network.roles.response)=300+2*cos(2*pi*(r.timeS(last)-15)/100);
phase=leotherm.reportPeakLag(r);
d=leotherm.buildThermalReportDetails(struct('scenario',r));
item=d(strcmp({d.stage},'lag_detail'));
verifyEqual(testCase,numel(item),1);
verifyEqual(testCase,item.charts.x,[1;3]);
verifyEqual(testCase,item.charts.y,[10;-10],'AbsTol',1e-10);
verifyEqual(testCase,item.charts.y,phase.signedPeakPhaseByCycleS);
verifyTrue(testCase,phase.mixedPhaseSigns);
end

function testOnlyOneScoredCycleAmongMultipleIsText(testCase)
r=history(2,10);
r.loads.totalExternalW(r.timeS>=100,:)=0;
d=leotherm.buildThermalReportDetails(struct('scenario',r));
verifyFalse(testCase,any(strcmp({d.stage},'lag_detail')));
end

function testPublicationKeepsEnergyWithoutSingletonPanel(testCase)
r=history(1,10);
d=leotherm.buildThermalReportDetails(struct('scenario',r));
energy=d(strcmp({d.stage},'energy_balance'));
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
manifest=leotherm.writeThermalPublicationFigures(energy,folder,'en');
verifyEqual(testCase,numel(manifest),1);
verifyEqual(testCase,manifest.stages,{'energy_balance'});
verifyEqual(testCase,manifest.sourceCharts,1);
saved=load(fullfile(folder,'publication_response_diagnostics_en_source.mat'));
verifyEqual(testCase,saved.item.charts.y,energy.charts.y);
verifyEmpty(testCase,saved.item.charts.panelLabel);
verifyTrue(testCase,isfile(fullfile(folder,'publication_response_diagnostics_en.pdf')));
end

function testPublicationKeepsMultiCyclePanel(testCase)
r=history(2,10);
d=leotherm.buildThermalReportDetails(struct('scenario',r));
d=d(ismember({d.stage},{'energy_balance','lag_detail'}));
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
manifest=leotherm.writeThermalPublicationFigures(d,folder,'zh');
verifyEqual(testCase,manifest.stages,{'lag_detail','energy_balance'});
verifyEqual(testCase,manifest.sourceCharts,2);
saved=load(fullfile(folder,'publication_response_diagnostics_zh_source.mat'));
verifyEqual(testCase,{saved.item.charts.panelLabel},{'a','b'});
end

function r=history(cycles,delay)
% Synthetic histories isolate chart selection from the orbital solver.
s=leotherm.defaultScenario; s.durationS=cycles*100-5; s.timeStepS=5;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
r.orbit.periodS=100;
r.loads.totalExternalW(:,:)=0;
r.loads.totalExternalW(:,1)=100+20*cos(2*pi*(r.timeS-25)/100);
r.temperatureK(:,r.network.roles.response)=300+2*cos(2*pi*(r.timeS-25-delay)/100);
end
