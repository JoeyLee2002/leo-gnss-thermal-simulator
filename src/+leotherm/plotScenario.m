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

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1050, 780]);
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
        'LineWidth', 1.0, 'DisplayName', temperatureLabels{k});
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

exportgraphics(figureHandle, outputPath, 'Resolution', 200);
if nargout == 0
    close(figureHandle);
end
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
