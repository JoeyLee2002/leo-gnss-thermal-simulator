function result = simulateTrajectory(trajectory, scenario, network, analysisMask)
%SIMULATETRAJECTORY Simulate thermal response on an external ECI trajectory.
% Required fields are epoch, elapsedS, positionM, and velocityMps. Optional
% fields are sunPositionM, betaDeg, periodS, raanDeg, and frameBodyAxesECI.

leotherm.validateScenario(scenario);
leotherm.validateNetwork(network);
leotherm.validateTrajectory(trajectory);
nEpoch = numel(trajectory.elapsedS);
if nargin < 4 || isempty(analysisMask)
    analysisMask = true(nEpoch, 1);
end
analysisMask = logical(analysisMask(:));
if numel(analysisMask) ~= nEpoch || ~any(analysisMask)
    error('leotherm:InvalidAnalysisMask', ...
        'analysisMask must select at least one of the N trajectory epochs.');
end

orbit = trajectory;
if ~isfield(orbit, 'sunPositionM') || isempty(orbit.sunPositionM)
    orbit.sunPositionM = leotherm.solarVectorECI(orbit.epoch);
end
normal = normalizeRows(cross(orbit.positionM, orbit.velocityMps, 2));
sunDirection = normalizeRows(orbit.sunPositionM - orbit.positionM);
if ~isfield(orbit, 'betaDeg') || isempty(orbit.betaDeg)
    orbit.betaDeg = rad2deg(asin(min(max(sum(normal .* sunDirection, 2), -1), 1)));
end
if ~isfield(orbit, 'periodS') || isempty(orbit.periodS)
    c = leotherm.constants;
    radius = mean(vecnorm(orbit.positionM, 2, 2));
    orbit.periodS = 2 * pi * sqrt(radius^3 / c.muEarth);
end
if ~isfield(orbit, 'raanDeg') || isempty(orbit.raanDeg)
    orbit.raanDeg = mod(rad2deg(atan2(normal(:, 1), -normal(:, 2))), 360);
end

if isfield(trajectory, 'frameBodyAxesECI') && ~isempty(trajectory.frameBodyAxesECI)
    frame = trajectory.frameBodyAxesECI;
else
    frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
        orbit.sunPositionM, scenario.attitude);
end
if isfield(orbit, 'frameBodyAxesECI')
    orbit = rmfield(orbit, 'frameBodyAxesECI');
end

loads = leotherm.environmentHeatLoads(orbit, frame, network, scenario.environment);
[temperatureK, numerics] = leotherm.solveThermalNetwork(orbit.elapsedS, loads.totalExternalW, ...
    network, scenario.environment, scenario.integration);

result.scenario = scenario;
result.network = network;
result.timeS = orbit.elapsedS(analysisMask);
result.orbit = trimStructure(orbit, analysisMask, nEpoch);
result.frame = frame(analysisMask, :, :);
result.loads = trimStructure(loads, analysisMask, nEpoch);
result.temperatureK = temperatureK(analysisMask, :);
result.numerics = numerics;
result.numerics.integratedNetHeatJ = numerics.integratedNetHeatJ(analysisMask);
result.codeBiasM = leotherm.temperatureCodeBias(result.temperatureK, network.bias);
result.metrics = leotherm.computeMetrics(result.timeS, result.orbit, result.loads, ...
    result.temperatureK, result.codeBiasM, network);
end

function output = trimStructure(input, keep, nEpoch)
output = input;
fields = fieldnames(input);
for k = 1:numel(fields)
    value = input.(fields{k});
    if ~isscalar(value) && size(value, 1) == nEpoch
        subscripts = repmat({':'}, 1, ndims(value));
        subscripts{1} = keep;
        output.(fields{k}) = value(subscripts{:});
    end
end
end

function output = normalizeRows(input)
lengths = vecnorm(input, 2, 2);
if any(lengths <= 0)
    error('leotherm:InvalidTrajectory', ...
        'Trajectory contains a zero direction vector.');
end
output = input ./ lengths;
end
