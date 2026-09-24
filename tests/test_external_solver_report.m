function tests = test_external_solver_report
tests = functiontests(localfunctions);
end

function testControlledCommandAndReport(testCase)
if ~ispc
    return
end
root = tempname; mkdir(root); testCase.addTeardown(@() rmdir(root, 's'));
inputDir = fullfile(root, 'input'); mkdir(inputDir);
outputDir = fullfile(root, 'output');
fid = fopen(fullfile(inputDir, 'input.txt'), 'w'); fprintf(fid, 'fixture'); fclose(fid);
config = struct('executable', fullfile(getenv('WINDIR'), 'System32', 'cmd.exe'), ...
    'arguments', {{'/c', 'exit', '0'}}, 'inputDirectory', inputDir, ...
    'workingDirectory', inputDir, 'outputDirectory', outputDir, ...
    'timeoutS', 30, 'adapterId', 'test_cmd', 'softwareVersion', 'fixture');
run = leotherm.io.runExternalThermalSolver(config);
verifyTrue(testCase, run.success);
verifyEqual(testCase, run.exitCode, 0);
verifyTrue(testCase, run.provenance.noShellExecution);
adapter = struct('id','test_cmd','version','1.0.0','displayName','Command fixture', ...
    'kind','external_command','capabilities',struct, 'handlers',struct, ...
    'provenance',struct('source','test'));
reportDir = fullfile(root, 'report');
report = leotherm.report.writeThermalSimulationReport( ...
    struct('adapter',adapter,'externalRun',run), reportDir, 'both');
verifyEqual(testCase, report.schema, 'leotherm.thermal_simulation_report.v1');
verifyTrue(testCase, isfile(fullfile(reportDir, 'thermal_simulation_report_zh.md')));
verifyTrue(testCase, isfile(fullfile(reportDir, 'thermal_simulation_report_en.md')));
verifyTrue(testCase, isfile(fullfile(reportDir, 'thermal_simulation_manifest.json')));
end

function testUnsafeCommandAndNonEmptyOutputRejected(testCase)
if ~ispc
    return
end
root = tempname; mkdir(root); testCase.addTeardown(@() rmdir(root, 's'));
inputDir = fullfile(root, 'input'); mkdir(inputDir);
bad = struct('executable', 'cmd.exe', 'arguments', {{'/c', 'exit', '0 & whoami'}}, ...
    'inputDirectory', inputDir, 'workingDirectory', inputDir, ...
    'outputDirectory', fullfile(root, 'out'));
verifyError(testCase, @() leotherm.io.runExternalThermalSolver(bad), ...
    'leotherm:ExternalSolverConfig');
out = fullfile(root, 'existing'); mkdir(out);
fid = fopen(fullfile(out, 'old.txt'), 'w'); fprintf(fid, 'x'); fclose(fid);
bad.arguments = {'/c','exit','0'}; bad.outputDirectory = out;
verifyError(testCase, @() leotherm.io.runExternalThermalSolver(bad), ...
    'leotherm:ExternalSolverConfig');
end

function testFailureAndTimeoutAreReturnedForReporting(testCase)
if ~ispc
    return
end
root = tempname; mkdir(root); testCase.addTeardown(@() rmdir(root, 's'));
inputDir = fullfile(root, 'input'); mkdir(inputDir);
failedDir = fullfile(root, 'failed');
failed = struct('executable', fullfile(getenv('WINDIR'), 'System32', 'cmd.exe'), ...
    'arguments', {{'/c', 'exit', '7'}}, 'inputDirectory', inputDir, ...
    'workingDirectory', inputDir, 'outputDirectory', failedDir, ...
    'expectedOutputs', {{'result.csv'}}, 'timeoutS', 30);
run = leotherm.io.runExternalThermalSolver(failed);
verifyFalse(testCase, run.success);
verifyEqual(testCase, run.status, 'failed');
verifyEqual(testCase, run.exitCode, 7);
verifyTrue(testCase, any(strcmp(run.missingOutputs, 'result.csv')));
verifyTrue(testCase, run.failureIsReturnedForReporting);
reportDir = fullfile(root, 'failed_report');
report = leotherm.report.writeThermalSimulationReport(struct('externalRun',run), reportDir, 'zh');
verifyFalse(testCase, report.physicalValidationEstablished);
verifyTrue(testCase, isfile(fullfile(reportDir, 'thermal_simulation_report_zh.md')));
timeoutDir = fullfile(root, 'timeout');
timed = struct('executable', fullfile(getenv('WINDIR'), 'System32', 'cmd.exe'), ...
    'arguments', {{'/c', 'ping', '-n', '5', '127.0.0.1'}}, ...
    'inputDirectory', inputDir, 'workingDirectory', inputDir, ...
    'outputDirectory', timeoutDir, 'timeoutS', 0.1);
timedRun = leotherm.io.runExternalThermalSolver(timed);
verifyFalse(testCase, timedRun.success);
verifyEqual(testCase, timedRun.status, 'timed_out');
verifyTrue(testCase, timedRun.timedOut);
end
