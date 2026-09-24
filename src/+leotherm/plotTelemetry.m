function figureHandle = plotTelemetry(result, report, nodeName, outputPath, language)
%PLOTTELEMETRY Export paired telemetry and residual plots with localized legends.
if nargin < 5, language = 'zh'; end
language = leotherm.normalizeLanguage(language);
figureHandle = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1100 720]);
tiledlayout(2, 1, 'TileSpacing', 'compact');
axesHandles = [nexttile, nexttile];
leotherm.drawTelemetry(axesHandles, result, report, nodeName, language);
parent = fileparts(outputPath);
if ~isempty(parent) && ~isfolder(parent), mkdir(parent); end
exportgraphics(figureHandle, outputPath, 'Resolution', 200);
if nargout == 0, close(figureHandle); end
end
