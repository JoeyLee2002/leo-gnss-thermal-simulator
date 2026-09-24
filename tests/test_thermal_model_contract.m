function tests = test_thermal_model_contract
tests = functiontests(localfunctions);
end

function testNormalizesReferenceNetwork(testCase)
model = leotherm.model.normalize(leotherm.defaultReceiverNetwork);
verifyEqual(testCase, model.schema, 'leotherm.thermal_model.v1');
verifyEqual(testCase, model.units.length, 'm');
verifyTrue(testCase, model.connectivity.networkConnected);
verifyEmpty(testCase, fieldnames(model.geometry));
verifyEmpty(testCase, fieldnames(model.volumeMesh));
leotherm.model.validate(model);
end

function testRejectsNonSIUnits(testCase)
network = leotherm.defaultReceiverNetwork;
verifyError(testCase, @() leotherm.model.normalize(network, [], [], ...
    struct('units', struct('length', 'mm'))), 'leotherm:modelInvalidUnits');
end

function testRejectsDisconnectedNetwork(testCase)
network = leotherm.defaultReceiverNetwork;
network.conductanceWK(:, 11) = 0;
network.conductanceWK(11, :) = 0;
verifyError(testCase, @() leotherm.model.normalize(network), 'leotherm:modelInvalid');
end

function testVolumeMeshConnectivityAndFiniteValues(testCase)
mesh.nodesM = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 1];
mesh.tetrahedra = [1 2 3 4; 2 3 4 5];
mesh.boundaryTriangles = zeros(0, 3);
leotherm.validateVolumeMesh(mesh);
model = leotherm.model.normalize(leotherm.defaultReceiverNetwork, [], mesh);
verifyTrue(testCase, model.connectivity.volumeConnected);
mesh.nodesM(1, 1) = NaN;
verifyError(testCase, @() leotherm.model.normalize(leotherm.defaultReceiverNetwork, [], mesh), 'leotherm:InvalidVolumeMesh');
end

function testUncertaintySamplesAreReproducible(testCase)
base = leotherm.model.normalize(leotherm.defaultReceiverNetwork);
[a, fa] = leotherm.model.sampleUncertainty(base, 4, 17);
[b, fb] = leotherm.model.sampleUncertainty(base, 4, 17);
verifyEqual(testCase, fa, fb);
verifyEqual(testCase, {a.sample}, {b.sample});
verifyEqual(testCase, a(1).model.network.capacityJK, b(1).model.network.capacityJK);
verifyLessThan(testCase, max(abs(fa(:) - 1)), 0.31);
end
