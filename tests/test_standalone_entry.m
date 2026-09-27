function tests = test_standalone_entry
tests = functiontests(localfunctions);
end

function testSmokeUsesBundledResourcesAndCreatesPdf(testCase)
root = leotherm.installRoot;
verifyTrue(testCase, isfolder(fullfile(root, 'templates')));
addpath(root);
cleanupPath = onCleanup(@() rmpath(root));
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
standalone_main('--smoke', output);
verifyTrue(testCase, isfile(fullfile(output, 'standalone_smoke_status.txt')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'thermal_report_zh.pdf')));
pipeline = jsondecode(fileread(fullfile(output, 'pipeline_status.json')));
verifyEqual(testCase, pipeline.status, 'complete');
verifyEqual(testCase, pipeline.stages(5).status, 'skipped');
status = fileread(fullfile(output, 'standalone_smoke_status.txt'));
verifyTrue(testCase, contains(status, 'outcome=complete'));
verifyTrue(testCase, contains(status, ['version=' leotherm.version]));
clear cleanup cleanupPath
end

function testGuiSmokeExportsPdf(testCase)
if ~usejava('jvm'), return; end
root = leotherm.installRoot;
addpath(root);
cleanupPath = onCleanup(@() rmpath(root));
output = tempname;
cleanup = onCleanup(@() removeFolder(output));
standalone_main('--gui-smoke', output);
verifyTrue(testCase, isfile(fullfile(output, 'standalone_gui_status.txt')));
verifyTrue(testCase, isfile(fullfile(output, 'report', 'thermal_report_zh.pdf')));
clear cleanup cleanupPath
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
