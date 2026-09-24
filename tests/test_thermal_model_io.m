function tests = test_thermal_model_io
tests = functiontests(localfunctions);
end

function testJsonRoundTripRetainsUnknownFields(testCase)
model = fixtureModel();
model.extensions = struct('vendorField', [1 2 3]);
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
path = fullfile(folder,'model.json');
leotherm.io.exportThermalModel(model,path,'PrettyPrint',true);
[actual, report] = leotherm.io.importThermalModel(path);
verifyEqual(testCase, actual.schema, model.schema);
verifyEqual(testCase, actual.extensions.vendorField(:), [1; 2; 3]);
verifyEqual(testCase, report.format, 'json');
end

function testMatRoundTrip(testCase)
model = fixtureModel(); folder = tempname; mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s'));
path = fullfile(folder,'model.mat'); leotherm.io.exportThermalModel(model,path);
actual = leotherm.io.importThermalModel(path);
verifyEqual(testCase, actual.nodes, model.nodes);
verifyEqual(testCase, actual.metadata.units, model.metadata.units);
end

function testSourceFingerprintSurvivesExportRoundTrip(testCase)
model = fixtureModel(); model.provenance.inputFingerprint = repmat('0',1,64);
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
path = fullfile(folder,'bad.json'); leotherm.io.writeThermalModelJson(path,model);
[actual, report] = leotherm.io.importThermalModel(path);
verifyEqual(testCase, actual.provenance.inputFingerprint, repmat('0',1,64));
verifyEqual(testCase, report.sourceFingerprint, repmat('0',1,64));
end

function testInvalidSchemaAndUnitsRejected(testCase)
model = fixtureModel(); model.schema = 'other.v1';
verifyError(testCase,@()leotherm.io.validateThermalModel(model),'leotherm:InvalidThermalModel');
model = fixtureModel(); model.metadata.units.length = 'cm';
verifyError(testCase,@()leotherm.io.validateThermalModel(model),'leotherm:InvalidThermalModel');
end

function model = fixtureModel()
u = struct('length','m','mass','kg','time','s','temperature','K','power','W', ...
    'heatCapacity','J/K','conductance','W/K','area','m^2');
model = struct('schema','leotherm.thermal_model.v1', ...
    'metadata',struct('modelId','fixture','createdUTC','2026-01-01T00:00:00Z','units',u), ...
    'nodes',struct('id',{'n1','n2'},'positionM',{[0 0 0],[1 0 0]}), ...
    'materials',struct('id','al','conductivityWmK',200), ...
    'components',struct('id','body','nodeIds',{{'n1','n2'}}), ...
    'contacts',struct('id','c1','nodeIds',{{'n1','n2'}},'conductanceWK',1), ...
    'boundaries',struct('id','b1','type','fixedTemperature','nodeIds',{{'n1'}},'temperatureK',300), ...
    'provenance',struct('source','fixture','transformations',{{}}), ...
    'uncertainty',struct('assumption','none'));
end
