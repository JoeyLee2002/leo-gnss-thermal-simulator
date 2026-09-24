function tests = test_coupling_options
tests = functiontests(localfunctions);
end

function testDefaultsDisableOptionalBoundaries(testCase)
options = leotherm.defaultCouplingOptions;
normalized = leotherm.normalizeCouplingOptions(struct, struct('nodeCount', 4));
verifyEmpty(testCase, normalized.contacts);
verifyEmpty(testCase, normalized.volumeThermal.fixedNodeIndices);
verifyEqual(testCase, normalized.volumeThermal.fixedTemperatureK, 293.15);
verifyEqual(testCase, options.volumeThermal.maximumTemperatureK, 500);
end

function testPartialOptionsAreExplicitlyCompleted(testCase)
options = leotherm.normalizeCouplingOptions(struct( ...
    'contacts', struct('leftNodes', 1, 'rightNodes', 2, 'conductanceWK', 0.5), ...
    'volumeThermal', struct('fixedNodeIndices', 1, 'fixedTemperatureK', 300)), ...
    struct('nodeCount', 4));
verifyEqual(testCase, options.contacts.conductanceWK, 0.5);
verifyEqual(testCase, options.volumeThermal.initialTemperatureK, 293.15);
verifyEqual(testCase, options.volumeThermal.fixedTemperatureK, 300);
end

function testGuiParserRejectsPartialContact(testCase)
defaults = leotherm.defaultCouplingOptions;
verifyError(testCase, @() leotherm.parseCouplingOptions({'1','','0.5','','293.15'}, ...
    defaults.volumeThermal), 'leotherm:InvalidCouplingOptions');
end

function testGuiParserAcceptsLists(testCase)
answer = {'1, 2', '3', '0.5', '1', '300'};
defaults = leotherm.defaultCouplingOptions;
options = leotherm.parseCouplingOptions(answer, defaults.volumeThermal);
verifyEqual(testCase, options.contacts.leftNodes, [1; 2]);
verifyEqual(testCase, options.contacts.rightNodes, 3);
verifyEqual(testCase, options.volumeThermal.fixedNodeIndices, 1);
verifyEqual(testCase, options.volumeThermal.fixedTemperatureK, 300);
end
