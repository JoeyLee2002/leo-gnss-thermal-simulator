function diagnostics = run_gui_smoke_test(outputDirectory, language)
%RUN_GUI_SMOKE_TEST Launch, compute, render, and export the GUI workbench.

root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(outputDirectory)
    versionTag = strrep(strtrim(fileread(fullfile(root, 'VERSION'))), '.', '_');
    outputDirectory = fullfile(root, 'results', ['gui_smoke_v' versionTag]);
end
if nargin < 2 || isempty(language)
    language = 'zh';
end
if ~exist(outputDirectory, 'dir')
    mkdir(outputDirectory);
end
failurePath = fullfile(outputDirectory, 'gui_smoke_failure.txt');
if isfile(failurePath)
    delete(failurePath);
end
addpath(root);
startup;
language = leotherm.normalizeLanguage(language);

app = launch_gui(language);
cleanup = onCleanup(@() delete(app));
scenario = leotherm.defaultScenario;
scenario.name = 'gui_smoke';
scenario.durationS = 2 * 3600;
scenario.timeStepS = 60;
scenario.convergence.enabled = false;
scenario.warmupOrbits = 1;
network = leotherm.defaultReceiverNetwork;
meshPath = fullfile(outputDirectory, 'gui_smoke_mesh.obj');
writeSmokeMesh(meshPath);
app.loadSurfaceMesh(meshPath, 1);
meshScenario = scenario;
meshScenario.durationS = 600;
meshScenario.warmupOrbits = 0;
meshThermal = struct('capacityJK', 10000 * ones(4, 1), 'maximumStepS', 10);
meshResult = app.runSurfaceMesh(meshScenario, meshThermal);
assert(all(isfinite(meshResult.temperatureK), 'all'), 'Mesh thermal result is not finite.');
volumePath = fullfile(outputDirectory, 'gui_smoke_volume.msh');
writeSmokeVolumeMesh(volumePath);
app.loadVolumeMesh(volumePath);
volumeTime = (0:60:600)';
volumePower = zeros(numel(volumeTime), 5);
volumeResult = app.runVolumeThermal(volumeTime, volumePower, ...
    struct('conductivityWmK', 1, 'densityKgM3', 1000, 'specificHeatJkgK', 1000), ...
    struct('initialTemperatureK', 293.15, 'maximumTemperatureK', 500));
assert(all(isfinite(volumeResult.temperatureK), 'all'), 'Volume thermal result is not finite.');
result = app.runScenario(scenario, network);
taskGuidance = findall(app.Figure, 'Tag', 'TaskGuidanceLabel');
assert(isscalar(taskGuidance), 'Missing task guidance label.');
if strcmp(language, 'zh')
    assert(~contains(taskGuidance.Text, 'tetrahedral') && ...
        ~contains(taskGuidance.Text, 'surface mesh') && ...
        ~contains(taskGuidance.Text, 'Telemetry results'), ...
        'Chinese task guidance contains untranslated English diagnostics.');
end
% Regression: changing a network input must make the existing scenario result
% visibly stale, and restoring the input must clear that state again.
nodeTable = findall(app.Figure, 'Tag', 'NetworkNodeTable');
assert(isscalar(nodeTable), 'Missing network node table for stale-result regression.');
nodeData = nodeTable.Data;
originalPower = nodeData.internal_power(1);
nodeData.internal_power(1) = originalPower + 1e-6;
nodeTable.Data = nodeData;
nodeTable.CellEditCallback(nodeTable, struct('Indices', [1 4]));
stateLabel = findall(app.Figure, 'Tag', 'ResultStateLabel');
scenarioStaleText = pick(language, '单场景结果已过期', 'Scenario result is stale');
assert(isscalar(stateLabel) && contains(stateLabel.Text, scenarioStaleText), ...
    'Editing the network must mark the scenario result stale.');
nodeData.internal_power(1) = originalPower;
nodeTable.Data = nodeData;
nodeTable.CellEditCallback(nodeTable, struct('Indices', [1 4]));
assert(~contains(stateLabel.Text, scenarioStaleText), ...
    'Restoring the network input must clear the scenario stale-result state.');
sweep = app.runSweep('beta_altitude', scenario, network, 600, [0, 30], 1);
[raw, ~, options] = leotherm.telemetryDemo(network, true);
app.TelemetryWorkspace.importSource(raw);
calibrationBefore = prepareCalibrationSmoke(app, outputDirectory);
[telemetryResult, telemetryReport] = app.TelemetryWorkspace.run(options);
assert(all(abs(telemetryReport.metrics.rmse_k - 0.2) < 1e-9), ...
    'Synthetic telemetry offset was not recovered.');
assert(telemetryResult.provenance.boundaryConditioning, 'Boundary forcing was not connected in the GUI.');
other = 'en'; if strcmp(language, 'en'), other = 'zh'; end
app.CalibrationWorkspace.Tab.Parent.SelectedTab = app.CalibrationWorkspace.Tab;
app.setLanguage(other);
verifyCalibrationDisplay(app, calibrationBefore, other);
app.setLanguage(language);
verifyCalibrationDisplay(app, calibrationBefore, language);
restored = app.TelemetryWorkspace.getState;
assert(strcmp(restored.selectedNode,network.nodeNames{network.roles.response}), ...
    'The boundary-connected measured node should be selected for inspection.');
assert(isequaln(restored.result.temperatureK, telemetryResult.temperatureK), ...
    'Language switching changed telemetry results.');
drawnow;
pause(0.5);

state = app.getState;
diagnostics.version = state.version;
diagnostics.language = state.language;
diagnostics.figureValid = isvalid(app.Figure);
tabs = app.TelemetryWorkspace.Tab.Parent.Children;
diagnostics.tabCount = numel(tabs);
resultTab = findall(app.Figure, 'Type', 'uitab', 'Title', ...
    pick(language, '结果与导出', 'Results and export'));
assert(numel(resultTab) == 1, 'Missing outer results tab.');
diagnostics.mainTabCount = numel(resultTab.Parent.Children);
diagnostics.resultEpochs = numel(result.timeS);
diagnostics.temperatureFinite = all(isfinite(result.temperatureK), 'all');
diagnostics.meshFaces = size(meshResult.mesh.faces, 1);
diagnostics.meshTemperatureFinite = all(isfinite(meshResult.temperatureK), 'all');
diagnostics.volumeNodes = volumeResult.mesh.nodeCount;
diagnostics.volumeTemperatureFinite = all(isfinite(volumeResult.temperatureK), 'all');
diagnostics.sweepRows = height(sweep);
diagnostics.sweepComplete = sum(strcmp(sweep.status, 'complete'));
diagnostics.legendCount = numel(findall(app.Figure, 'Type', 'legend'));
diagnostics.boundaryConditioning = telemetryReport.boundaryConditioning;
diagnostics.calibrationProfileRows = height(state.calibration.profile.parameters);
diagnostics.calibrationDayRows = height(state.calibration.split);
diagnostics.calibrationStatePreserved = true;
diagnostics.calibrationFitRun = false;
allLegends = findall(app.Figure,'Type','legend');
expected = '规定的边界温度';
if strcmp(language,'en'), expected = 'Prescribed boundary temperature'; end
hasBoundaryLegend = false;
for k = 1:numel(allLegends)
    hasBoundaryLegend = hasBoundaryLegend || any(strcmp(allLegends(k).String,expected));
end
assert(hasBoundaryLegend,'The selected boundary curve needs a localized legend.');
[screenshots, screenshotBytes] = exportTabs( ...
    app.Figure, tabs, outputDirectory, language);
resultTab.Parent.SelectedTab = resultTab;
drawnow;
resultPath = fullfile(outputDirectory, 'gui_results.png');
exportapp(app.Figure, resultPath);
resultInfo = dir(resultPath);
screenshots{end + 1} = resultPath;
screenshotBytes(end + 1) = resultInfo.bytes;
diagnostics.screenshots = screenshots;
diagnostics.minimumScreenshotBytes = min(screenshotBytes);

assert(diagnostics.figureValid, 'GUI figure is not valid.');
assert(diagnostics.tabCount == 7, 'GUI must contain seven configuration tabs.');
assert(diagnostics.mainTabCount == 3, 'GUI must contain quick start, simulation, and results tabs.');
assert(diagnostics.resultEpochs > 1, 'GUI smoke scenario returned no time series.');
assert(diagnostics.temperatureFinite, 'GUI smoke scenario contains non-finite temperatures.');
assert(diagnostics.volumeNodes == 5 && diagnostics.volumeTemperatureFinite, ...
    'GUI volume conduction workflow did not complete.');
assert(diagnostics.sweepRows == 2 && diagnostics.sweepComplete == 2, ...
    'GUI smoke sweep did not complete both cases.');
assert(diagnostics.legendCount >= 10, ...
    'Every scenario and sweep plot must contain a legend.');
assert(diagnostics.minimumScreenshotBytes > 10000, ...
    'One or more GUI screenshots are unexpectedly small.');

save(fullfile(outputDirectory, 'gui_smoke.mat'), 'diagnostics', 'result');
writeStatus(fullfile(outputDirectory, 'gui_smoke_status.txt'), diagnostics);
clear cleanup
end

function [paths, sizes] = exportTabs(figureHandle, tabs, outputDirectory, language)
if strcmp(language, 'zh')
    titles = {'单场景', '参数扫描', '热网络', '三维几何', '工程热模型', '遥测与验证', '设备标定'};
else
    titles = {'Single scenario', 'Parameter sweep', ...
        'Thermal network', '3-D geometry', 'Engineering thermal model', ...
        'Telemetry and validation', 'Device calibration'};
end
names = {'scenario', 'sweep', 'network', 'geometry', 'thermal_model', ...
    'telemetry', 'calibration'};
paths = cell(numel(titles), 1);
sizes = zeros(numel(titles), 1);
for k = 1:numel(titles)
    index = find(strcmp({tabs.Title}, titles{k}), 1);
    assert(~isempty(index), 'Missing GUI tab: %s', titles{k});
    tabs(index).Parent.SelectedTab = tabs(index);
    drawnow;
    paths{k} = fullfile(outputDirectory, ['gui_' names{k} '.png']);
    exportapp(figureHandle, paths{k});
    info = dir(paths{k});
    sizes(k) = info.bytes;
end
end

function writeStatus(path, diagnostics)
file = fopen(path, 'w');
assert(file >= 0, 'Cannot create GUI smoke-test status file.');
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'outcome=complete\n');
fprintf(file, 'version=%s\n', diagnostics.version);
fprintf(file, 'language=%s\n', diagnostics.language);
fprintf(file, 'tabs=%d\n', diagnostics.tabCount);
fprintf(file, 'main_tabs=%d\n', diagnostics.mainTabCount);
fprintf(file, 'result_epochs=%d\n', diagnostics.resultEpochs);
fprintf(file, 'temperature_finite=%d\n', diagnostics.temperatureFinite);
fprintf(file, 'mesh_faces=%d\n', diagnostics.meshFaces);
fprintf(file, 'mesh_temperature_finite=%d\n', diagnostics.meshTemperatureFinite);
fprintf(file, 'volume_nodes=%d\n', diagnostics.volumeNodes);
fprintf(file, 'volume_temperature_finite=%d\n', diagnostics.volumeTemperatureFinite);
fprintf(file, 'sweep_rows=%d\n', diagnostics.sweepRows);
fprintf(file, 'sweep_complete=%d\n', diagnostics.sweepComplete);
fprintf(file, 'legend_count=%d\n', diagnostics.legendCount);
fprintf(file, 'calibration_profile_rows=%d\n', diagnostics.calibrationProfileRows);
fprintf(file, 'calibration_day_rows=%d\n', diagnostics.calibrationDayRows);
fprintf(file, 'calibration_state_preserved=%d\n', diagnostics.calibrationStatePreserved);
fprintf(file, 'calibration_fit_run=%d\n', diagnostics.calibrationFitRun);
fprintf(file, 'minimum_screenshot_bytes=%d\n', ...
    diagnostics.minimumScreenshotBytes);
clear cleanup
end

function value = pick(language, chinese, english)
value = english;
if strcmp(language, 'zh')
    value = chinese;
end
end

function writeSmokeMesh(path)
fid = fopen(path, 'w');
assert(fid >= 0, 'Cannot create GUI mesh fixture.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\n');
fprintf(fid, 'f 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n');
clear cleanup
end

function writeSmokeVolumeMesh(path)
fid = fopen(path, 'w');
assert(fid >= 0, 'Cannot create GUI volume mesh fixture.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '$MeshFormat\n2.2 0 8\n$EndMeshFormat\n$Nodes\n5\n');
fprintf(fid, '1 0 0 0\n2 1 0 0\n3 0 1 0\n4 0 0 1\n5 1 1 1\n$EndNodes\n');
fprintf(fid, '$Elements\n2\n1 4 0 1 2 3 4\n2 4 0 2 3 4 5\n$EndElements\n');
clear cleanup
end

function state = prepareCalibrationSmoke(app, directory)
panel = app.CalibrationWorkspace;
telemetry = app.TelemetryWorkspace.getState;
assert(isempty(telemetry.data), 'This check must start before telemetry simulation.');
panel.loadCurrentDevice;
panel.loadTelemetryDays;
state = panel.getState;
p = state.profile.parameters;
assert(~any(p.estimate) && all(p.lower == p.nominal & p.upper == p.nominal), ...
    'Default parameters must be locked at the current device values.');
assert(all(p.priorSigma == 0) && all(p.evidence == "") && all(p.kind == "unverified"), ...
    'Default priors must not invent uncertainties or evidence.');
assert(~isempty(state.split) && all(state.split.role == "exclude"), ...
    'Every telemetry day must initially be excluded.');
assert(state.settings.temperatureSigmaK == 1 && state.settings.regularizationWeight == 1 ...
    && isempty(state.settings.sensorEvidence) && isnan(state.settings.rmseToleranceK), ...
    'Sensor evidence and RMSE acceptance must be explicitly declared.');
assert(~state.settings.independentHoldoutConfirmed && ~state.settings.forcingIndependenceConfirmed ...
    && ~state.settings.parameterEvidenceConfirmed, 'Confirmations must default to false.');
assert(isempty(state.result), 'Loading a profile or days must not fit a model.');
telemetryAfter = app.TelemetryWorkspace.getState;
assert(isempty(telemetryAfter.data), 'Calibration must read telemetry without running its workspace.');

profileTable = findall(panel.Tab, 'Tag', 'CalibrationProfileTable');
assert(~any(profileTable.ColumnEditable(1:5)) && all(profileTable.ColumnEditable(6:11)), ...
    'Identifiers, units and nominal values must be read-only.');
row = find(p.field == "capacityJK", 1);
nominal = p.nominal(row);
editCell(profileTable, row, 6, 0.9 * nominal);
editCell(profileTable, row, 7, 1.1 * nominal);
editCell(profileTable, row, 8, 0.1 * nominal);
editCell(profileTable, row, 10, 'Synthetic GUI state fixture only; not device evidence.');
language = app.getState; language = language.language;
editCell(profileTable, row, 11, char(leotherm.deviceCalibrationText('physical', language)));
editCell(profileTable, row, 9, true);
dayTable = findall(panel.Tab, 'Tag', 'CalibrationDayTable');
editCell(dayTable, 1, 2, char(leotherm.deviceCalibrationText('train', language)));
evidence = findall(panel.Tab, 'Tag', 'CalibrationSensorEvidence');
evidence.Value = 'Synthetic GUI state fixture only; no sensor characterization.';
evidence.ValueChangedFcn(evidence, []);
tolerance = findall(panel.Tab, 'Tag', 'CalibrationTolerance');
tolerance.Value = '0.75';
tolerance.ValueChangedFcn(tolerance, []);
state = panel.getState;
assert(isnan(state.settings.rmseToleranceK) && ~state.toleranceEnabled ...
    && strcmp(state.toleranceDraft, '0.75'), 'An unchecked draft must not become an acceptance limit.');
assert(state.profile.parameters.nominal(row) == nominal, 'Editing priors changed a nominal value.');

path = [tempname(directory) '.mat'];
panel.exportProfile(path);
loaded = load(path, 'profile');
assert(isequaln(loaded.profile, state.profile), 'MAT export changed raw profile tokens.');
panel.importProfile(path);
assertError(@() panel.exportProfile(path), 'leotherm:DeviceCalibrationExport');
assertError(@() panel.run([], [], [], directory), 'leotherm:DeviceCalibrationExport');
state = panel.getState;
stale = state;
stale.profile.referenceNetwork.name = 'deliberately_stale_GUI_fixture';
panel.restoreState(stale);
newDirectory = tempname(directory);
assertError(@() panel.run([], [], [], newDirectory), 'leotherm:DeviceCalibrationProfile');
assert(~isfolder(newDirectory), 'Stale device validation must precede output creation.');
panel.restoreState(state);
panel.setEnabled(false);
assert(strcmp(profileTable.Enable, 'off') && strcmp(dayTable.Enable, 'off'), ...
    'Busy state must disable editable calibration tables.');
panel.setEnabled(true);
assert(strcmp(tolerance.Enable, 'off'), 'An unchecked tolerance must stay disabled after busy state.');
state = panel.getState;
end

function verifyCalibrationDisplay(app, before, language)
panel = app.CalibrationWorkspace;
after = panel.getState;
assert(isequaln(before.profile, after.profile) && isequaln(before.split, after.split) ...
    && isequaln(before.settings, after.settings), 'Language switching changed calibration inputs.');
assert(strcmp(after.toleranceDraft, before.toleranceDraft) && ~after.toleranceEnabled, ...
    'Language switching lost an unchecked tolerance draft.');
assert(isempty(after.result), 'The smoke test did not fit and must not claim calibration success.');
assert(panel.Tab.Parent.SelectedTab == panel.Tab, 'Language switching lost the selected calibration tab.');
profileTable = findall(panel.Tab, 'Tag', 'CalibrationProfileTable');
days = findall(panel.Tab, 'Tag', 'CalibrationDayTable');
p = after.profile.parameters;
assert(strcmp(profileTable.Data{1,1}, char(leotherm.deviceCalibrationText(p.field(1), language))), ...
    'Parameter field display is not localized.');
row = find(p.estimate, 1);
assert(strcmp(profileTable.Data{row,11}, char(leotherm.deviceCalibrationText(p.kind(row), language))), ...
    'Parameter-kind display is not localized.');
assert(strcmp(days.Data{1,2}, char(leotherm.deviceCalibrationText(after.split.role(1), language))), ...
    'Day-role display is not localized.');
expectedTitle = 'Device calibration'; expectedHeader = 'Nominal (read-only)';
if strcmp(language, 'zh'), expectedTitle = '设备标定'; expectedHeader = '标称值（只读）'; end
assert(strcmp(panel.Tab.Title, expectedTitle) && strcmp(profileTable.ColumnName{5}, expectedHeader), ...
    'Calibration tab or table header is not localized.');
end

function editCell(handle, row, column, value)
event = struct('Indices', [row column], 'NewData', value);
handle.CellEditCallback(handle, event);
end

function assertError(action, expected)
caught = false;
try
    action();
catch exception
    assert(strcmp(exception.identifier, expected), 'Unexpected failure: %s', exception.message);
    caught = true;
end
assert(caught, 'Expected rejection: %s', expected);
end
