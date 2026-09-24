function [nodalPowerW, diagnostics] = coupleSurfaceToVolumeThermal(surfaceMesh, volumeMesh, surfaceHeat, options)
%COUPLESURFACETOVOLUMETHERMAL Conservatively map surface heat to volume nodes.
%   [P, D] = coupleSurfaceToVolumeThermal(S, V, Q) maps per-face heat
%   powers Q (W) from an STL/OBJ surface mesh S to Gmsh tetrahedral mesh V.
%   Q may be an nFace vector, an epoch-by-face matrix, a structure returned
%   by surfaceMeshLoads (field totalExternalW), or a heat-flux structure
%   with field heatFluxWm2.  Matching is exact within coordinateToleranceM;
%   no interpolation or nearest-neighbour projection is performed.
%   Boundary triangles are matched first.  For a matched triangle its power
%   is split equally among the three volume nodes (consistent with a linear
%   boundary shape-function integral for constant flux).

if nargin < 4 || isempty(options), options = struct; end
if ~isstruct(options) || ~isscalar(options)
    error('leotherm:InvalidMeshCoupling', 'options must be a scalar structure.');
end
leotherm.validateSurfaceMesh(surfaceMesh);
leotherm.validateVolumeMesh(volumeMesh);
nFace = size(surfaceMesh.faces, 1); nNode = size(volumeMesh.nodesM, 1);
tol = 1e-9;
if isfield(options, 'coordinateToleranceM'), tol = options.coordinateToleranceM; end
if ~isnumeric(tol) || ~isscalar(tol) || ~isfinite(tol) || tol <= 0
    error('leotherm:InvalidMeshCoupling', 'coordinateToleranceM must be positive and finite.');
end

[facePower, inputKind] = resolveSurfaceHeat(surfaceHeat, surfaceMesh, nFace);
nEpoch = size(facePower, 1);
nodalPowerW = zeros(nEpoch, nNode);

% Coordinate matching is deliberately one-to-one: ambiguous or missing
% points indicate incompatible meshes and must not be silently repaired.
surfaceNodeMap = zeros(size(surfaceMesh.vertices, 1), 1);
for i = 1:numel(surfaceNodeMap)
    d = vecnorm(volumeMesh.nodesM - surfaceMesh.vertices(i, :), 2, 2);
    candidates = find(d <= tol);
    if numel(candidates) ~= 1
        if isempty(candidates)
            error('leotherm:MeshCouplingMismatch', ...
                'Surface vertex %d has no volume node within %.3g m.', i, tol);
        else
            error('leotherm:MeshCouplingMismatch', ...
                'Surface vertex %d matches multiple volume nodes within %.3g m.', i, tol);
        end
    end
    surfaceNodeMap(i) = candidates;
end

% Build canonical boundary-facet lookup. Supplied Gmsh boundary triangles
% take precedence; otherwise derive exterior facets from tetrahedra.
[boundaryTriangles, boundarySource] = volumeBoundaryTriangles(volumeMesh);
boundaryKeys = sort(boundaryTriangles, 2);
faceVolumeNodes = surfaceNodeMap(surfaceMesh.faces);
faceKeys = sort(faceVolumeNodes, 2);
[isBoundary, boundaryIndex] = ismember(faceKeys, boundaryKeys, 'rows');
if any(~isBoundary)
    bad = find(~isBoundary, 1);
    error('leotherm:MeshCouplingMismatch', ...
        'Surface face %d is not a volume boundary triangle; nonconforming interpolation is unsupported.', bad);
end

% Each boundary face receives exactly its input power; equal nodal weights
% make sum(P_node) == sum(Q_face) to roundoff for every epoch.
for f = 1:nFace
    nodes = boundaryTriangles(boundaryIndex(f), :);
    nodalPowerW(:, nodes) = nodalPowerW(:, nodes) + facePower(:, f) / 3;
end
inputTotal = sum(facePower, 2);
outputTotal = sum(nodalPowerW, 2);
closure = outputTotal - inputTotal;
diagnostics = struct('method', 'exact_boundary_triangle_equal_shape_weights', ...
    'inputKind', inputKind, 'surfaceFaceCount', nFace, 'volumeNodeCount', nNode, ...
    'matchedBoundaryFaceCount', nFace, 'coordinateToleranceM', tol, ...
    'boundarySource', boundarySource, 'surfaceVertexToVolumeNode', surfaceNodeMap, ...
    'surfaceFaceToBoundaryTriangle', boundaryIndex, 'facePowerW', facePower, ...
    'inputTotalPowerW', inputTotal, 'outputTotalPowerW', outputTotal, ...
    'energyClosureW', closure, 'maximumAbsoluteClosureW', max(abs(closure)));
end

function [power, kind] = resolveSurfaceHeat(value, mesh, nFace)
kind = 'face_power_w';
if isstruct(value)
    if isfield(value, 'totalExternalW'), value = value.totalExternalW; kind = 'surfaceLoads.totalExternalW';
    elseif isfield(value, 'heatFluxWm2'), value = value.heatFluxWm2; kind = 'heat_flux_w_m2_times_face_area';
    elseif isfield(value, 'faceHeatFluxWm2'), value = value.faceHeatFluxWm2; kind = 'faceHeatFluxWm2';
    else, error('leotherm:InvalidMeshCoupling', 'surfaceHeat structure needs totalExternalW or heatFluxWm2.');
    end
    if strcmp(kind, 'heat_flux_w_m2_times_face_area') || strcmp(kind, 'faceHeatFluxWm2')
        if isvector(value), value = reshape(value, 1, []); end
        value = value .* reshape(mesh.faceAreasM2, 1, []);
    end
end
if ~isnumeric(value) || any(~isfinite(value), 'all')
    error('leotherm:InvalidMeshCoupling', 'Surface heat values must be finite numeric data.');
end
if isvector(value) && numel(value) == nFace
    power = reshape(value, 1, []);
elseif size(value, 2) == nFace
    power = value;
else
    error('leotherm:InvalidMeshCoupling', 'Surface heat must be one value per face or epoch-by-face.');
end
end

function [triangles, source] = volumeBoundaryTriangles(mesh)
if isfield(mesh, 'boundaryTriangles') && ~isempty(mesh.boundaryTriangles)
    triangles = mesh.boundaryTriangles; source = 'volumeMesh.boundaryTriangles'; return;
end
t = mesh.tetrahedra;
allFaces = [t(:, [1 2 3]); t(:, [1 2 4]); t(:, [1 3 4]); t(:, [2 3 4])];
keys = sort(allFaces, 2);
[~, ~, groups] = unique(keys, 'rows'); counts = accumarray(groups, 1);
triangles = allFaces(counts(groups) == 1, :); source = 'derived_exterior_tetra_facets';
end
