function tests = test_v014_release_regression
%TEST_V014_RELEASE_REGRESSION Release-gate coverage for the v0.14 exchange API.
% These tests exercise only public adapters and test fixtures; they do not
% start the GUI or call the thermal solver.
tests = functiontests(localfunctions);
end

function testComponentCreateDoesNotRequireNetwork(testCase)
spec = struct('id','v014_component','name','v0.14 fixture', ...
    'nodeIndex',1,'capacityJK',125,'internalPowerW',2, ...
    'source','release fixture','confidence','low','uncertainty',struct);
component = leotherm.componentModel('create', spec);
verifyEqual(testCase, component.id, 'v014_component');
verifyEqual(testCase, component.capacityJK, 125);
verifyEqual(testCase, component.internalPowerW, 2);
end

function testJsonAndMatRoundTripPreserveSourceFingerprint(testCase)
model = fixtureModel;
sourceFingerprint = repmat('a', 1, 64);
model.provenance.inputFingerprint = sourceFingerprint;
folder = tempname;
mkdir(folder);

jsonPath = fullfile(folder, 'model.json');
matPath = fullfile(folder, 'model.mat');
jsonExport = leotherm.io.exportThermalModel(model, jsonPath);
matExport = leotherm.io.exportThermalModel(model, matPath);
[jsonModel, jsonReport] = leotherm.io.importThermalModel(jsonPath);
[matModel, matReport] = leotherm.io.importThermalModel(matPath);

verifyEqual(testCase, jsonModel.provenance.inputFingerprint, sourceFingerprint);
verifyEqual(testCase, matModel.provenance.inputFingerprint, sourceFingerprint);
verifyEqual(testCase, jsonReport.sourceFingerprint, sourceFingerprint);
verifyEqual(testCase, matReport.sourceFingerprint, sourceFingerprint);
verifyEqual(testCase, jsonReport.inputFingerprint, jsonExport.outputFingerprint);
verifyEqual(testCase, matReport.inputFingerprint, matExport.outputFingerprint);
verifyNotEqual(testCase, jsonReport.inputFingerprint, sourceFingerprint);
verifyNotEqual(testCase, matReport.inputFingerprint, sourceFingerprint);
cleanupTestFolder(folder);
end

function cleanupTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end

function testUncertaintyMustBeScalar(testCase)
model = fixtureModel;
model.uncertainty = repmat(struct('assumption','fixture'), 1, 2);
verifyError(testCase, @() leotherm.io.validateThermalModel(model), ...
    'leotherm:InvalidThermalModel');
end

function testTemperatureCurveGridEvaluatesOnGrid(testCase)
material = struct('id','v014_curve','name','v0.14 curve', ...
    'kind','temperature_dependent','temperatureK',[200 300 400], ...
    'conductivityWmK',[1 2 3],'densityKgM3',[900 1000 1100], ...
    'specificHeatJkgK',[800 900 1000],'temperatureRangeK',[200 400], ...
    'source','release fixture','confidence','low','uncertainty',struct);
value = leotherm.materialLibrary('evaluate', material, [200 300 400]);
verifyEqual(testCase, value.conductivityWmK, [1 2 3], 'AbsTol', 1e-12);
verifyEqual(testCase, value.specificHeatJkgK, [800 900 1000], 'AbsTol', 1e-12);
end

function testTemperatureCurveRequiresIncreasingGrid(testCase)
material = struct('id','v014_bad_curve','name','bad curve', ...
    'kind','temperature_dependent','temperatureK',[200 200 400], ...
    'conductivityWmK',[1 2 3],'densityKgM3',[900 1000 1100], ...
    'specificHeatJkgK',[800 900 1000],'temperatureRangeK',[200 400], ...
    'source','release fixture','confidence','low','uncertainty',struct);
verifyError(testCase, @() leotherm.materialLibrary(material), ...
    'leotherm:InvalidMaterial');
end

function testMappingPreviewAndApplyAreExplicit(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
mapping = struct('schema','leotherm.thermal_model_mapping.v1', ...
    'allowedFields',{{'capacityJK','internalPowerW'}}, ...
    'entries',struct('exchangeNodeId',{'n1'},'networkNodeIndex',1, ...
    'fields',{{'capacityJK','internalPowerW'}}));
before = network;
preview = leotherm.model.previewNetworkMapping(model, network, mapping);
verifyTrue(testCase, preview.valid);
verifyEmpty(testCase, preview.conflicts);
verifyEqual(testCase, network, before);
verifyGreaterThanOrEqual(testCase, numel(preview.changedFields), 1);

verifyError(testCase, @() leotherm.model.applyNetworkMapping(model, network, mapping), ...
    'leotherm:NetworkMappingConfirmationRequired');
actual = leotherm.model.applyNetworkMapping(model, network, mapping, ...
    'ConfirmationToken', preview.confirmationToken);
verifyEqual(testCase, actual.capacityJK(1), model.nodes(1).capacityJK);
verifyEqual(testCase, actual.internalPowerW(1), model.nodes(1).internalPowerW);
verifyEqual(testCase, network, before);
verifyEqual(testCase, actual.provenance.thermalModelMapping.previewFingerprint, ...
    preview.fingerprint);
end

function model = fixtureModel
units = struct('length','m','mass','kg','time','s','temperature','K', ...
    'power','W','heatCapacity','J/K','conductance','W/K','area','m^2');
node = struct('id','n1','name','node one','positionM',[0 0 0], ...
    'capacityJK',250,'initialTemperatureK',290,'internalPowerW',1, ...
    'projectedAreaM2',0.1,'radiatingAreaM2',0.1, ...
    'solarAbsorptivity',0.3,'irEmissivity',0.8);
model = struct('schema','leotherm.thermal_model.v1', ...
    'metadata',struct('modelId','v014_fixture', ...
    'createdUTC','2026-01-01T00:00:00Z','units',units), ...
    'nodes',node,'materials',struct([]),'components',struct([]), ...
    'contacts',struct([]),'boundaries',struct([]), ...
    'provenance',struct('source','v014 fixture','transformations',{{}}), ...
    'uncertainty',struct('assumption','none'));
end
