function tests = test_thermal_pipeline
tests = functiontests(localfunctions);
end

function testDefaultTaskPreflight(testCase)
task = shortTask;
audit = leotherm.preflightThermalPipeline(task);
verifyTrue(testCase, audit.ready);
verifyEqual(testCase, audit.stages, ...
    ["preflight","nodal_simulation","numerical_acceptance","report"]);
end

function testDisabledOptionsDoNotRequireTheirInputs(testCase)
task = shortTask;
task.sweep.mode = 'not_a_mode';
task.geometry.solver = 'not_a_solver';
task.telemetry.source = 'missing.csv';
task.calibration.profile = [];
audit = leotherm.preflightThermalPipeline(task);
verifyTrue(testCase, audit.ready);
verifyEqual(testCase, audit.stages, ...
    ["preflight","nodal_simulation","numerical_acceptance","report"]);
end

function testMissingCoupledInputsFailBeforeOutput(testCase)
task = shortTask;
task.geometry.enabled = true;
audit = leotherm.preflightThermalPipeline(task);
verifyFalse(testCase, audit.ready);
output = tempname;
verifyError(testCase, @() leotherm.runThermalPipeline(task, output), ...
    'leotherm:PipelinePreflight');
verifyFalse(testCase, isfolder(output));
end

function testScenarioTaskProducesOneRunAndReport(testCase)
task = shortTask;
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
run = leotherm.runThermalPipeline(task, output);
verifyEqual(testCase, run.status, 'complete');
verifyTrue(testCase, run.acceptance.passed);
verifyEqual(testCase, numel(run.stages), 9);
verifyEqual(testCase, {run.stages(2).status, run.stages(5).status, ...
    run.stages(6).status, run.stages(7).status}, ...
    {'skipped','skipped','skipped','skipped'});
verifyTrue(testCase, isfile(fullfile(output, 'input_snapshot.mat')));
verifyTrue(testCase, isfile(fullfile(output, 'pipeline_status.json')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'thermal_report_en.pdf')));
analysis = reportAnalysis(output);
verifyEqual(testCase, {analysis.stage}, {'scenario'});
manifest = jsondecode(fileread(fullfile(output, 'report', 'thermal_manifest.json')));
verifyEqual(testCase, manifest.metadata.taskId, run.taskId);
verifyEqual(testCase, manifest.metadata.inputFingerprint, run.inputFingerprint);
verifyError(testCase, @() leotherm.runThermalPipeline(task, output), ...
    'leotherm:PipelineOutput');
clear cleanup
end

function testTelemetryTaskPreflightRejectsMissingSource(testCase)
task = shortTask;
task.telemetry.enabled = true;
audit = leotherm.preflightThermalPipeline(task);
verifyFalse(testCase, audit.ready);
end

function testTelemetryDrivenRunProducesComparison(testCase)
task = shortTask;
[raw, ~, options] = leotherm.telemetryDemo(task.network, true);
task.telemetry.enabled = true;
task.telemetry.source = raw;
task.telemetry.options = options;
audit = leotherm.preflightThermalPipeline(task);
verifyTrue(testCase, audit.ready);
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
run = leotherm.runThermalPipeline(task, output);
verifyEqual(testCase, run.status, 'complete');
verifyGreaterThan(testCase, sum(run.telemetry.report.metrics.used_samples), 0);
manifest = jsondecode(fileread(fullfile(output, 'report', 'thermal_manifest.json')));
verifyTrue(testCase, manifest.telemetryValidation);
analysis = reportAnalysis(output);
verifyTrue(testCase, any(strcmp({analysis.stage}, 'telemetry')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'telemetry_summary_en.png')));
verifyTrue(testCase, contains(fileread(fullfile(output, 'report', ...
    'thermal_report_en.md')), 'synthetic-data comparison'));
clear cleanup
end

function testSweepUsesBatchStage(testCase)
task = shortTask;
task.sweep.enabled = true;
task.sweep.mode = 'beta_altitude';
task.sweep.altitudeKm = 600;
task.sweep.betaDeg = 0;
task.sweep.branch = 1;
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
run = leotherm.runThermalPipeline(task, output);
verifyEqual(testCase, run.status, 'complete');
verifyEqual(testCase, height(run.sweep), 1);
verifyEqual(testCase, run.sweep.status{1}, 'complete');
analysis = reportAnalysis(output);
verifyTrue(testCase, any(strcmp({analysis.stage}, 'sweep')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'sweep_summary_en.png')));
verifyTrue(testCase, contains(fileread(fullfile(output, 'report', ...
    'thermal_report_en.md')), 'not a trend or an optimum'));
clear cleanup
end

function testCoupledMeshRunsInsidePipeline(testCase)
task = shortTask;
task.geometry.enabled = true;
task.scenario.durationS = 20;
task.scenario.timeStepS = 10;
[task.surfaceMesh, task.volumeMesh] = tetraFixtures;
task.material = struct('conductivityWmK', 1, 'densityKgM3', 1000, ...
    'specificHeatJkgK', 1000);
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
run = leotherm.runThermalPipeline(task, output);
verifyEqual(testCase, run.status, 'complete');
verifyFalse(testCase, run.coupled.provenance.surfaceTemperatureFeedback);
verifyTrue(testCase, run.acceptance.passed);
analysis = reportAnalysis(output);
verifyTrue(testCase, any(strcmp({analysis.stage}, 'geometry')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'geometry_summary_en.png')));
verifyTrue(testCase, contains(fileread(fullfile(output, 'report', ...
    'thermal_report_en.md')), 'Coupling is one-way'));
clear cleanup
end

function testCalibrationCannotReuseValidationEpochs(testCase)
task = shortTask;
[raw, ~, options] = leotherm.telemetryDemo(task.network, true);
task.telemetry.enabled = true;
task.telemetry.source = raw;
task.telemetry.options = options;
task.telemetry.workflow = 'validation';
task.calibration.enabled = true;
differentSource = raw;
differentSource.quality(1) = 0;
task.calibration.source = differentSource;
task.calibration.profile = leotherm.deviceCalibrationProfile(task.network);
task.calibration.split = leotherm.calibrationDaySplit( ...
    leotherm.readTelemetry(raw, [], task.network));
audit = leotherm.preflightThermalPipeline(task);
verifyFalse(testCase, audit.ready);
verifyEqual(testCase, audit.errorIdentifier, "leotherm:PipelineDataLeakage");
end

function task = shortTask
task = leotherm.createThermalPipelineTask;
task.scenario.durationS = 120;
task.scenario.timeStepS = 60;
task.scenario.warmupOrbits = 0;
task.scenario.convergence.enabled = false;
task.language = 'en';
end

function analysis = reportAnalysis(output)
loaded = load(fullfile(output, 'report', 'thermal_report_data.mat'), 'report');
analysis = loaded.report.analysis;
end

function removeFolder(path)
if isfolder(path), rmdir(path, 's'); end
end

function [surface, volume] = tetraFixtures
v = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
f = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
surface = struct('vertices', v, 'faces', f, 'faceNormals', zeros(4,3), ...
    'faceAreasM2', zeros(4,1), 'faceSolarAbsorptivity', ones(4,1), ...
    'faceIREmissivity', 0.8 * ones(4,1));
for k = 1:4
    n = cross(v(f(k,2),:) - v(f(k,1),:), v(f(k,3),:) - v(f(k,1),:));
    surface.faceAreasM2(k) = norm(n) / 2;
    surface.faceNormals(k,:) = n / norm(n);
end
volume = struct('nodesM', v, 'tetrahedra', [1 2 3 4], ...
    'boundaryTriangles', f, 'boundaryPhysicalTags', ones(4,1));
end
