function [temperatureK, diagnostics] = solveVolumeThermal(timeS, nodalPowerW, model, thermal)
%SOLVEVOLUMETHERMAL Solve transient tetrahedral heat conduction.
% Backward Euler is the default theta-method member and fixed temperatures
% are imposed by elimination, matching standard implicit FE practice.
if nargin < 4 || isempty(thermal), thermal = struct; end
timeS = timeS(:);
if ~isnumeric(timeS) || numel(timeS) < 2 || any(~isfinite(timeS)) || any(diff(timeS) <= 0)
    error('leotherm:InvalidVolumeThermalInput', 'timeS must be finite and strictly increasing.');
end
if ~isstruct(model) || ~isscalar(model) || ~isfield(model, 'nodeCount') ...
        || ~isfield(model, 'capacityJK') || ~isfield(model, 'stiffnessWK')
    error('leotherm:InvalidVolumeThermalInput', 'The assembled volume thermal model is incomplete.');
end
nNode = model.nodeCount;
if ~isnumeric(nodalPowerW) || ~isequal(size(nodalPowerW), [numel(timeS), nNode]) ...
        || any(~isfinite(nodalPowerW), 'all')
    error('leotherm:InvalidVolumeThermalInput', 'nodalPowerW must be an epoch-by-node matrix.');
end
capacity = model.capacityJK(:); stiffness = model.stiffnessWK;
if numel(capacity) ~= nNode || any(~isfinite(capacity)) || any(capacity <= 0) ...
        || ~isequal(size(stiffness), [nNode nNode]) || any(~isfinite(stiffness), 'all')
    error('leotherm:InvalidVolumeThermalInput', 'Model capacity and stiffness dimensions are invalid.');
end
initial = vectorOption(thermal, 'initialTemperatureK', 293.15, nNode, 'initialTemperatureK');
theta = scalarOption(thermal, 'theta', 1, 'theta');
if theta < 0.5 || theta > 1, error('leotherm:InvalidVolumeThermalInput', 'theta must lie in [0.5, 1].'); end
fixedIndex = zeros(0, 1); fixedTemperature = zeros(numel(timeS), 0);
if isfield(thermal, 'fixedNodeIndices')
    fixedIndex = thermal.fixedNodeIndices(:);
    if ~isnumeric(fixedIndex) || any(fixedIndex ~= floor(fixedIndex)) ...
            || any(fixedIndex < 1) || any(fixedIndex > nNode)
        error('leotherm:InvalidVolumeThermalInput', 'fixedNodeIndices must be valid integer node indices.');
    end
    fixedIndex = unique(fixedIndex, 'stable');
    fixedTemperature = fixedTemperatureOption(thermal, 'fixedTemperatureK', 293.15, ...
        numel(timeS), numel(fixedIndex));
end
minimumK = scalarOption(thermal, 'minimumTemperatureK', 0, 'minimumTemperatureK');
maximumK = scalarOption(thermal, 'maximumTemperatureK', Inf, 'maximumTemperatureK');
if minimumK >= maximumK, error('leotherm:InvalidVolumeThermalInput', 'Temperature bounds are invalid.'); end
temperatureK = zeros(numel(timeS), nNode); temperatureK(1, :) = initial';
if ~isempty(fixedIndex), temperatureK(1, fixedIndex) = fixedTemperature(1, :); end
free = true(nNode, 1); free(fixedIndex) = false;
mass = spdiags(capacity, 0, nNode, nNode);
diagnostics = struct('method', 'theta_linear_tetrahedron_conduction', ...
    'theta', theta, 'fixedNodeCount', numel(fixedIndex), 'acceptedSteps', 0, ...
    'maximumLinearResidual', 0, 'integratedNodalPowerJ', zeros(numel(timeS), 1), ...
    'formulation', model.formulation);
for k = 1:(numel(timeS) - 1)
    dt = timeS(k + 1) - timeS(k);
    A = mass / dt + theta * stiffness;
    rhs = (mass / dt - (1 - theta) * stiffness) * temperatureK(k, :)' ...
        + theta * nodalPowerW(k + 1, :)' + (1 - theta) * nodalPowerW(k, :)';
    state = zeros(nNode, 1);
    if isempty(fixedIndex)
        state = A \ rhs;
    else
        state(fixedIndex) = fixedTemperature(k + 1, :)';
        state(free) = A(free, free) \ (rhs(free) - A(free, fixedIndex) * state(fixedIndex));
    end
    residual = A * state - rhs; residual(fixedIndex) = 0;
    if any(~isfinite(state)) || any(state < minimumK) || any(state > maximumK)
        error('leotherm:VolumeThermalStateOutOfBounds', 'Volume temperature left the configured bounds.');
    end
    temperatureK(k + 1, :) = state'; diagnostics.acceptedSteps = diagnostics.acceptedSteps + 1;
    diagnostics.maximumLinearResidual = max(diagnostics.maximumLinearResidual, norm(residual, inf));
    diagnostics.integratedNodalPowerJ(k + 1) = diagnostics.integratedNodalPowerJ(k) ...
        + dt * sum((nodalPowerW(k, :)' + nodalPowerW(k + 1, :)') / 2);
end
end

function value = vectorOption(input, name, fallback, n, label)
value = fallback;
if isfield(input, name), value = input.(name); end
if ~isnumeric(value) || ~isvector(value) || (numel(value) ~= 1 && numel(value) ~= n) ...
        || any(~isfinite(value)) || any(value <= 0)
    error('leotherm:InvalidVolumeThermalInput', '%s must be positive scalar or node vector.', label);
end
if isscalar(value), value = repmat(value, n, 1); else, value = value(:); end
end

function value = scalarOption(input, name, fallback, label)
value = fallback;
if isfield(input, name), value = input.(name); end
if ~isnumeric(value) || ~isscalar(value) || isnan(value) || value < 0
    error('leotherm:InvalidVolumeThermalInput', '%s must be a nonnegative scalar.', label);
end
end

function value = fixedTemperatureOption(input, name, fallback, nEpoch, nFixed)
value = fallback;
if isfield(input, name), value = input.(name); end
if isscalar(value), value = repmat(value, nEpoch, nFixed); end
if isvector(value) && numel(value) == nFixed, value = repmat(value(:)', nEpoch, 1); end
if ~isnumeric(value) || ~isequal(size(value), [nEpoch, nFixed]) ...
        || any(~isfinite(value), 'all') || any(value <= 0, 'all')
    error('leotherm:InvalidVolumeThermalInput', 'fixedTemperatureK must align with fixed nodes and epochs.');
end
end
