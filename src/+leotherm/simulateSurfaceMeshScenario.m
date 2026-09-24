function result = simulateSurfaceMeshScenario(scenario, mesh, thermal)
%SIMULATESURFACEMESHSCENARIO Run an LEO face-resolved thermal simulation.
% Orbit, eclipse and attitude are supplied by the established simulator;
% each mesh face receives its own radiative forcing and participates in the
% gray-body radiosity solve. Optional centroid-ray self-shadowing is applied
% independently of the scalar Earth-eclipse factor.
if nargin < 3, thermal = struct; end
leotherm.validateScenario(scenario);
leotherm.validateSurfaceMesh(mesh);
c = leotherm.constants;
radius = c.radiusEarth + scenario.orbit.altitudeM;
periodS = 2 * pi * sqrt(radius^3 / c.muEarth);
mainSteps = floor(scenario.durationS / scenario.timeStepS);
mainElapsed = (0:mainSteps)' * scenario.timeStepS;
if mainElapsed(end) < scenario.durationS - eps(scenario.durationS)
    mainElapsed(end + 1, 1) = scenario.durationS;
end
warmupOrbits = 0;
if isfield(scenario, 'warmupOrbits') && ~scenario.convergence.enabled
    warmupOrbits = scenario.warmupOrbits;
end
warmupSteps = ceil(warmupOrbits * periodS / scenario.timeStepS);
elapsed = [(-warmupSteps:-1)' * scenario.timeStepS; mainElapsed];
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, elapsed, scenario.orbit);
if isfield(scenario.environment, 'freezeSunAtEpoch') && scenario.environment.freezeSunAtEpoch
    fixedSun = leotherm.solarVectorECI(scenario.startEpoch);
    orbit.sunPositionM = repmat(fixedSun, numel(elapsed), 1);
end
nEpoch = numel(elapsed);
nFace = size(mesh.faces, 1);
externalW = zeros(nEpoch, nFace);
directSolarW = zeros(nEpoch, nFace);
faceVisibleFraction = zeros(nEpoch, nFace);
eclipseVisibleFraction = zeros(nEpoch, 1);
shadowedFaceCount = zeros(nEpoch, 1);
shadowDiagnostics = struct('method', 'disabled');
shadowingEnabled = isfield(mesh, 'solarSelfShadowing') && mesh.solarSelfShadowing;
for k = 1:nEpoch
    frame = leotherm.bodyFrame(orbit.positionM(k, :), orbit.velocityMps(k, :), ...
        orbit.sunPositionM(k, :), scenario.attitude);
    sunECI = orbit.sunPositionM(k, :) - orbit.positionM(k, :);
    sunECI = sunECI / norm(sunECI);
    earthECI = -orbit.positionM(k, :) / norm(orbit.positionM(k, :));
    sunBody = squeeze(frame(1, :, :)) * sunECI';
    earthBody = squeeze(frame(1, :, :)) * earthECI';
    earthView = min((c.radiusEarth / norm(orbit.positionM(k, :)))^2, 1);
    dayside = max(dot(-earthECI, sunECI), 0);
    visible = leotherm.conicalShadowFraction(orbit.positionM(k, :), orbit.sunPositionM(k, :));
    env = scenario.environment;
    env.solarConstantWm2 = env.solarConstantWm2;
    if ~env.includeDirectSolar, env.solarConstantWm2 = 0; end
    if ~env.includeAlbedo, env.albedo = 0; end
    if ~env.includeEarthIR, env.earthIRWm2 = 0; end
    env.earthViewFactor = earthView;
    env.daysideFactor = dayside;
    loads = leotherm.surfaceMeshLoads(mesh, sunBody', earthBody', visible, env);
    externalW(k, :) = loads.totalExternalW';
    directSolarW(k, :) = loads.directSolarW';
    faceVisibleFraction(k, :) = loads.faceVisibleFraction';
    eclipseVisibleFraction(k) = visible;
    shadowedFaceCount(k) = loads.shadowDiagnostics.blockedFaces;
    if loads.selfShadowing, shadowDiagnostics = loads.shadowDiagnostics; end
end
solverThermal = thermal;
solverThermal.deepSpaceK = scenario.environment.deepSpaceK;
solverThermal.maximumStepS = scenario.timeStepS;
[temperature, numerics] = leotherm.solveSurfaceMeshThermal(elapsed, externalW, mesh, solverThermal);
keep = elapsed >= 0;
result = struct('scenario', scenario, 'mesh', mesh, 'timeS', elapsed(keep), ...
    'orbit', trimOrbit(orbit, keep), 'externalW', externalW(keep, :), ...
    'temperatureK', temperature(keep, :), 'numerics', numerics, ...
    'provenance', struct('model', 'face_resolved_gray_body_radiosity', ...
    'directSolarSelfShadowing', shadowingEnabled, ...
    'selfShadowingMethod', shadowDiagnostics.method, ...
    'faceToFaceRadiation', true, ...
    'solidMeshConduction', false, 'thermalBoundary', 'deep_space_only'));
result.directSolarW = directSolarW(keep, :);
result.faceVisibleFraction = faceVisibleFraction(keep, :);
result.eclipseVisibleFraction = eclipseVisibleFraction(keep);
result.shadowedFaceCount = shadowedFaceCount(keep);
result.shadowDiagnostics = shadowDiagnostics;
result.metrics = meshMetrics(result.timeS, result.temperatureK, result.externalW);
end

function orbit = trimOrbit(input, keep)
orbit = input;
fields = fieldnames(input);
for k = 1:numel(fields)
    value = input.(fields{k});
    if ~isscalar(value) && size(value, 1) == numel(keep)
        subscripts = repmat({':'}, 1, ndims(value));
        subscripts{1} = keep;
        orbit.(fields{k}) = value(subscripts{:});
    end
end
end

function metrics = meshMetrics(timeS, temperatureK, externalW)
metrics = struct('faceTemperatureMinK', min(temperatureK, [], 1)', ...
    'faceTemperatureMaxK', max(temperatureK, [], 1)', ...
    'faceTemperatureSpanK', max(temperatureK, [], 1)' - min(temperatureK, [], 1)', ...
    'totalExternalEnergyJ', trapz(timeS, sum(externalW, 2)));
end
