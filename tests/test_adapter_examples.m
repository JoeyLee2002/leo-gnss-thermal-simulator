function tests = test_adapter_examples
%TEST_ADAPTER_EXAMPLES Smoke tests for the dependency-free adapter example.
tests = functiontests(localfunctions);
end

function testStructSourceExportsAndRoundTrips(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'examples', 'adapters'));
folder = tempname; mkdir(folder); testCase.addTeardown(@() rmdir(folder, 's'));
source = fixtureSource();
path = fullfile(folder, 'model.json');
[model, report] = generic_exchange_adapter(source, path);
verifyEqual(testCase, report.adapter, 'generic_exchange_adapter');
verifyTrue(testCase, report.exported);
verifyEqual(testCase, model.schema, 'leotherm.thermal_model.v1');
[actual, imported] = leotherm.io.importThermalModel(path);
verifyEqual(testCase, actual.metadata.units.length, 'm');
verifyEqual(testCase, actual.extensions.adapterNote, 'synthetic');
verifyEqual(testCase, imported.format, 'json');
end

function testNeutralJsonInputIsAccepted(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'examples', 'adapters'));
folder = tempname; mkdir(folder); testCase.addTeardown(@() rmdir(folder, 's'));
source = fixtureSource();
inputPath = fullfile(folder, 'neutral.json');
fid = fopen(inputPath, 'w', 'n', 'UTF-8');
fwrite(fid, unicode2native(jsonencode(source), 'UTF-8'), 'uint8'); fclose(fid);
[model, report] = generic_exchange_adapter(inputPath);
verifyEqual(testCase, report.inputKind, 'json');
verifyEqual(testCase, model.metadata.modelId, 'adapter_test_fixture');
verifyEqual(testCase, numel(model.nodes), 2);
end

function testRunExampleNeedsNoExternalSoftware(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'), fullfile(root, 'examples', 'adapters'));
folder = tempname; mkdir(folder); testCase.addTeardown(@() rmdir(folder, 's'));
path = run_generic_exchange_adapter(folder);
verifyTrue(testCase, isfile(path));
[~, report] = leotherm.io.importThermalModel(path);
verifyEqual(testCase, report.schema, 'leotherm.thermal_model.v1');
end

function source = fixtureSource()
units = struct('length','m','mass','kg','time','s','temperature','K', ...
    'power','W','heatCapacity','J/K','conductance','W/K','area','m^2');
metadata = struct('modelId','adapter_test_fixture','createdUTC','2026-01-01T00:00:00Z', ...
    'units',units);
source = struct('schema','leotherm.thermal_model.v1','metadata',metadata, ...
    'nodes',struct('id',{'n1','n2'},'positionM',{[0 0 0],[1 0 0]}), ...
    'materials',struct([]),'components',struct([]),'contacts',struct([]), ...
    'boundaries',struct([]), 'provenance',struct('source','test','transformations',{{}}), ...
    'uncertainty',struct('enabled',false), ...
    'extensions',struct('adapterNote','synthetic'));
end
