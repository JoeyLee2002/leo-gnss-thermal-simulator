function [viewFactors, diagnostics] = computeMeshViewFactors(mesh, options)
%COMPUTEMESHVIEWFACTORS Estimate diffuse face-to-face view factors.
% Uses a centroid differential-area approximation and optional ray blocking.
leotherm.validateSurfaceMesh(mesh);
if nargin < 2 || isempty(options), options = struct; end
visibility = optionText(options, 'visibility', 'ray');
surfaceSide = optionSide(options, mesh, 'outward');
maxRayFaces = optionNumber(options, 'maxRayFaces', 2500);
nFace = size(mesh.faces, 1);
if nFace > maxRayFaces && strcmp(visibility, 'ray')
    error('leotherm:MeshTooLargeForRayViewFactors', ...
        'Ray preprocessing is limited to %d faces.', maxRayFaces);
end
if isfield(mesh, 'faceCentroids')
    centroids = mesh.faceCentroids;
else
    centroids = zeros(nFace, 3);
    for k = 1:nFace
        centroids(k, :) = mean(mesh.vertices(mesh.faces(k, :), :), 1);
    end
end
areas = mesh.faceAreasM2(:);
normals = mesh.faceNormals;
viewFactors = zeros(nFace);
candidateCount = 0;
blockedCount = 0;
for i = 1:(nFace - 1)
    for j = (i + 1):nFace
        separation = centroids(j, :) - centroids(i, :);
        distance2 = dot(separation, separation);
        if distance2 <= 1e-24, continue; end
        distance = sqrt(distance2);
        direction = separation / distance;
        normalSign = 1;
        if strcmp(surfaceSide, 'inward'), normalSign = -1; end
        cosineI = normalSign * dot(normals(i, :), direction);
        cosineJ = normalSign * dot(normals(j, :), -direction);
        if cosineI <= 0 || cosineJ <= 0, continue; end
        candidateCount = candidateCount + 1;
        if strcmp(visibility, 'ray') && rayBlocked(centroids(i, :), direction, distance, mesh, i, j)
            blockedCount = blockedCount + 1;
            continue;
        end
        differential = cosineI * cosineJ * areas(j) / (pi * distance2);
        viewFactors(i, j) = differential;
        viewFactors(j, i) = areas(i) / areas(j) * differential;
    end
end
scale = ones(nFace, 1);
for iteration = 1:30
    scaled = viewFactors .* (scale * scale');
    rowSum = sum(scaled, 2);
    over = rowSum > 1;
    if ~any(over), break; end
    scale(over) = scale(over) ./ sqrt(rowSum(over));
end
viewFactors = viewFactors .* (scale * scale');
viewFactors(1:nFace+1:end) = 0;
rowSum = sum(viewFactors, 2);
if any(rowSum > 1)
    globalScale = 1 / sqrt(max(rowSum));
    viewFactors = viewFactors * globalScale^2;
end
areaF = areas .* ones(1, nFace);
reciprocity = max(abs(areaF .* viewFactors - areaF' .* viewFactors'), [], 'all');
diagnostics = struct('method', 'differential_area_centroid', ...
    'visibility', visibility, 'candidatePairs', candidateCount, ...
    'blockedPairs', blockedCount, 'rowSums', sum(viewFactors, 2), ...
    'spaceViewFactors', 1 - sum(viewFactors, 2), ...
    'reciprocityError', reciprocity, 'scalingIterations', iteration, ...
    'surfaceSide', surfaceSide, ...
    'warning', 'Centroid approximation; use a dedicated high-fidelity backend for certification.');
end

function blocked = rayBlocked(origin, direction, distance, mesh, faceI, faceJ)
blocked = false;
epsilon = max(1e-10, 1e-8 * distance);
vertices = mesh.vertices;
faces = mesh.faces;
for k = 1:size(faces, 1)
    if k == faceI || k == faceJ, continue; end
    a = vertices(faces(k, 1), :);
    b = vertices(faces(k, 2), :);
    c = vertices(faces(k, 3), :);
    edge1 = b - a;
    edge2 = c - a;
    pvec = cross(direction, edge2);
    determinant = dot(edge1, pvec);
    if abs(determinant) < 1e-14, continue; end
    invDet = 1 / determinant;
    tvec = origin + epsilon * direction - a;
    u = dot(tvec, pvec) * invDet;
    if u < -1e-10 || u > 1 + 1e-10, continue; end
    qvec = cross(tvec, edge1);
    v = dot(direction, qvec) * invDet;
    if v < -1e-10 || u + v > 1 + 1e-10, continue; end
    hit = dot(edge2, qvec) * invDet;
    if hit > epsilon && hit < distance - epsilon
        blocked = true;
        return
    end
end
end

function value = optionText(options, name, fallback)
value = fallback;
if isfield(options, name), value = char(options.(name)); end
if ~ismember(value, {'ray', 'centroid'})
    error('leotherm:InvalidMeshViewFactorOption', 'visibility must be ray or centroid.');
end
end

function value = optionSide(options, mesh, fallback)
value = fallback;
if isfield(mesh, 'radiationSide'), value = char(mesh.radiationSide); end
if isfield(options, 'surfaceSide'), value = char(options.surfaceSide); end
if ~ismember(value, {'outward', 'inward'})
    error('leotherm:InvalidMeshViewFactorOption', 'surfaceSide must be outward or inward.');
end
end

function value = optionNumber(options, name, fallback)
value = fallback;
if isfield(options, name), value = options.(name); end
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= floor(value)
    error('leotherm:InvalidMeshViewFactorOption', '%s must be a positive integer.', name);
end
end
