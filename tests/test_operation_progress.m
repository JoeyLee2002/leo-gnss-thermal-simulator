function tests=test_operation_progress
tests=functiontests(localfunctions);
end

function testObserverDoesNotChangeSolution(testCase)
s=shortScenario; n=leotherm.defaultReceiverNetwork;
a=leotherm.simulateScenario(s,n);
events={};
b=leotherm.simulateScenario(s,n,@observe);
verifyEqual(testCase,a.temperatureK,b.temperatureK);
verifyEqual(testCase,a.numerics,b.numerics);
verifyEqual(testCase,a.metrics,b.metrics);
verifyTrue(testCase,any(strcmp(events,'integrating')));
    function cancelled=observe(e)
        events{end+1}=e.stage;
        cancelled=false;
    end
end

function testStopInsideIntegration(testCase)
s=shortScenario;
verifyError(testCase,@() leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork, ...
    @(e)strcmp(e.stage,'integrating')),'leotherm:OperationCancelled');
end

function testStopDuringPeriodicInitialization(testCase)
s=leotherm.defaultScenario;
verifyError(testCase,@() leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork, ...
    @(e)strcmp(e.stage,'warmup')),'leotherm:OperationCancelled');
end

function testInvalidCallbackDoesNotRun(testCase)
folder=tempname;
verifyError(testCase,@() leotherm.runPaperStudy(folder,'en',42),'leotherm:InvalidProgress');
verifyFalse(testCase,isfolder(folder));
verifyError(testCase,@() leotherm.notifyProgress(@(~)0,'test',0,1,'',''),'leotherm:InvalidProgress');
end

function testCancelledStudyHasNoSuccessMarker(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
verifyError(testCase,@() leotherm.runPaperStudy(folder,'en',@(~)true),'leotherm:OperationCancelled');
state=jsondecode(fileread(fullfile(folder,'paper_study_status.json')));
verifyEqual(testCase,state.status,'cancelled');
verifyEqual(testCase,state.caseCount,0);
verifyFalse(testCase,isfile(fullfile(folder,'paper_study.mat')));
end

function testCancelledPipelineStatusIsNotFailure(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
task=leotherm.createThermalPipelineTask(shortScenario,leotherm.defaultReceiverNetwork);
verifyError(testCase,@() leotherm.runThermalPipeline(task,folder,@(~)true),'leotherm:OperationCancelled');
state=jsondecode(fileread(fullfile(folder,'pipeline_status.json')));
verifyEqual(testCase,state.status,'cancelled');
end

function testReportCanBeStopped(testCase)
s=shortScenario; r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
verifyError(testCase,@() leotherm.writeThermalReport(r,folder,'en', ...
    @(e)strcmp(e.stage,'report_figures')),'leotherm:OperationCancelled');
verifyFalse(testCase,isfile(fullfile(folder,'thermal_report_en.pdf')));
end

function testGuiStopRestoresControls(testCase)
for language={'en','zh'}
    app=leotherm.ThermalSimulatorApp('on',language{1});
    cleanup=onCleanup(@() deleteApp(app));
    folder=tempname; folderCleanup=onCleanup(@() removeFolder(folder));
    clock=timer('StartDelay',0.4,'TimerFcn',@(~,~)app.stopOperation(false));
    timerCleanup=onCleanup(@() deleteTimer(clock)); start(clock);
    study=app.runPaperTask(folder,false);
    verifyEmpty(testCase,study);
    verifyTrue(testCase,isvalid(app));
    state=app.getOperationState;
    verifyFalse(testCase,state.busy);
    verifyTrue(testCase,state.cancelRequested);
    button=findobj(app.Figure,'Tag','QuickStartRunButton');
    verifyEqual(testCase,char(button.Enable),'on');
    status=jsondecode(fileread(fullfile(folder,'paper_study_status.json')));
    verifyEqual(testCase,status.status,'cancelled');
    clear timerCleanup folderCleanup cleanup
end
end

function testWindowCloseStopsRunningPaper(testCase)
app=leotherm.ThermalSimulatorApp('on','en');
cleanup=onCleanup(@() deleteApp(app));
folder=tempname; folderCleanup=onCleanup(@() removeFolder(folder));
clock=timer('StartDelay',0.4,'TimerFcn',@(~,~)closeWindow);
timerCleanup=onCleanup(@() deleteTimer(clock)); start(clock);
wall=tic; study=app.runPaperTask(folder,false);
verifyEmpty(testCase,study);
verifyFalse(testCase,isvalid(app));
verifyLessThan(testCase,toc(wall),20);
state=jsondecode(fileread(fullfile(folder,'paper_study_status.json')));
verifyEqual(testCase,state.status,'cancelled');
    function closeWindow
        callback=app.Figure.CloseRequestFcn;
        callback(app.Figure,[]);
    end
end

function s=shortScenario
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=30;
s.warmupOrbits=0; s.convergence.enabled=false;
end
function removeFolder(path)
if isfolder(path), rmdir(path,'s'); end
end
function deleteApp(app)
if isvalid(app), delete(app); end
end
function deleteTimer(t)
if isvalid(t), stop(t); delete(t); end
end
