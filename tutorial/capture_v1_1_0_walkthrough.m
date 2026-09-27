function output = capture_v1_1_0_walkthrough(output)
%CAPTURE_V1_1_0_WALKTHROUGH Capture real GUI states for the v1.1 tutorial.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
if nargin < 1 || isempty(output)
    output = fullfile(root, 'results', 'tutorial_v1_1_0_capture');
end
if isfolder(output)
    error('leotherm:TutorialOutput', 'Use a new tutorial directory.');
end
mkdir(output);
frames = fullfile(output, 'frames');
mkdir(frames);
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
app.Figure.Position = [60 60 1380 860];
app.Figure.Visible = 'on';
capture(app, frames, '01_quick_start', '快速开始');

capture(app, frames, '02_all_optional_off', '仿真');
toggle(app, 'PipelineSweepCheck', true);
capture(app, frames, '03_sweep_selected', '仿真');
toggle(app, 'PipelineSweepCheck', false);
toggle(app, 'PipelineTelemetryCheck', true);
capture(app, frames, '04_telemetry_requires_data', '仿真');
toggle(app, 'PipelineTelemetryCheck', false);
toggle(app, 'PipelineGeometryCheck', true);
capture(app, frames, '05_geometry_requires_mesh', '仿真');
toggle(app, 'PipelineGeometryCheck', false);
toggle(app, 'PipelineCalibrationCheck', true);
capture(app, frames, '06_calibration_requires_data', '仿真');
toggle(app, 'PipelineCalibrationCheck', false);

app.loadProject(fullfile(root, 'examples', 'projects', '01_first_simulation.mat'));
capture(app, frames, '07_first_project_ready', '仿真');
baseOutput = fullfile(output, 'base_run');
base = app.runPipeline(baseOutput);
assert(strcmp(base.status, 'complete') && base.acceptance.passed);
capture(app, frames, '08_base_results', '结果与导出');

state = app.getState;
state.scenario.name = 'tutorial_one_case_sweep';
state.scenario.durationS = 3600;
state.scenario.timeStepS = 60;
state.scenario.warmupOrbits = 0;
state.scenario.convergence.enabled = false;
state.pipelineOptions.sweep = true;
state.scanSettings.mode = 'beta_altitude';
state.scanSettings.altitudes = '600';
state.scanSettings.betas = '0';
state.scanSettings.branch = 1;
state.lastPipelineRun = [];
state.result = [];
state.sweep = table;
project = fullfile(output, 'tutorial_sweep_project.mat');
leotherm.writeWorkspaceProject(project, state, false);
app.loadProject(project);
capture(app, frames, '09_scan_project_ready', '仿真');
sweepOutput = fullfile(output, 'sweep_run');
sweep = app.runPipeline(sweepOutput);
assert(strcmp(sweep.status, 'complete') && height(sweep.sweep) == 1);
capture(app, frames, '10_scan_results', '结果与导出');
capture(app, frames, '11_scan_chart', '参数扫描');

save(fullfile(output, 'capture_manifest.mat'), 'base', 'sweep', '-v7.3');
fprintf('TUTORIAL_CAPTURE=%s\n', output);
clear cleanup
end

function toggle(app, tag, enabled)
control = findobj(app.Figure, 'Tag', tag);
assert(isscalar(control), 'Required pipeline checkbox is missing.');
control.Value = enabled;
control.ValueChangedFcn(control, []);
drawnow;
end

function capture(app, folder, name, tabTitle)
tab = findobj(app.Figure, 'Type', 'uitab', 'Title', tabTitle);
assert(isscalar(tab), 'Required tutorial tab is missing.');
if strcmp(tabTitle, '参数扫描')
    parentTab = findobj(app.Figure, 'Type', 'uitab', 'Title', '仿真');
    parentTab.Parent.SelectedTab = parentTab;
end
tab.Parent.SelectedTab = tab;
drawnow;
exportapp(app.Figure, fullfile(folder, [name '.png']));
end
