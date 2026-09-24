function tests = test_end_to_end
tests = functiontests(localfunctions);
end

function testReferenceScenarioIsFinite(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 2 * 3600;
scenario.timeStepS = 30;
scenario.warmupOrbits = 8;
[scenario.orbit.raanDeg, accessible] = leotherm.solveRaanForBeta( ...
    scenario.startEpoch, scenario.orbit.inclinationDeg, 0, 1);
verifyTrue(testCase, accessible);
network = leotherm.defaultReceiverNetwork;
result = leotherm.simulateScenario(scenario, network);
verifyTrue(testCase, all(isfinite(result.temperatureK), 'all'));
verifyGreaterThan(testCase, min(result.temperatureK, [], 'all'), 150);
verifyLessThan(testCase, max(result.temperatureK, [], 'all'), 400);
verifyGreaterThan(testCase, result.metrics.eclipseFraction, 0.2);
verifyGreaterThan(testCase, result.metrics.rfTemperatureSpanK, 0);
verifyGreaterThan(testCase, result.metrics.codeBiasSpanM, 0);
end

function testHeatLoadsAreNonnegative(testCase)
scenario = leotherm.defaultScenario;
network = leotherm.defaultReceiverNetwork;
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, (0:60:600)', scenario.orbit);
frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
    orbit.sunPositionM, scenario.attitude);
loads = leotherm.environmentHeatLoads(orbit, frame, network, scenario.environment);
verifyGreaterThanOrEqual(testCase, min(loads.totalExternalW, [], 'all'), 0);
verifyGreaterThanOrEqual(testCase, min(loads.visibleFraction), 0);
verifyLessThanOrEqual(testCase, max(loads.visibleFraction), 1);
end

function testExternalTrajectoryInterface(testCase)
scenario = leotherm.defaultScenario;
scenario.timeStepS = 30;
network = leotherm.defaultReceiverNetwork;
elapsedS = (-3600:scenario.timeStepS:1800)';
trajectory = leotherm.propagateCircularOrbit( ...
    scenario.startEpoch, elapsedS, scenario.orbit);
keep = elapsedS >= 0;
result = leotherm.simulateTrajectory(trajectory, scenario, network, keep);
verifyEqual(testCase, result.timeS(1), 0);
verifyEqual(testCase, size(result.temperatureK, 1), sum(keep));
verifyEqual(testCase, size(result.frame), [sum(keep), 3, 3]);
verifyTrue(testCase, all(isfinite(result.codeBiasM)));
end
