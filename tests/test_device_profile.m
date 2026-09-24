function tests = test_device_profile
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.network = leotherm.defaultReceiverNetwork;
testCase.TestData.profile = leotherm.deviceCalibrationProfile(testCase.TestData.network);
end

function testDefaultsLockedAndExactTemplate(testCase)
n = testCase.TestData.network;
p = testCase.TestData.profile;
t = p.parameters;
verifyEqual(testCase, p.schemaVersion, 1);
verifyEqual(testCase, p.name, n.name);
verifyEqual(testCase, p.nodeNames, n.nodeNames);
verifyTrue(testCase, isequaln(p.referenceNetwork, n));
verifyEqual(testCase, t.Properties.VariableNames, ...
    {'field', 'node', 'peer', 'unit', 'nominal', 'lower', 'upper', ...
    'priorSigma', 'estimate', 'evidence', 'kind'});
fields = ["capacityJK", "internalPowerW", "projectedAreaM2", ...
    "radiatingAreaM2", "solarAbsorptivity", "irEmissivity"];
units = ["J/K", "W", "m^2", "m^2", "1", "1"];
for k = 1:numel(fields)
    rows = t.field == fields(k);
    verifyEqual(testCase, sum(rows), numel(n.nodeNames));
    verifyEqual(testCase, t.node(rows), string(n.nodeNames(:)));
    verifyEqual(testCase, t.peer(rows), strings(numel(n.nodeNames), 1));
    verifyEqual(testCase, t.unit(rows), repmat(units(k), numel(n.nodeNames), 1));
    verifyEqual(testCase, t.nominal(rows), n.(char(fields(k)))(:));
end
[left, right] = find(triu(n.conductanceWK > 0, 1));
edges = t.field == "conductanceWK";
names = string(n.nodeNames(:));
verifyEqual(testCase, height(t), 6 * numel(n.nodeNames) + numel(left));
verifyEqual(testCase, t.node(edges), names(left));
verifyEqual(testCase, t.peer(edges), names(right));
verifyEqual(testCase, t.nominal(edges), n.conductanceWK( ...
    sub2ind(size(n.conductanceWK), left, right)));
verifyEqual(testCase, t.unit(edges), repmat("W/K", numel(left), 1));
verifyEqual(testCase, t.lower, t.nominal);
verifyEqual(testCase, t.upper, t.nominal);
verifyEqual(testCase, t.priorSigma, zeros(height(t), 1));
verifyEqual(testCase, t.estimate, false(height(t), 1));
verifyEqual(testCase, t.evidence, strings(height(t), 1));
verifyEqual(testCase, t.kind, repmat("unverified", height(t), 1));
verifyEqual(testCase, leotherm.validateDeviceCalibrationProfile(p, n), p);
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, []), n);
end

function testInvalidNetworkRejected(testCase)
n = testCase.TestData.network;
n.capacityJK(1) = 0;
verifyError(testCase, @() leotherm.deviceCalibrationProfile(n), 'leotherm:InvalidNetwork');
verifyError(testCase, @() leotherm.validateDeviceCalibrationProfile( ...
    testCase.TestData.profile, n), 'leotherm:InvalidNetwork');
verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile( ...
    n, testCase.TestData.profile, []), 'leotherm:InvalidNetwork');
end

function testMissingEvidenceAndUncertaintyRejected(testCase)
[p, row] = activeCapacity(testCase.TestData.profile);
for evidence = ["", "   ", string(sprintf('\t\n'))]
    bad = p;
    bad.parameters.evidence(row) = evidence;
    verifyInvalid(testCase, bad);
end
for sigma = [0, -1, Inf, NaN]
    bad = p;
    bad.parameters.priorSigma(row) = sigma;
    verifyInvalid(testCase, bad);
end
bad = p;
bad.parameters.evidence(row) = missing;
verifyInvalid(testCase, bad);
end

function testKindsAreExplicitNotVerifiedClaims(testCase)
[p, row] = activeCapacity(testCase.TestData.profile);
for kind = ["unverified", "verified", "Physical", ""]
    bad = p;
    bad.parameters.kind(row) = kind;
    verifyInvalid(testCase, bad);
end
for kind = ["physical", "effective"]
    p.parameters.kind(row) = kind;
    normalized = leotherm.validateDeviceCalibrationProfile(p, testCase.TestData.network);
    verifyEqual(testCase, normalized.parameters.evidence, p.parameters.evidence);
    verifyEqual(testCase, normalized.parameters.kind(row), kind);
end
end

function testLockedRowsRetainRangesAndSigma(testCase)
[p, row] = activeCapacity(testCase.TestData.profile);
p.parameters.estimate(row) = false;
p.parameters.kind(row) = "unverified";
p.parameters.evidence(row) = "";
normalized = leotherm.validateDeviceCalibrationProfile(p, testCase.TestData.network);
verifyEqual(testCase, normalized, p);
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile( ...
    testCase.TestData.network, p, []), testCase.TestData.network);
p.parameters.lower(row) = p.parameters.nominal(row);
p.parameters.upper(row) = p.parameters.nominal(row);
leotherm.validateDeviceCalibrationProfile(p, testCase.TestData.network);
p.parameters.estimate(row) = true;
verifyInvalid(testCase, p);
end

function testNominalCannotRecenterPrior(testCase)
for active = [false, true]
    [p, row] = activeCapacity(testCase.TestData.profile);
    p.parameters.estimate(row) = active;
    p.parameters.nominal(row) = p.parameters.nominal(row) + eps(p.parameters.nominal(row));
    verifyInvalid(testCase, p);
end
end

function testStaleReferenceRejectedIncludingNonparameterFields(testCase)
p = testCase.TestData.profile;
n = testCase.TestData.network;
variants = cell(1, 7);
variants{1} = n;
variants{1}.name = 'renamed_network';
variants{2} = n;
variants{2}.initialTemperatureK(1) = n.initialTemperatureK(1) + 1;
variants{3} = n;
variants{3}.bias.linearMPerK(1) = 0.01;
variants{4} = n;
variants{4}.capacityJK(1) = n.capacityJK(1) + 1;
variants{5} = n;
variants{5}.nodeNames([1, 2]) = n.nodeNames([2, 1]);
variants{6} = n;
variants{6}.conductanceWK(1, 2) = 0.1;
variants{6}.conductanceWK(2, 1) = 0.1;
variants{7} = n;
variants{7}.measuredBoundaryG = ones(numel(n.nodeNames), 1);
for k = 1:numel(variants)
    verifyError(testCase, @() leotherm.validateDeviceCalibrationProfile(p, variants{k}), ...
        'leotherm:DeviceCalibrationProfile');
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile(variants{k}, p, []), ...
        'leotherm:DeviceCalibrationProfile');
end
bad = p;
bad.referenceNetwork.name = 'tampered_reference';
verifyInvalid(testCase, bad);
end

function testReferenceUsesIsequalnAndExcludedFieldsStayFixed(testCase)
n = testCase.TestData.network;
n.metadata = struct('unknownValue', NaN, 'source', 'synthetic fixture');
n.measuredBoundaryG = ones(numel(n.nodeNames), 1);
n.massKg = ones(numel(n.nodeNames), 1);
n.cpJKgK = n.capacityJK;
p = leotherm.deviceCalibrationProfile(n);
verifyFalse(testCase, any(ismember(p.parameters.field, ...
    ["initialTemperatureK", "bias", "massKg", "cpJKgK", "measuredBoundaryG"])));
[p, row] = activeCapacity(p);
expected = n;
expected.capacityJK(1) = p.parameters.upper(row);
actual = leotherm.applyDeviceCalibrationProfile(n, p, p.parameters.upper(row));
verifyTrue(testCase, isequaln(actual, expected));
end

function testProfileMetadataRejected(testCase)
p = testCase.TestData.profile;
badProfiles = {[], p([]), [p, p], rmfield(p, 'referenceNetwork')};
for k = 1:numel(badProfiles)
    verifyInvalid(testCase, badProfiles{k});
end
for version = {0, 2, NaN, Inf, true, "1", [1, 1], 1 + 1i}
    bad = p;
    bad.schemaVersion = version{1};
    verifyInvalid(testCase, bad);
end
for name = {"", "   ", string(missing), 1, ["a", "b"]}
    bad = p;
    bad.name = name{1};
    verifyInvalid(testCase, bad);
end
bad = p;
bad.nodeNames = fliplr(bad.nodeNames);
verifyInvalid(testCase, bad);
end

function testExactRowsAndColumnsRequired(testCase)
p = testCase.TestData.profile;
bad = p;
bad.parameters(1, :) = [];
verifyInvalid(testCase, bad);
bad = p;
bad.parameters = [p.parameters; p.parameters(1, :)];
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.evidence = [];
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.extra = zeros(height(p.parameters), 1);
verifyInvalid(testCase, bad);
bad = p;
bad.parameters = table2struct(p.parameters);
verifyInvalid(testCase, bad);
end

function testMaliciousAndUnknownFieldPathsRejected(testCase)
for field = ["capacityJK(1)", "bias.linearMPerK", "initialTemperatureK", ...
        "measuredBoundaryG", "massKg", "cpJKgK", "unknown", "capacityJK;error('bad')"]
    bad = testCase.TestData.profile;
    bad.parameters.field(1) = field;
    verifyInvalid(testCase, bad);
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile( ...
        testCase.TestData.network, bad, []), 'leotherm:DeviceCalibrationProfile');
end
end

function testDuplicateAndReversedEdgesRejected(testCase)
p = testCase.TestData.profile;
bad = p;
bad.parameters(2, :) = bad.parameters(1, :);
verifyInvalid(testCase, bad);
edges = find(p.parameters.field == "conductanceWK");
bad = p;
bad.parameters(edges(2), :) = bad.parameters(edges(1), :);
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.node(edges(1)) = p.parameters.peer(edges(1));
bad.parameters.peer(edges(1)) = p.parameters.node(edges(1));
verifyInvalid(testCase, bad);
bad = p;
bad.parameters(edges(2), :) = bad.parameters(edges(1), :);
bad.parameters.node(edges(2)) = p.parameters.peer(edges(1));
bad.parameters.peer(edges(2)) = p.parameters.node(edges(1));
verifyInvalid(testCase, bad);
end

function testUnknownNodesPeersAndUnitsRejected(testCase)
p = testCase.TestData.profile;
edge = find(p.parameters.field == "conductanceWK", 1);
bad = p;
bad.parameters.node(1) = "not_a_node";
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.peer(1) = p.parameters.node(2);
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.peer(edge) = p.parameters.node(edge);
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.node(edge) = string(testCase.TestData.network.nodeNames{1});
bad.parameters.peer(edge) = string(testCase.TestData.network.nodeNames{2});
verifyInvalid(testCase, bad);
bad = p;
bad.parameters.unit(1) = "kg";
verifyInvalid(testCase, bad);
end

function testColumnTypesAreStrict(testCase)
p = testCase.TestData.profile;
for value = {double(p.parameters.estimate), string(p.parameters.estimate), ...
        [p.parameters.estimate, p.parameters.estimate]}
    bad = p;
    bad.parameters.estimate = value{1};
    verifyInvalid(testCase, bad);
end
for field = {'field', 'node', 'peer', 'unit', 'evidence', 'kind'}
    bad = p;
    bad.parameters.(field{1}) = cellstr(bad.parameters.(field{1}));
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.(field{1})(1) = missing;
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.(field{1}) = repmat(bad.parameters.(field{1}), 1, 2);
    verifyInvalid(testCase, bad);
end
for field = {'nominal', 'lower', 'upper', 'priorSigma'}
    for value = {NaN, Inf, -Inf, 1i}
        bad = p;
        bad.parameters.(field{1})(1) = value{1};
        verifyInvalid(testCase, bad);
    end
    bad = p;
    bad.parameters.(field{1}) = string(bad.parameters.(field{1}));
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.(field{1}) = false(height(p.parameters), 1);
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.(field{1}) = repmat(bad.parameters.(field{1}), 1, 2);
    verifyInvalid(testCase, bad);
end
end

function testPhysicalBoundsCheckedEvenWhenLocked(testCase)
p = testCase.TestData.profile;
fields = ["capacityJK", "internalPowerW", "projectedAreaM2", ...
    "radiatingAreaM2", "conductanceWK", "solarAbsorptivity", "irEmissivity"];
for field = fields
    row = find(p.parameters.field == field, 1);
    bad = p;
    bad.parameters.lower(row) = -eps;
    verifyInvalid(testCase, bad);
end
bad = p;
bad.parameters.lower(1) = 0;
verifyInvalid(testCase, bad);
for field = ["solarAbsorptivity", "irEmissivity"]
    row = find(p.parameters.field == field, 1);
    bad = p;
    bad.parameters.upper(row) = 1 + eps(1);
    verifyInvalid(testCase, bad);
end
bad = p;
bad.parameters.priorSigma(1) = -eps;
verifyInvalid(testCase, bad);
end

function testAllRangesMustContainNominal(testCase)
[p, row] = activeCapacity(testCase.TestData.profile);
for active = [false, true]
    p.parameters.estimate(row) = active;
    bad = p;
    bad.parameters.lower(row) = p.parameters.nominal(row) + 1;
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.upper(row) = p.parameters.nominal(row) - 1;
    verifyInvalid(testCase, bad);
    bad = p;
    bad.parameters.lower(row) = p.parameters.upper(row);
    bad.parameters.upper(row) = p.parameters.lower(row);
    verifyInvalid(testCase, bad);
end
end

function testReorderedRowsDefineFreeVectorOrder(testCase)
n = testCase.TestData.network;
[p, capacity] = activeCapacity(testCase.TestData.profile);
edge = find(p.parameters.field == "conductanceWK", 1);
p = activate(p, edge, 0, 2 * p.parameters.nominal(edge), 0.1);
p.parameters.kind(edge) = "effective";
permutation = [edge, capacity, setdiff(1:height(p.parameters), [edge, capacity])];
p.parameters = p.parameters(permutation, :);
normalized = leotherm.validateDeviceCalibrationProfile(p, n);
verifyEqual(testCase, normalized.parameters, p.parameters);
values = [p.parameters.upper(1), p.parameters.lower(2)];
actual = leotherm.applyDeviceCalibrationProfile(n, p, values);
expected = n;
expected.capacityJK(1) = values(2);
left = find(string(n.nodeNames) == p.parameters.node(1));
right = find(string(n.nodeNames) == p.parameters.peer(1));
expected.conductanceWK(left, right) = values(1);
expected.conductanceWK(right, left) = values(1);
verifyEqual(testCase, actual, expected);
verifyEqual(testCase, actual.conductanceWK, actual.conductanceWK');
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, values'), expected);
end

function testColumnOrderAndNumericNormalization(testCase)
p = testCase.TestData.profile;
p.parameters.priorSigma = single(p.parameters.priorSigma);
p.parameters = p.parameters(:, end:-1:1);
normalized = leotherm.validateDeviceCalibrationProfile(p, testCase.TestData.network);
verifyEqual(testCase, normalized, testCase.TestData.profile);
end

function testApplyHardBoundsNoClippingTolerance(testCase)
n = testCase.TestData.network;
[p, row] = activeCapacity(testCase.TestData.profile);
lower = p.parameters.lower(row);
upper = p.parameters.upper(row);
for value = [lower, upper, p.parameters.nominal(row)]
    expected = n;
    expected.capacityJK(1) = value;
    verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, value), expected);
end
for value = [lower - eps(lower), upper + eps(upper)]
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile(n, p, value), ...
        'leotherm:DeviceCalibrationParameters');
end
end

function testApplyRejectsInvalidFreeVectors(testCase)
n = testCase.TestData.network;
[p, row] = activeCapacity(testCase.TestData.profile);
nominal = p.parameters.nominal(row);
for value = {[], [nominal, nominal], NaN, Inf, -Inf, nominal + 1i, ...
        "6200", {nominal}, true, zeros(2), zeros(1, 1, 2)}
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile(n, p, value{1}), ...
        'leotherm:DeviceCalibrationParameters');
end
p = testCase.TestData.profile;
for value = {[], zeros(0, 1), zeros(1, 0)}
    verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, value{1}), n);
end
for value = {0, false(0, 1), zeros(0, 2), zeros(0, 1, 2)}
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile(n, p, value{1}), ...
        'leotherm:DeviceCalibrationParameters');
end
end

function testApplyVectorFieldsAndPhysicalEndpoints(testCase)
n = testCase.TestData.network;
p = testCase.TestData.profile;
fields = ["internalPowerW", "projectedAreaM2", "radiatingAreaM2", ...
    "solarAbsorptivity", "irEmissivity"];
expected = n;
for k = 1:numel(fields)
    row = find(p.parameters.field == fields(k), 1);
    p = activate(p, row, 0, 1, 0.1);
    expected.(char(fields(k)))(1) = 1;
end
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, ones(5, 1)), expected);
for field = fields
    expected.(char(field))(1) = 0;
end
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, zeros(5, 1)), expected);
end

function testZeroConductanceEndpointAndFixedRowsStayUnchanged(testCase)
n = testCase.TestData.network;
[p, capacity] = activeCapacity(testCase.TestData.profile);
p.parameters.estimate(capacity) = false;
edge = find(p.parameters.field == "conductanceWK", 1);
p = activate(p, edge, 0, 2 * p.parameters.nominal(edge), 0.1);
expected = n;
left = find(string(n.nodeNames) == p.parameters.node(edge));
right = find(string(n.nodeNames) == p.parameters.peer(edge));
expected.conductanceWK(left, right) = 0;
expected.conductanceWK(right, left) = 0;
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, 0), expected);
verifyEqual(testCase, n, testCase.TestData.network);
end

function testSingleNodeNoEdgesAndRowVectors(testCase)
n = testCase.TestData.network;
n.nodeNames = {'single|node'};
fields = {'capacityJK', 'initialTemperatureK', 'internalPowerW', ...
    'projectedAreaM2', 'radiatingAreaM2', 'solarAbsorptivity', 'irEmissivity'};
for k = 1:numel(fields)
    n.(fields{k}) = n.(fields{k})(1);
end
n.normalBody = [1, 0, 0];
n.conductanceWK = 0;
n.bias.linearMPerK = 0;
n.bias.quadraticNode = 1;
n.roles = struct;
p = leotherm.deviceCalibrationProfile(n);
verifyEqual(testCase, height(p.parameters), 6);
verifyEqual(testCase, leotherm.applyDeviceCalibrationProfile(n, p, []), n);
n = testCase.TestData.network;
n.capacityJK = n.capacityJK';
p = leotherm.deviceCalibrationProfile(n);
[p, row] = activeCapacity(p);
actual = leotherm.applyDeviceCalibrationProfile(n, p, p.parameters.upper(row));
expected = n;
expected.capacityJK(1) = p.parameters.upper(row);
verifyEqual(testCase, actual, expected);
end

function testIntegerNetworkDoesNotTruncateFreeValues(testCase)
n = testCase.TestData.network;
n.capacityJK = int32(n.capacityJK);
p = leotherm.deviceCalibrationProfile(n);
[p, row] = activeCapacity(p);
value = p.parameters.nominal(row) + 0.5;
actual = leotherm.applyDeviceCalibrationProfile(n, p, value);
expected = n;
expected.capacityJK = double(n.capacityJK);
expected.capacityJK(1) = value;
verifyEqual(testCase, actual, expected);
end

function verifyInvalid(testCase, p)
verifyError(testCase, @() leotherm.validateDeviceCalibrationProfile( ...
    p, testCase.TestData.network), 'leotherm:DeviceCalibrationProfile');
end

function [p, row] = activeCapacity(p)
row = find(p.parameters.field == "capacityJK", 1);
nominal = p.parameters.nominal(row);
p = activate(p, row, 0.5 * nominal, 1.5 * nominal, 0.1 * nominal);
end

function p = activate(p, row, lower, upper, sigma)
p.parameters.lower(row) = lower;
p.parameters.upper(row) = upper;
p.parameters.priorSigma(row) = sigma;
p.parameters.estimate(row) = true;
p.parameters.evidence(row) = "Synthetic test assumption only.";
p.parameters.kind(row) = "physical";
end
