function [initialTemperatureK, diagnostics] = initializePeriodicState(scenario, network)
%INITIALIZEPERIODICSTATE Find the periodic thermal state at analysis start.
% A repeatable one-orbit forcing cycle is constructed with J2 disabled and the
% Sun direction frozen at the analysis epoch. The nonlinear network is cycled
% until the same-phase node temperatures converge.

c = leotherm.constants;
radius = c.radiusEarth + scenario.orbit.altitudeM;
periodS = 2 * pi * sqrt(radius^3 / c.muEarth);
timeS = (0:scenario.timeStepS:periodS)';
if timeS(end) < periodS - eps(periodS)
    timeS(end + 1, 1) = periodS;
end

orbitConfig = scenario.orbit;
orbitConfig.useJ2 = false;
orbit = leotherm.propagateCircularOrbit( ...
    scenario.startEpoch, timeS, orbitConfig);
orbit.sunPositionM = repmat(orbit.sunPositionM(1, :), numel(timeS), 1);
normal = normalizeRows(cross(orbit.positionM, orbit.velocityMps, 2));
sunDirection = normalizeRows(orbit.sunPositionM - orbit.positionM);
orbit.betaDeg = rad2deg(asin(min(max(sum(normal .* sunDirection, 2), -1), 1)));

frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
    orbit.sunPositionM, scenario.attitude);
loads = leotherm.environmentHeatLoads(orbit, frame, network, scenario.environment);
externalW = loads.totalExternalW;
externalW(end, :) = externalW(1, :);

state = network.initialTemperatureK(:);
errorK = Inf;
stableCycles = 0;
nodeErrorK = Inf(size(state));
converged = false;
assert(scenario.convergence.maximumCycles >= 1, ...
    'maximumCycles must be at least one.');
for cycle = 1:scenario.convergence.maximumCycles
    cycleNetwork = network;
    cycleNetwork.initialTemperatureK = state;
    temperatureK = leotherm.solveThermalNetwork(timeS, externalW, ...
        cycleNetwork, scenario.environment, scenario.integration);
    next = temperatureK(end, :)';
    nodeErrorK = abs(next - state);
    errorK = max(nodeErrorK);
    state = next;
    if cycle >= scenario.convergence.minimumCycles ...
            && errorK <= scenario.convergence.toleranceK
        stableCycles = stableCycles + 1;
    else
        stableCycles = 0;
    end
    if stableCycles >= scenario.convergence.requiredStableCycles
        converged = true;
        break
    end
end

diagnostics.enabled = true;
diagnostics.converged = converged;
diagnostics.cycles = cycle;
diagnostics.periodS = periodS;
diagnostics.periodicErrorK = errorK;
diagnostics.nodePeriodicErrorK = nodeErrorK;
diagnostics.toleranceK = scenario.convergence.toleranceK;
diagnostics.requiredStableCycles = scenario.convergence.requiredStableCycles;
diagnostics.method = 'frozen_sun_repeatable_orbit';

if ~converged
    message = sprintf(['Periodic initialization did not converge after %d cycles; ' ...
        'maximum same-phase node error is %.6g K.'], cycle, errorK);
    if scenario.convergence.failOnNonConvergence
        error('leotherm:PeriodicInitializationFailed', '%s', message);
    else
        warning('leotherm:PeriodicInitializationNotConverged', '%s', message);
    end
end
initialTemperatureK = state;
end

function output = normalizeRows(input)
lengths = vecnorm(input, 2, 2);
assert(all(lengths > 0), 'Cannot normalize a zero direction vector.');
output = input ./ lengths;
end
