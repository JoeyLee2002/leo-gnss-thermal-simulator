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
s = leotherm.thermalFigureStyle(language);
colors = s.colors(1+mod(0:numel(altitudes)-1,size(s.colors,1)),:);
if ismember('actual_beta_deg', data.Properties.VariableNames)
    xName = 'actual_beta_deg';
    temperatureName = 'response_temperature_span_k';
else
    xName = 'beta_deg';
    temperatureName = 'rf_temperature_span_k';
end

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
if ismember('orbital_phase_delay_s',data.Properties.VariableNames)
    variables{3}='orbital_phase_delay_s';
    if strcmp(language,'zh'), labels{3}='轨道基频相位时延（s）';
    else, labels{3}='Orbital-frequency phase delay (s)'; end
end
available=cellfun(@(name) any(isfinite(data.(name))),variables);
for metricIndex=2:4
    labels{metricIndex}=leotherm.thermalMetricLabel(variables{metricIndex},language);
end
variables=variables(available); labels=labels(available);
panels=numel(variables);
if panels==0, error('leotherm:NoCompleteCases','No finite sweep metrics to plot.'); end
cols=1; if panels>=4, cols=2; end
rows=ceil(panels/cols);
figureHandle = figure('Color', 'w', 'Units','centimeters', ...
    'Position', [2, 2, s.widthCm, max(12,rows*5.5)]);
tiledlayout(rows, cols, 'TileSpacing', 'compact', 'Padding', 'loose');
for panel = 1:panels
    nexttile; hold on
    for k = 1:numel(altitudes)
        rows = data.altitude_km == altitudes(k);
        beta = data.(xName)(rows);
        value = data.(variables{panel})(rows);
        [beta, order] = sort(beta);
        plot(beta, value(order), '-o', 'Color', colors(k, :), ...
            'LineStyle',s.lineStyles{1+mod(k-1,4)}, ...
            'MarkerFaceColor','w','LineWidth', 1.55, 'MarkerSize', 5, ...
            'DisplayName', altitudeLabel(language, altitudes(k)));
    end
    xlabel(xLabel); ylabel(labels{panel}); title(char('a'+panel-1)); grid on
    legend('Location', 'southoutside','Orientation','horizontal','NumColumns',2);
end
leotherm.exportThermalFigure(figureHandle, outputPath, language);
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
