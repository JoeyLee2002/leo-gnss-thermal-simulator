function validateVolumeMesh(mesh)
%VALIDATEVOLUMEMESH Validate a linear tetrahedral volume mesh.
if ~isstruct(mesh) || ~isscalar(mesh), invalid('mesh must be a scalar structure.'); end
if ~isfield(mesh, 'nodesM') || ~isfield(mesh, 'tetrahedra')
    invalid('mesh.nodesM and mesh.tetrahedra are required.');
end
if ~isnumeric(mesh.nodesM) || size(mesh.nodesM, 2) ~= 3 || isempty(mesh.nodesM) ...
        || any(~isfinite(mesh.nodesM), 'all')
    invalid('mesh.nodesM must be a nonempty finite N-by-3 matrix.');
end
if ~isnumeric(mesh.tetrahedra) || size(mesh.tetrahedra, 2) ~= 4 ...
        || isempty(mesh.tetrahedra) || any(~isfinite(mesh.tetrahedra), 'all') ...
        || any(mesh.tetrahedra(:) ~= floor(mesh.tetrahedra(:))) ...
        || any(mesh.tetrahedra(:) < 1) || any(mesh.tetrahedra(:) > size(mesh.nodesM, 1))
    invalid('mesh.tetrahedra must contain valid integer node indices.');
end
if any(arrayfun(@(k) numel(unique(mesh.tetrahedra(k, :))) < 4, 1:size(mesh.tetrahedra, 1)))
    invalid('mesh.tetrahedra must not repeat a node within an element.');
end
for k = 1:size(mesh.tetrahedra, 1)
    p = mesh.nodesM(mesh.tetrahedra(k, :), :);
    volume = abs(det([p(2,:) - p(1,:); p(3,:) - p(1,:); p(4,:) - p(1,:) ])) / 6;
    if ~isfinite(volume) || volume <= 0, invalid('mesh.tetrahedra contains a zero-volume element.'); end
end
if isfield(mesh, 'boundaryTriangles')
    if ~isnumeric(mesh.boundaryTriangles) || size(mesh.boundaryTriangles, 2) ~= 3 ...
            || any(~isfinite(mesh.boundaryTriangles), 'all') ...
            || any(mesh.boundaryTriangles(:) ~= floor(mesh.boundaryTriangles(:))) ...
            || any(mesh.boundaryTriangles(:) < 1) || any(mesh.boundaryTriangles(:) > size(mesh.nodesM, 1))
        invalid('mesh.boundaryTriangles must contain valid integer node indices.');
    end
    if any(arrayfun(@(k) numel(unique(mesh.boundaryTriangles(k, :))) < 3, ...
            1:size(mesh.boundaryTriangles, 1)))
        invalid('mesh.boundaryTriangles must not repeat a node within a triangle.');
    end
    canonical = sort(mesh.boundaryTriangles, 2);
    if size(unique(canonical, 'rows'), 1) ~= size(canonical, 1)
        invalid('mesh.boundaryTriangles must not contain duplicate facets.');
    end
end
if isfield(mesh, 'boundaryPhysicalTags')
    if ~isfield(mesh, 'boundaryTriangles')
        invalid('mesh.boundaryPhysicalTags requires boundaryTriangles.');
    end
    if ~isnumeric(mesh.boundaryPhysicalTags) || ~isvector(mesh.boundaryPhysicalTags) ...
            || numel(mesh.boundaryPhysicalTags) ~= size(mesh.boundaryTriangles, 1) ...
            || any(~isfinite(mesh.boundaryPhysicalTags)) ...
            || any(mesh.boundaryPhysicalTags(:) ~= floor(mesh.boundaryPhysicalTags(:)))
        invalid('mesh.boundaryPhysicalTags must contain one finite integer tag per boundary triangle.');
    end
end
if isfield(mesh, 'tetraPhysicalTags') && ...
        (~isnumeric(mesh.tetraPhysicalTags) || ~isvector(mesh.tetraPhysicalTags) ...
        || numel(mesh.tetraPhysicalTags) ~= size(mesh.tetrahedra, 1) ...
        || any(~isfinite(mesh.tetraPhysicalTags)) ...
        || any(mesh.tetraPhysicalTags(:) ~= floor(mesh.tetraPhysicalTags(:))))
    invalid('mesh.tetraPhysicalTags must contain one finite integer tag per tetrahedron.');
end
end

function invalid(message, varargin)
error('leotherm:InvalidVolumeMesh', message, varargin{:});
end
