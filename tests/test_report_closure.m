function tests = test_report_closure
tests = functiontests(localfunctions);
end

function testScenarioRunExportsAuditablePdf(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanupApp = onCleanup(@() delete(app));
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
app.runScenario(scenario, leotherm.defaultReceiverNetwork);
output = tempname;
cleanupOutput = onCleanup(@() removeFolder(output));
app.exportResults(output);
pdfPath = fullfile(output, 'report', 'thermal_report_zh.pdf');
verifyPdf(testCase, pdfPath);
manifest = jsondecode(fileread(fullfile(output, 'report', 'thermal_manifest.json')));
verifyFalse(testCase, manifest.telemetryValidation);
verifyFalse(testCase, manifest.metadata.scenarioStale);
verifyTrue(testCase, isfile(fullfile(output, 'scenario', 'timeseries.csv')));
clear cleanupOutput cleanupApp
end

function testTelemetryOnlyRunCanExportReport(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanupApp = onCleanup(@() delete(app));
[raw, ~, options] = leotherm.telemetryDemo(leotherm.defaultReceiverNetwork, true);
app.TelemetryWorkspace.importSource(raw);
app.TelemetryWorkspace.run(options);
output = tempname;
cleanupOutput = onCleanup(@() removeFolder(output));
app.exportResults(output);
pdfPath = fullfile(output, 'report', 'thermal_report_zh.pdf');
verifyPdf(testCase, pdfPath);
manifest = jsondecode(fileread(fullfile(output, 'report', 'thermal_manifest.json')));
verifyTrue(testCase, manifest.telemetryValidation);
clear cleanupOutput cleanupApp
end

function testTelemetryResultAppearsInMainResults(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanupApp = onCleanup(@() delete(app));
[raw, ~, options] = leotherm.telemetryDemo(leotherm.defaultReceiverNetwork, true);
app.TelemetryWorkspace.importSource(raw);
app.TelemetryWorkspace.run(options);
app.setLanguage('en');
conclusion = findobj(app.Figure, 'Tag', 'ResultConclusionLabel');
verifyTrue(testCase, contains(conclusion.Text, 'Telemetry comparison is complete'));
button = findobj(app.Figure, 'Tag', 'TaskResultsButton');
verifyEqual(testCase, char(button.Enable), 'on');
tableControl = findobj(app.Figure, 'Type', 'uitable');
matches = arrayfun(@(item) strcmp(strjoin(cellstr(string(item.ColumnName)), '|'), ...
    'Temperature node|Scored pairs|RMSE (K)|Assessment'), tableControl);
verifyTrue(testCase, any(matches));
clear cleanupApp
end

function testStaleTelemetryCannotEnterReport(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'en');
cleanupApp = onCleanup(@() delete(app));
[raw, ~, options] = leotherm.telemetryDemo(leotherm.defaultReceiverNetwork, true);
app.TelemetryWorkspace.importSource(raw);
app.TelemetryWorkspace.run(options);
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
app.runScenario(scenario, leotherm.defaultReceiverNetwork);
output = tempname;
verifyError(testCase, @() app.exportResults(output), 'leotherm:StaleResult');
verifyFalse(testCase, isfolder(output));
clear cleanupApp
end

function testTelemetryTemplateUsesOptionalPipelineStage(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'en');
cleanupApp = onCleanup(@() delete(app));
state = app.getState;
root = leotherm.installRoot;
templatePath = fullfile(root, 'templates', '04_telemetry_validation.json');
state.activeTemplateId = 'telemetry_validation';
state.activeTemplatePath = templatePath;
state.activeTemplateSnapshot = leotherm.readSimulationTemplate(templatePath);
state.pipelineOptions.telemetry = true;
state.scenario.durationS = 120;
state.scenario.timeStepS = 60;
state.scenario.warmupOrbits = 0;
state.scenario.convergence.enabled = false;
projectPath = [tempname '.mat'];
cleanupProject = onCleanup(@() removeFile(projectPath));
leotherm.writeWorkspaceProject(projectPath, state, false);
app.loadProject(projectPath);
button = findobj(app.Figure, 'Tag', 'TaskRunButton');
verifyEqual(testCase, button.Text, 'Run task');
verifyEqual(testCase, char(button.Enable), 'off');
telemetryCheck = findobj(app.Figure, 'Tag', 'PipelineTelemetryCheck');
verifyTrue(testCase, telemetryCheck.Value);
telemetryCheck.Value = false;
telemetryCheck.ValueChangedFcn(telemetryCheck, []);
verifyEqual(testCase, char(button.Enable), 'on');
telemetryCheck.Value = true;
telemetryCheck.ValueChangedFcn(telemetryCheck, []);
verifyEqual(testCase, char(button.Enable), 'off');
[raw, ~, options] = leotherm.telemetryDemo(leotherm.defaultReceiverNetwork, true);
app.TelemetryWorkspace.importSource(raw);
telemetryState = app.TelemetryWorkspace.getState;
telemetryState.options = options;
app.TelemetryWorkspace.restoreState(telemetryState);
output = tempname;
cleanupOutput = onCleanup(@() removeFolder(output));
run = app.runPipeline(output);
verifyEqual(testCase, run.status, 'complete');
verifyNotEmpty(testCase, run.telemetry.report);
verifyTrue(testCase, isfile(fullfile(output, 'report', 'thermal_report_en.pdf')));
verifyEqual(testCase, char(findobj(app.Figure, 'Tag', 'TaskResultsButton').Enable), 'on');
clear cleanupOutput cleanupProject cleanupApp
end

function testOptionalStageChoicesPersistInProject(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanupApp = onCleanup(@() delete(app));
state = app.getState;
state.pipelineOptions = struct('sweep', true, 'geometry', false, ...
    'telemetry', true, 'calibration', false);
projectPath = [tempname '.mat'];
cleanupProject = onCleanup(@() removeFile(projectPath));
leotherm.writeWorkspaceProject(projectPath, state, false);
app.loadProject(projectPath);
restored = app.getState;
verifyEqual(testCase, restored.pipelineOptions, state.pipelineOptions);
verifyTrue(testCase, findobj(app.Figure, 'Tag', 'PipelineSweepCheck').Value);
verifyFalse(testCase, findobj(app.Figure, 'Tag', 'PipelineGeometryCheck').Value);
verifyTrue(testCase, findobj(app.Figure, 'Tag', 'PipelineTelemetryCheck').Value);
verifyFalse(testCase, findobj(app.Figure, 'Tag', 'PipelineCalibrationCheck').Value);
verifyEqual(testCase, char(findobj(app.Figure, 'Tag', 'TaskRunButton').Enable), 'off');
clear cleanupProject cleanupApp
end

function testChineseOptionalStagePreflightGuidance(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanupApp = onCleanup(@() delete(app));
cases = { ...
    'PipelineTelemetryCheck', '遥测'; ...
    'PipelineGeometryCheck', '三维'; ...
    'PipelineCalibrationCheck', '标定'};
guidance = findobj(app.Figure, 'Tag', 'TaskGuidanceLabel');
runButton = findobj(app.Figure, 'Tag', 'TaskRunButton');
for k = 1:size(cases, 1)
    check = findobj(app.Figure, 'Tag', cases{k, 1});
    check.Value = true;
    check.ValueChangedFcn(check, []);
    verifyTrue(testCase, contains(guidance.Text, cases{k, 2}));
    verifyEqual(testCase, char(runButton.Enable), 'off');
    check.Value = false;
    check.ValueChangedFcn(check, []);
    verifyEqual(testCase, char(runButton.Enable), 'on');
end
clear cleanupApp
end

function verifyPdf(testCase, path)
verifyTrue(testCase, isfile(path));
fid = fopen(path, 'rb');
cleanup = onCleanup(@() fclose(fid));
verifyEqual(testCase, fread(fid, 5, '*char')', '%PDF-');
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end

function removeFile(path)
if isfile(path), delete(path); end
end
