function drawTelemetry(axesHandles, result, report, nodeName, language)
%DRAWTELEMETRY Shared UI/export renderer; never draw lines across failed arcs.
language = leotherm.normalizeLanguage(language);
for ax = axesHandles(:)'
    cla(ax); hold(ax, 'on'); grid(ax, 'on');
end
labels = leotherm.nodeDisplayNames({char(nodeName)}, language);
if isfield(result, 'epoch'), epoch = result.epoch; else, epoch = result.orbit.epoch; end
origin = epoch(find(~isnat(epoch), 1));
time = seconds(epoch - origin) / 3600;
node = find(strcmp(result.network.nodeNames, nodeName), 1);
if ~isempty(node)
    segments = ones(numel(time), 1);
    if isfield(result, 'segmentId'), segments = result.segmentId; end
    first = true;
    for id = unique(segments(segments > 0))'
        rows = segments == id;
        h = plot(axesHandles(1), time(rows), result.temperatureK(rows, node), ...
            'Color', [0.05 0.4 0.7], 'LineWidth', 1.2, ...
            'DisplayName', pick(language, '仿真温度', 'Simulated temperature'));
        if ~first, h.HandleVisibility = 'off'; end
        if isfield(result, 'boundaryMapped') && result.boundaryMapped(node)
            h = stairs(axesHandles(1), time(rows), result.boundaryTemperatureK(rows,node), ...
                '--', 'Color',[0.45 0.32 0.55], 'LineWidth',1.1, ...
                'DisplayName',pick(language,'规定的边界温度','Prescribed boundary temperature'));
            if ~first, h.HandleVisibility = 'off'; end
        end
        first = false;
    end
    if first
        plot(axesHandles(1),NaN,NaN,'Color',[0.05 0.4 0.7], ...
            'DisplayName',pick(language,'无有效仿真温度','No valid simulated temperature'));
    end
end
if ~isempty(report) && ~isempty(report.samples)
    samples = report.samples(report.samples.node == string(nodeName), :);
    observedRows = isfinite(samples.observed_k) & samples.observed_k > 0 ...
        & ~ismember(samples.reason, ["quality_rejected","invalid_utc_time"]);
    x = seconds(samples.epoch_utc - origin) / 3600;
    observationLabel = pick(language, '实测温度', 'Measured temperature');
    if strcmp(report.datasetKind, 'synthetic_demo_not_flight_data')
        observationLabel = pick(language, '合成观测（演示）', 'Synthetic observations (demo)');
    end
    scatter(axesHandles(1), x(observedRows), samples.observed_k(observedRows), ...
        12, [0.8 0.3 0.12], 'filled', 'DisplayName', ...
        observationLabel);
    scatter(axesHandles(2), x(samples.used), samples.residual_k(samples.used), ...
        16, [0.15 0.5 0.38], 'filled', 'DisplayName', ...
        pick(language, '参与统计的残差', 'Scored residuals'));
end
yline(axesHandles(2), 0, '--', 'DisplayName', pick(language, '零误差', 'Zero error'));
title(axesHandles(1), labels{1}, 'Interpreter', 'none');
title(axesHandles(2), pick(language, '仿真减实测', 'Simulation minus measurement'));
ylabel(axesHandles(1), pick(language, '温度（K）', 'Temperature (K)'));
ylabel(axesHandles(2), pick(language, '温差（K）', 'Temperature error (K)'));
for ax = axesHandles(:)'
    xlabel(ax, pick(language, '自起始历元起的时间（h）', 'Time from first epoch (h)'));
    legend(ax, 'show', 'Location', 'best', 'Interpreter', 'none'); hold(ax, 'off');
end
end

function value = pick(language, chinese, english)
if strcmp(language, 'zh'), value = chinese; else, value = english; end
end
