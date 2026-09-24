function result = simulateScenario(scenario, network)
%SIMULATESCENARIO Run orbit, environment, thermal, and bias models end to end.

leotherm.validateScenario(scenario);
leotherm.validateNetwork(network);
c = leotherm.constants;
radius = c.radiusEarth + scenario.orbit.altitudeM;
periodS = 2 * pi * sqrt(radius^3 / c.muEarth);
mainSteps = floor(scenario.durationS / scenario.timeStepS);
mainElapsedS = (0:mainSteps)' * scenario.timeStepS;
if mainElapsedS(end) < scenario.durationS - eps(scenario.durationS)
    mainElapsedS(end + 1, 1) = scenario.durationS;
end

if isfield(scenario, 'convergence') && scenario.convergence.enabled
    [initialTemperatureK, convergence] = ...
        leotherm.initializePeriodicState(scenario, network);
    runNetwork = network;
    runNetwork.initialTemperatureK = initialTemperatureK;
    orbit = leotherm.propagateCircularOrbit( ...
        scenario.startEpoch, mainElapsedS, scenario.orbit);
    orbit = applyControlledSun(orbit, scenario);
    result = leotherm.simulateTrajectory(orbit, scenario, runNetwork, true(size(mainElapsedS)));
else
    warmupS = scenario.warmupOrbits * periodS;
    warmupSteps = ceil(warmupS / scenario.timeStepS);
    elapsedS = (-warmupSteps:mainSteps)' * scenario.timeStepS;
    if elapsedS(end) < scenario.durationS - eps(scenario.durationS)
        elapsedS(end + 1, 1) = scenario.durationS;
    end
    orbit = leotherm.propagateCircularOrbit( ...
        scenario.startEpoch, elapsedS, scenario.orbit);
    orbit = applyControlledSun(orbit, scenario);
    keep = elapsedS >= 0;
    result = leotherm.simulateTrajectory(orbit, scenario, network, keep);
    convergence.enabled = false;
    convergence.converged = NaN;
    convergence.cycles = scenario.warmupOrbits;
    convergence.periodS = periodS;
    convergence.periodicErrorK = NaN;
    convergence.nodePeriodicErrorK = NaN(numel(network.nodeNames), 1);
    convergence.toleranceK = NaN;
    convergence.requiredStableCycles = NaN;
    convergence.method = 'fixed_backward_warmup';
end
result.network = network;
result.initialTemperatureUsedK = result.temperatureK(1, :)';
result.convergence = convergence;
end

function orbit = applyControlledSun(orbit, scenario)
if isfield(scenario.environment, 'freezeSunAtEpoch') ...
        && scenario.environment.freezeSunAtEpoch
    sunAtEpoch = leotherm.solarVectorECI(scenario.startEpoch);
    orbit.sunPositionM = repmat(sunAtEpoch, numel(orbit.elapsedS), 1);
    normal = normalizeRows(cross(orbit.positionM, orbit.velocityMps, 2));
    sunDirection = normalizeRows(orbit.sunPositionM - orbit.positionM);
    orbit.betaDeg = rad2deg(asin(min(max(sum(normal .* sunDirection, 2), -1), 1)));
end
end

function output = normalizeRows(input)
output = input ./ vecnorm(input, 2, 2);
end
