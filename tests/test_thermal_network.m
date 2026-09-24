function tests = test_thermal_network
tests = functiontests(localfunctions);
end

function testIsolatedConductionConservesEnergy(testCase)
network = twoNodeNetwork;
network.initialTemperatureK = [280; 320];
network.capacityJK = [100; 200];
network.conductanceWK = [0, 1; 1, 0];
timeS = (0:2:5000)';
environment = baseEnvironment;
limits.minimumTemperatureK = 1;
limits.maximumTemperatureK = 1000;
temperature = leotherm.solveThermalNetwork(timeS, zeros(numel(timeS), 2), ...
    network, environment, limits);
energy = temperature * network.capacityJK;
verifyEqual(testCase, max(energy) - min(energy), 0, 'AbsTol', 1e-8);
expected = sum(network.initialTemperatureK .* network.capacityJK) / sum(network.capacityJK);
verifyEqual(testCase, temperature(end, 1), expected, 'AbsTol', 1e-6);
verifyEqual(testCase, temperature(end, 2), expected, 'AbsTol', 1e-6);
end

function testRadiativeEquilibrium(testCase)
network = oneNodeNetwork;
network.initialTemperatureK = 300;
network.capacityJK = 100;
network.internalPowerW = 50;
network.radiatingAreaM2 = 1;
network.irEmissivity = 0.8;
timeS = (0:10:50000)';
environment = baseEnvironment;
limits.minimumTemperatureK = 1;
limits.maximumTemperatureK = 1000;
temperature = leotherm.solveThermalNetwork(timeS, zeros(numel(timeS), 1), ...
    network, environment, limits);
c = leotherm.constants;
expected = (50 / (0.8 * c.sigma) + environment.deepSpaceK^4)^0.25;
verifyEqual(testCase, temperature(end), expected, 'AbsTol', 0.02);
end

function testIndependentEnergyLedgerCloses(testCase)
network = oneNodeNetwork;
network.initialTemperatureK = 280;
network.capacityJK = 100;
network.internalPowerW = 10;
network.radiatingAreaM2 = 0;
timeS = (0:5:100)';
environment = baseEnvironment;
limits.minimumTemperatureK = 1;
limits.maximumTemperatureK = 1000;
external = repmat(3, numel(timeS), 1);
[temperature, diagnostics] = leotherm.solveThermalNetwork( ...
    timeS, external, network, environment, limits);
stored = network.capacityJK .* (temperature(:,1) - temperature(1,1));
ledger = diagnostics.integratedExternalHeatJ + diagnostics.integratedInternalHeatJ ...
    - diagnostics.integratedRadiatedHeatJ + diagnostics.integratedBoundaryHeatJ;
verifyEqual(testCase, diagnostics.integratedExternalHeatJ(end), 3*timeS(end), 'AbsTol', 1e-10);
verifyEqual(testCase, diagnostics.integratedInternalHeatJ(end), 10*timeS(end), 'AbsTol', 1e-10);
verifyEqual(testCase, stored(end), ledger(end), 'AbsTol', 1e-8);
verifyLessThan(testCase, diagnostics.maximumEnergyClosureJ, 1e-8);
verifyEqual(testCase, diagnostics.energyClosureResidualJ(end), 0, 'AbsTol', 1e-8);
end

function network = oneNodeNetwork
network.name = 'one_node_test';
network.nodeNames = {'node'};
network.capacityJK = 100;
network.initialTemperatureK = 293;
network.internalPowerW = 0;
network.projectedAreaM2 = 0;
network.radiatingAreaM2 = 0;
network.normalBody = [0, 0, 0];
network.solarAbsorptivity = 0;
network.irEmissivity = 0;
network.conductanceWK = 0;
network.bias.linearMPerK = 0;
network.bias.quadraticNode = 1;
network.bias.quadraticMPerK2 = 0;
end

function network = twoNodeNetwork
one = oneNodeNetwork;
network = one;
network.name = 'two_node_test';
network.nodeNames = {'left', 'right'};
fields = {'capacityJK', 'initialTemperatureK', 'internalPowerW', ...
    'projectedAreaM2', 'radiatingAreaM2', 'solarAbsorptivity', 'irEmissivity'};
for k = 1:numel(fields)
    network.(fields{k}) = repmat(one.(fields{k}), 2, 1);
end
network.normalBody = zeros(2, 3);
network.conductanceWK = zeros(2);
network.bias.linearMPerK = zeros(2, 1);
end

function environment = baseEnvironment
environment.deepSpaceK = 3;
end
