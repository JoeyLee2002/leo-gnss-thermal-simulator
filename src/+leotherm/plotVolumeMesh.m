function graphics = plotVolumeMesh(mesh, nodalTemperatureK, axesHandle, language)
%PLOTVOLUMEMESH Render tetrahedral boundary and optional nodal temperature.
if nargin < 2, nodalTemperatureK = []; end
if nargin < 3 || isempty(axesHandle)
    figureHandle = figure; axesHandle = axes(figureHandle);
else
    figureHandle = ancestor(axesHandle, 'figure');
end
if nargin < 4 || isempty(language), language = 'zh'; end
leotherm.validateVolumeMesh(mesh);
if ~isempty(nodalTemperatureK)
    nodalTemperatureK = nodalTemperatureK(:);
    if numel(nodalTemperatureK) ~= size(mesh.nodesM, 1) || any(~isfinite(nodalTemperatureK))
        error('leotherm:InvalidVolumePlot', 'nodalTemperatureK must contain one finite value per node.');
    end
end
faces = boundaryFaces(mesh);
cla(axesHandle);
if ~isempty(faces)
    patch(axesHandle, 'Faces', faces, 'Vertices', mesh.nodesM, ...
        'FaceColor', [0.65 0.72 0.72], 'FaceAlpha', 0.18, ...
        'EdgeColor', [0.20 0.28 0.28]);
end
hold(axesHandle, 'on');
if isempty(nodalTemperatureK)
    scatter3(axesHandle, mesh.nodesM(:,1), mesh.nodesM(:,2), mesh.nodesM(:,3), ...
        22, [0.15 0.35 0.35], 'filled');
else
    scatter3(axesHandle, mesh.nodesM(:,1), mesh.nodesM(:,2), mesh.nodesM(:,3), ...
        28, nodalTemperatureK, 'filled');
    colormap(axesHandle, parula(256)); colorbar(axesHandle);
end
hold(axesHandle, 'off');
axis(axesHandle, 'equal'); grid(axesHandle, 'on'); view(axesHandle, 3);
xlabel(axesHandle, 'X (m)'); ylabel(axesHandle, 'Y (m)'); zlabel(axesHandle, 'Z (m)');
if strcmp(language, 'en'), title(axesHandle, 'Tetrahedral volume mesh');
else, title(axesHandle, '四面体体网格'); end
try
    rotate3d(figureHandle, 'on');
catch
    % Rotation is a convenience and may be unavailable in headless MATLAB.
end
graphics = struct('figure', figureHandle, 'axes', axesHandle);
end

function faces = boundaryFaces(mesh)
if isfield(mesh, 'boundaryTriangles') && ~isempty(mesh.boundaryTriangles)
    faces = mesh.boundaryTriangles; return
end
allFaces = [mesh.tetrahedra(:, [1 2 3]); mesh.tetrahedra(:, [1 2 4]); ...
    mesh.tetrahedra(:, [1 3 4]); mesh.tetrahedra(:, [2 3 4])];
sortedFaces = sort(allFaces, 2);
[~, ~, groups] = unique(sortedFaces, 'rows'); counts = accumarray(groups, 1);
faces = allFaces(counts(groups) == 1, :);
end
