function loads = surfaceMeshLoads(mesh, sunDirectionBody, earthDirectionBody, visibleFraction, environment, options)
%SURFACEMESHLOADS Evaluate face-resolved radiative loads for one pose.
% Direct solar visibility combines the scalar Earth-eclipse factor with an
% optional per-face geometric self-shadowing factor.
leotherm.validateSurfaceMesh(mesh);
if nargin < 6 || isempty(options), options = struct; end
if ~isnumeric(sunDirectionBody) || ~isequal(size(sunDirectionBody), [1 3]) ...
        || any(~isfinite(sunDirectionBody)) || norm(sunDirectionBody) <= 0
    error('leotherm:InvalidMeshLoads', 'sunDirectionBody must be one nonzero 1-by-3 vector.');
end
if ~isnumeric(earthDirectionBody) || ~isequal(size(earthDirectionBody), [1 3]) ...
        || any(~isfinite(earthDirectionBody)) || norm(earthDirectionBody) <= 0
    error('leotherm:InvalidMeshLoads', 'earthDirectionBody must be one nonzero 1-by-3 vector.');
end
if ~isnumeric(visibleFraction) || any(~isfinite(visibleFraction(:))) ...
        || any(visibleFraction(:) < 0) || any(visibleFraction(:) > 1) ...
        || ~(isscalar(visibleFraction) || numel(visibleFraction) == size(mesh.faces, 1))
    error('leotherm:InvalidMeshLoads', ...
        'visibleFraction must be a scalar or one value per mesh face in [0, 1].');
end
required = {'solarConstantWm2', 'earthIRWm2', 'albedo'};
for k = 1:numel(required)
    if ~isfield(environment, required{k})
        error('leotherm:InvalidMeshLoads', 'Missing environment.%s.', required{k});
    end
end
sun = sunDirectionBody / norm(sunDirectionBody);
earth = earthDirectionBody / norm(earthDirectionBody);
sunIncidence = max(mesh.faceNormals * sun', 0);
earthIncidence = max(mesh.faceNormals * earth', 0);
alpha = mesh.faceSolarAbsorptivity(:);
epsilon = mesh.faceIREmissivity(:);
area = mesh.faceAreasM2(:);
if isscalar(visibleFraction)
    solarVisibility = visibleFraction .* ones(size(area));
else
    solarVisibility = visibleFraction(:);
end
selfShadowing = false;
shadowDiagnostics = struct('method', 'disabled', 'candidateTests', 0, ...
    'illuminatedFaces', 0, 'blockedFaces', 0, 'blockedFraction', 0, ...
    'blockerFaceIndex', zeros(size(area)), ...
    'sunDirectionBody', sun, 'maxRayDistanceM', 0, ...
    'warning', 'Self-shadowing disabled.');
if isfield(mesh, 'solarSelfShadowing') && mesh.solarSelfShadowing
    selfShadowing = true;
end
if isfield(options, 'selfShadowing'), selfShadowing = logical(options.selfShadowing); end
if ~isscalar(selfShadowing)
    error('leotherm:InvalidMeshLoads', 'options.selfShadowing must be a logical scalar.');
end
if selfShadowing && ~isscalar(visibleFraction)
    error('leotherm:InvalidMeshLoads', ...
        'Self-shadowing requires one scalar Earth-eclipse factor per pose.');
end
if selfShadowing && isscalar(visibleFraction)
    [faceVisible, shadowDiagnostics] = leotherm.meshSolarVisibility(mesh, sun, options);
    solarVisibility = visibleFraction * faceVisible;
end
direct = environment.solarConstantWm2 .* solarVisibility .* sunIncidence .* area .* alpha;
earthViewFactor = 1;
if isfield(environment, 'earthViewFactor'), earthViewFactor = environment.earthViewFactor; end
daysideFactor = 1;
if isfield(environment, 'daysideFactor'), daysideFactor = environment.daysideFactor; end
albedo = environment.solarConstantWm2 * environment.albedo * earthViewFactor * daysideFactor ...
    .* earthIncidence .* area .* alpha;
earthIR = environment.earthIRWm2 * earthViewFactor .* earthIncidence .* area .* epsilon;
loads = struct('directSolarW', direct, 'albedoW', albedo, 'earthIRW', earthIR, ...
    'totalExternalW', direct + albedo + earthIR, 'sunIncidence', sunIncidence, ...
    'earthIncidence', earthIncidence, 'visibleFraction', visibleFraction, ...
    'faceVisibleFraction', solarVisibility, 'selfShadowing', selfShadowing, ...
    'shadowDiagnostics', shadowDiagnostics, 'mode', 'face_environment_preview');
end
