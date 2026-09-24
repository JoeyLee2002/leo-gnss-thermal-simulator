function mesh = readVolumeMesh(filePath)
%READVOLUMEMESH Read an ASCII Gmsh 2.2 tetrahedral volume mesh.
if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)) )
    error('leotherm:InvalidVolumeMeshFile', 'Volume mesh path must be text.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('leotherm:VolumeMeshFileNotFound', 'Volume mesh file does not exist: %s', filePath);
end
lines = regexp(fileread(filePath), '\r\n|\n|\r', 'split');
version = '';
nodeIds = zeros(0, 1); nodes = zeros(0, 3);
tetraIds = zeros(0, 4); tetraPhysical = zeros(0, 1);
triIds = zeros(0, 3); triPhysical = zeros(0, 1);
k = 1;
while k <= numel(lines)
    token = strtrim(lines{k});
    if strcmp(token, '$MeshFormat')
        if k + 1 > numel(lines)
            invalidFile('Gmsh $MeshFormat section is incomplete.');
        end
        version = strtrim(lines{k + 1}); k = k + 1;
        formatValues = sscanf(version, '%f');
        if numel(formatValues) < 2
            invalidFile('Gmsh $MeshFormat record is incomplete.');
        end
        if formatValues(2) ~= 0
            error('leotherm:UnsupportedVolumeMeshFormat', ...
                'Binary Gmsh files are not supported; export an ASCII MSH 2.x file.');
        end
        if formatValues(1) < 2 || formatValues(1) >= 3
            error('leotherm:UnsupportedVolumeMeshFormat', 'Only ASCII Gmsh version 2.x is supported.');
        end
    elseif strcmp(token, '$Nodes')
        count = lineCount(lines, k, 'Nodes');
        nodeIds = zeros(count, 1); nodes = zeros(count, 3);
        for i = 1:count
            values = sscanf(strtrim(lines{k + 1 + i}), '%f');
            if numel(values) < 4, invalidFile('Gmsh node record is incomplete.'); end
            if ~isfinite(values(1)) || values(1) ~= floor(values(1)) || values(1) < 1
                invalidFile('Gmsh node IDs must be positive integers.');
            end
            if any(~isfinite(values(2:4)))
                invalidFile('Gmsh node coordinates must be finite.');
            end
            nodeIds(i) = values(1); nodes(i, :) = values(2:4)';
        end
        if numel(unique(nodeIds)) ~= numel(nodeIds)
            invalidFile('Gmsh node IDs must be unique.');
        end
        k = k + count + 1;
    elseif strcmp(token, '$Elements')
        count = lineCount(lines, k, 'Elements');
        for i = 1:count
            values = sscanf(strtrim(lines{k + 1 + i}), '%f')';
            if numel(values) < 3, invalidFile('Gmsh element record is incomplete.'); end
            elementType = values(2); tagCount = values(3); firstNode = 4 + tagCount;
            if ~isfinite(elementType) || elementType ~= floor(elementType) || elementType < 1 ...
                    || ~isfinite(tagCount) || tagCount ~= floor(tagCount) || tagCount < 0
                invalidFile('Gmsh element type and tag count must be valid integers.');
            end
            if elementType == 4
                if numel(values) < firstNode + 3, invalidFile('Gmsh tetrahedron record is incomplete.'); end
                tetraIds(end + 1, :) = values(firstNode:firstNode + 3); %#ok<AGROW>
                if tagCount >= 1
                    tetraPhysical(end + 1, 1) = values(4); %#ok<AGROW>
                else
                    tetraPhysical(end + 1, 1) = 0; %#ok<AGROW>
                end
            elseif elementType == 2
                if numel(values) < firstNode + 2, invalidFile('Gmsh boundary triangle record is incomplete.'); end
                triIds(end + 1, :) = values(firstNode:firstNode + 2); %#ok<AGROW>
                if tagCount >= 1, triPhysical(end + 1, 1) = values(4); %#ok<AGROW>
                else, triPhysical(end + 1, 1) = 0; %#ok<AGROW>
                end
            end
        end
        k = k + count + 1;
    end
    k = k + 1;
end
if isempty(version), invalidFile('Gmsh $MeshFormat section is missing.'); end
formatValues = sscanf(version, '%f');
if isempty(formatValues)
    error('leotherm:UnsupportedVolumeMeshFormat', 'The Gmsh mesh-format line is invalid.');
end
versionNumber = formatValues(1);
if versionNumber < 2 || versionNumber >= 3
    error('leotherm:UnsupportedVolumeMeshFormat', 'Only ASCII Gmsh version 2.x is supported.');
end
if isempty(nodes) || isempty(tetraIds), invalidFile('The Gmsh file contains no linear tetrahedra.'); end
[ok, nodeIndex] = ismember(tetraIds, nodeIds);
if any(~ok, 'all'), invalidFile('A tetrahedron references an unknown node.'); end
tetrahedra = nodeIndex;
[ok, boundaryIndex] = ismember(triIds, nodeIds);
if any(~ok, 'all'), invalidFile('A boundary triangle references an unknown node.'); end
boundaryTriangles = boundaryIndex;
for i = 1:size(tetrahedra, 1)
    p = nodes(tetrahedra(i, :), :);
    signedSixVolume = det([p(2,:) - p(1,:); p(3,:) - p(1,:); p(4,:) - p(1,:) ]);
    if abs(signedSixVolume) <= 1e-18, invalidFile('The Gmsh file contains a zero-volume tetrahedron.'); end
    if signedSixVolume < 0, tetrahedra(i, [1 2]) = tetrahedra(i, [2 1]); end
end
mesh = struct('name', '', 'sourcePath', filePath, 'format', 'gmsh_ascii_2', ...
    'nodesM', nodes, 'tetrahedra', tetrahedra, 'boundaryTriangles', boundaryTriangles, ...
    'boundaryPhysicalTags', triPhysical, 'tetraPhysicalTags', tetraPhysical, ...
    'nodeCount', size(nodes, 1), ...
    'tetrahedronCount', size(tetrahedra, 1), ...
    'thermalParameterProvenance', 'material_parameters_required');
leotherm.validateVolumeMesh(mesh);
end

function count = lineCount(lines, sectionLine, section)
count = sscanf(strtrim(lines{sectionLine + 1}), '%d', 1);
if isempty(count) || count < 1 || sectionLine + count + 2 > numel(lines) ...
        || ~strcmp(strtrim(lines{sectionLine + count + 2}), ['$End' section])
    invalidFile(['Malformed Gmsh ' section ' section.']);
end
end

function invalidFile(message)
error('leotherm:InvalidVolumeMeshFile', '%s', message);
end
