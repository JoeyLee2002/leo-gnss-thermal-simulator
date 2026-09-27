function standalone_main(varargin)
%STANDALONE_MAIN Entry point for the MATLAB Runtime desktop release.
if ~isempty(varargin) && ismember(char(varargin{1}), {'--smoke','--gui-smoke'})
    if numel(varargin) ~= 2
        error('leotherm:StandaloneSmoke', ...
            'Use --smoke or --gui-smoke with an output directory.');
    end
    outputDirectory = char(varargin{2});
    if isfolder(outputDirectory)
        error('leotherm:StandaloneSmoke', 'Use a new output directory.');
    end
    if strcmp(char(varargin{1}), '--gui-smoke')
        guiSmoke(outputDirectory);
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
    run = leotherm.runThermalPipeline(task, outputDirectory);
    assert(strcmp(run.status, 'complete'), 'Pipeline did not complete.');
    pdf = fullfile(outputDirectory, 'report', 'thermal_report_zh.pdf');
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
app = leotherm.launchApp('zh');
waitfor(app.Figure);
end

function guiSmoke(outputDirectory)
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
scenario = leotherm.defaultScenario;
scenario.name = 'standalone_gui_smoke';
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
app.runScenario(scenario, leotherm.defaultReceiverNetwork);
run = app.runPipeline(outputDirectory);
assert(strcmp(run.status, 'complete'), 'GUI pipeline did not complete.');
pdf = fullfile(outputDirectory, 'report', 'thermal_report_zh.pdf');
assert(isfile(pdf), 'The GUI report PDF was not created.');
fid = fopen(fullfile(outputDirectory, 'standalone_gui_status.txt'), 'w');
assert(fid >= 0, 'Cannot write standalone GUI status.');
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'outcome=complete\nversion=%s\ntask_id=%s\npdf=%s\n', ...
    leotherm.version, run.taskId, pdf);
clear fileCleanup cleanup
end
