function report = writeThermalReport(input, outputDirectory, language)
%WRITETHERMALREPORT Write one unified, traceable thermal-results report.
%   REPORT = WRITETHERMALREPORT(INPUT, OUTPUTDIRECTORY, LANGUAGE) accepts a
%   scenario result directly or a bundle with scenarioResult,
%   surfaceResult, volumeResult, sweep and telemetry fields.  Existing
%   component exporters are intentionally not called, so this API can be
%   added to established workflows without changing their files.
%
%   LANGUAGE is 'zh', 'en', or 'both' (default).  Machine-readable files use
%   stable English keys; Markdown and display-label columns are bilingual.

if nargin < 2 || isempty(outputDirectory)
    error('leotherm:ReportExport', 'An output directory is required.');
end
if nargin < 3 || isempty(language), language = 'both'; end
languages = reportLanguages(language);
bundle = normalizeBundle(input);
if isempty(bundle.scenario) && isempty(bundle.surface) && isempty(bundle.volume) ...
        && isempty(bundle.sweep) && isempty(bundle.telemetry)
    error('leotherm:ReportExport', 'No thermal result was supplied.');
end
if isfolder(outputDirectory)
    listing = dir(outputDirectory);
    if any(~ismember({listing.name}, {'.','..'}))
        error('leotherm:ReportExport', ...
            'Use a new or empty directory; existing report files are not overwritten.');
    end
else
    [ok, message] = mkdir(outputDirectory);
    if ~ok, error('leotherm:ReportExport', 'Cannot create report directory: %s', message); end
end

report = collectReport(bundle);
report.softwareVersion = leotherm.version;
report.generatedUTC = datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX');
report.languages = languages;
report.metadata = bundle.metadata;

writeSectionCsv(report, outputDirectory);
writeEnergyCsv(report, outputDirectory);
writeDiagnosticsCsv(report, outputDirectory);
writeTelemetryCsv(report, outputDirectory);
writeManifest(report, bundle, outputDirectory);

for k = 1:numel(languages)
    lang = languages{k};
    if ~isempty(bundle.scenario)
        try
            leotherm.plotScenario(bundle.scenario, ...
                fullfile(outputDirectory, ['scenario_summary_' lang '.png']), lang);
        catch exception
            report.warnings = appendWarning(report.warnings, ...
                ['scenario figure unavailable: ' exception.message]);
        end
    end
    if ~isempty(bundle.sweep)
        try
            leotherm.plotSweep(bundle.sweep, ...
                fullfile(outputDirectory, ['sweep_summary_' lang '.png']), lang);
        catch exception
            report.warnings = appendWarning(report.warnings, ...
                ['sweep figure unavailable: ' exception.message]);
        end
    end
end
for k = 1:numel(languages)
    lang = languages{k};
    leotherm.writeThermalPdfReport(report, bundle, ...
        fullfile(outputDirectory, ['thermal_report_' lang '.pdf']), lang, outputDirectory);
    writeMarkdown(report, fullfile(outputDirectory, ['thermal_report_' lang '.md']), lang);
end
% Preserve the exact source structs and final warnings for later re-rendering.
save(fullfile(outputDirectory, 'thermal_report_data.mat'), 'bundle', 'report', '-v7.3');
writeManifest(report, bundle, outputDirectory);
end

function languages = reportLanguages(value)
value = lower(char(string(value)));
switch value
    case {'zh','中文'}, languages = {'zh'};
    case {'en','english'}, languages = {'en'};
    case {'both','bilingual','中英'}, languages = {'zh','en'};
    otherwise, error('leotherm:InvalidLanguage', 'Language must be zh, en, or both.');
end
end

function bundle = normalizeBundle(input)
bundle = struct('scenario', [], 'surface', [], 'volume', [], 'sweep', [], ...
    'sweepContext', [], 'telemetry', [], 'metadata', []);
if ~isstruct(input) || ~isscalar(input)
    error('leotherm:ReportExport', 'Input must be a scalar result or bundle structure.');
end
if isfield(input, 'timeS') && isfield(input, 'temperatureK') && isfield(input, 'network')
    bundle.scenario = input;
end
% Coupled surface-volume results carry the scenario at the top level while
% their thermal states live under surface and volume. Preserve that context
% in the report rather than forcing users to build a second bundle manually.
if isempty(bundle.scenario) && isfield(input, 'scenario') && ...
        isstruct(input.scenario) && isscalar(input.scenario)
    bundle.scenario = input;
end
aliases = struct('scenario', {{'scenario','scenarioResult','result'}}, ...
    'surface', {{'surface','surfaceResult','meshResult','currentMeshResult'}}, ...
    'volume', {{'volume','volumeResult','currentVolumeResult'}}, ...
    'sweep', {{'sweep','summary','currentSweep'}}, ...
    'sweepContext', {{'sweepContext','context'}}, ...
    'telemetry', {{'telemetry','telemetryState'}}, ...
    'metadata', {{'metadata','reportMetadata'}});
names = fieldnames(aliases);
for i = 1:numel(names)
    if ~isempty(bundle.(names{i})), continue; end
    candidates = aliases.(names{i});
    for j = 1:numel(candidates)
        if isfield(input, candidates{j}) && ~isempty(input.(candidates{j}))
            bundle.(names{i}) = input.(candidates{j}); break;
        end
    end
end
% A TelemetryPanel state is already a suitable telemetry bundle.
if isstruct(bundle.telemetry) && isfield(bundle.telemetry, 'result')
    % leave state intact; collectReport understands result/report/data.
end
end

function report = collectReport(bundle)
report = struct('sections', [], 'energy', [], 'diagnostics', [], ...
    'telemetry', [], 'sources', [], 'warnings', {cell(0,1)});
rows = cell(0, 7);
rows = addScenarioRows(rows, bundle.scenario);
rows = addSurfaceRows(rows, bundle.surface);
rows = addVolumeRows(rows, bundle.volume);
rows = addOrbitRows(rows, bundle.scenario);
rows = addCouplingRows(rows, bundle);
rows = addTelemetryRows(rows, bundle.telemetry);
report.sections = cell2table(rows, 'VariableNames', ...
    {'section','field','value','unit','status','source','notes'});
report.energy = energyRows(bundle);
report.diagnostics = diagnosticsRows(bundle);
report.telemetry = telemetryRows(bundle.telemetry);
report.sources = sourceRows(bundle);
end

function rows = addScenarioRows(rows, result)
if isempty(result), return; end
scenario = fieldOr(result, 'scenario', struct);
rows = addRow(rows, 'task_input', 'scenario_name', fieldOr(scenario,'name',''), '', 'available', 'scenario.name', '');
rows = addRow(rows, 'task_input', 'duration', fieldOr(scenario,'durationS',NaN), 's', statusFor(scenario,'durationS'), 'scenario.durationS', '');
rows = addRow(rows, 'task_input', 'time_step', fieldOr(scenario,'timeStepS',NaN), 's', statusFor(scenario,'timeStepS'), 'scenario.timeStepS', '');
rows = addRow(rows, 'task_input', 'warmup_orbits', fieldOr(scenario,'warmupOrbits',NaN), 'orbit', statusFor(scenario,'warmupOrbits'), 'scenario.warmupOrbits', '');
network = fieldOr(result, 'network', struct);
rows = addRow(rows, 'network', 'node_count', numel(fieldOr(network,'nodeNames',{})), 'node', 'available', 'network.nodeNames', '');
rows = addRow(rows, 'network', 'node_names', strjoin(cellstr(string(fieldOr(network,'nodeNames',{}))), ', '), '', 'available', 'network.nodeNames', '');
if isfield(network, 'conductanceWK')
    rows = addRow(rows, 'network', 'conductance_range', rangeText(network.conductanceWK), 'W/K', 'available', 'network.conductanceWK', '');
end
if isfield(network, 'internalPowerW')
    rows = addRow(rows, 'network', 'internal_power_range', rangeText(network.internalPowerW), 'W', 'available', 'network.internalPowerW', '');
end
end

function rows = addSurfaceRows(rows, result)
if isempty(result), return; end
mesh = fieldOr(result, 'mesh', struct); n = size(fieldOr(mesh,'faces',zeros(0,3)),1);
rows = addRow(rows, 'surface_mesh', 'face_count', n, 'face', 'available', 'surface.mesh.faces', '');
rows = addRow(rows, 'surface_mesh', 'total_area', fieldOr(mesh,'totalAreaM2',sum(fieldOr(mesh,'faceAreasM2',[]))), 'm^2', statusFor(mesh,'faceAreasM2'), 'surface.mesh.faceAreasM2', '');
rows = addRow(rows, 'surface_radiation', 'view_factor_source', ...
    fieldOr(fieldOr(result,'numerics',struct),'viewFactorDiagnostics',struct('method','not_recorded')).method, '', ...
    'available', 'surface.numerics.viewFactorDiagnostics', '');
rows = addRow(rows, 'surface_radiation', 'thermal_parameter_provenance', ...
    fieldOr(mesh,'thermalParameterProvenance','not_declared'), '', 'available', ...
    'surface.mesh.thermalParameterProvenance', '');
if isfield(result,'directSolarW') || isfield(result,'eclipseVisibleFraction')
    rows = addRow(rows, 'surface_radiation', 'radiation_history', 'stored', '', 'available', 'surface result fields', '');
end
end

function rows = addVolumeRows(rows, result)
if isempty(result), return; end
mesh = fieldOr(result, 'mesh', struct); model = fieldOr(result, 'model', struct);
rows = addRow(rows, 'volume_mesh', 'node_count', size(fieldOr(mesh,'nodesM',zeros(0,3)),1), 'node', 'available', 'volume.mesh.nodesM', '');
rows = addRow(rows, 'volume_mesh', 'tetrahedron_count', size(fieldOr(mesh,'tetrahedra',zeros(0,4)),1), 'tetrahedron', 'available', 'volume.mesh.tetrahedra', '');
rows = addRow(rows, 'volume_conduction', 'formulation', fieldOr(model,'formulation','not_recorded'), '', statusFor(model,'formulation'), 'volume.model.formulation', '');
rows = addRow(rows, 'volume_conduction', 'conductivity_range', rangeText(fieldOr(model,'elementConductivityWmK',[])), 'W/(m K)', statusFor(model,'elementConductivityWmK'), 'volume.model.elementConductivityWmK', '');
rows = addRow(rows, 'volume_conduction', 'density_range', rangeText(fieldOr(model,'elementDensityKgM3',[])), 'kg/m^3', statusFor(model,'elementDensityKgM3'), 'volume.model.elementDensityKgM3', '');
rows = addRow(rows, 'volume_conduction', 'specific_heat_range', rangeText(fieldOr(model,'elementSpecificHeatJkgK',[])), 'J/(kg K)', statusFor(model,'elementSpecificHeatJkgK'), 'volume.model.elementSpecificHeatJkgK', '');
end

function rows = addOrbitRows(rows, result)
if isempty(result), return; end
scenario = fieldOr(result,'scenario',struct); orbit = fieldOr(result,'orbit',struct); attitude = fieldOr(scenario,'attitude',struct);
rows = addRow(rows, 'orbit_attitude', 'epoch_start_utc', formatValue(fieldOr(scenario,'startEpoch','')), '', statusFor(scenario,'startEpoch'), 'scenario.startEpoch', '');
rows = addRow(rows, 'orbit_attitude', 'altitude', fieldOr(fieldOr(scenario,'orbit',struct),'altitudeM',NaN), 'm', statusFor(fieldOr(scenario,'orbit',struct),'altitudeM'), 'scenario.orbit.altitudeM', '');
rows = addRow(rows, 'orbit_attitude', 'inclination', fieldOr(fieldOr(scenario,'orbit',struct),'inclinationDeg',NaN), 'deg', statusFor(fieldOr(scenario,'orbit',struct),'inclinationDeg'), 'scenario.orbit.inclinationDeg', '');
rows = addRow(rows, 'orbit_attitude', 'attitude_mode', fieldOr(attitude,'mode','not_recorded'), '', statusFor(attitude,'mode'), 'scenario.attitude.mode', '');
rows = addRow(rows, 'orbit_attitude', 'trajectory_frame', fieldOr(fieldOr(orbit,'frame',struct),'name','not_recorded'), '', 'not_available', 'result.orbit/frame', 'Frame labels are not present in all result producers.');
end

function rows = addCouplingRows(rows, bundle)
result = bundle.volume;
if isempty(result), return; end
coupling = [];
if isstruct(result) && isfield(result, 'couplingDiagnostics')
    coupling = result.couplingDiagnostics;
elseif isstruct(bundle.surface) && isfield(bundle.surface, 'couplingDiagnostics')
    coupling = bundle.surface.couplingDiagnostics;
end
if isempty(coupling), return; end
rows = addRow(rows, 'surface_volume_coupling', 'input_kind', ...
    fieldOr(coupling, 'inputKind', 'not_recorded'), '', ...
    statusFor(coupling, 'inputKind'), 'coupling.inputKind', '');
rows = addRow(rows, 'surface_volume_coupling', 'boundary_matching', ...
    fieldOr(coupling, 'method', 'not_recorded'), '', ...
    statusFor(coupling, 'method'), 'coupling.method', '');
rows = addRow(rows, 'surface_volume_coupling', 'matched_boundary_faces', ...
    fieldOr(coupling, 'matchedBoundaryFaceCount', NaN), 'face', ...
    statusFor(coupling, 'matchedBoundaryFaceCount'), 'coupling.matchedBoundaryFaceCount', '');
rows = addRow(rows, 'surface_volume_coupling', 'maximum_absolute_closure', ...
    fieldOr(coupling, 'maximumAbsoluteClosureW', NaN), 'W', ...
    statusFor(coupling, 'maximumAbsoluteClosureW'), 'coupling.maximumAbsoluteClosureW', '');
if isstruct(bundle.volume) && isfield(bundle.volume, 'contactDiagnostics')
    contact = bundle.volume.contactDiagnostics;
    rows = addRow(rows, 'surface_volume_coupling', 'contact_pair_count', ...
        fieldOr(contact, 'pairCount', NaN), 'pair', statusFor(contact, 'pairCount'), ...
        'volume.contactDiagnostics.pairCount', '');
end
end

function rows = addTelemetryRows(rows, state)
[result, comparison, data] = telemetryParts(state);
if isempty(result) && isempty(comparison) && isempty(data)
    rows = addRow(rows, 'telemetry_comparison', 'status', 'not_available', '', 'not_available', '', ...
        'No telemetry result was supplied; validation was not performed.');
    return
end
if isempty(comparison)
    rows = addRow(rows, 'telemetry_comparison', 'status', 'simulation_only', '', 'not_available', '', ...
        'Telemetry input exists but no comparison report is available.');
else
    rows = addRow(rows, 'telemetry_comparison', 'independence', fieldOr(comparison,'independence','not_recorded'), '', 'available', 'telemetry.report.independence', '');
    rows = addRow(rows, 'telemetry_comparison', 'conclusion', fieldOr(comparison,'conclusion',''), '', 'available', 'telemetry.report.conclusion', '');
end
if ~isempty(data), rows = addRow(rows, 'telemetry_comparison', 'source', fieldOr(data,'source',''), '', 'available', 'telemetry.data.source', ''); end
if ~isempty(result) && isfield(result,'provenance')
    rows = addRow(rows, 'telemetry_comparison', 'simulation_provenance', formatValue(result.provenance), '', 'available', 'telemetry.result.provenance', '');
end
end

function rows = energyRows(bundle)
rows = table(strings(0,1), strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'component','quantity','value','unit','status'});
rows = addEnergy(rows, 'scenario', fieldOr(bundle.scenario,'numerics',struct), ...
    {'integratedExternalHeatJ','integratedInternalHeatJ','integratedRadiatedHeatJ','integratedBoundaryHeatJ','integratedNetHeatJ','maximumEnergyClosureJ'}, 'J');
rows = addEnergy(rows, 'surface', fieldOr(bundle.surface,'numerics',struct), ...
    {'integratedExternalHeatJ','maximumEnergyClosureJ'}, 'J');
rows = addEnergy(rows, 'volume', fieldOr(bundle.volume,'diagnostics',struct), ...
    {'integratedNodalPowerJ'}, 'J');
end

function rows = addEnergy(rows, component, source, names, unit)
for k = 1:numel(names)
    name = names{k};
    if isstruct(source) && isfield(source,name)
        value = source.(name); if isempty(value), continue; end
        if ~isscalar(value), value = value(end); end
        rows = [rows; {component,name,double(value),unit,'available'}]; %#ok<AGROW>
    end
end
if strcmp(component,'volume') && isstruct(source) && isfield(source,'maximumLinearResidual')
    rows(end+1,:) = {component,'maximum_linear_residual',double(source.maximumLinearResidual),'solver units','diagnostic_only'};
end
end

function rows = diagnosticsRows(bundle)
rows = table(strings(0,1), strings(0,1), strings(0,1), strings(0,1), ...
    'VariableNames', {'component','name','value','status'});
items = {'scenario',bundle.scenario,'surface',bundle.surface,'volume',bundle.volume};
for i = 1:2:numel(items)
    component = items{i}; result = items{i+1}; if isempty(result), continue; end
    source = fieldOr(result,'numerics',fieldOr(result,'diagnostics',struct));
    if ~isstruct(source), continue; end
    names = fieldnames(source);
    for k = 1:numel(names)
        value = source.(names{k});
        if isstruct(value) || istable(value) || ~isscalar(value) || ischar(value) || isstring(value), continue; end
        if isnumeric(value) || islogical(value)
            rows = [rows; {component,names{k},formatValue(value),'available'}]; %#ok<AGROW>
        end
    end
end
end

function rows = telemetryRows(state)
[~, comparison, ~] = telemetryParts(state);
rows = table(strings(0,1), zeros(0,1), zeros(0,1), strings(0,1), ...
    'VariableNames', {'node','used_samples','rmse_k','assessment'});
if isempty(comparison) || ~isfield(comparison,'metrics') || ~istable(comparison.metrics), return; end
m = comparison.metrics;
for k = 1:height(m)
    rows = [rows; {string(m.node(k)), double(m.used_samples(k)), double(m.rmse_k(k)), string(m.assessment(k))}]; %#ok<AGROW>
end
end

function rows = sourceRows(bundle)
rows = table(strings(0,1), strings(0,1), strings(0,1), 'VariableNames', {'component','source','status'});
rows = addSource(rows,'software',leotherm.version,'available');
if ~isempty(bundle.scenario), rows = addSource(rows,'scenario',fieldOr(fieldOr(bundle.scenario,'scenario',struct),'name','embedded result'),'available'); end
if ~isempty(bundle.surface), rows = addSource(rows,'surface_mesh',fieldOr(fieldOr(bundle.surface,'mesh',struct),'sourcePath','embedded mesh'),'available'); end
if ~isempty(bundle.volume), rows = addSource(rows,'volume_mesh',fieldOr(fieldOr(bundle.volume,'model',struct),'meshSourcePath',fieldOr(fieldOr(bundle.volume,'mesh',struct),'sourcePath','embedded mesh')),'available'); end
[~,~,data] = telemetryParts(bundle.telemetry);
if ~isempty(data), rows = addSource(rows,'telemetry',fieldOr(data,'source','embedded data'),'available'); end
end

function rows = addSource(rows, component, source, status)
rows(end+1,:) = {string(component),string(formatValue(source)),string(status)};
end

function rows = addRow(rows, section, field, value, unit, status, source, notes)
rows(end+1,:) = {section, field, formatValue(value), unit, status, source, notes};
end

function value = fieldOr(s, name, fallback)
value = fallback;
if isstruct(s) && isfield(s,name), value = s.(name); end
end

function status = statusFor(s, name)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name)), status = 'available'; else, status = 'not_available'; end
end

function text = rangeText(value)
if isempty(value) || ~isnumeric(value), text = 'not_available'; return; end
value = value(isfinite(value)); if isempty(value), text = 'not_available'; return; end
text = sprintf('[%.6g, %.6g]', min(value(:)), max(value(:)));
end

function text = formatValue(value)
if ischar(value), text = value; return; end
if isstring(value), text = char(strjoin(value, ', ')); return; end
if isdatetime(value), text = char(string(value)); return; end
if isnumeric(value) || islogical(value)
    if isempty(value), text = ''; elseif isscalar(value), text = sprintf('%.12g', double(value)); else, text = mat2str(value); end
    return
end
if isstruct(value)
    try
        text = char(jsonencode(value));
    catch
        text = '<struct>';
    end
else
    text = char(string(value));
end
end

function [result, comparison, data] = telemetryParts(state)
result = []; comparison = []; data = [];
if isempty(state), return; end
if isstruct(state) && isfield(state,'result'), result = state.result; else, result = state; end
if isstruct(state) && isfield(state,'report'), comparison = state.report; end
if isstruct(state) && isfield(state,'data'), data = state.data; end
end

function writeSectionCsv(report, directory)
writetable(report.sections, fullfile(directory, 'thermal_sections.csv'));
end
function writeEnergyCsv(report, directory)
writetable(report.energy, fullfile(directory, 'thermal_energy.csv'));
end
function writeDiagnosticsCsv(report, directory)
writetable(report.diagnostics, fullfile(directory, 'thermal_diagnostics.csv'));
end
function writeTelemetryCsv(report, directory)
writetable(report.telemetry, fullfile(directory, 'thermal_telemetry.csv'));
end

function writeManifest(report, bundle, directory)
[~, comparison] = telemetryParts(bundle.telemetry);
manifest = struct('schemaVersion','1.0','softwareVersion',report.softwareVersion, ...
    'generatedUTC',char(report.generatedUTC),'languages',{report.languages}, ...
    'sections',{unique(cellstr(report.sections.section))}, ...
    'telemetryValidation',~isempty(comparison), ...
    'pdfReports',{cellfun(@(lang) ['thermal_report_' lang '.pdf'], ...
        report.languages, 'UniformOutput', false)}, ...
    'sourceFiles',{table2struct(report.sources)}, ...
    'metadata', report.metadata);
if ~isempty(report.warnings), manifest.warnings = report.warnings; else, manifest.warnings = {}; end
fid = fopen(fullfile(directory, 'thermal_manifest.json'), 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:ReportExport', 'Cannot write thermal_manifest.json.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(manifest, 'PrettyPrint', true));
end

function writeMarkdown(report, path, language)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:ReportExport', 'Cannot write report Markdown.'); end
cleanup = onCleanup(@() fclose(fid));
zh = strcmp(language,'zh');
put(fid, pick(zh,'# 热仿真结果报告','# Thermal simulation results report'));
put(fid, sprintf(pick(zh,'软件版本：%s；生成时间（UTC）：%s','Software version: %s; generated UTC: %s'), ...
    report.softwareVersion, char(report.generatedUTC)));
put(fid, pick(zh, '## 输入、网格、材料与轨道姿态', '## Inputs, mesh, material, orbit and attitude'));
put(fid, pick(zh, '| 类别 | 字段 | 数值 | 单位 | 状态 | 来源 | 备注 |', '| Section | Field | Value | Unit | Status | Source | Notes |'));
put(fid, '|---|---|---|---|---|---|---|');
for k = 1:height(report.sections)
    r = report.sections(k,:);
    put(fid, sprintf('| %s | %s | %s | %s | %s | %s | %s |', ...
        textCell(r.section), textCell(r.field), textCell(r.value), textCell(r.unit), ...
        textCell(r.status), textCell(r.source), textCell(r.notes)));
end
put(fid, pick(zh,'## 能量守恒','## Energy conservation'));
put(fid, pick(zh,'| 组件 | 量 | 数值 | 单位 | 状态 |','| Component | Quantity | Value | Unit | Status |'));
put(fid, '|---|---|---:|---|---|');
for k = 1:height(report.energy)
    r = report.energy(k,:); put(fid, sprintf('| %s | %s | %.12g | %s | %s |', ...
        textCell(r.component), textCell(r.quantity), r.value, textCell(r.unit), textCell(r.status)));
end
put(fid, pick(zh,'## 数值诊断','## Numerical diagnostics'));
for k = 1:height(report.diagnostics)
    r = report.diagnostics(k,:); put(fid, sprintf('- `%s.%s` = %s (%s)', ...
        textCell(r.component), textCell(r.name), textCell(r.value), textCell(r.status)));
end
put(fid, pick(zh,'## 遥测对比','## Telemetry comparison'));
if isempty(report.telemetry)
    put(fid, pick(zh,'未提供遥测对比结果；未执行遥测验证。','No telemetry comparison was supplied; telemetry validation was not performed.'));
else
    put(fid, pick(zh,'| 节点 | 有效样本 | RMSE（K） | 评价 |','| Node | Used samples | RMSE (K) | Assessment |'));
    put(fid, '|---|---:|---:|---|');
    for k = 1:height(report.telemetry)
        r = report.telemetry(k,:); put(fid, sprintf('| %s | %d | %.12g | %s |', ...
            textCell(r.node), r.used_samples, r.rmse_k, textCell(r.assessment)));
    end
end
put(fid, pick(zh,'## 来源与结论边界','## Sources and interpretation boundary'));
for k = 1:height(report.sources)
    r = report.sources(k,:); put(fid, sprintf('- `%s`: %s (%s)', ...
        textCell(r.component), textCell(r.source), textCell(r.status)));
end
put(fid, pick(zh, ['缺失的模块明确标记为 not_available；本报告不从缺失输入推断接触界面、材料或遥测结论。' ...
    '遥测对比若不存在，仅表示仿真结果，不能宣称完成独立验证。'], ...
    ['Missing modules are marked not_available; this report does not infer contact interfaces, materials, or telemetry conclusions. ' ...
    'Without telemetry comparison, the output is simulation-only and must not be described as independent validation.']));
if ~isempty(report.warnings)
    put(fid, pick(zh,'### 导出警告','### Export warnings'));
    for k = 1:numel(report.warnings), put(fid, ['- ' report.warnings{k}]); end
end
end

function put(fid, text)
fprintf(fid, '%s\n', text);
end
function value = pick(zh, chinese, english)
if zh, value = chinese; else, value = english; end
end

function value = textCell(value)
if iscell(value), value = value{1}; end
if isstring(value), value = char(value); end
if ischar(value), return; end
value = formatValue(value);
end

function warnings = appendWarning(warnings, message)
warnings = [warnings(:); {message}];
end
