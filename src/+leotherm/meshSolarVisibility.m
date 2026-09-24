function [visible, diagnostics] = meshSolarVisibility(mesh, sunDirectionBody, options)
%MESHSOLARVISIBILITY Determine direct-solar visibility for each mesh face.
% The ray starts at each face centroid and travels from the spacecraft toward
% the Sun. A hit by any other triangle means that the face is self-shadowed.
% This is a binary geometric test; the conical Earth eclipse factor remains a
% separate scalar applied by the caller.
leotherm.validateSurfaceMesh(mesh);
if nargin < 3 || isempty(options), options = struct; end
if ~isnumeric(sunDirectionBody) || ~isequal(size(sunDirectionBody), [1 3]) ...
        || any(~isfinite(sunDirectionBody)) || norm(sunDirectionBody) <= 0
    error('leotherm:InvalidMeshSolarVisibility', ...
        'sunDirectionBody must be one nonzero 1-by-3 vector.');
end
maxRayFaces = optionNumber(options, 'maxRayFaces', 2500);
nFace = size(mesh.faces, 1);
if nFace > maxRayFaces
    error('leotherm:MeshTooLargeForSolarShadow', ...
        'Solar self-shadowing is limited to %d faces.', maxRayFaces);
end

direction = sunDirectionBody / norm(sunDirectionBody);
centroids = mesh.faceCentroids;
vertices = mesh.vertices;
faces = mesh.faces;
visible = true(nFace, 1);
blocker = zeros(nFace, 1);
candidateCount = 0;
blockedCount = 0;
surfaceSide = 'outward';
if isfield(mesh, 'radiationSide'), surfaceSide = char(mesh.radiationSide); end
if isfield(options, 'surfaceSide'), surfaceSide = char(options.surfaceSide); end
normalSign = 1;
if strcmp(surfaceSide, 'inward'), normalSign = -1; end
illuminated = normalSign * (mesh.faceNormals * direction') > 1e-12;

for i = 1:nFace
    if ~illuminated(i), continue; end
    origin = centroids(i, :);
    epsilon = max(1e-10, 1e-8 * max(1, norm(origin)));
    rayOrigin = origin + epsilon * direction;
    for k = 1:nFace
        if k == i, continue; end
        candidateCount = candidateCount + 1;
        a = vertices(faces(k, 1), :);
        b = vertices(faces(k, 2), :);
        c = vertices(faces(k, 3), :);
        hitDistance = rayTriangleDistance(rayOrigin, direction, a, b, c, epsilon);
        if hitDistance > 0
            visible(i) = false;
            blocker(i) = k;
            blockedCount = blockedCount + 1;
            break
        end
    end
end

diagnostics = struct('method', 'centroid_to_sun_ray', ...
    'candidateTests', candidateCount, 'illuminatedFaces', sum(illuminated), ...
    'blockedFaces', blockedCount, ...
    'blockedFraction', mean(~visible), 'blockerFaceIndex', blocker, ...
    'sunDirectionBody', direction, 'surfaceSide', surfaceSide, ...
    'maxRayDistanceM', Inf, ...
    'warning', 'Binary centroid ray test; grazing and partial triangle coverage are not resolved.');
end

function distance = rayTriangleDistance(origin, direction, a, b, c, epsilon)
% Moller-Trumbore intersection with a strict positive forward-ray distance.
edge1 = b - a;
edge2 = c - a;
pvec = cross(direction, edge2);
determinant = dot(edge1, pvec);
if abs(determinant) < 1e-14
    distance = -1;
    return
end
invDet = 1 / determinant;
tvec = origin - a;
u = dot(tvec, pvec) * invDet;
if u < -1e-10 || u > 1 + 1e-10
    distance = -1;
    return
end
qvec = cross(tvec, edge1);
v = dot(direction, qvec) * invDet;
if v < -1e-10 || u + v > 1 + 1e-10
    distance = -1;
    return
end
distance = dot(edge2, qvec) * invDet;
if distance <= epsilon
    distance = -1;
end
end

function value = optionNumber(options, name, fallback)
value = fallback;
if isfield(options, name), value = options.(name); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) ...
        || value < 1 || value ~= floor(value)
    error('leotherm:InvalidMeshSolarVisibility', ...
        '%s must be a positive integer.', name);
end
end
