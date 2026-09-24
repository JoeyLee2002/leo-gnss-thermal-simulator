function [temperatureK, diagnostics] = solveSurfaceMeshThermal(timeS, externalW, mesh, thermal)
%SOLVESURFACEMESHTHERMAL Solve a face-resolved gray-body thermal model.
% The model includes conduction, deep-space exchange, and diffuse face-to-face
% radiation. It is intentionally separate from the established node solver.
leotherm.validateSurfaceMesh(mesh);
timeS = timeS(:);
nFace = size(mesh.faces, 1);
if ~isnumeric(timeS) || numel(timeS) < 2 || any(~isfinite(timeS)) || any(diff(timeS) <= 0)
    error('leotherm:InvalidMeshThermalInput', 'timeS must be a finite increasing vector.');
end
if ~isnumeric(externalW) || ~isequal(size(externalW), [numel(timeS), nFace]) ...
        || any(~isfinite(externalW), 'all')
    error('leotherm:InvalidMeshThermalInput', 'externalW must be an epoch-by-face matrix.');
end
if nargin < 4 || isempty(thermal), thermal = struct; end
capacityFallback = mesh.faceAreasM2(:) * 5000;
capacitySource = 'reference_area_scaled_default';
if isfield(mesh, 'faceHeatCapacityJK')
    capacityFallback = mesh.faceHeatCapacityJK;
    capacitySource = 'mesh.faceHeatCapacityJK';
end
initialFallback = 293.15 * ones(nFace, 1);
initialSource = 'uniform_reference_default';
if isfield(mesh, 'faceInitialTemperatureK')
    initialFallback = mesh.faceInitialTemperatureK;
    initialSource = 'mesh.faceInitialTemperatureK';
end
capacity = getVector(thermal, 'capacityJK', capacityFallback, nFace, 'capacityJK');
if isfield(thermal, 'capacityJK'), capacitySource = 'thermal.capacityJK'; end
initial = getVector(thermal, 'initialTemperatureK', initialFallback, nFace, 'initialTemperatureK');
if isfield(thermal, 'initialTemperatureK'), initialSource = 'thermal.initialTemperatureK'; end
epsilon = 0.80 * ones(nFace, 1);
epsilonSource = 'reference_emissivity_default';
if isfield(mesh, 'faceIREmissivity')
    epsilon = mesh.faceIREmissivity(:);
    epsilonSource = 'mesh.faceIREmissivity';
end
if isfield(thermal, 'irEmissivity')
    epsilon = getVector(thermal, 'irEmissivity', epsilon, nFace, 'irEmissivity');
    epsilonSource = 'thermal.irEmissivity';
end
conductance = zeros(nFace);
conductanceSource = 'zero_mesh_conduction_default';
if isfield(mesh, 'faceConductanceWK')
    conductance = mesh.faceConductanceWK;
    conductanceSource = 'mesh.faceConductanceWK';
end
if isfield(thermal, 'conductanceWK'), conductance = thermal.conductanceWK; end
if isfield(thermal, 'conductanceWK'), conductanceSource = 'thermal.conductanceWK'; end
if ~isnumeric(conductance) || ~isequal(size(conductance), [nFace nFace]) ...
        || any(~isfinite(conductance), 'all') || any(conductance(:) < 0) ...
        || max(abs(conductance - conductance'), [], 'all') > 1e-12 || any(diag(conductance) ~= 0)
    error('leotherm:InvalidMeshThermalInput', 'conductanceWK must be symmetric and nonnegative.');
end
spaceK = 3;
if isfield(thermal, 'deepSpaceK'), spaceK = thermal.deepSpaceK; end
if ~isnumeric(spaceK) || ~isscalar(spaceK) || ~isfinite(spaceK) || spaceK < 0
    error('leotherm:InvalidMeshThermalInput', 'deepSpaceK must be a finite nonnegative scalar.');
end
if isfield(mesh, 'viewFactors')
    F = mesh.viewFactors;
    viewDiagnostics = struct('method', 'mesh_attached');
else
    viewOptions = struct('visibility', 'ray');
    if isfield(thermal, 'radiationSide'), viewOptions.surfaceSide = thermal.radiationSide; end
    [F, viewDiagnostics] = leotherm.computeMeshViewFactors(mesh, viewOptions);
end
if any(sum(F, 2) > 1 + 1e-8)
    error('leotherm:InvalidMeshThermalInput', 'View-factor row sums exceed one.');
end
minimumK = getScalar(thermal, 'minimumTemperatureK', 100, 'minimumTemperatureK');
maximumK = getScalar(thermal, 'maximumTemperatureK', 500, 'maximumTemperatureK');
maximumStep = Inf;
if isfield(thermal, 'maximumStepS'), maximumStep = thermal.maximumStepS; end
if ~isnumeric(maximumStep) || ~isscalar(maximumStep) || isnan(maximumStep) || maximumStep <= 0
    error('leotherm:InvalidMeshThermalInput', 'maximumStepS must be positive or Inf.');
end
if minimumK >= maximumK, error('leotherm:InvalidMeshThermalInput', 'Temperature bounds are invalid.'); end
temperatureK = zeros(numel(timeS), nFace);
temperatureK(1, :) = initial';
c = leotherm.constants;
sigma = c.sigma;
spaceFourth = spaceK^4;
laplacian = diag(sum(conductance, 2)) - conductance;
diagnostics = struct('method', 'gray_body_radiosity_rk4', ...
    'viewFactors', F, 'viewFactorDiagnostics', viewDiagnostics, ...
    'capacitySource', capacitySource, ...
    'initialTemperatureSource', initialSource, ...
    'emissivitySource', epsilonSource, ...
    'conductanceSource', conductanceSource, ...
    'thermalParameterProvenance', meshField(mesh, 'thermalParameterProvenance', 'not_declared'), ...
    'acceptedSteps', 0, 'maximumEnergyClosureJ', 0, ...
    'integratedExternalHeatJ', zeros(numel(timeS), 1));
for k = 1:(numel(timeS) - 1)
    dt = timeS(k + 1) - timeS(k);
    h = min(dt, maximumStep);
    elapsed = 0;
    state = temperatureK(k, :)';
    heat = 0;
    while elapsed < dt
        h = min(h, dt - elapsed);
        rhs = @(y, u) derivative(y, (1-u/dt)*externalW(k, :)' + ...
            (u/dt)*externalW(k+1, :)', F, epsilon, mesh.faceAreasM2(:), ...
            sigma, spaceFourth, laplacian, capacity);
        k1 = rhs(state, elapsed);
        k2 = rhs(state + h*k1/2, elapsed + h/2);
        k3 = rhs(state + h*k2/2, elapsed + h/2);
        k4 = rhs(state + h*k3, elapsed + h);
        increment = h * (k1 + 2*k2 + 2*k3 + k4) / 6;
        state = state + increment;
        if any(~isfinite(state)) || any(state < minimumK) || any(state > maximumK)
            error('leotherm:MeshThermalStateOutOfBounds', 'Face temperature left the configured bounds.');
        end
        heat = heat + sum(capacity .* increment);
        elapsed = elapsed + h;
        diagnostics.acceptedSteps = diagnostics.acceptedSteps + 1;
    end
    temperatureK(k + 1, :) = state';
    diagnostics.integratedExternalHeatJ(k + 1) = diagnostics.integratedExternalHeatJ(k) ...
        + dt * sum((externalW(k, :)' + externalW(k+1, :)') / 2);
    diagnostics.maximumEnergyClosureJ = max(diagnostics.maximumEnergyClosureJ, ...
        abs(sum(capacity .* (state - temperatureK(k, :)')) - heat));
end
end

function rate = derivative(T, external, F, epsilon, area, sigma, spaceFourth, laplacian, capacity)
n = numel(T);
radiosityMatrix = eye(n) - diag(1 - epsilon) * F;
source = epsilon .* sigma .* (T.^4) + ...
    (1 - epsilon) .* (1 - sum(F, 2)) .* sigma .* spaceFourth;
radiosity = radiosityMatrix \ source;
irradiation = F * radiosity + (1 - sum(F, 2)) .* sigma .* spaceFourth;
netRadiated = area .* (radiosity - irradiation);
conductive = -laplacian * T;
rate = (external + conductive - netRadiated) ./ capacity;
end

function value = getVector(input, name, fallback, n, label)
value = fallback;
if isfield(input, name), value = input.(name); end
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= n ...
        || any(~isfinite(value)) || any(value <= 0)
    error('leotherm:InvalidMeshThermalInput', '%s must contain %d positive values.', label, n);
end
value = value(:);
end

function value = getScalar(input, name, fallback, label)
value = fallback;
if isfield(input, name), value = input.(name); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('leotherm:InvalidMeshThermalInput', '%s must be positive.', label);
end
end

function value = meshField(mesh, name, fallback)
value = fallback;
if isfield(mesh, name), value = mesh.(name); end
end
