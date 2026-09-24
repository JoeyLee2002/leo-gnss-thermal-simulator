function figureHandle = plotSweep(summary, outputPath, language)
%PLOTSWEEP Plot a localized sweep summary with a legend in every panel.

if nargin < 3
    language = 'en';
end
language = leotherm.normalizeLanguage(language);
parent = fileparts(outputPath);
if ~isempty(parent) && ~exist(parent, 'dir')
    mkdir(parent);
end
valid = strcmp(summary.status, 'complete');
if ismember('accessible', summary.Properties.VariableNames)
    valid = valid & summary.accessible;
end
data = summary(valid, :);
if isempty(data)
    error('leotherm:NoCompleteCases', ...
        'The sweep contains no complete accessible cases to plot.');
end
altitudes = unique(data.altitude_km);
colors = lines(numel(altitudes));
if ismember('actual_beta_deg', data.Properties.VariableNames)
    xName = 'actual_beta_deg';
    temperatureName = 'response_temperature_span_k';
else
    xName = 'beta_deg';
    temperatureName = 'rf_temperature_span_k';
end

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1050, 760]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
variables = {'eclipse_fraction', temperatureName, ...
    'forcing_to_rf_lag_s', 'code_bias_span_m'};
if strcmp(language, 'zh')
    labels = {'入影比例', '响应节点温度跨度（K）', ...
        '热流到响应节点的时延（s）', '码偏差跨度（m）'};
    xLabel = '实际β角（°）';
else
    labels = {'Eclipse fraction', 'Response-temperature span (K)', ...
        'Forcing-to-response lag (s)', 'Code-bias span (m)'};
    xLabel = 'Actual beta angle (deg)';
end
for panel = 1:4
    nexttile; hold on
    for k = 1:numel(altitudes)
        rows = data.altitude_km == altitudes(k);
        beta = data.(xName)(rows);
        value = data.(variables{panel})(rows);
        [beta, order] = sort(beta);
        plot(beta, value(order), '-o', 'Color', colors(k, :), ...
            'LineWidth', 1.1, 'MarkerSize', 4, ...
            'DisplayName', altitudeLabel(language, altitudes(k)));
    end
    xlabel(xLabel); ylabel(labels{panel}); title(labels{panel}); grid on
    legend('Location', 'best');
end
exportgraphics(figureHandle, outputPath, 'Resolution', 200);
if nargout == 0
    close(figureHandle);
end
end

function value = altitudeLabel(language, altitudeKm)
if strcmp(language, 'zh')
    value = sprintf('%g千米', altitudeKm);
else
    value = sprintf('%g km', altitudeKm);
end
end
