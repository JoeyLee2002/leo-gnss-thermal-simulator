function tests = test_unified_report
tests = functiontests(localfunctions);
end

function testScenarioReportIsBilingualAndTraceable(testCase)
previous = get(groot, 'DefaultFigureVisible');
cleanupFigure = onCleanup(@() set(groot, 'DefaultFigureVisible', previous));
set(groot, 'DefaultFigureVisible', 'off');
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.convergence.enabled = false;
scenario.warmupOrbits = 0;
result = leotherm.simulateScenario(scenario, leotherm.defaultReceiverNetwork);
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
report = leotherm.writeThermalReport(result, outDir, 'both');
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_manifest.json')));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_report_zh.md')));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_report_en.md')));
verifyPdf(testCase, fullfile(outDir, 'thermal_report_zh.pdf'));
verifyPdf(testCase, fullfile(outDir, 'thermal_report_en.pdf'));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_sections.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_energy.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_diagnostics.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'thermal_telemetry.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'scenario_summary_zh.png')));
verifyTrue(testCase, isfile(fullfile(outDir, 'scenario_summary_en.png')));
sections = readtable(fullfile(outDir, 'thermal_sections.csv'));
verifyTrue(testCase, any(strcmp(sections.section, 'orbit_attitude')));
verifyTrue(testCase, any(strcmp(sections.status, 'not_available'))); % telemetry is absent
manifest = jsondecode(fileread(fullfile(outDir, 'thermal_manifest.json')));
verifyEqual(testCase, manifest.softwareVersion, leotherm.version);
verifyFalse(testCase, manifest.telemetryValidation);
verifyEqual(testCase, numel(manifest.pdfReports), 2);
verifyEqual(testCase, report.softwareVersion, leotherm.version);
verifyTrue(testCase, contains(fileread(fullfile(outDir, ...
    'thermal_report_zh.md')), '未做预热'));
end

function testImportedTelemetryAloneIsNotValidation(testCase)
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
input = struct('telemetry', struct('data', table((1:3)', ...
    'VariableNames', {'sample'})));
leotherm.writeThermalReport(input, outDir, 'zh');
manifest = jsondecode(fileread(fullfile(outDir, 'thermal_manifest.json')));
verifyFalse(testCase, manifest.telemetryValidation);
verifyPdf(testCase, fullfile(outDir, 'thermal_report_zh.pdf'));
end

function testCombinedResultsKeepEachModuleInThePdfBundle(testCase)
previous = get(groot, 'DefaultFigureVisible');
cleanupFigure = onCleanup(@() set(groot, 'DefaultFigureVisible', previous));
set(groot, 'DefaultFigureVisible', 'off');
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
result = leotherm.simulateScenario(scenario, leotherm.defaultReceiverNetwork);
sweep = leotherm.runBetaAltitudeSweep(scenario, result.network, 600, 0, 1);
surface = struct('mesh', struct('faces', [1 2 3], 'faceAreasM2', 1), ...
    'temperatureK', [290; 291], 'numerics', struct);
volume = struct('mesh', struct('nodesM', zeros(4,3), ...
    'tetrahedra', [1 2 3 4]), 'model', struct, ...
    'temperatureK', [289; 292], 'diagnostics', struct);
bundle = struct('scenarioResult', result, 'sweep', sweep, ...
    'surfaceResult', surface, 'volumeResult', volume, ...
    'metadata', struct('scenarioStale', true, 'sweepStale', false));
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
leotherm.writeThermalReport(bundle, outDir, 'zh');
manifest = jsondecode(fileread(fullfile(outDir, 'thermal_manifest.json')));
verifyTrue(testCase, manifest.metadata.scenarioStale);
verifyTrue(testCase, isfile(fullfile(outDir, 'scenario_summary_zh.png')));
verifyTrue(testCase, isfile(fullfile(outDir, 'sweep_summary_zh.png')));
verifyPdf(testCase, fullfile(outDir, 'thermal_report_zh.pdf'));
sections = readtable(fullfile(outDir, 'thermal_sections.csv'));
verifyTrue(testCase, any(strcmp(sections.section, 'surface_mesh')));
verifyTrue(testCase, any(strcmp(sections.section, 'volume_mesh')));
clear cleanup cleanupFigure
end

function verifyPdf(testCase, path)
verifyTrue(testCase, isfile(path));
info = dir(path);
verifyGreaterThan(testCase, info.bytes, 10000);
fid = fopen(path, 'rb');
cleanup = onCleanup(@() fclose(fid));
verifyEqual(testCase, fread(fid, 5, '*char')', '%PDF-');
end

function testReportRejectsNonEmptyDirectory(testCase)
outDir = tempname; mkdir(outDir);
cleanup = onCleanup(@() removeFolder(outDir));
fid = fopen(fullfile(outDir, 'existing.txt'), 'w'); fprintf(fid, 'x'); fclose(fid);
verifyError(testCase, @() leotherm.writeThermalReport(struct, outDir), ...
    'leotherm:ReportExport');
end

function testCalibrationAnalysisUsesDeclaredRoleMetrics(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
result = leotherm.simulateScenario(scenario, leotherm.defaultReceiverNetwork);
metrics = table(["train";"validation";"test"], ...
    ["rf";"rf";"rf"], [20;10;10], [4;5;6], [2;3;4], ...
    'VariableNames', {'role','node','used_samples', ...
    'baseline_rmse_k','calibrated_rmse_k'});
calibration = struct('status', 'accepted_within_declared_scope', ...
    'stageMetrics', metrics);
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
report = leotherm.writeThermalReport(struct('scenarioResult', result, ...
    'calibration', calibration), outDir, 'both');
verifyTrue(testCase, any(strcmp({report.analysis.stage}, 'calibration')));
verifyTrue(testCase, isfile(fullfile(outDir, 'calibration_summary_zh.png')));
verifyTrue(testCase, isfile(fullfile(outDir, 'calibration_summary_en.png')));
verifyTrue(testCase, contains(fileread(fullfile(outDir, ...
    'thermal_report_zh.md')), '训练集'));
verifyTrue(testCase, contains(fileread(fullfile(outDir, ...
    'thermal_report_en.md')), 'Training error is not independent validation'));
verifyPdf(testCase, fullfile(outDir, 'thermal_report_zh.pdf'));
clear cleanup
end

function testUnscoredTelemetryReportStatesNoAgreement(testCase)
metrics = table("rf", 0, NaN, "insufficient_samples", ...
    'VariableNames', {'node','used_samples','rmse_k','assessment'});
comparison = struct('metrics', metrics, 'samples', table, ...
    'datasetKind', 'synthetic_demo_not_flight_data', ...
    'independence', 'synthetic_not_independent_validation');
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
report = leotherm.writeThermalReport( ...
    struct('telemetry', struct('report', comparison)), outDir, 'zh');
verifyTrue(testCase, any(strcmp({report.analysis.stage}, 'telemetry')));
verifyFalse(testCase, isfile(fullfile(outDir, 'telemetry_summary_zh.png')));
verifyTrue(testCase, contains(fileread(fullfile(outDir, ...
    'thermal_report_zh.md')), '没有可评分样本'));
manifest = jsondecode(fileread(fullfile(outDir, 'thermal_manifest.json')));
verifyFalse(testCase, manifest.telemetryValidation);
verifyPdf(testCase, fullfile(outDir, 'thermal_report_zh.pdf'));
clear cleanup
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
