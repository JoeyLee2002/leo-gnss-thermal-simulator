function tests=test_background_figures
tests=functiontests(localfunctions);
end

function testExportDoesNotOpenWindows(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
result=leotherm.checkBackgroundReportFigures(folder);
verifyEqual(testCase,result.visibilityAtCreation,{'off','off'});
verifyEqual(testCase,result.ownerState,'maximized');
for name={'scenario.png','scenario.pdf','sweep.png','sweep.pdf'}
    verifyTrue(testCase,isfile(fullfile(folder,name{1})));
end
end

function testExplicitPreviewStillWorks(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() removeFolder(folder));
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=60;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
fig=leotherm.plotScenario(r,fullfile(folder,'preview.png'),'en');
figureCleanup=onCleanup(@() delete(fig));
verifyEqual(testCase,char(fig.Visible),'on');
verifyEqual(testCase,numel(findall(fig,'Type','axes')),4);
end

function testFailedExportDoesNotLeakFigure(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() removeFolder(folder));
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=60;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
try
    leotherm.plotScenario(r,fullfile(folder,'invalid.badformat'),'en');
    verifyFail(testCase,'Unsupported export format should fail.');
catch exception
    verifyFalse(testCase,isempty(exception.identifier));
end
verifyEmpty(testCase,findall(groot,'Tag','ScenarioExportFigure'));
end

function removeFolder(path)
if isfolder(path), rmdir(path,'s'); end
end
