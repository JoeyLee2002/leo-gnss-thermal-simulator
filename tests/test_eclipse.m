function tests = test_eclipse
tests = functiontests(localfunctions);
end

function testBetaZeroEclipseAgainstAnalyticLimit(testCase)
scenario = leotherm.defaultScenario;
scenario.orbit.useJ2 = false;
[scenario.orbit.raanDeg, accessible] = leotherm.solveRaanForBeta( ...
    scenario.startEpoch, scenario.orbit.inclinationDeg, 0, 1);
verifyTrue(testCase, accessible);
c = leotherm.constants;
a = c.radiusEarth + scenario.orbit.altitudeM;
periodS = 2 * pi * sqrt(a^3 / c.muEarth);
timeS = linspace(0, periodS, 6001)';
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, timeS, scenario.orbit);
visible = leotherm.conicalShadowFraction(orbit.positionM, orbit.sunPositionM);
numericFraction = mean(visible < 0.5);
analyticFraction = asin(c.radiusEarth / a) / pi;
verifyEqual(testCase, numericFraction, analyticFraction, 'AbsTol', 0.01);
end

function testHighBetaHasNoUmbra(testCase)
scenario = leotherm.defaultScenario;
scenario.orbit.useJ2 = false;
[scenario.orbit.raanDeg, accessible] = leotherm.solveRaanForBeta( ...
    scenario.startEpoch, scenario.orbit.inclinationDeg, 80, 1);
verifyTrue(testCase, accessible);
c = leotherm.constants;
a = c.radiusEarth + scenario.orbit.altitudeM;
periodS = 2 * pi * sqrt(a^3 / c.muEarth);
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, ...
    linspace(0, periodS, 2001)', scenario.orbit);
visible = leotherm.conicalShadowFraction(orbit.positionM, orbit.sunPositionM);
verifyGreaterThan(testCase, min(visible), 0.999);
end

