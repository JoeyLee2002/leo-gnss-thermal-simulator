function figureHandle = plotScenario(result, outputPath, language)
%PLOTSCENARIO Create a localized four-panel scenario summary.

if nargin < 3
    language = 'en';
end
language = leotherm.normalizeLanguage(language);
parent = fileparts(outputPath);
if ~isempty(parent) && ~exist(parent, 'dir')
    mkdir(parent);
end
timeHour = result.timeS / 3600;
network = result.network;
[temperatureNodes, temperatureLabels] = resolveTemperatureNodes(network, language);

s = leotherm.thermalFigureStyle(language);
windowCleanup=[];
if nargout==0, windowCleanup=leotherm.preserveAppWindows; end
figureHandle = figure('Visible','off','Color', 'w', 'Units','centimeters', ...
    'Position', [2, 2, s.widthCm, 22],'Tag','ScenarioExportFigure');
try
tiledlayout(4, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile
plot(timeHour, result.loads.visibleFraction, 'k', 'LineWidth', 1.1, ...
    'DisplayName', pick(language, '太阳可见比例', 'Solar visibility'));
ylim([-0.05, 1.05]);
ylabel(pick(language, '太阳可见比例', 'Solar visibility')); grid on
if strcmp(language, 'zh')
    scenarioTitle = '单场景热响应';
else
    scenarioTitle = strrep(result.scenario.name, '_', '\_');
end
title(sprintf(pick(language, '%s | 平均β角 = %.2f°', ...
    '%s | mean beta angle = %.2f deg'), ...
    scenarioTitle, result.metrics.meanBetaDeg));
legend('Location', 'eastoutside');

nexttile
plot(timeHour, sum(result.loads.directSolarW, 2), ...
    'Color', [0.85, 0.35, 0.05], 'LineWidth', 1.0, ...
    'DisplayName', pick(language, '太阳直射', 'Direct solar')); hold on
plot(timeHour, sum(result.loads.albedoW, 2), ...
    'Color', [0.10, 0.50, 0.70], 'LineWidth', 1.0, ...
    'DisplayName', pick(language, '地球反照', 'Earth albedo'));
plot(timeHour, sum(result.loads.earthIRW, 2), ...
    'Color', [0.25, 0.25, 0.25], 'LineWidth', 1.0, ...
    'DisplayName', pick(language, '地球红外', 'Earth infrared'));
ylabel(pick(language, '热功率（W）', 'Heat load (W)'));
legend('Location', 'eastoutside'); grid on

nexttile
hold on
for k = 1:numel(temperatureNodes)
    plot(timeHour, result.temperatureK(:, temperatureNodes(k)), ...
        'Color',s.nodeColors(mod(temperatureNodes(k)-1,11)+1,:), ...
        'LineStyle',s.lineStyles{1+mod(k-1,4)}, ...
        'LineWidth', 1.55, 'DisplayName', temperatureLabels{k});
end
ylabel(pick(language, '温度（K）', 'Temperature (K)'));
legend('Location', 'eastoutside', 'Interpreter', 'none');
grid on

nexttile
plot(timeHour, result.codeBiasM, 'Color', [0.60, 0.10, 0.20], ...
    'LineWidth', 1.0, ...
    'DisplayName', pick(language, '温度诱导码偏差', ...
    'Temperature-induced code bias'));
xlabel(pick(language, '时间（h）', 'Elapsed time (h)'));
ylabel(pick(language, '码偏差（m）', 'Code bias (m)')); grid on
legend('Location', 'eastoutside');

plotAxes = findall(figureHandle, 'Type', 'axes');
for k = 1:numel(plotAxes), plotAxes(k).Toolbar.Visible = 'off'; end
leotherm.exportThermalFigure(figureHandle, outputPath, language);
catch exception
    delete(figureHandle); rethrow(exception);
end
if nargout == 0
    close(figureHandle);
else
    figureHandle.Visible='on';
end
if ~isempty(windowCleanup), delete(windowCleanup); end
end

function [indices, labels] = resolveTemperatureNodes(network, language)
roles = {'antenna', 'response', 'oscillator'};
legacy = {'gnss_antenna', 'gnss_rf_frontend', 'gnss_oscillator'};
indices = [];
for k = 1:numel(roles)
    index = [];
    if isfield(network, 'roles') && isfield(network.roles, roles{k})
        index = network.roles.(roles{k});
    end
    if isempty(index)
        index = find(strcmp(network.nodeNames, legacy{k}), 1);
    end
    if ~isempty(index) && ~ismember(index, indices)
        indices(end + 1) = index; %#ok<AGROW>
    end
end
if isempty(indices)
    error('leotherm:MissingPlotNode', ...
        'Define network.roles.response or a GNSS response node before plotting.');
end
labels = leotherm.nodeDisplayNames(network.nodeNames(indices), language);
end

function value = pick(language, chinese, english)
if strcmp(language, 'zh')
    value = chinese;
else
    value = english;
end
end
