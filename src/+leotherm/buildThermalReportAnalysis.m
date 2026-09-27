function sections = buildThermalReportAnalysis(bundle)
%BUILDTHERMALREPORTANALYSIS Derive report claims only from completed results.
sections = struct('stage', {}, 'titleZh', {}, 'titleEn', {}, ...
    'linesZh', {}, 'linesEn', {}, 'figureStem', {});

scenario = fieldOr(bundle, 'scenario', []);
if isstruct(scenario) && isscalar(scenario) ...
        && all(isfield(scenario, {'loads', 'temperatureK', 'network', 'metrics'}))
    m = fieldOr(scenario, 'metrics', struct);
    eclipse = fieldOr(m, 'eclipseFraction', NaN);
    zh = { ...
        sprintf('平均β角 %s 度；入影占比 %s。', fmt(fieldOr(m, 'meanBetaDeg', NaN)), percent(eclipse)), ...
        sprintf('射频节点温度跨度 %s K；温度诱导码偏差跨度 %s m。', ...
        fmt(fieldOr(m, 'rfTemperatureSpanK', NaN)), fmt(fieldOr(m, 'codeBiasSpanM', NaN)))};
    en = { ...
        sprintf('Mean beta angle: %s deg; eclipse fraction: %s.', ...
        fmt(fieldOr(m, 'meanBetaDeg', NaN)), percent(eclipse)), ...
        sprintf('RF temperature span: %s K; assumed temperature-induced code-bias span: %s m.', ...
        fmt(fieldOr(m, 'rfTemperatureSpanK', NaN)), fmt(fieldOr(m, 'codeBiasSpanM', NaN)))};
    lag = fieldOr(m, 'forcingToRfLagS', NaN);
    if isfiniteScalar(lag)
        zh{end+1} = sprintf('热流至射频响应的估计时延为 %s s。', fmt(lag));
        en{end+1} = sprintf('Estimated forcing-to-RF response lag: %s s.', fmt(lag));
    else
        zh{end+1} = '本次时延指标未定义；不能把它解释成零时延。';
        en{end+1} = 'The lag metric is undefined in this run, not zero lag.';
    end
    if isfiniteScalar(eclipse) && eclipse < 0.01
        zh{end+1} = '几乎没有入影，不能据此分析入影后的热滞后。';
        en{end+1} = 'With almost no eclipse, post-eclipse thermal lag cannot be assessed.';
    end
    transitions = fieldOr(m, 'eclipseTransitionCount', NaN);
    if isfiniteScalar(transitions) && transitions > 0
        zh{end+1} = sprintf('记录 %s 次光照转换；该次数取决于本次时长与轨道条件。', fmt(transitions));
        en{end+1} = sprintf('%s illumination transitions occurred over this run.', fmt(transitions));
    end
    if isfiniteScalar(lag) && lag > 0 && isfiniteScalar(eclipse) && eclipse > 0
        zh{end+1} = '射频响应滞后于外部热流，与热惯性相容，但不能单独证明机理。';
        en{end+1} = 'RF response trails forcing, consistent with thermal inertia but not proof of mechanism.';
    end
    zh{end+1} = '上述码偏差由设定的温度灵敏度计算，不是实测GNSS误差。';
    en{end+1} = 'The code bias uses assumed thermal sensitivity; it is not measured GNSS error.';
    configuration = fieldOr(scenario, 'scenario', struct);
    if isequal(fieldOr(configuration, 'warmupOrbits', NaN), 0)
        zh{end+1} = '未做预热；初始温度暂态可能影响温度跨度和时延。';
        en{end+1} = 'No warmup was used; initial-temperature transients may affect spans and lag.';
    end
    sections(end+1) = entry('scenario', '轨道热环境与节点响应', ...
        'Orbit heating and nodal response', zh, en, 'scenario_summary');
end

sweep = fieldOr(bundle, 'sweep', []);
if istable(sweep) && ~isempty(sweep) ...
        && ismember('status', sweep.Properties.VariableNames) ...
        && any(strcmp(string(sweep.status), 'complete'))
    valid = strcmp(string(sweep.status), 'complete');
    data = sweep(valid, :);
    beta = sweepColumn(data, {'actual_beta_deg', 'beta_deg'});
    eclipse = sweepColumn(data, {'eclipse_fraction'});
    rf = sweepColumn(data, {'rf_temperature_span_k'});
    bias = sweepColumn(data, {'code_bias_span_m'});
    zh = {sprintf('完成 %d/%d 个工况；β角范围 %s 度，入影比例范围 %s。', ...
        height(data), height(sweep), rangeText(beta), percentRange(eclipse)), ...
        sprintf('射频温度跨度范围 %s K；码偏差跨度范围 %s m。', ...
        rangeText(rf), rangeText(bias))};
    en = {sprintf('%d/%d cases completed; beta range %s deg and eclipse fraction %s.', ...
        height(data), height(sweep), rangeText(beta), percentRange(eclipse)), ...
        sprintf('RF temperature-span range: %s K; code-bias-span range: %s m.', ...
        rangeText(rf), rangeText(bias))};
    if height(data) == 1
        zh{end+1} = '只有一个有效工况：这是案例结果，不能推断参数趋势或最优值。';
        en{end+1} = 'One valid case is a case result, not a trend or an optimum.';
    else
        [peak, index] = max(bias);
        if ~isempty(peak) && isfinite(peak) && numel(beta) >= index
            zh{end+1} = sprintf('本次网格中最大码偏差跨度 %s m，对应β角 %s 度。', ...
                fmt(peak), fmt(beta(index)));
            en{end+1} = sprintf('Largest code-bias span on this grid: %s m at beta %s deg.', ...
                fmt(peak), fmt(beta(index)));
        end
        zh{end+1} = '范围仅描述本次扫描网格；未控制其他变量时不作因果判断。';
        en{end+1} = 'Ranges describe this grid; causal effects require controlled comparisons.';
    end
    sections(end+1) = entry('sweep', '参数扫描：覆盖与响应范围', ...
        'Sweep coverage and response range', zh, en, 'sweep_summary');
end

surface = fieldOr(bundle, 'surface', []);
volume = fieldOr(bundle, 'volume', []);
if ~isempty(surface) || ~isempty(volume)
    zh = {}; en = {};
    if ~isempty(surface)
        values = finiteValues(fieldOr(surface, 'temperatureK', []));
        faces = size(fieldOr(fieldOr(surface, 'mesh', struct), 'faces', []), 1);
        zh{end+1} = sprintf('表面 %d 个面片；计算温度范围 %s K。', faces, rangeText(values));
        en{end+1} = sprintf('%d surface faces; calculated temperature range %s K.', ...
            faces, rangeText(values));
    end
    if ~isempty(volume)
        values = finiteValues(fieldOr(volume, 'temperatureK', []));
        nodes = size(fieldOr(fieldOr(volume, 'mesh', struct), 'nodesM', []), 1);
        zh{end+1} = sprintf('体网格 %d 个节点；计算温度范围 %s K。', nodes, rangeText(values));
        en{end+1} = sprintf('%d volume nodes; calculated temperature range %s K.', ...
            nodes, rangeText(values));
        coupling = fieldOr(volume, 'couplingDiagnostics', []);
        if ~isempty(coupling)
            closure = fieldOr(coupling, 'maximumAbsoluteClosureW', NaN);
            zh{end+1} = sprintf('表面至体边界热流映射的最大闭合差 %s W。', fmt(closure));
            en{end+1} = sprintf('Maximum surface-to-volume heat-flow mapping closure: %s W.', ...
                fmt(closure));
            zh{end+1} = '当前是单向表面至体耦合；表面温度不反馈到体求解。';
            en{end+1} = 'Coupling is one-way; surface temperatures do not feed back to the volume solve.';
        end
    end
    zh{end+1} = '温度范围是数值结果；材料和接触边界仍需按目标卫星核实。';
    en{end+1} = 'Temperature ranges are numerical; mission materials and contacts need confirmation.';
    figureStem = '';
    if hasHistory(surface) || hasHistory(volume)
        figureStem = 'geometry_summary';
    end
    sections(end+1) = entry('geometry', '三维温度与耦合诊断', ...
        'Three-dimensional temperature and coupling', zh, en, figureStem);
end

calibration = fieldOr(bundle, 'calibration', []);
if isstruct(calibration) && ~isempty(calibration)
    metrics = fieldOr(calibration, 'stageMetrics', table);
    status = char(string(fieldOr(calibration, 'status', 'not_recorded')));
    zh = {sprintf('标定状态：%s；仅通过声明准则后才采用冻结参数。', ...
        calibrationStatusZh(status))};
    en = {sprintf('Calibration status: %s; frozen parameters are adopted only after declared checks.', ...
        status)};
    roles = {'train', 'validation', 'test'};
    roleZh = {'训练', '验证', '测试'};
    for k = 1:3
        [before, after, count] = pooledCalibration(metrics, roles{k});
        if count == 0, continue; end
        zh{end+1} = sprintf('%s集：%d 个评分样本，标称/标定 RMSE 为 %s/%s K。', ...
            roleZh{k}, count, fmt(before), fmt(after)); %#ok<AGROW>
        en{end+1} = sprintf('%s: %d scored samples; nominal/calibrated RMSE %s/%s K.', ...
            roles{k}, count, fmt(before), fmt(after)); %#ok<AGROW>
    end
    zh{end+1} = '训练集误差不是独立验证；样本计数不等于独立卫星日数。';
    en{end+1} = 'Training error is not independent validation; samples are not independent days.';
    figureStem = '';
    if istable(metrics) && ~isempty(metrics), figureStem = 'calibration_summary'; end
    sections(end+1) = entry('calibration', '设备标定与留出集检验', ...
        'Calibration and held-out checks', zh, en, figureStem);
end

telemetry = fieldOr(bundle, 'telemetry', []);
comparison = fieldOr(telemetry, 'report', []);
if isstruct(comparison) && ~isempty(comparison)
    metrics = fieldOr(comparison, 'metrics', table);
    used = 0; rmse = [];
    if istable(metrics) && ~isempty(metrics)
        used = sum(metrics.used_samples);
        rmse = finiteValues(metrics.rmse_k);
    end
    kind = char(string(fieldOr(comparison, 'datasetKind', 'not_recorded')));
    independence = char(string(fieldOr(comparison, 'independence', 'not_recorded')));
    zh = {sprintf('比较 %d 个温度节点、%d 个评分样本；节点 RMSE 范围 %s K。', ...
        height(metrics), used, rangeText(rmse)), ...
        sprintf('数据类型：%s；独立性：%s。', ...
        datasetKindZh(kind), independenceZh(independence))};
    en = {sprintf('%d nodes and %d scored samples; node RMSE range %s K.', ...
        height(metrics), used, rangeText(rmse)), ...
        sprintf('Dataset kind: %s; independence: %s.', kind, independence)};
    if contains(kind, 'synthetic')
        zh{end+1} = '本次是合成数据对比，不能作为在轨物理验证。';
        en{end+1} = 'This is a synthetic-data comparison, not in-flight physical validation.';
    else
        zh{end+1} = '误差仅在精确匹配且通过质量筛选的历元上统计。';
        en{end+1} = 'Errors use exactly matched, quality-accepted epochs only.';
    end
    figureStem = 'telemetry_summary';
    if used == 0
        zh{end+1} = '没有可评分样本，因此不生成残差图，也不作吻合度结论。';
        en{end+1} = 'No scored samples: no residual chart or agreement conclusion is available.';
        figureStem = '';
    end
    sections(end+1) = entry('telemetry', '遥测温度对比与证据边界', ...
        'Telemetry comparison and evidence boundary', zh, en, figureStem);
end
end

function item = entry(stage, zh, en, linesZh, linesEn, figureStem)
item = struct('stage', stage, 'titleZh', zh, 'titleEn', en, ...
    'linesZh', {linesZh}, 'linesEn', {linesEn}, 'figureStem', figureStem);
end

function value = fieldOr(source, name, fallback)
value = fallback;
if isstruct(source) && isscalar(source) && isfield(source, name)
    value = source.(name);
end
end

function value = sweepColumn(data, names)
value = [];
for k = 1:numel(names)
    if ismember(names{k}, data.Properties.VariableNames)
        value = finiteValues(data.(names{k}));
        return
    end
end
end

function value = finiteValues(value)
if ~isnumeric(value), value = []; return; end
value = value(isfinite(value));
end

function value = isfiniteScalar(input)
value = isnumeric(input) && isscalar(input) && isfinite(input);
end

function value = fmt(input)
if isfiniteScalar(input), value = sprintf('%.4g', input);
else, value = 'N/A'; end
end

function value = rangeText(input)
input = finiteValues(input);
if isempty(input), value = 'N/A'; return; end
value = sprintf('%.4g - %.4g', min(input), max(input));
end

function value = percent(input)
if isfiniteScalar(input), value = sprintf('%.2f%%', 100 * input);
else, value = 'N/A'; end
end

function value = percentRange(input)
input = finiteValues(input);
if isempty(input), value = 'N/A'; return; end
value = sprintf('%.2f%% - %.2f%%', 100 * min(input), 100 * max(input));
end

function [before, after, count] = pooledCalibration(metrics, role)
before = NaN; after = NaN; count = 0;
required = {'role', 'used_samples', 'baseline_rmse_k', 'calibrated_rmse_k'};
if ~istable(metrics) || ~all(ismember(required, metrics.Properties.VariableNames))
    return
end
rows = strcmp(string(metrics.role), role) & metrics.used_samples > 0 ...
    & isfinite(metrics.baseline_rmse_k) & isfinite(metrics.calibrated_rmse_k);
n = metrics.used_samples(rows);
count = sum(n);
if count == 0, return; end
before = sqrt(sum(n .* metrics.baseline_rmse_k(rows).^2) / count);
after = sqrt(sum(n .* metrics.calibrated_rmse_k(rows).^2) / count);
end

function valid = hasHistory(result)
valid = isstruct(result) && isscalar(result) ...
    && all(isfield(result, {'timeS', 'temperatureK'})) ...
    && ~isempty(result.timeS) && isnumeric(result.temperatureK) ...
    && size(result.temperatureK, 1) == numel(result.timeS);
end

function value = calibrationStatusZh(code)
switch code
    case 'accepted_within_declared_scope', value = '在声明范围内接受';
    case 'criteria_not_met', value = '未满足准则';
    case 'review_required', value = '需要人工复核';
    otherwise, value = '未记录或未识别';
end
end

function value = datasetKindZh(code)
if contains(code, 'synthetic')
    value = '合成演示数据';
elseif strcmp(code, 'not_recorded')
    value = '未记录';
else
    value = '用户提供的数据，类型待核实';
end
end

function value = independenceZh(code)
switch code
    case 'synthetic_not_independent_validation'
        value = '合成数据，非独立验证';
    case 'not_established_user_must_confirm_held_out_data'
        value = '未建立，需核实留出数据';
    case 'conditioned_on_measured_initial_state'
        value = '依赖实测初温';
    case 'in_sample_calibration_not_validation'
        value = '训练集内比较';
    otherwise
        value = '未记录或未识别';
end
end
