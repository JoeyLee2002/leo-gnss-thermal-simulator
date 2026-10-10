function page = writeThermalPdfReport(report, bundle, path, language, assetDirectory)
%WRITETHERMALPDFREPORT Render a readable, task-specific PDF without toolboxes.
language = leotherm.normalizeLanguage(language);
if ~ismember(language, {'zh','en'})
    error('leotherm:ReportExport', 'PDF language must be zh or en.');
end
if isfile(path)
    error('leotherm:ReportExport', 'PDF already exists: %s', path);
end
destination = path;
path = tempname(fileparts(destination));
mkdir(path);
pageCleanup = onCleanup(@() removePageDirectory(path));
page = 0;
lines = summaryLines(report, bundle, language);
page = textPages(path, page, language, ...
    tr(language, '任务结果概览', 'Task result overview'), lines, 24);

for k = 1:numel(report.analysis)
    item = report.analysis(k);
    if strcmp(language, 'zh')
        titleText = item.titleZh; analysisLines = item.linesZh;
    else
        titleText = item.titleEn; analysisLines = item.linesEn;
    end
    if ~isempty(item.figureStem)
        figurePath = fullfile(assetDirectory, [item.figureStem '_' language '.png']);
        if isfile(figurePath)
            page = analysisPage(path, page, language, titleText, analysisLines, figurePath);
        else
            error('leotherm:ReportExport', ...
                'Analysis figure is missing for stage %s: %s', item.stage, figurePath);
        end
    else
        page = textPages(path, page, language, titleText, analysisLines, 22);
    end
end

if isfield(report, 'details')
    for k = 1:numel(report.details)
        item = report.details(k);
        if strcmp(language, 'zh')
            titleText = item.titleZh; analysisLines = item.linesZh;
        else
            titleText = item.titleEn; analysisLines = item.linesEn;
        end
        page = analysisPage(path, page, language, titleText, analysisLines, ...
            fullfile(assetDirectory, [item.figureStem '_' language '.png']));
    end
end
if isfield(report, 'nodeStatistics') && ~isempty(report.nodeStatistics)
    values = report.nodeStatistics;
    displayNames = leotherm.nodeDisplayNames(cellstr(values.node_name),language);
    lines = {tr(language, '温度为 K，热容为 J/K，功耗为配置值 W。均值采用时间加权。', ...
        'Temperature: K; capacity: J/K; configured power: W. Means are time-weighted.')};
        for k = 1:height(values)
            row = values(k,:);
            lines{end+1} = sprintf('# %d: %s',row.node_id,displayNames{k}); %#ok<AGROW>
            lines{end+1} = sprintf(tr(language, '最低 %.3f | 均值 %.3f | 最高 %.3f | 完整极差 %.3f', ...
                'Min %.3f | Mean %.3f | Max %.3f | Full range %.3f'), ...
                row.minimum_k,row.time_mean_k,row.maximum_k,row.peak_to_peak_k); %#ok<AGROW>
            lines{end+1} = sprintf(tr(language, '热容 %.5g | 内部功耗 %.5g | 末端减起点 %.3f K', ...
                'Capacity %.5g | Internal power %.5g | End minus start %.3f K'), ...
                row.capacity_j_per_k,row.configured_internal_power_w,row.end_minus_start_k); %#ok<AGROW>
        end
    page = textPages(path,page,language,tr(language,'全节点统计附表','All-node statistics'),lines,30);
end
rows = sectionLines(report.sections, language);
if isempty(rows)
    rows = {tr(language, '没有结构化输入记录。', 'No structured input record is available.')};
end
page = textPages(path, page, language, ...
    tr(language, '输入与结果明细', 'Inputs and result details'), rows, 24);

if ~isempty(report.telemetry)
    lines = telemetryLines(report.telemetry, language);
    page = textPages(path, page, language, ...
        tr(language, '遥测对比', 'Telemetry comparison'), lines, 24);
end
lines = acceptanceLines(report, bundle, language);
page = textPages(path, page, language, tr(language, '计算检查与复核记录', ...
    'Computation checks and audit record'), lines, 24);
if isfield(report,'synthesis')
    item=report.synthesis.conclusion;
    page=textPages(path,page,language,tr(language,item.titleZh,item.titleEn), ...
        synthesisLines(item,language),24);
end

pages = arrayfun(@(k) fullfile(path,sprintf('page_%04d.pdf',k)),1:page,'UniformOutput',false);
leotherm.mergeReportPdfPages(pages,destination);
fid = fopen(destination, 'rb');
if fid < 0, error('leotherm:ReportExport', 'PDF was not created: %s', destination); end
cleanup = onCleanup(@() fclose(fid));
header = fread(fid, 5, '*char')';
if ~strcmp(header, '%PDF-')
    error('leotherm:ReportExport', 'Invalid PDF output: %s', path);
end
end

function removePageDirectory(path)
% This directory was created by tempname for this report only.
if isfolder(path), rmdir(path,'s'); end
end

function lines=synthesisLines(item,language)
if strcmp(language,'zh'), lines=item.linesZh; else, lines=item.linesEn; end
for k=1:numel(lines), lines{k}=sprintf('%d. %s',k,lines{k}); end
end

function page = textPages(path, page, language, titleText, lines, limit)
first = 1;
while first <= numel(lines)
    last = first - 1;
    remaining = 0.835 - 0.105;
    while last < numel(lines) && last - first + 1 < limit
        next = last + 1;
        cost = lineCost(lines{next});
        if startsWith(lines{next}, '# ') && next < numel(lines)
            cost = cost + lineCost(lines{next + 1});
        end
        if cost > remaining, break; end
        last = next;
        remaining = remaining - lineCost(lines{last});
    end
    if last < first
        error('leotherm:ReportExport', 'PDF text block does not fit on a page.');
    end
    currentTitle = titleText;
    if first > 1
        currentTitle = [titleText tr(language, '（续）', ' (continued)')];
    end
    page = textPage(path, page, language, currentTitle, lines(first:last));
    first = last + 1;
end
end

function cost = lineCost(value)
if startsWith(value, '# '), cost = 0.024*numel(wrapText(extractAfter(value,2),85))+0.024;
else, cost = 0.024*numel(wrapText(value,100))+0.008; end
end

function page = textPage(path, page, language, titleText, lines)
page = page + 1;
[fig, ax] = newPage(language, titleText, page);
cleanup = onCleanup(@() close(fig));
y = 0.835;
for k = 1:numel(lines)
    value = char(lines{k});
    if startsWith(value, '# ')
        y = y - 0.010;
        wrapped = wrapText(extractAfter(value,2),85);
        for j = 1:numel(wrapped)
            put(ax,0.075,y,wrapped{j},11,[0.08 0.35 0.31],true); y = y-0.024;
        end
        y = y-0.014;
    else
        wrapped = wrapText(value,100);
        for j = 1:numel(wrapped)
            leotherm.drawReportBodyLine(ax,wrapped{j},y,j<numel(wrapped)); y = y-0.024;
        end
        y = y-0.008;
    end
    if y < 0.105
        error('leotherm:ReportExport', 'PDF page has too much text.');
    end
end
appendPage(fig, path, page);
clear cleanup
end

function page = imagePage(path, page, language, titleText, imagePath)
page = page + 1;
[fig, ~] = newPage(language, titleText, page);
cleanup = onCleanup(@() close(fig));
ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.06 0.17 0.88 0.65]);
image(ax, imread(imagePath));
axis(ax, 'image');
axis(ax, 'off');
appendPage(fig, path, page);
clear cleanup
end

function page = analysisPage(path, page, language, titleText, lines, imagePath)
wrapped = {};
justify = false(1,0);
for k = 1:numel(lines)
    paragraph = wrapText(lines{k},100);
    wrapped = [wrapped,paragraph]; %#ok<AGROW>
    justify = [justify,true(1,numel(paragraph)-1),false]; %#ok<AGROW>
end
if numel(wrapped) > 12
    page = textPages(path,page,language,titleText,lines,24);
    page = imagePage(path,page,language,titleText,imagePath);
    return
end
page = page + 1;
[fig, ax] = newPage(language, titleText, page);
cleanup = onCleanup(@() close(fig));
y = 0.825;
for k = 1:numel(wrapped)
    leotherm.drawReportBodyLine(ax,wrapped{k},y,justify(k));
    y = y - 0.027;
end
top = y - 0.020;
if top <= 0.36
    error('leotherm:ReportExport', 'No room for the analysis figure.');
end
chart = axes('Parent', fig, 'Units', 'normalized', ...
    'Position', [0.065 0.14 0.87 top - 0.14]);
image(chart, imread(imagePath));
axis(chart, 'image'); axis(chart, 'off');
appendPage(fig, path, page);
clear cleanup
end

function [fig, ax] = newPage(language, titleText, page)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
    'Position', [80 60 827 1169], 'MenuBar', 'none', 'ToolBar', 'none');
ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 1], ...
    'XLim', [0 1], 'YLim', [0 1], 'Visible', 'off');
hold(ax, 'on');
ax.Toolbar.Visible = 'off';
patch(ax, [0 1 1 0], [0 0 1 1], [1 1 1], 'EdgeColor', 'none');
patch(ax, [0 1 1 0], [0.945 0.945 1 1], [0.09 0.20 0.22], 'EdgeColor', 'none');
put(ax, 0.075, 0.966, tr(language, '低轨卫星热仿真任务报告', ...
    'LEO thermal simulation task report'), 10, [1 1 1], true);
put(ax, 0.075, 0.890, titleText, 18, [0.08 0.22 0.24], true);
plot(ax, [0.075 0.925], [0.865 0.865], 'Color', [0.15 0.55 0.48], 'LineWidth', 1.2);
plot(ax, [0.075 0.925], [0.072 0.072], 'Color', [0.78 0.82 0.81], 'LineWidth', 0.7);
h=put(ax, 0.5, 0.045, sprintf('%d', page), 8, [0.40 0.45 0.46], false);
set(h,'HorizontalAlignment','center');
end

function h=put(ax, x, y, value, size, color, bold)
weight = 'normal';
if bold, weight = 'bold'; end
h=text(ax, x, y, char(value), 'FontName', 'Microsoft YaHei', ...
    'FontSize', size, 'FontWeight', weight, 'Color', color, ...
    'Interpreter', 'none', 'VerticalAlignment', 'middle');
end

function appendPage(fig, path, page) %#ok<INUSL>
singlePage = fullfile(path,sprintf('page_%04d.pdf',page)); %#ok<NASGU>
% Avoid the native incremental-PDF merger on R2021b.
evalc('exportgraphics(fig, singlePage, ''ContentType'', ''vector'');');
end

function lines = summaryLines(report, bundle, language)
lines = { ...
    ['# ' tr(language, '任务信息', 'Task information')], ...
    pair(language, '软件版本', 'Software version', report.softwareVersion), ...
    pair(language, '生成时间 UTC', 'Generated UTC', char(report.generatedUTC))};
scenario = fieldOr(bundle, 'scenario', []);
if ~isempty(scenario)
    input = fieldOr(scenario, 'scenario', struct);
    lines{end+1} = pair(language, '任务名称', 'Task name', fieldOr(input, 'name', ''));
    lines{end+1} = pair(language, '分析时长', 'Analysis duration', ...
        [number(fieldOr(input, 'durationS', NaN) / 3600, language) ' h']);
    lines{end+1} = pair(language, '时间步长', 'Time step', ...
        [number(fieldOr(input, 'timeStepS', NaN), language) ' s']);
    lines{end+1} = pair(language, '热网络', 'Thermal network', ...
        fieldOr(fieldOr(scenario, 'network', struct), 'name', ''));
end
meta = fieldOr(bundle, 'metadata', struct);
if isstruct(meta) && isfield(meta, 'taskId') && ~isempty(meta.taskId)
    lines{end+1} = pair(language, '任务 ID', 'Task ID', meta.taskId);
end
if isstruct(meta) && isfield(meta, 'calibrationApplied') && meta.calibrationApplied
    lines{end+1} = pair(language, '设备标定', 'Device calibration', ...
        fieldOr(meta, 'calibrationStatus', 'not_recorded'));
end
lines{end+1} = ['# ' tr(language, '本次实际生成', 'Outputs from this run')];
parts = {};
names = {'scenario','sweep','surface','volume'};
zh = {'单场景','参数扫描','表面热仿真','体内导热'};
en = {'scenario','sweep','surface thermal model','volume conduction'};
for k = 1:numel(names)
    if ~isempty(fieldOr(bundle, names{k}, []))
        parts{end+1} = tr(language, zh{k}, en{k}); %#ok<AGROW>
    end
end
[telemetryResult, comparison] = telemetryParts(fieldOr(bundle, 'telemetry', []));
if ~isempty(telemetryResult) && isempty(comparison)
    parts{end+1} = tr(language, '遥测驱动仿真', 'telemetry-driven simulation');
end
if ~isempty(comparison)
    parts{end+1} = tr(language, '遥测对比', 'telemetry comparison');
end
lines{end+1} = strjoin(parts, tr(language, '、', ', '));
if ~isempty(scenario)
    metrics = fieldOr(scenario, 'metrics', struct);
    lines{end+1} = ['# ' tr(language, '主要发现', 'Main findings')];
    lines{end+1} = pair(language, '平均 β 角', 'Mean beta angle', ...
        [number(fieldOr(metrics, 'meanBetaDeg', NaN), language) ' deg']);
    lines{end+1} = pair(language, '入影比例', 'Eclipse fraction', ...
        [number(100 * fieldOr(metrics, 'eclipseFraction', NaN), language) ' %']);
    lines{end+1} = pair(language, '射频节点温度跨度', 'RF temperature span', ...
        [number(fieldOr(metrics, 'rfTemperatureSpanK', NaN), language) ' K']);
    lines{end+1} = pair(language, '半仿真码偏差跨度', 'Semi-synthetic code-bias span', ...
        [number(fieldOr(metrics, 'codeBiasSpanM', NaN), language) ' m']);
    if isfield(metrics, 'forcingToRfLagS')
        harmonic=leotherm.reportHarmonicResponse(scenario);
        if ~isempty(harmonic) && harmonic.available
            lines{end+1}=pair(language,'轨道基频等效相位时延','Orbital-frequency phase delay', ...
                sprintf('%.2f s',harmonic.phaseDelayS));
        else
            phase = leotherm.reportPeakLag(scenario);
            lines{end+1} = leotherm.reportLagExplanation(phase,language);
        end
    end
end
if ~isempty(fieldOr(bundle, 'sweep', []))
    sweep = bundle.sweep;
    if istable(sweep) && ismember('status', sweep.Properties.VariableNames)
        completed = sum(strcmp(string(sweep.status), 'complete'));
        lines{end+1} = pair(language, '扫描有效工况', 'Completed sweep cases', ...
            sprintf('%d / %d', completed, height(sweep)));
    end
end
surface = fieldOr(bundle, 'surface', []);
if ~isempty(surface) && isfield(surface, 'temperatureK')
    lines{end+1} = pair(language, '表面温度范围', 'Surface temperature range', ...
        temperatureRange(surface.temperatureK, language));
end
volume = fieldOr(bundle, 'volume', []);
if ~isempty(volume) && isfield(volume, 'temperatureK')
    lines{end+1} = pair(language, '体网格温度范围', 'Volume temperature range', ...
        temperatureRange(volume.temperatureK, language));
end
closure = report.energy(strcmp(report.energy.quantity, 'maximumEnergyClosureJ'), :);
if ~isempty(closure)
    lines{end+1} = pair(language, '最大能量闭合差', 'Maximum energy closure', ...
        [number(max(abs(closure.value)), language) ' J']);
end
end

function lines = sectionLines(sections, language)
lines = {};
for k = 1:height(sections)
    row = sections(k, :);
    key = char(row.field);
    if ismember(key, {'node_names','simulation_provenance'}), continue; end
    if ismember(key, {'trajectory_frame','telemetry_status'})
        [name, value] = leotherm.reportMetadataText(key, char(row.value), language);
    else
        name = fieldName(key, language);
        value = localValue(key, char(row.value), language);
    end
    unit = char(row.unit);
    status = char(row.status);
    if strcmp(status, 'not_available')
        value = tr(language, '未提供', 'Not available');
    end
    lines{end+1} = sprintf('%s: %s %s', name, value, ...
        unitName(unit, language)); %#ok<AGROW>
end
end

function lines = telemetryLines(values, language)
lines = {tr(language, '仅列出实际完成比较的节点；详细逐样本结果见 CSV 与 MAT。', ...
    'Only compared nodes are listed; sample-level data are in CSV and MAT.')};
for k = 1:height(values)
    row = values(k, :);
    lines{end+1} = sprintf('%s | %s: %d | RMSE: %s K | %s', ... %#ok<AGROW>
        char(row.node), tr(language, '样本', 'samples'), row.used_samples, ...
        number(row.rmse_k, language), ...
        localValue('assessment', char(row.assessment), language)); %#ok<AGROW>
end
end

function lines = acceptanceLines(report, bundle, language)
lines = {['# ' tr(language, '数值与配置验收', 'Numerical and configuration checks')]};
scenario = fieldOr(bundle, 'scenario', []);
if ~isempty(scenario) && isfield(scenario, 'temperatureK')
    valid = ~isempty(scenario.temperatureK) && all(isfinite(scenario.temperatureK(:)));
    lines{end+1} = pair(language, '单场景温度有限值', ...
        'Finite scenario temperatures', passText(valid, language));
end
meta = fieldOr(bundle, 'metadata', struct);
if isstruct(meta) && isfield(meta, 'stages') && ~isempty(meta.stages)
    lines{end+1} = ['# ' tr(language, '任务阶段', 'Task stages')];
    for k = 1:numel(meta.stages)
        lines{end+1} = sprintf('%s: %s', ...
            pipelineStageText(meta.stages(k).name, language), ...
            pipelineStageText(meta.stages(k).status, language)); %#ok<AGROW>
    end
end

names = {'scenarioStale','sweepStale','meshStale','volumeStale','coupledStale'};
sources = {'scenario','sweep','surface','volume','coupled'};
labelsZh = {'单场景与当前输入','扫描与当前输入','表面结果与当前输入', ...
    '体网格结果与当前输入','耦合结果与当前输入'};
labelsEn = {'Scenario versus current inputs','Sweep versus current inputs', ...
    'Surface versus current inputs','Volume versus current inputs', ...
    'Coupled result versus current inputs'};
for k = 1:numel(names)
    present = ~isempty(fieldOr(bundle, sources{k}, []));
    if strcmp(sources{k}, 'coupled')
        present = isstruct(meta) && isfield(meta, 'coupledPresent') ...
            && meta.coupledPresent;
    end
    if present && isstruct(meta) && isfield(meta, names{k})
        lines{end+1} = pair(language, labelsZh{k}, labelsEn{k}, ...
            staleText(meta.(names{k}), language)); %#ok<AGROW>
    end
end
[~, comparison] = telemetryParts(fieldOr(bundle, 'telemetry', []));
if isempty(comparison)
    row = report.sections(strcmp(report.sections.field, 'telemetry_status'), :);
    if ~isempty(row)
        [label, value] = leotherm.reportMetadataText('telemetry_status', char(row.value(1)), language);
        lines{end+1} = sprintf('%s: %s', label, value);
    end
else
    lines{end+1} = pair(language, '遥测比较独立性', ...
        'Telemetry comparison independence', ...
        localValue('independence', fieldOr(comparison, 'independence', ...
        tr(language, '未记录', 'Not recorded')), language));
    lines{end+1} = tr(language, '遥测误差与样本数见上一页；阈值由用户自行设定。', ...
        'Telemetry errors and sample counts are on the preceding page; user criteria apply.');
end
lines{end+1} = ['# ' tr(language, '本次评估范围', 'Assessment scope')];
lines{end+1} = tr(language, '本报告评估所配置热网络的仿真结果及数值检查；设备温限符合性不在本次评估范围内。', ...
    'This report evaluates the configured thermal simulation and numerical checks. Device temperature-limit compliance is outside this assessment.');
lines{end+1} = ['# ' tr(language, '复核文件', 'Audit files')];
lines{end+1} = tr(language, '同目录提供原始结果 MAT、指标 CSV、Markdown、清单和图像。', ...
    'MAT results, metric CSV, Markdown, manifest, and figures accompany this PDF.');
lines{end+1} = pair(language, '软件版本', 'Software version', report.softwareVersion);
end

function value = pipelineStageText(key, language)
key = char(key);
if strcmp(language, 'en'), value = strrep(key, '_', ' '); return; end
switch key
    case 'snapshot', value = '输入快照';
    case 'calibration', value = '设备标定';
    case 'freeze_model', value = '冻结模型';
    case 'nodal_simulation', value = '节点热仿真';
    case 'batch_simulation', value = '参数扫描';
    case 'geometry_simulation', value = '三维几何仿真';
    case 'telemetry_comparison', value = '遥测对比';
    case 'numerical_acceptance', value = '数值与数据验收';
    case 'report', value = '报告生成';
    case 'complete', value = '完成';
    case 'skipped', value = '跳过';
    case 'failed', value = '失败';
    otherwise, value = key;
end
end

function name = fieldName(key, language)
keys = {'scenario_name','duration','time_step','warmup_orbits','node_count', ...
    'node_names','conductance_range','internal_power_range','face_count', ...
    'total_area','view_factor_source','thermal_parameter_provenance', ...
    'radiation_history','tetrahedron_count','formulation','conductivity_range', ...
    'density_range','specific_heat_range','epoch_start_utc','altitude', ...
    'inclination','attitude_mode','trajectory_frame','input_kind', ...
    'boundary_matching','matched_boundary_faces','maximum_absolute_closure', ...
    'contact_pair_count','status','independence','conclusion','source', ...
    'simulation_provenance'};
zh = {'场景名称','分析时长','时间步长','固定预热配置（非收敛模式）','节点数','节点名称', ...
    '导热系数范围','内部功耗范围','面片数','总面积','视因子来源', ...
    '热参数来源','辐射时序','四面体数','求解形式','导热率范围', ...
    '密度范围','比热范围','开始历元 UTC','轨道高度','轨道倾角', ...
    '姿态模式','轨道坐标系','耦合输入类型','边界匹配方式', ...
    '匹配边界面数','最大热流闭合差','接触对数','状态','独立性', ...
    '结论','数据来源','仿真来源'};
en = {'Scenario name','Duration','Time step','Fixed warmup setting (non-convergence mode)','Node count', ...
    'Node names','Conductance range','Internal power range','Face count', ...
    'Total area','View-factor source','Thermal parameter source', ...
    'Radiation history','Tetrahedron count','Formulation','Conductivity range', ...
    'Density range','Specific heat range','Start epoch UTC','Altitude', ...
    'Inclination','Attitude mode','Trajectory frame','Coupling input kind', ...
    'Boundary matching','Matched boundary faces','Maximum heat-flow closure', ...
    'Contact pair count','Status','Independence','Conclusion','Data source', ...
    'Simulation provenance'};
index = find(strcmp(keys, key), 1);
if isempty(index), name = key; else, name = tr(language, zh{index}, en{index}); end
end

function value = localValue(key, value, language)
value = char(string(value));
if strcmp(language, 'en'), return; end
if strcmp(key, 'conclusion')
    value = '这是观测对比，不单独证明模型的物理正确性。';
    return
end
codes = {'nadir','sun_pointing','inertial','simulation_only', ...
    'comparison_only','insufficient_samples','within_user_rmse_limit', ...
    'outside_user_rmse_limit', ...
    'not_established_user_must_confirm_held_out_data', ...
    'conditioned_on_measured_initial_state', ...
    'synthetic_not_independent_validation', ...
    'conditioned_on_prescribed_boundary_not_whole_spacecraft_validation'};
labels = {'对地定向','对日定向','惯性固定','仅仿真，未进行遥测对比', ...
    '仅完成对比','有效样本不足','满足用户设定的 RMSE 上限', ...
    '超过用户设定的 RMSE 上限','独立性未建立，需确认留出数据', ...
    '使用实测初温的条件验证','合成演示数据，非独立在轨验证', ...
    '依赖实测边界，非整星独立验证'};
index = find(strcmp(codes, value), 1);
if ~isempty(index), value = labels{index}; end
end

function value = passText(ok, language)
if ok, value = tr(language, '通过', 'Pass');
else, value = tr(language, '不通过', 'Fail'); end
end

function value = staleText(stale, language)
if stale, value = tr(language, '已过期，需要重新运行', 'Stale; rerun required');
else, value = tr(language, '一致', 'Current'); end
end

function value = pair(language, zh, en, content)
value = [tr(language, zh, en) '：' char(string(content))];
if strcmp(language, 'en')
    value = [en ': ' char(string(content))];
end
end

function value = number(input, language)
if isnumeric(input) && isscalar(input) && isfinite(input)
    value = sprintf('%.4g', input);
else
    value = tr(language, '未提供', 'Not available');
end
end

function value = temperatureRange(temperatureK, language)
values = temperatureK(isfinite(temperatureK));
if isempty(values)
    value = tr(language, '未提供', 'Not available');
else
    value = sprintf('%.2f - %.2f K', min(values), max(values));
end
end

function value = unitName(unit, language)
value = unit;
if strcmp(language, 'en'), return; end
switch unit
    case 'orbit', value = '圈';
    case 'node', value = '个';
    case 'face', value = '个';
    case 'tetrahedron', value = '个';
    case 'deg', value = '度';
    case 'pair', value = '对';
end
end

function lines = wrapText(value, width)
% Preserve full text; use double-width accounting for CJK characters.
value = strrep(char(value), newline, ' '); lines = {};
while ~isempty(value)
    weights = 1+double(value > 255);
    last = find(cumsum(weights) <= width,1,'last');
    if isempty(last), last = 1; end
    if last < numel(value)
        if ~any(value(1:last)>255)
            space = find(value(1:last)==' ',1,'last');
            if ~isempty(space) && space > last/2, last = space; end
        elseif value(last)<=255 && value(last+1)<=255 && ...
                ~isspace(value(last)) && ~isspace(value(last+1))
            % Mixed Chinese text may break at CJK boundaries, not only spaces.
            boundary=find(value(1:last)>255 | isspace(value(1:last)),1,'last');
            if ~isempty(boundary), last=boundary; end
        end
        % Keep closing punctuation with the preceding character.
        while last>1 && any(value(last+1)=='，。；：！？、）》】,.!?;:')
            last=last-1;
        end
    end
    lines{end+1} = strtrim(value(1:last)); %#ok<AGROW>
    value = strtrim(value(last+1:end));
end
if isempty(lines), lines = {''}; end
end

function value = tr(language, chinese, english)
if strcmp(language, 'zh'), value = chinese; else, value = english; end
end

function value = fieldOr(source, name, fallback)
value = fallback;
if isstruct(source) && isfield(source, name), value = source.(name); end
end

function [result, comparison] = telemetryParts(state)
result = []; comparison = [];
if ~isstruct(state), return; end
if isfield(state, 'result'), result = state.result; end
if isfield(state, 'report'), comparison = state.report; end
end
