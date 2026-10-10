function capture_english_intro(output)
%CAPTURE_ENGLISH_INTRO Production GUI and actual task reports for the introduction.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'src'));
assert(~isfolder(output), 'Use a new capture directory.');
mkdir(output); mkdir(fullfile(output, 'frames'));
app = leotherm.ThermalSimulatorApp('on');
cleanup = onCleanup(@() delete(app));
state = app.getState;
assert(strcmp(state.language, 'en'), 'Default interface must be English.');
app.Figure.Position = [40 40 1500 900];
cap('01_start', 'Quick start', '');
app.loadProject(fullfile(root, 'examples', 'projects', '01_first_simulation.mat'));
cap('02_scenario', 'Simulation', 'Single scenario');
cap('03_network', 'Simulation', 'Thermal network');
base = app.runPipeline(fullfile(output, 'base_run'));
assert(strcmp(base.status, 'complete') && base.acceptance.passed);
cap('04_results', 'Results and export', '');
cap('05_temperatures', 'Simulation', 'Single scenario');
app.saveProject(fullfile(output, 'base_project.mat'), false);
state = app.getState;
state.scenario.name = 'english_intro_six_cases';
state.scenario.warmupOrbits = 0;
state.pipelineOptions.sweep = true;
state.scanSettings.mode = 'beta_altitude';
state.scanSettings.altitudes = '500,600';
state.scanSettings.betas = '0,15,30';
state.scanSettings.branch = 1;
restore(state, 'sweep_project');
cap('06_sweep_setup', 'Simulation', 'Parameter sweep');
sweep = app.runPipeline(fullfile(output, 'sweep_run'));
assert(strcmp(sweep.status, 'complete') && height(sweep.sweep) == 6);
cap('07_sweep_results', 'Simulation', 'Parameter sweep');
app.loadProject(fullfile(root, 'examples', 'projects', '06_surface_volume_coupled.mat'));
state = app.getState;
state.scenario.durationS = 600;
state.scenario.timeStepS = 30;
state.scenario.warmupOrbits = 0;
state.scenario.convergence.enabled = false;
state.pipelineOptions = struct('sweep',false,'geometry',true,'telemetry',false,'calibration',false);
restore(state, 'geometry_project');
cap('08_geometry', 'Simulation', '3-D geometry');
geometry = app.runPipeline(fullfile(output, 'geometry_run'));
assert(strcmp(geometry.status, 'complete'));
app.loadProject(fullfile(output, 'base_project.mat'));
app.loadThermalModel(fullfile(root, 'examples', 'projects', '06_engineering_model_exchange.json'));
cap('09_exchange', 'Simulation', 'Engineering thermal model');
app.loadProject(fullfile(root, 'examples', 'projects', '04_telemetry_validation.mat'));
cap('10_telemetry', 'Simulation', 'Telemetry and validation');
telemetry = app.runPipeline(fullfile(output, 'telemetry_run'));
assert(strcmp(telemetry.status, 'complete'));
cap('11_telemetry_results', 'Simulation', 'Telemetry and validation');
app.loadProject(fullfile(output, 'base_project.mat'));
cap('12_calibration', 'Simulation', 'Device calibration');
cap('13_deliver', 'Results and export', '');
save(fullfile(output, 'capture_manifest.mat'), 'base','sweep','geometry','telemetry','-v7.3');
fprintf('ENGLISH_CAPTURE_COMPLETE\n');
clear cleanup

    function restore(state, name)
        path = fullfile(output, [name '.mat']);
        leotherm.writeWorkspaceProject(path, state, false);
        app.loadProject(path);
    end
    function cap(name, mainTitle, detailTitle)
        tab = findall(app.Figure, 'Type', 'uitab', 'Title', mainTitle);
        assert(isscalar(tab), 'Missing main tab: %s', mainTitle);
        tab.Parent.SelectedTab = tab;
        if ~isempty(detailTitle)
            tab = findall(app.Figure, 'Type', 'uitab', 'Title', detailTitle);
            assert(isscalar(tab), 'Missing detail tab: %s', detailTitle);
            tab.Parent.SelectedTab = tab;
        end
        app.Figure.Position = [40 40 1500 900];
        drawnow; pause(0.3); drawnow;
        exportapp(app.Figure, fullfile(output, 'frames', [name '.png']));
        fprintf('CAPTURE=%s\n', name);
    end
end
