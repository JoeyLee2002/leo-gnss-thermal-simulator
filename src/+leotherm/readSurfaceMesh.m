function mesh = readSurfaceMesh(filePath)
%READSURFACEMESH Read a triangulated STL or OBJ surface mesh.
% Mesh coordinates are metres in the spacecraft body frame unless the user
% explicitly applies another unit conversion before importing.
if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
    error('leotherm:InvalidMeshFile', 'Mesh file path must be text.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('leotherm:MeshFileNotFound', 'Mesh file does not exist: %s', filePath);
end
[~, name, ext] = fileparts(filePath);
ext = lower(ext);
switch ext
    case '.stl'
        [vertices, faces, format] = readStl(filePath);
    case '.obj'
        [vertices, faces, format] = readObj(filePath);
    otherwise
        error('leotherm:UnsupportedMeshFormat', ...
            'Supported surface mesh formats are STL and OBJ.');
end
mesh = finalizeMesh(vertices, faces, filePath, [name ext], format);
end

function [vertices, faces, format] = readStl(filePath)
bytes = readBytes(filePath);
isBinary = false;
if numel(bytes) >= 84
    count = double(typecast(uint8(bytes(81:84)), 'uint32'));
    isBinary = (84 + 50 * count == numel(bytes)) && count > 0;
end
if isBinary
    [vertices, faces] = readBinaryStl(bytes);
    format = 'stl_binary';
else
    [vertices, faces] = readAsciiStl(filePath);
    format = 'stl_ascii';
end
end

function [vertices, faces] = readBinaryStl(bytes)
count = double(typecast(uint8(bytes(81:84)), 'uint32'));
vertices = zeros(3 * count, 3);
faces = reshape(1:(3 * count), 3, count)';
offset = 85;
for k = 1:count
    record = bytes(offset:(offset + 49));
    values = typecast(uint8(record(13:48)), 'single');
    vertices(3*k-2:3*k, :) = reshape(double(values), 3, 3)';
    offset = offset + 50;
end
end

function [vertices, faces] = readAsciiStl(filePath)
text = fileread(filePath);
tokens = regexp(text, ['(?im)^\s*vertex\s+' ...
    '([-+0-9.eE]+)\s+([-+0-9.eE]+)\s+([-+0-9.eE]+)'], 'tokens');
if isempty(tokens) || mod(numel(tokens), 3) ~= 0
    error('leotherm:InvalidMeshFile', 'ASCII STL contains no complete triangular facets.');
end
vertices = zeros(3 * numel(tokens), 3);
for k = 1:numel(tokens)
    vertices(k, :) = str2double(tokens{k});
end
faces = reshape(1:size(vertices, 1), 3, [])';
end

function [vertices, faces, format] = readObj(filePath)
lines = regexp(fileread(filePath), '\r\n|\n|\r', 'split');
vertices = zeros(0, 3);
faces = zeros(0, 3);
for k = 1:numel(lines)
    line = strtrim(lines{k});
    if isempty(line) || startsWith(line, '#'), continue; end
    if startsWith(line, 'v ')
        values = sscanf(line(2:end), '%f');
        if numel(values) < 3
            error('leotherm:InvalidMeshFile', 'OBJ vertex record is incomplete.');
        end
        vertices(end + 1, :) = values(1:3)'; %#ok<AGROW>
    elseif startsWith(line, 'f ')
        parts = strsplit(strtrim(line(2:end)));
        indices = zeros(1, numel(parts));
        for p = 1:numel(parts)
            slash = strfind(parts{p}, '/');
            token = parts{p};
            if ~isempty(slash), token = token(1:slash(1)-1); end
            index = str2double(token);
            if ~isfinite(index) || index == 0 || index ~= fix(index)
                error('leotherm:InvalidMeshFile', 'OBJ face contains a non-integer vertex index.');
            end
            if index < 0, index = size(vertices, 1) + index + 1; end
            indices(p) = index;
        end
        if numel(indices) < 3 || any(indices < 1) || any(indices > size(vertices, 1))
            error('leotherm:InvalidMeshFile', 'OBJ face references an invalid vertex.');
        end
        for p = 2:(numel(indices) - 1)
            faces(end + 1, :) = [indices(1), indices(p), indices(p + 1)]; %#ok<AGROW>
        end
    end
end
format = 'obj';
if isempty(vertices) || isempty(faces)
    error('leotherm:InvalidMeshFile', 'OBJ contains no complete triangular faces.');
end
end

function mesh = finalizeMesh(vertices, faces, filePath, label, format)
[vertices, faces] = normalizeMeshArrays(vertices, faces);
[vertices, ~, map] = unique(vertices, 'rows');
faces = reshape(map(faces), [], 3);
p1 = vertices(faces(:, 1), :);
p2 = vertices(faces(:, 2), :);
p3 = vertices(faces(:, 3), :);
rawNormals = cross(p2 - p1, p3 - p1, 2);
areas = 0.5 * vecnorm(rawNormals, 2, 2);
keep = isfinite(areas) & areas > 1e-14;
faces = faces(keep, :);
rawNormals = rawNormals(keep, :);
areas = areas(keep);
if isempty(faces)
    error('leotherm:InvalidMeshFile', 'Mesh contains no non-degenerate triangles.');
end
normals = rawNormals ./ vecnorm(rawNormals, 2, 2);
boundary = boundaryEdgeCount(faces);
mesh = struct('name', label, 'sourcePath', filePath, 'format', format, ...
    'vertices', vertices, 'faces', faces, 'faceNormals', normals, ...
    'faceCentroids', (p1(keep, :) + p2(keep, :) + p3(keep, :)) / 3, ...
    'faceAreasM2', areas, 'totalAreaM2', sum(areas), ...
    'boundingBoxM', [min(vertices, [], 1); max(vertices, [], 1)], ...
    'boundaryEdgeCount', boundary, 'isWatertight', boundary == 0, ...
    'radiationSide', 'outward', ...
    'solarSelfShadowing', false, ...
    'faceHeatCapacityJK', areas * 5000, ...
    'faceInitialTemperatureK', 293.15 * ones(size(areas)), ...
    'faceConductanceWK', zeros(numel(areas), numel(areas)), ...
    'thermalParameterProvenance', 'reference_defaults_not_calibrated', ...
    'faceSolarAbsorptivity', 0.60 * ones(size(areas)), ...
    'faceIREmissivity', 0.80 * ones(size(areas)));
leotherm.validateSurfaceMesh(mesh);
end

function [vertices, faces] = normalizeMeshArrays(vertices, faces)
vertices = reshape(vertices, [], 3);
faces = reshape(faces, [], 3);
end

function count = boundaryEdgeCount(faces)
edges = [faces(:, [1 2]); faces(:, [2 3]); faces(:, [3 1])];
edges = sort(edges, 2);
[~, ~, group] = unique(edges, 'rows');
counts = accumarray(group, 1);
count = sum(counts == 1);
end

function bytes = readBytes(filePath)
fid = fopen(filePath, 'r', 'ieee-le');
if fid < 0, error('leotherm:InvalidMeshFile', 'Cannot open mesh file.'); end
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8')';
clear cleanup
end
