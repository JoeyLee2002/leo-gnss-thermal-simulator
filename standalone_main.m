function standalone_main(varargin)
%STANDALONE_MAIN Entry point for the MATLAB Runtime desktop release.
if ~isempty(varargin) && strcmp(char(varargin{1}),'--gui-startup-smoke')
    if numel(varargin) ~= 2
        error('leotherm:StandaloneSmoke','Use --gui-startup-smoke NEW_DIRECTORY.');
    end
    leotherm.checkGuiStartup(char(varargin{2}));
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--sample-reports')
    if numel(varargin)~=2 || isfolder(char(varargin{2})) || isfile(char(varargin{2}))
        error('leotherm:StandaloneSmoke','Use --sample-reports NEW_DIRECTORY.');
    end
    scenario=leotherm.defaultScenario;
    scenario.name='sample_report_120s'; scenario.durationS=120; scenario.timeStepS=60;
    scenario.warmupOrbits=0; scenario.convergence.enabled=false;
    result=leotherm.simulateScenario(scenario,leotherm.defaultReceiverNetwork);
    leotherm.writeThermalReport(result,char(varargin{2}),'both');
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--gui-module-smoke')
    if numel(varargin)~=2
        error('leotherm:StandaloneSmoke','Use --gui-module-smoke NEW_DIRECTORY.');
    end
    leotherm.checkModuleRunButtons(char(varargin{2}));
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--gui-figure-smoke')
    if numel(varargin)~=2
        error('leotherm:StandaloneSmoke','Use --gui-figure-smoke NEW_DIRECTORY.');
    end
    outputDirectory=char(varargin{2});
    result=leotherm.checkBackgroundReportFigures(outputDirectory);
    fid=fopen(fullfile(outputDirectory,'gui_figure_smoke.json'),'w','n','UTF-8');
    assert(fid>=0,'Cannot write figure check result.');
    cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s',jsonencode(result,'PrettyPrint',true));
    fprintf('GUI_FIGURE_SMOKE_OK version=%s\n',leotherm.version);
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--gui-window-smoke')
    if numel(varargin)~=2 || isfolder(char(varargin{2})) || isfile(char(varargin{2}))
        error('leotherm:StandaloneSmoke','Use --gui-window-smoke NEW_DIRECTORY.');
    end
    outputDirectory=char(varargin{2}); mkdir(outputDirectory);
    result=leotherm.checkFileDialogWindow;
    fid=fopen(fullfile(outputDirectory,'gui_window_smoke.json'),'w','n','UTF-8');
    assert(fid>=0,'Cannot write window check result.');
    cleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s',jsonencode(result,'PrettyPrint',true));
    fprintf('GUI_WINDOW_SMOKE_OK version=%s\n',leotherm.version);
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--gui-progress-smoke')
    if numel(varargin)~=2
        error('leotherm:StandaloneSmoke','Use --gui-progress-smoke NEW_DIRECTORY.');
    end
    guiProgressSmoke(char(varargin{2}));
    return
end
if ~isempty(varargin) && strcmp(char(varargin{1}), '--paper-study')
    if numel(varargin) < 2 || numel(varargin) > 3
        error('leotherm:PaperStudyArguments','Use --paper-study NEW_DIRECTORY [zh|en|both].');
    end
    language='both'; if numel(varargin)==3, language=char(varargin{3}); end
    leotherm.runPaperStudy(char(varargin{2}),language);
    return
end
if ~isempty(varargin) && ismember(char(varargin{1}), {'--smoke','--gui-smoke','--gui-report-window-smoke'})
    if numel(varargin) ~= 2
        error('leotherm:StandaloneSmoke', ...
            'Use --smoke or --gui-smoke with an output directory.');
    end
    outputDirectory = char(varargin{2});
    if isfolder(outputDirectory)
        error('leotherm:StandaloneSmoke', 'Use a new output directory.');
    end
    if ismember(char(varargin{1}), {'--gui-smoke','--gui-report-window-smoke'})
        guiSmoke(outputDirectory,strcmp(char(varargin{1}),'--gui-report-window-smoke'));
        return
    end
    templates = leotherm.listSimulationTemplates( ...
        fullfile(leotherm.installRoot, 'templates'));
    assert(numel(templates) >= 4, 'Built-in task templates are missing.');
    scenario = leotherm.defaultScenario;
    scenario.name = 'standalone_smoke';
    scenario.durationS = 120;
    scenario.timeStepS = 60;
    scenario.warmupOrbits = 0;
    scenario.convergence.enabled = false;
    task = leotherm.createThermalPipelineTask( ...
        scenario, leotherm.defaultReceiverNetwork);
    task.language = 'en';
    run = leotherm.runThermalPipeline(task, outputDirectory);
    assert(strcmp(run.status, 'complete'), 'Pipeline did not complete.');
    pdf = fullfile(outputDirectory, 'report', 'thermal_report_en.pdf');
    assert(isfile(pdf), 'The standalone report PDF was not created.');
    fid = fopen(fullfile(outputDirectory, 'standalone_smoke_status.txt'), 'w');
    assert(fid >= 0, 'Cannot write standalone smoke status.');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, 'outcome=complete\nversion=%s\ntemplates=%d\ntask_id=%s\npdf=%s\n', ...
        leotherm.version, numel(templates), run.taskId, pdf);
    return
end
if ~isempty(varargin)
    error('leotherm:StandaloneArguments', 'Unknown standalone argument.');
end
app = leotherm.launchApp;
waitfor(app.Figure);
end

function guiSmoke(outputDirectory,checkWindow)
visibility='off'; if checkWindow, visibility='on'; end
app = leotherm.ThermalSimulatorApp(visibility);
cleanup = onCleanup(@() delete(app));
if checkWindow
    drawnow;
    exportapp(app.Figure,[outputDirectory '_window.png']);
    figure(app.Figure);
    app.Figure.WindowState='maximized'; pause(0.5); drawnow;
    initialWindowState=char(app.Figure.WindowState);
    assert(~strcmp(initialWindowState,'minimized'),'The test app started minimized.');
    app.Figure.UserData=struct('visibility',{{}});
    oldCreate=get(groot,'DefaultFigureCreateFcn');
    oldVisible=get(groot,'DefaultFigureVisible');
    defaultsCleanup=onCleanup(@() restoreFigureDefaults(oldCreate,oldVisible));
    set(groot,'DefaultFigureCreateFcn',@(fig,~) recordReportFigure(app.Figure,fig), ...
        'DefaultFigureVisible','on');
end
scenario = leotherm.defaultScenario;
scenario.name = 'standalone_gui_smoke';
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
app.runScenario(scenario, leotherm.defaultReceiverNetwork);
if checkWindow
    drawnow;
    assert(strcmp(char(app.Figure.WindowState),initialWindowState), ...
        'First scenario chart rendering changed the owner state.');
end
run = app.runPipeline(outputDirectory);
assert(strcmp(run.status, 'complete'), 'GUI pipeline did not complete.');
pdf = fullfile(outputDirectory, 'report', 'thermal_report_en.pdf');
assert(isfile(pdf), 'The GUI report PDF was not created.');
if checkWindow
    drawnow;
    assert(strcmp(char(app.Figure.WindowState),initialWindowState),'Report generation changed the owner state.');
    values=app.Figure.UserData.visibility;
    assert(numel(values)>10 && all(strcmp(values,'off')),'Report generation showed temporary figures.');
    fprintf('REPORT_WINDOW_OK hidden_figures=%d state=%s\n',numel(values),initialWindowState);
    clear defaultsCleanup
end
fid = fopen(fullfile(outputDirectory, 'standalone_gui_status.txt'), 'w');
assert(fid >= 0, 'Cannot write standalone GUI status.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'outcome=complete\nversion=%s\ntask_id=%s\npdf=%s\n', ...
    leotherm.version, run.taskId, pdf);
if checkWindow, fprintf(fid,'window_requested=maximized\nwindow_observed=%s\n',initialWindowState); end
clear fileCleanup cleanup
end

function recordReportFigure(owner,fig)
data=owner.UserData; data.visibility{end+1}=char(fig.Visible); owner.UserData=data;
end

function restoreFigureDefaults(create,visible)
set(groot,'DefaultFigureCreateFcn',create,'DefaultFigureVisible',visible);
end

function guiProgressSmoke(outputDirectory)
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('leotherm:StandaloneSmoke','Use a new output directory.');
end
mkdir(outputDirectory);
rows=struct([]);
for index=1:3
    language='en'; if index==2, language='zh'; end
    closeAfter=index==3;
    app=leotherm.ThermalSimulatorApp('on',language);
    appCleanup=onCleanup(@() deleteApp(app));
    samples=0; lastEvent=[]; requested=false; requestedAt=NaN; stopDisplay=[];
    wall=tic;
    clock=timer('ExecutionMode','fixedSpacing','Period',0.5, ...
        'TimerFcn',@sample);
    timerCleanup=onCleanup(@() deleteClock(clock));
    folder=fullfile(outputDirectory,sprintf('cancel_%d',index));
    start(clock);
    study=app.runPaperTask(folder,false);
    elapsed=toc(wall);
    assert(isempty(study) && requested,'GUI cancellation did not occur.');
    status=jsondecode(fileread(fullfile(folder,'paper_study_status.json')));
    assert(strcmp(status.status,'cancelled'),'Cancelled task was marked complete.');
    assert(~isfile(fullfile(folder,'paper_study.mat')),'Unexpected success artifact.');
    assert(samples>=2 && ~isempty(lastEvent),'Progress did not process repeated callbacks.');
    assert(elapsed-requestedAt<20,'Stop did not reach a checkpoint within 20 seconds.');
    if closeAfter
        assert(~isvalid(app),'Window close did not close the app.');
    else
        state=app.getOperationState;
        assert(~state.busy,'App stayed busy after stopping.');
        button=findobj(app.Figure,'Tag','QuickStartRunButton');
        assert(strcmp(char(button.Enable),'on'),'Run control was not restored.');
    end
    rows(index).language=language;
    rows(index).closeRequested=closeAfter;
    rows(index).timerCallbacks=samples;
    rows(index).lastStage=lastEvent.stage;
    rows(index).elapsedS=elapsed;
    rows(index).stopLatencyS=elapsed-requestedAt;
    rows(index).stopDisplay=stopDisplay;
    clear timerCleanup appCleanup
end
result=struct('version',leotherm.version,'outcome','passed','checks',rows);
fid=fopen(fullfile(outputDirectory,'gui_progress_smoke.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot write GUI smoke result.');
fileCleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(result,'PrettyPrint',true));
fprintf('GUI_PROGRESS_SMOKE_OK version=%s\n',leotherm.version);

    function sample(~,~)
        if requested || ~isvalid(app), return; end
        state=app.getOperationState;
        if ~state.busy || isempty(state.progress), return; end
        samples=samples+1; lastEvent=state.progress;
        if samples<2 || toc(wall)<3, return; end
        requested=true; requestedAt=toc(wall);
        if closeAfter
            callback=app.Figure.CloseRequestFcn;
            callback(app.Figure,[]);
        else
            button=findobj(app.Figure,'Tag','OperationStopButton');
            callback=button.ButtonPushedFcn; callback(button,[]);
        end
        state=app.getOperationState; stopDisplay=state.dialog;
        assert(~isempty(stopDisplay) && stopDisplay.cancelRequested,'Stop button did not request cancellation.');
        if strcmp(language,'en')
            text=[stopDisplay.title stopDisplay.message stopDisplay.buttonText];
            assert(~any(double(text)>=hex2dec('4E00') & double(text)<=hex2dec('9FFF')), ...
                'English stopping UI contains Chinese.');
            assert(strcmp(stopDisplay.buttonText,'Stopping...'),'Unexpected stopping label.');
        end
    end
end

function deleteApp(app)
if isvalid(app), delete(app); end
end

function deleteClock(clock)
if isvalid(clock), stop(clock); delete(clock); end
end
