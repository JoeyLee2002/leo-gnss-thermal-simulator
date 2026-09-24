function validateSurfaceMesh(mesh)
%VALIDATESURFACEMESH Validate a triangulated spacecraft surface mesh.
if ~isstruct(mesh) || ~isscalar(mesh)
    invalid('mesh must be a scalar structure.');
end
required = {'vertices', 'faces', 'faceNormals', 'faceAreasM2'};
for k = 1:numel(required)
    if ~isfield(mesh, required{k}), invalid('mesh.%s is required.', required{k}); end
end
if ~isnumeric(mesh.vertices) || ~isreal(mesh.vertices) || size(mesh.vertices, 2) ~= 3 ...
        || isempty(mesh.vertices) || any(~isfinite(mesh.vertices), 'all')
    invalid('mesh.vertices must be a nonempty finite N-by-3 matrix.');
end
if ~isnumeric(mesh.faces) || ~isreal(mesh.faces) || size(mesh.faces, 2) ~= 3 ...
        || isempty(mesh.faces) || any(~isfinite(mesh.faces), 'all') ...
        || any(mesh.faces(:) ~= floor(mesh.faces(:))) ...
        || any(mesh.faces(:) < 1) || any(mesh.faces(:) > size(mesh.vertices, 1))
    invalid('mesh.faces must contain valid integer triangle indices.');
end
if ~isnumeric(mesh.faceNormals) || ~isequal(size(mesh.faceNormals), size(mesh.faces)) ...
        || any(~isfinite(mesh.faceNormals), 'all')
    invalid('mesh.faceNormals must be a finite number-of-faces by 3 matrix.');
end
if ~isnumeric(mesh.faceAreasM2) || ~isvector(mesh.faceAreasM2) ...
        || numel(mesh.faceAreasM2) ~= size(mesh.faces, 1) ...
        || any(~isfinite(mesh.faceAreasM2)) || any(mesh.faceAreasM2 <= 0)
    invalid('mesh.faceAreasM2 must contain one positive area per face.');
end
norms = vecnorm(mesh.faceNormals, 2, 2);
if any(abs(norms - 1) > 1e-8), invalid('Mesh face normals must be unit vectors.'); end
% Keep geometric quality and thermal integration measures consistent. A
% caller-provided area or normal must describe the supplied triangle; otherwise
% radiative loads and view factors can be silently scaled incorrectly.
p1 = mesh.vertices(mesh.faces(:, 1), :);
p2 = mesh.vertices(mesh.faces(:, 2), :);
p3 = mesh.vertices(mesh.faces(:, 3), :);
crossProduct = cross(p2 - p1, p3 - p1, 2);
geometricAreas = 0.5 * vecnorm(crossProduct, 2, 2);
if any(~isfinite(geometricAreas)) || any(geometricAreas <= 0)
    invalid('mesh.faces must contain non-degenerate triangles.');
end
relativeAreaError = abs(mesh.faceAreasM2(:) - geometricAreas) ./ geometricAreas;
if any(relativeAreaError > 1e-6)
    invalid('mesh.faceAreasM2 must match geometric triangle areas.');
end
geometricNormals = crossProduct ./ vecnorm(crossProduct, 2, 2);
if any(abs(abs(sum(mesh.faceNormals .* geometricNormals, 2)) - 1) > 1e-6)
    invalid('mesh.faceNormals must align with geometric triangle normals.');
end
if isfield(mesh, 'faceCentroids')
    if ~isnumeric(mesh.faceCentroids) || ~isequal(size(mesh.faceCentroids), size(mesh.faces)) ...
            || any(~isfinite(mesh.faceCentroids), 'all')
        invalid('mesh.faceCentroids must be a finite number-of-faces by 3 matrix.');
    end
end
if isfield(mesh, 'viewFactors')
    F = mesh.viewFactors;
    if ~isnumeric(F) || ~isequal(size(F), [size(mesh.faces, 1), size(mesh.faces, 1)]) ...
            || any(~isfinite(F), 'all') || any(F(:) < -1e-12) || any(diag(F) ~= 0)
        invalid('mesh.viewFactors must be a finite nonnegative square matrix with zero diagonal.');
    end
    if any(sum(F, 2) > 1 + 1e-8)
        invalid('mesh.viewFactors row sums cannot exceed one.');
    end
end
if isfield(mesh, 'radiationSide')
    side = char(mesh.radiationSide);
    if ~ismember(side, {'outward', 'inward'})
        invalid('mesh.radiationSide must be outward or inward.');
    end
end
if isfield(mesh, 'solarSelfShadowing')
    if ~(isscalar(mesh.solarSelfShadowing) && (islogical(mesh.solarSelfShadowing) ...
            || (isnumeric(mesh.solarSelfShadowing) && isfinite(mesh.solarSelfShadowing) ...
            && (mesh.solarSelfShadowing == 0 || mesh.solarSelfShadowing == 1))))
        invalid('mesh.solarSelfShadowing must be a logical scalar.');
    end
end
if isfield(mesh, 'faceSolarAbsorptivity')
    checkFaceParameter(mesh.faceSolarAbsorptivity, size(mesh.faces, 1), 'faceSolarAbsorptivity', 0, 1);
end
if isfield(mesh, 'faceIREmissivity')
    checkFaceParameter(mesh.faceIREmissivity, size(mesh.faces, 1), 'faceIREmissivity', 0, 1);
end
if isfield(mesh, 'faceHeatCapacityJK')
    checkPositiveFaceParameter(mesh.faceHeatCapacityJK, size(mesh.faces, 1), 'faceHeatCapacityJK');
end
if isfield(mesh, 'faceInitialTemperatureK')
    checkPositiveFaceParameter(mesh.faceInitialTemperatureK, size(mesh.faces, 1), 'faceInitialTemperatureK');
end
if isfield(mesh, 'faceConductanceWK')
    G = mesh.faceConductanceWK;
    n = size(mesh.faces, 1);
    if ~isnumeric(G) || ~isequal(size(G), [n n]) || any(~isfinite(G), 'all') ...
            || any(G(:) < 0) || any(diag(G) ~= 0) ...
            || max(abs(G - G'), [], 'all') > 1e-12
        invalid('mesh.faceConductanceWK must be symmetric, nonnegative, and have a zero diagonal.');
    end
end
if isfield(mesh, 'thermalParameterProvenance')
    value = string(mesh.thermalParameterProvenance);
    if ~isscalar(value) || strlength(value) == 0
        invalid('mesh.thermalParameterProvenance must be a nonempty text scalar.');
    end
end
end

function checkFaceParameter(value, n, label, low, high)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= n ...
        || any(~isfinite(value)) || any(value < low | value > high)
    invalid('mesh.%s must contain %d values in [%g, %g].', label, n, low, high);
end
end

function checkPositiveFaceParameter(value, n, label)
if ~isnumeric(value) || ~isvector(value) || numel(value) ~= n ...
        || any(~isfinite(value)) || any(value <= 0)
    invalid('mesh.%s must contain %d positive finite values.', label, n);
end
end

function invalid(message, varargin)
error('leotherm:InvalidSurfaceMesh', message, varargin{:});
end
