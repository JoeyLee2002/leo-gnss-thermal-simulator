function plotThermalReportStage(bundle, stage, path, language)
%PLOTTHERMALREPORTSTAGE Draw only observed outputs of completed stages.
language = leotherm.normalizeLanguage(language);
fig = figure('Visible', 'off', 'Color', 'w', ...
    'Position', [80 80 1050 720]);
cleanup = onCleanup(@() close(fig));
switch stage
    case 'single_sweep'
        plotSingleSweep(bundle, language);
    case 'geometry'
        plotGeometry(bundle, language);
    case 'telemetry'
        plotTelemetry(bundle, language);
    case 'calibration'
        plotCalibration(bundle, language);
    otherwise
        error('leotherm:ReportFigure', 'Unsupported report stage: %s', stage);
end
exportgraphics(fig, path, 'Resolution', 170);
clear cleanup
end

function plotSingleSweep(bundle, language)
data = bundle.sweep(strcmp(string(bundle.sweep.status), 'complete'), :);
if height(data) ~= 1
    error('leotherm:ReportFigure', 'Single-case sweep plot requires one complete case.');
end
names = {'eclipse_fraction', 'rf_temperature_span_k', 'code_bias_span_m'};
titlesZh = {'入影比例', '射频温度跨度', '码偏差跨度'};
titlesEn = {'Eclipse fraction', 'RF temperature span', 'Code-bias span'};
units = {'%', 'K', 'm'};
colors = [0.11 0.50 0.62; 0.18 0.57 0.40; 0.74 0.31 0.19];
layout = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:3
    nexttile(layout);
    value = data.(names{k})(1);
    if k == 1, value = 100 * value; end
    bar(1, value, 'FaceColor', colors(k, :), 'DisplayName', ...
        pick(language, '当前工况', 'Current case'));
    if strcmp(language, 'zh'), title(titlesZh{k}); else, title(titlesEn{k}); end
    ylabel(units{k});
    xlim([0.4 1.6]); set(gca, 'XTick', []);
    if isfinite(value)
        ylim([0 max(1.25 * value, eps)]);
        text(1, value, sprintf('%.4g', value), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    end
    legend('Location', 'best'); grid on
end
end

function plotGeometry(bundle, language)
hasSurface = hasHistory(bundle.surface);
hasVolume = hasHistory(bundle.volume);
layout = tiledlayout(double(hasSurface) + double(hasVolume), 1, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
if hasSurface
    nexttile(layout);
    temperaturePanel(bundle.surface, language, ...
        pick(language, '表面面片温度', 'Surface-face temperatures'));
end
if hasVolume
    nexttile(layout);
    temperaturePanel(bundle.volume, language, ...
        pick(language, '体网格节点温度', 'Volume-node temperatures'));
end
end

function temperaturePanel(result, language, titleText)
t = result.timeS(:) / 3600;
values = result.temperatureK;
if isempty(t) || isempty(values) || size(values, 1) ~= numel(t)
    error('leotherm:ReportFigure', 'Geometry temperature history is incomplete.');
end
plot(t, min(values, [], 2), 'Color', [0.12 0.43 0.68], ...
    'DisplayName', pick(language, '最小值', 'Minimum')); hold on
plot(t, mean(values, 2), 'Color', [0.13 0.53 0.42], ...
    'DisplayName', pick(language, '均值', 'Mean'));
plot(t, max(values, [], 2), 'Color', [0.76 0.28 0.20], ...
    'DisplayName', pick(language, '最大值', 'Maximum'));
title(titleText); xlabel(pick(language, '时间（h）', 'Elapsed time (h)'));
ylabel(pick(language, '温度（K）', 'Temperature (K)'));
grid on; legend('Location', 'best');
end

function plotTelemetry(bundle, language)
samples = bundle.telemetry.report.samples;
needed = {'used','observed_k','predicted_k','residual_k','node','epoch_utc'};
if ~istable(samples) || ~all(ismember(needed, samples.Properties.VariableNames))
    error('leotherm:ReportFigure', 'Telemetry scored samples are unavailable.');
end
samples = samples(samples.used, :);
if isempty(samples)
    error('leotherm:ReportFigure', 'Telemetry has no scored samples.');
end
nodes = unique(string(samples.node), 'stable');
colors = lines(numel(nodes));
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(layout); hold on
for k = 1:numel(nodes)
    rows = find(string(samples.node) == nodes(k));
    rows = rows(round(linspace(1, numel(rows), min(numel(rows), 1200))));
    scatter(samples.observed_k(rows), samples.predicted_k(rows), 10, ...
        colors(k, :), 'filled', 'MarkerFaceAlpha', 0.45, ...
        'DisplayName', char(nodes(k)));
end
low = min([samples.observed_k; samples.predicted_k]);
high = max([samples.observed_k; samples.predicted_k]);
plot([low high], [low high], 'k--', 'DisplayName', ...
    pick(language, '一致线', 'Identity'));
xlabel(pick(language, '实测温度（K）', 'Observed temperature (K)'));
ylabel(pick(language, '仿真温度（K）', 'Simulated temperature (K)'));
title(pick(language, '精确匹配历元：仿真与观测', ...
    'Exactly matched epochs: simulation versus observation'));
legend('Location', 'bestoutside', 'Interpreter', 'none'); grid on

nexttile(layout); hold on
first = min(samples.epoch_utc);
for k = 1:numel(nodes)
    rows = find(string(samples.node) == nodes(k));
    rows = rows(round(linspace(1, numel(rows), min(numel(rows), 1200))));
    elapsed = hours(samples.epoch_utc(rows) - first);
    plot(elapsed, samples.residual_k(rows), '.', 'Color', colors(k, :), ...
        'DisplayName', char(nodes(k)));
end
yline(0, 'k--', 'HandleVisibility', 'off');
xlabel(pick(language, '距首个评分历元（h）', ...
    'Hours since first scored epoch'));
ylabel(pick(language, '仿真减实测（K）', 'Simulation minus observation (K)'));
title(pick(language, '评分样本残差', 'Scored-sample residuals'));
legend('Location', 'bestoutside', 'Interpreter', 'none'); grid on
end

function plotCalibration(bundle, language)
metrics = bundle.calibration.stageMetrics;
roles = {'train', 'validation', 'test'};
values = nan(3, 2);
for k = 1:3
    rows = strcmp(string(metrics.role), roles{k}) & metrics.used_samples > 0 ...
        & isfinite(metrics.baseline_rmse_k) ...
        & isfinite(metrics.calibrated_rmse_k);
    n = metrics.used_samples(rows);
    if isempty(n), continue; end
    values(k, 1) = sqrt(sum(n .* metrics.baseline_rmse_k(rows).^2) / sum(n));
    values(k, 2) = sqrt(sum(n .* metrics.calibrated_rmse_k(rows).^2) / sum(n));
end
if ~any(isfinite(values(:)))
    error('leotherm:ReportFigure', 'Calibration has no scored samples.');
end
bar(values, 'grouped');
set(gca, 'XTickLabel', {pick(language, '训练', 'Train'), ...
    pick(language, '验证', 'Validation'), pick(language, '测试', 'Test')});
ylabel(pick(language, '样本加权 RMSE（K）', 'Sample-weighted RMSE (K)'));
title(pick(language, '冻结参数前后的分组误差', ...
    'Grouped error before and after parameter freezing'));
legend({pick(language, '标称参数', 'Nominal'), ...
    pick(language, '标定参数', 'Calibrated')}, 'Location', 'best');
grid on
end

function value = pick(language, zh, en)
if strcmp(language, 'zh'), value = zh; else, value = en; end
end

function valid = hasHistory(result)
valid = isstruct(result) && isscalar(result) ...
    && all(isfield(result, {'timeS', 'temperatureK'})) ...
    && ~isempty(result.timeS) && isnumeric(result.temperatureK) ...
    && size(result.temperatureK, 1) == numel(result.timeS);
end
