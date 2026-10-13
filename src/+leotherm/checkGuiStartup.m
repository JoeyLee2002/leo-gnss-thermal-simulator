function record = checkGuiStartup(directory, visibility)
%CHECKGUISTARTUP Time startup and verify deferred pages preserve task inputs.
if nargin < 2, visibility = 'on'; end
if isfolder(directory) || isfile(directory)
    error('leotherm:StartupCheck','Use a new output directory.');
end
mkdir(directory);
wall = tic;
app = leotherm.ThermalSimulatorApp(visibility,'en');
cleanup = onCleanup(@() delete(app));
record.constructorS = toc(wall);
drawnow;
record.renderedS = toc(wall);
fprintf('STARTUP_READY constructor_s=%.3f rendered_s=%.3f\n',record.constructorS,record.renderedS);
if strcmp(visibility,'on')
    exportapp(app.Figure,fullfile(directory,'quick_start.png'));
end
record.initialAxes = numel(findall(app.Figure,'Type','axes'));
assert(record.initialAxes == 0,'Unused charts were created at startup.');
assert(~app.TelemetryWorkspace.UIReady && ~app.CalibrationWorkspace.UIReady, ...
    'Advanced panels were eagerly built.');
before = app.getState;
assert(~app.hasUnsavedChanges,'A new task is marked as modified.');
names = {'scenario','sweep','geometry','thermal_model','telemetry','calibration'};
record.pages = struct('name',{},'loadS',{});
for index = 1:numel(names)
    clock = tic;
    app.prepareWorkspace(names{index});
    drawnow;
    record.pages(index) = struct('name',names{index},'loadS',toc(clock));
    count = numel(findall(app.Figure));
    app.prepareWorkspace(names{index});
    assert(numel(findall(app.Figure)) == count,'Loading a page twice duplicated controls.');
end
after = app.getState;
assert(isequaln(before,after),'Deferred page creation changed task inputs or results.');
assert(~app.hasUnsavedChanges,'Opening a page modified the saved task.');
record.version = leotherm.version;
record.outcome = 'passed';
record.inputsPreserved = true;
fid = fopen(fullfile(directory,'startup_check.json'),'w','n','UTF-8');
assert(fid >= 0,'Cannot write startup measurements.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(record,'PrettyPrint',true));
fprintf('STARTUP_CHECK_OK constructor_s=%.3f rendered_s=%.3f\n',record.constructorS,record.renderedS);
end
