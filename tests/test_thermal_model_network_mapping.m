function tests = test_thermal_model_network_mapping
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
end

function testPreviewIsReadOnlyAndTraceable(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
before = network;
mapping = fixtureMapping(network);

preview = leotherm.model.previewNetworkMapping(model, network, mapping);

verifyEqual(testCase, network, before);
verifyTrue(testCase, preview.valid);
verifyEmpty(testCase, preview.conflicts);
verifyEqual(testCase, numel(preview.changedFields), 4);
verifyEqual(testCase, preview.unmappedExchangeNodeIds, {'x3'}');
verifyEqual(testCase, strlength(string(preview.fingerprint)), 64);
verifyEqual(testCase, strlength(string(preview.confirmationToken)), 64);
verifyTrue(testCase, all(contains(string({preview.changedFields.source}), 'fixture-source')));
end

function testApplyRequiresFreshConfirmation(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
mapping = fixtureMapping(network);
preview = leotherm.model.previewNetworkMapping(model, network, mapping);

verifyError(testCase, @() leotherm.model.applyNetworkMapping(model, network, mapping), ...
    'leotherm:NetworkMappingConfirmationRequired');
verifyError(testCase, @() leotherm.model.applyNetworkMapping(model, network, mapping, ...
    'ConfirmationToken', repmat('0', 1, 64)), ...
    'leotherm:NetworkMappingConfirmationRequired');

[actual, result] = leotherm.model.applyNetworkMapping(model, network, mapping, ...
    'ConfirmationToken', preview.confirmationToken);
verifyEqual(testCase, actual.capacityJK(1), model.nodes(1).capacityJK);
verifyEqual(testCase, actual.internalPowerW(2), model.nodes(2).internalPowerW);
verifyNotEqual(testCase, actual.capacityJK(1), network.capacityJK(1));
verifyEqual(testCase, actual.thermalModelMappingProvenance.source, 'fixture-source');
verifyEqual(testCase, actual.provenance.thermalModelMapping.previewFingerprint, preview.fingerprint);
verifyTrue(testCase, result.applied);
leotherm.validateNetwork(actual);
end

function testAllowApplyAndPerEntryFields(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
mapping = fixtureMapping(network);
mapping.allowedFields = {};
mapping.entries(1).fields = {'initialTemperatureK'};
mapping.entries(2).fields = {'internalPowerW'};

actual = leotherm.model.applyNetworkMapping(model, network, mapping, ...
    struct('allowApply', true));
verifyEqual(testCase, actual.initialTemperatureK(1), model.nodes(1).initialTemperatureK);
verifyEqual(testCase, actual.internalPowerW(2), model.nodes(2).internalPowerW);
verifyEqual(testCase, actual.capacityJK, network.capacityJK);
end

function testDuplicateTargetsAreConflicts(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
mapping = fixtureMapping(network);
mapping.entries(2).networkNodeIndex = 1;
mapping.entries(2).networkNodeName = '';

preview = leotherm.model.previewNetworkMapping(model, network, mapping);
verifyFalse(testCase, preview.valid);
verifyTrue(testCase, any(strcmp({preview.conflicts.code}, 'duplicate_network_node')));
verifyError(testCase, @() leotherm.model.applyNetworkMapping(model, network, mapping, ...
    'AllowApply', true), 'leotherm:NetworkMappingConflict');
end

function testNoImplicitNameMatching(testCase)
model = fixtureModel;
network = leotherm.defaultReceiverNetwork;
model.nodes(1).id = network.nodeNames{1};
mapping = fixtureMapping(network);
mapping.entries(1).exchangeNodeId = network.nodeNames{1};
mapping.entries(1).networkNodeIndex = [];
mapping.entries(1).networkNodeName = 'not_a_network_node';

preview = leotherm.model.previewNetworkMapping(model, network, mapping);
verifyFalse(testCase, preview.valid);
verifyTrue(testCase, any(strcmp({preview.conflicts.code}, 'unknown_network_node')));
end

function testStrictUnitsFiniteRangeAndLength(testCase)
network = leotherm.defaultReceiverNetwork;
mapping = fixtureMapping(network);

bad = fixtureModel; bad.metadata.units.area = 'cm^2';
verifyError(testCase, @() leotherm.model.previewNetworkMapping(bad, network, mapping), ...
    'leotherm:InvalidThermalModel');

bad = fixtureModel; bad.nodes(1).capacityJK = [1 2];
verifyError(testCase, @() leotherm.model.previewNetworkMapping(bad, network, mapping), ...
    'leotherm:NetworkMappingInvalidValue');

bad = fixtureModel; bad.nodes(1).capacityJK = -1;
verifyError(testCase, @() leotherm.model.previewNetworkMapping(bad, network, mapping), ...
    'leotherm:NetworkMappingInvalidValue');

bad = fixtureModel; bad.nodes(1).capacityJK = NaN;
verifyError(testCase, @() leotherm.model.previewNetworkMapping(bad, network, mapping), ...
    'leotherm:InvalidThermalModel');
end

function mapping = fixtureMapping(network)
entries = repmat(struct('exchangeNodeId', '', 'networkNodeIndex', [], ...
    'networkNodeName', '', 'fields', []), 2, 1);
entries(1).exchangeNodeId = 'x1';
entries(1).networkNodeIndex = 1;
entries(2).exchangeNodeId = 'x2';
entries(2).networkNodeName = network.nodeNames{2};
mapping = struct('schema', 'leotherm.thermal_model_mapping.v1', ...
    'allowedFields', {{'capacityJK','internalPowerW'}}, 'entries', entries);
end

function model = fixtureModel()
units = struct('length','m','mass','kg','time','s','temperature','K', ...
    'power','W','heatCapacity','J/K','conductance','W/K','area','m^2');
base = struct('id', '', 'name', '', 'positionM', [0 0 0], ...
    'capacityJK', 100, 'initialTemperatureK', 290, 'internalPowerW', 0, ...
    'projectedAreaM2', 0, 'radiatingAreaM2', 0, ...
    'solarAbsorptivity', 0.3, 'irEmissivity', 0.8);
nodes = repmat(base, 3, 1);
nodes(1).id = 'x1'; nodes(1).name = 'exchange_one';
nodes(1).capacityJK = 1234; nodes(1).initialTemperatureK = 281;
nodes(1).internalPowerW = 3.25;
nodes(2).id = 'x2'; nodes(2).name = 'exchange_two';
nodes(2).capacityJK = 4321; nodes(2).initialTemperatureK = 302;
nodes(2).internalPowerW = 7.5;
nodes(3).id = 'x3'; nodes(3).name = 'unmapped';
model = struct('schema', 'leotherm.thermal_model.v1', ...
    'metadata', struct('modelId', 'mapping-fixture', ...
        'createdUTC', '2026-01-01T00:00:00Z', 'units', units), ...
    'nodes', nodes, 'materials', struct([]), 'components', struct([]), ...
    'contacts', struct([]), 'boundaries', struct([]), ...
    'provenance', struct('source', 'fixture-source', 'transformations', {{}}), ...
    'uncertainty', struct('assumption', 'none'));
end
