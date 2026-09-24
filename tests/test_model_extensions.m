function tests = test_model_extensions
tests = functiontests(localfunctions);
end

function testPeriodicInitializationConverges(testCase)
scenario = leotherm.defaultScenario;
scenario.timeStepS = 60;
scenario.convergence.toleranceK = 5e-3;
network = leotherm.defaultReceiverNetwork;
[state, diagnostics] = leotherm.initializePeriodicState(scenario, network);
verifyTrue(testCase, diagnostics.converged);
verifyLessThanOrEqual(testCase, diagnostics.periodicErrorK, ...
    scenario.convergence.toleranceK);
verifyTrue(testCase, all(isfinite(state)));
end

function testSymmetricNetworkHasNoPreferredExteriorMount(testCase)
network = leotherm.symmetricReceiverNetwork;
verifyEqual(testCase, rangeValue(network.capacityJK(1:6)), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, rangeValue(network.projectedAreaM2(1:6)), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, rangeValue(network.solarAbsorptivity(1:6)), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, network.projectedAreaM2(8), 0);
verifyEqual(testCase, network.normalBody(8, :), [0, 0, 0]);
verifyEqual(testCase, network.conductanceWK(1:6, 7), ...
    repmat(network.conductanceWK(1, 7), 6, 1));
end

function testControlledAsymmetryPreservesNetworkValidity(testCase)
base = leotherm.symmetricReceiverNetwork;
surface = leotherm.applyThermalAsymmetry(base, 'surface_optical', 0.4);
verifyGreaterThan(testCase, surface.solarAbsorptivity(3), ...
    surface.solarAbsorptivity(4));
mount = leotherm.applyThermalAsymmetry(base, 'receiver_mount', 1.0);
verifyGreaterThan(testCase, mount.projectedAreaM2(8), 0);
verifyEqual(testCase, mount.normalBody(8, :), [0, 0, -1]);
zero = leotherm.applyThermalAsymmetry(base, 'receiver_mount', 0);
verifyEqual(testCase, zero.projectedAreaM2, base.projectedAreaM2);
verifyEqual(testCase, zero.conductanceWK, base.conductanceWK);
end

function testHysteresisAreaForUnitCircle(testCase)
period = 100;
time = (0:0.25:300)';
phase = 2 * pi * time / period;
metrics = leotherm.hysteresisLoopMetrics(time, cos(phase), sin(phase), period);
verifyGreaterThanOrEqual(testCase, metrics.completeCycles, 2);
verifyEqual(testCase, metrics.areaPhysicalMedian, pi, 'AbsTol', 5e-3);
verifyGreaterThan(testCase, metrics.areaNormalizedMedian, 0);
end

function testPositivePhaseLagRejectsCycleAlias(testCase)
period = 100;
time = (0:1:500)';
forcing = sin(2 * pi * time / period);
response = sin(2 * pi * (time - 20) / period);
lag = leotherm.positivePhaseLag(time, forcing, response, period);
verifyEqual(testCase, lag, 20, 'AbsTol', 1);
verifyLessThanOrEqual(testCase, lag, period / 2);
end

function testOrbitalPeakLagUsesNextPeak(testCase)
period = 100;
time = (0:0.25:300)';
forcing = cos(2 * pi * time / period);
response = cos(2 * pi * (time - 20) / period);
metrics = leotherm.orbitalPeakLagMetrics(time, forcing, response, period);
verifyGreaterThanOrEqual(testCase, metrics.completeCycles, 2);
verifyEqual(testCase, metrics.peakToPeakLagMedianS, 20, 'AbsTol', 0.25);
verifyEqual(testCase, metrics.troughToTroughLagMedianS, 20, 'AbsTol', 0.25);
end

function testSatmoStyleNetworkIsSevenNodeModel(testCase)
network = leotherm.satmoStyleNetwork;
verifyEqual(testCase, numel(network.nodeNames), 7);
verifyEqual(testCase, size(network.conductanceWK), [7, 7]);
verifyEqual(testCase, sum(network.projectedAreaM2 > 0), 6);
end

function testGenericResponseRoleRunsWithoutGnssNodeNames(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 600;
scenario.timeStepS = 10;
scenario.convergence.enabled = false;
scenario.warmupOrbits = 1;
network = leotherm.satmoStyleNetwork;
result = leotherm.simulateScenario(scenario, network);
verifyTrue(testCase, isfinite(result.metrics.responseTemperatureSpanK));
verifyTrue(testCase, isnan(result.metrics.antennaTemperatureSpanK));
verifyEqual(testCase, result.metrics.responseTemperatureSpanK, ...
    result.metrics.rfTemperatureSpanK);
end

function testControlledSignedBetaBaselineIsSymmetric(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 2 * 3600;
scenario.timeStepS = 30;
scenario.orbit.inclinationDeg = 90;
scenario.orbit.useJ2 = false;
scenario.environment.freezeSunAtEpoch = true;
network = leotherm.symmetricReceiverNetwork;
spans = zeros(2, 1);
for index = 1:2
    target = [-30, 30];
    [scenario.orbit.raanDeg, accessible] = leotherm.solveRaanForBeta( ...
        scenario.startEpoch, scenario.orbit.inclinationDeg, target(index), 1);
    verifyTrue(testCase, accessible);
    result = leotherm.simulateScenario(scenario, network);
    spans(index) = result.metrics.responseTemperatureSpanK;
end
asymmetry = abs(diff(spans)) / mean(abs(spans));
verifyLessThan(testCase, asymmetry, 0.01);
end

function testUncertaintyEnsembleIsReproducible(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 600;
scenario.timeStepS = 60;
scenario.convergence.enabled = false;
scenario.warmupOrbits = 1;
network = leotherm.symmetricReceiverNetwork;
first = leotherm.runUncertaintyEnsemble(scenario, network, 2, 42, []);
second = leotherm.runUncertaintyEnsemble(scenario, network, 2, 42, []);
verifyEqual(testCase, first.capacity_factor, second.capacity_factor);
verifyEqual(testCase, first.conductance_factor, second.conductance_factor);
verifyEqual(testCase, first.rf_temperature_span_k, ...
    second.rf_temperature_span_k, 'AbsTol', 1e-12);
end

function value = rangeValue(values)
value = max(values) - min(values);
end
