function model = assembleVolumeThermalModel(mesh, material)
%ASSEMBLEVOLUMETHERMALMODEL Assemble linear-tetrahedron conduction matrices.
% The formulation is the standard Galerkin heat equation used by MOOSE's
% heat-conduction module, implemented independently for this MATLAB package.
leotherm.validateVolumeMesh(mesh);
if nargin < 2 || isempty(material), material = struct; end
nTet = size(mesh.tetrahedra, 1); nNode = size(mesh.nodesM, 1);
[kappa, rho, cp, regionTags] = resolveMaterialRegions(mesh, material, nTet);
rows = zeros(16 * nTet, 1); cols = rows; values = rows;
capacityJK = zeros(nNode, 1); volumes = zeros(nTet, 1); cursor = 0;
for e = 1:nTet
    index = mesh.tetrahedra(e, :); p = mesh.nodesM(index, :);
    jacobian = [p(2,:) - p(1,:); p(3,:) - p(1,:); p(4,:) - p(1,:)];
    volume = abs(det(jacobian)) / 6;
    coefficient = inv([ones(4, 1), p]);
    gradients = coefficient(2:4, :);
    elementK = volume * kappa(e) * (gradients' * gradients);
    [rr, cc] = ndgrid(index, index); range = cursor + (1:16);
    rows(range) = rr(:); cols(range) = cc(:); values(range) = elementK(:);
    cursor = cursor + 16;
    capacityJK(index) = capacityJK(index) + volume * rho(e) * cp(e) / 4;
    volumes(e) = volume;
end
model = struct('nodeCount', nNode, 'tetrahedronCount', nTet, ...
    'stiffnessWK', sparse(rows, cols, values, nNode, nNode), ...
    'capacityJK', capacityJK, 'elementVolumesM3', volumes, 'material', material, ...
    'elementConductivityWmK', kappa, 'elementDensityKgM3', rho, ...
    'elementSpecificHeatJkgK', cp, 'elementPhysicalTags', regionTags, ...
    'meshSourcePath', meshField(mesh, 'sourcePath', ''), ...
    'formulation', 'linear_tetrahedron_galerkin_lumped_capacity');
end

function [kappa, rho, cp, tags] = resolveMaterialRegions(mesh, material, nTet)
tags = zeros(nTet, 1);
if isfield(mesh, 'tetraPhysicalTags')
    tags = mesh.tetraPhysicalTags(:);
end
if ~isfield(material, 'regionProperties') || isempty(material.regionProperties)
    kappa = materialVector(material, 'conductivityWmK', 1, nTet, 'conductivityWmK');
    rho = materialVector(material, 'densityKgM3', 1000, nTet, 'densityKgM3');
    cp = materialVector(material, 'specificHeatJkgK', 1000, nTet, 'specificHeatJkgK');
    return;
end
regions = material.regionProperties;
if ~isstruct(regions) || isempty(regions) || ~isvector(regions)
    error('leotherm:InvalidVolumeMaterial', 'regionProperties must be a nonempty structure array.');
end
required = {'physicalTag','conductivityWmK','densityKgM3','specificHeatJkgK'};
for i = 1:numel(required)
    if ~all(isfield(regions, required{i}))
        error('leotherm:InvalidVolumeMaterial', ...
            'Each regionProperties entry requires %s.', required{i});
    end
end
regionTags = [regions.physicalTag]';
if any(~isnumeric(regionTags) | ~isfinite(regionTags) | regionTags ~= floor(regionTags)) ...
        || numel(unique(regionTags)) ~= numel(regionTags)
    error('leotherm:InvalidVolumeMaterial', ...
        'regionProperties physicalTag values must be unique finite integers.');
end
if any(tags == 0)
    error('leotherm:MissingVolumePhysicalTag', ...
        'Every tetrahedron needs a nonzero Physical Tag when regionProperties is used.');
end
kappa = zeros(nTet, 1); rho = kappa; cp = kappa;
for i = 1:numel(regions)
    mask = tags == regionTags(i);
    if ~any(mask), continue; end
    kappa(mask) = positiveRegionValue(regions(i).conductivityWmK, 'conductivityWmK');
    rho(mask) = positiveRegionValue(regions(i).densityKgM3, 'densityKgM3');
    cp(mask) = positiveRegionValue(regions(i).specificHeatJkgK, 'specificHeatJkgK');
end
if any(kappa == 0)
    missing = unique(tags(kappa == 0));
    error('leotherm:UnmatchedVolumePhysicalTag', ...
        'No regionProperties entry matches tetrahedron Physical Tag(s): %s.', mat2str(missing'));
end
end

function value = positiveRegionValue(value, name)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('leotherm:InvalidVolumeMaterial', '%s must be one positive finite scalar per region.', name);
end
end

function value = materialVector(material, name, fallback, n, label)
value = fallback;
if isfield(material, name), value = material.(name); end
if ~isnumeric(value) || ~isvector(value) || (numel(value) ~= 1 && numel(value) ~= n) ...
        || any(~isfinite(value)) || any(value <= 0)
    error('leotherm:InvalidVolumeMaterial', ...
        '%s must be one positive scalar or one value per tetrahedron.', label);
end
if isscalar(value), value = repmat(value, n, 1); else, value = value(:); end
end

function value = meshField(mesh, name, fallback)
value = fallback;
if isfield(mesh, name), value = mesh.(name); end
end
