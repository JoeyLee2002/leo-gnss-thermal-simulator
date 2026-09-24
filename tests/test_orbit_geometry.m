function tests = test_orbit_geometry
tests = functiontests(localfunctions);
end

function testRaanBetaInverse(testCase)
epoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
scenario = leotherm.defaultScenario;
scenario.orbit.useJ2 = false;
targets = [-60, -30, 0, 30, 60];
for target = targets
    [raan, accessible] = leotherm.solveRaanForBeta( ...
        epoch, scenario.orbit.inclinationDeg, target, 1);
    verifyTrue(testCase, accessible);
    scenario.orbit.raanDeg = raan;
    orbit = leotherm.propagateCircularOrbit(epoch, 0, scenario.orbit);
    verifyEqual(testCase, orbit.betaDeg, target, 'AbsTol', 0.05);
end
end

function testInaccessibleBetaRejected(testCase)
epoch = datetime(2024, 6, 21, 0, 0, 0, 'TimeZone', 'UTC');
[raan, accessible] = leotherm.solveRaanForBeta(epoch, 10, 70, 1);
verifyFalse(testCase, accessible);
verifyTrue(testCase, isnan(raan));
end

function testNadirFrameOrthonormal(testCase)
scenario = leotherm.defaultScenario;
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, (0:60:600)', scenario.orbit);
frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
    orbit.sunPositionM, scenario.attitude);
for k = 1:size(frame, 1)
    dcm = squeeze(frame(k, :, :));
    verifyEqual(testCase, dcm * dcm', eye(3), 'AbsTol', 1e-11);
    verifyEqual(testCase, det(dcm), 1, 'AbsTol', 1e-11);
    nadir = -orbit.positionM(k, :) / norm(orbit.positionM(k, :));
    verifyEqual(testCase, dcm(3, :), nadir, 'AbsTol', 1e-11);
end
end

