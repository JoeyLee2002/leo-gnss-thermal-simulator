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

function verifyPdf(testCase, path)
verifyTrue(testCase, isfile(path));
fid = fopen(path, 'rb');
cleanup = onCleanup(@() fclose(fid));
verifyEqual(testCase, fread(fid, 5, '*char')', '%PDF-');
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
