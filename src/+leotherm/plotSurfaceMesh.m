function graphics = plotSurfaceMesh(mesh, faceValues, axesHandle, language)
%PLOTSURFACEMESH Render a surface mesh with optional face data.
if nargin < 2, faceValues = []; end
if nargin < 3 || isempty(axesHandle)
    figureHandle = figure;
    axesHandle = axes(figureHandle);
else
    figureHandle = ancestor(axesHandle, 'figure');
end
if nargin < 4 || isempty(language), language = 'zh'; end
leotherm.validateSurfaceMesh(mesh);
if ~isempty(faceValues)
    faceValues = faceValues(:);
    if numel(faceValues) ~= size(mesh.faces, 1) || any(~isfinite(faceValues))
        error('leotherm:InvalidMeshPlot', 'faceValues must contain one finite value per mesh face.');
    end
end
cla(axesHandle);
if isempty(faceValues)
    patch(axesHandle, 'Faces', mesh.faces, 'Vertices', mesh.vertices, ...
        'FaceColor', [0.52 0.67 0.67], 'EdgeColor', [0.20 0.28 0.28]);
else
    patch(axesHandle, 'Faces', mesh.faces, 'Vertices', mesh.vertices, ...
        'FaceVertexCData', faceValues, 'FaceColor', 'flat', ...
        'EdgeColor', [0.18 0.22 0.22]);
    colormap(axesHandle, parula(256));
    colorbar(axesHandle);
end
axis(axesHandle, 'equal');
grid(axesHandle, 'on');
view(axesHandle, 3);
xlabel(axesHandle, 'X (m)');
ylabel(axesHandle, 'Y (m)');
zlabel(axesHandle, 'Z (m)');
if strcmp(language, 'en')
    title(axesHandle, 'Spacecraft surface mesh');
else
    title(axesHandle, '卫星三维表面网格');
end
try
    rotate3d(figureHandle, 'on');
catch
    % UIFigure backends may not expose the legacy rotate3d interaction.
end
graphics = struct('figure', figureHandle, 'axes', axesHandle);
end
