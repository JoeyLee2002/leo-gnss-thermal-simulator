function tests = test_gui_thermal_model
tests = functiontests(localfunctions);
end

function testThermalModelEntryPointAndSummary(testCase)
if ~usejava('jvm'), return; end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
verifyEqual(testCase, numel(findobj(app.Figure, 'Tag', 'ThermalModelImportButton')), 1);
verifyEqual(testCase, numel(findobj(app.Figure, 'Tag', 'ThermalModelExportMATButton')), 1);
verifyEqual(testCase, numel(findobj(app.Figure, 'Tag', 'ThermalModelExportJSONButton')), 1);
verifyEqual(testCase, string(findobj(app.Figure, 'Tag', 'ThermalModelExportMATButton').Enable), "off");
end

function testImportExportAndAtomicFailure(testCase)
if ~usejava('jvm'), return; end
folder = tempname; mkdir(folder); cleanupFolder = onCleanup(@() rmdir(folder, 's'));
model = fixtureModel;
inputPath = fullfile(folder, 'model.json');
leotherm.io.exportThermalModel(model, inputPath, 'PrettyPrint', true);
app = leotherm.ThermalSimulatorApp('off', 'en');
cleanupApp = onCleanup(@() delete(app));
app.loadThermalModel(inputPath);
state = app.getState;
verifyEqual(testCase, state.thermalModel.metadata.modelId, 'gui_fixture');
summary = findobj(app.Figure, 'Tag', 'ThermalModelSummary');
verifyTrue(testCase, any(contains(string(summary.Value), 'gui_fixture')));
exportPath = fullfile(folder, 'roundtrip.mat');
app.saveThermalModel(exportPath);
verifyTrue(testCase, isfile(exportPath));

bad = model; bad.schema = 'invalid.v1';
badPath = fullfile(folder, 'bad.mat');
thermalModel = bad;
save(badPath, 'thermalModel');
verifyError(testCase, @() app.loadThermalModel(badPath), 'leotherm:InvalidThermalModel');
verifyEqual(testCase, app.getState.thermalModel.metadata.modelId, 'gui_fixture');
clear thermalModel cleanupApp cleanupFolder
end

function testExplicitMappingPreviewApplyAndRollback(testCase)
if ~usejava('jvm'), return; end
folder = tempname; mkdir(folder); cleanupFolder = onCleanup(@() rmdir(folder, 's'));
model = fixtureModel;
for k = 1:numel(model.nodes)
    model.nodes(k).capacityJK = 100 + k;
    model.nodes(k).internalPowerW = k;
end
model.nodes = model.nodes(1:2);
modelPath = fullfile(folder, 'model.json');
leotherm.io.exportThermalModel(model, modelPath, 'PrettyPrint', true);
mapping = struct('schema', 'leotherm.thermal_model_mapping.v1', ...
    'allowedFields', {{'capacityJK','internalPowerW'}}, ...
    'entries', struct('exchangeNodeId', {'n1','n2'}, ...
    'networkNodeIndex', {1, 2}));
mappingPath = fullfile(folder, 'mapping.json');
fid = fopen(mappingPath, 'w', 'n', 'UTF-8');
cleanupFile = onCleanup(@() fclose(fid));
fwrite(fid, unicode2native(jsonencode(mapping), 'UTF-8'), 'uint8');
clear cleanupFile
app = leotherm.ThermalSimulatorApp('off', 'en');
cleanupApp = onCleanup(@() delete(app));
before = app.getState.network;
app.loadThermalModel(modelPath);
app.loadThermalModelMapping(mappingPath);
preview = app.previewThermalModelMapping;
verifyTrue(testCase, preview.valid);
verifyEmpty(testCase, preview.conflicts);
verifyGreaterThan(testCase, numel(preview.changedFields), 0);
verifyError(testCase, @() app.applyThermalModelMapping, ...
    'leotherm:NetworkMappingConfirmationRequired');
app.applyThermalModelMapping(preview.confirmationToken);
verifyEqual(testCase, app.getState.network.capacityJK(1), model.nodes(1).capacityJK);
verifyNotEqual(testCase, app.getState.network.capacityJK(1), before.capacityJK(1));
verifyEqual(testCase, app.getState.task.network.capacityJK(1), model.nodes(1).capacityJK);
app.rollbackThermalModelNetwork;
verifyEqual(testCase, app.getState.network, before);
clear cleanupApp cleanupFolder
end

function model = fixtureModel
units = struct('length','m','mass','kg','time','s','temperature','K', ...
    'power','W','heatCapacity','J/K','conductance','W/K','area','m^2');
model = struct('schema','leotherm.thermal_model.v1', ...
    'metadata',struct('modelId','gui_fixture','createdUTC','2026-01-01T00:00:00Z','units',units), ...
    'nodes',struct('id',{'n1','n2'},'positionM',{[0 0 0],[1 0 0]}), ...
    'materials',struct('id','al','conductivityWmK',200), ...
    'components',struct('id','body','nodeIds',{{'n1','n2'}}), ...
    'contacts',struct('id','c1','nodeIds',{{'n1','n2'}},'conductanceWK',1), ...
    'boundaries',struct('id','b1','type','fixedTemperature','nodeIds',{{'n1'}},'temperatureK',300), ...
    'provenance',struct('source','gui_test','transformations',{{}}), ...
    'uncertainty',struct('assumption','none'));
end
