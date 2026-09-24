function report = writeThermalSimulationReport(input, outputDirectory, language)
%WRITETHERMALSIMULATIONREPORT Write an auditable external-solver report.
%   INPUT may contain adapter, externalRun, thermalResult, validation and
%   notes. The report never labels exchange success as physical validation.

if nargin < 2 || isempty(outputDirectory)
    error('leotherm:ReportExport', 'An output directory is required.');
end
if nargin < 3 || isempty(language), language = 'both'; end
languages = languagesFor(language);
if ~isstruct(input) || ~isscalar(input)
    error('leotherm:ReportExport', 'Input must be a scalar report bundle.');
end
if isfolder(outputDirectory)
    listing = dir(outputDirectory);
    if any(~ismember({listing.name}, {'.','..'}))
        error('leotherm:ReportExport', 'Report output directory must be new or empty.');
    end
else
    [ok, message] = mkdir(outputDirectory);
    if ~ok, error('leotherm:ReportExport', 'Cannot create report directory: %s', message); end
end
report = struct('schema', 'leotherm.thermal_simulation_report.v1', ...
    'softwareVersion', leotherm.version, ...
    'generatedUTC', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'languages', {languages}, 'adapter', fieldOr(input, 'adapter', struct), ...
    'externalRun', fieldOr(input, 'externalRun', struct), ...
    'validation', fieldOr(input, 'validation', struct), ...
    'physicalValidationEstablished', false, ...
    'warnings', {{'Exchange and numerical consistency do not establish physical validation.'}});
save(fullfile(outputDirectory, 'thermal_simulation_report_data.mat'), 'input', 'report', '-v7.3');
metrics = metricTable(report);
writetable(metrics, fullfile(outputDirectory, 'thermal_simulation_metrics.csv'));
for k = 1:numel(languages)
    path = fullfile(outputDirectory, ['thermal_simulation_report_' languages{k} '.md']);
    writeMarkdown(report, path, languages{k}, metrics);
end
if isfield(input, 'thermalResult') && ~isempty(input.thermalResult)
    thermalDir = fullfile(outputDirectory, 'thermal_result');
    leotherm.writeThermalReport(input.thermalResult, thermalDir, language);
end
writeManifest(outputDirectory, report);
end

function values = languagesFor(value)
value = lower(char(string(value)));
switch value
    case {'zh','中文'}, values = {'zh'};
    case {'en','english'}, values = {'en'};
    case {'both','bilingual','中英'}, values = {'zh','en'};
    otherwise, error('leotherm:InvalidLanguage', 'Language must be zh, en, or both.');
end
end

function tableOut = metricTable(report)
run = report.externalRun;
adapter = report.adapter;
rows = { ...
    'software_version', report.softwareVersion, '', 'available'; ...
    'adapter_id', fieldText(adapter, 'id', 'not_recorded'), '', statusOf(adapter, 'id'); ...
    'adapter_version', fieldText(adapter, 'version', 'not_recorded'), '', statusOf(adapter, 'version'); ...
    'solver_exit_code', fieldValue(run, 'exitCode', NaN), '', statusOf(run, 'exitCode'); ...
    'solver_timed_out', fieldValue(run, 'timedOut', NaN), '', statusOf(run, 'timedOut'); ...
    'solver_status', fieldText(run, 'status', 'not_recorded'), '', statusOf(run, 'status'); ...
    'solver_success', fieldValue(run, 'success', false), '', statusOf(run, 'success'); ...
    'missing_expected_outputs', numel(fieldOr(run, 'missingOutputs', {})), 'count', statusOf(run, 'missingOutputs'); ...
    'physical_validation_established', false, '', 'not_established'};
tableOut = cell2table(rows, 'VariableNames', {'metric','value','unit','status'});
end

function writeMarkdown(report, path, language, metrics)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:ReportExport', 'Cannot write report: %s', path); end
cleanup = onCleanup(@() fclose(fid));
if strcmp(language, 'zh')
    fprintf(fid, '# 热仿真任务报告\n\n');
    fprintf(fid, '软件版本：%s\n\n', report.softwareVersion);
    fprintf(fid, '报告生成时间（UTC）：%s\n\n', report.generatedUTC);
    fprintf(fid, '## 外部适配器\n\n');
    fprintf(fid, '适配器：%s\n\n', fieldText(report.adapter, 'displayName', '未记录'));
    fprintf(fid, '适配器 ID：%s；版本：%s。\n\n', fieldText(report.adapter, 'id', '未记录'), fieldText(report.adapter, 'version', '未记录'));
    fprintf(fid, '## 求解器运行\n\n');
    fprintf(fid, '状态：%s；退出码：%s；超时：%s；运行成功：%s。\n\n', ...
        fieldText(report.externalRun, 'status', '未记录'), ...
        displayValue(fieldValue(report.externalRun, 'exitCode', NaN), language), ...
        displayValue(fieldValue(report.externalRun, 'timedOut', NaN), language), ...
        displayValue(fieldValue(report.externalRun, 'success', false), language));
    fprintf(fid, '## 证据边界\n\n');
    fprintf(fid, '**本报告记录文件交换、命令运行和数值结果状态，不等于热真空、飞行或物理正确性验证。**\n\n');
else
    fprintf(fid, '# Thermal Simulation Task Report\n\n');
    fprintf(fid, 'Software version: %s\n\n', report.softwareVersion);
    fprintf(fid, 'Generated UTC: %s\n\n', report.generatedUTC);
    fprintf(fid, '## External adapter\n\n');
    fprintf(fid, 'Adapter: %s\n\n', fieldText(report.adapter, 'displayName', 'not recorded'));
    fprintf(fid, 'Adapter id: %s; version: %s.\n\n', fieldText(report.adapter, 'id', 'not recorded'), fieldText(report.adapter, 'version', 'not recorded'));
    fprintf(fid, '## Solver run\n\n');
    fprintf(fid, 'Status: %s; exit code: %s; timed out: %s; success: %s.\n\n', ...
        fieldText(report.externalRun, 'status', 'not recorded'), ...
        displayValue(fieldValue(report.externalRun, 'exitCode', NaN), language), ...
        displayValue(fieldValue(report.externalRun, 'timedOut', NaN), language), ...
        displayValue(fieldValue(report.externalRun, 'success', false), language));
    fprintf(fid, '## Evidence boundary\n\n');
    fprintf(fid, '**This report records exchange, command execution, and numerical-result status; it is not thermal-vacuum, flight, or physical-validity evidence.**\n\n');
end
fprintf(fid, '| metric | value | unit | status |\n|---|---|---|---|\n');
for k = 1:height(metrics)
    fprintf(fid, '| %s | %s | %s | %s |\n', metrics.metric{k}, ...
        displayValue(metrics.value{k}, language), metrics.unit{k}, metrics.status{k});
end
end

function writeManifest(directory, report)
files = dir(fullfile(directory, '**', '*'));
files = files(~[files.isdir]);
entries = repmat(struct('path','','bytes',0,'sha256',''), numel(files), 1);
prefix = [char(java.io.File(directory).getCanonicalPath()) filesep];
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    entries(k).path = char(path(numel(prefix) + 1:end));
    entries(k).bytes = files(k).bytes;
    entries(k).sha256 = hashFile(path);
end
manifest = struct('schema','leotherm.thermal_simulation_manifest.v1', ...
    'softwareVersion',report.softwareVersion,'report',report,'files',entries);
fid = fopen(fullfile(directory, 'thermal_simulation_manifest.json'), 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:ReportExport', 'Cannot write report manifest.'); end
fprintf(fid, '%s', jsonencode(manifest));
fclose(fid);
end

function value = hashFile(path)
fid = fopen(path, 'rb');
if fid < 0, error('leotherm:ReportExport', 'Cannot hash report artifact.'); end
cleanup = onCleanup(@() fclose(fid));
md = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes = fread(fid, 1024 * 1024, '*uint8');
    if ~isempty(bytes), md.update(typecast(bytes, 'int8')); end
end
value = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2)', 1, []));
end

function value = fieldOr(source, name, fallback)
if isstruct(source) && isfield(source, name), value = source.(name); else, value = fallback; end
end
function value = fieldText(source, name, fallback)
value = fieldOr(source, name, fallback);
if isstring(value) && isscalar(value), value = char(value); end
if ~ischar(value), value = char(string(value)); end
end
function value = fieldValue(source, name, fallback)
value = fieldOr(source, name, fallback);
if isempty(value), value = fallback; end
end
function value = statusOf(source, name)
if isstruct(source) && isfield(source, name) && ~isempty(source.(name)), value = 'available'; else, value = 'not_available'; end
end
function value = displayValue(value, ~)
if ischar(value), return; end
if isstring(value), value = char(value); return; end
if islogical(value), value = char(string(value)); return; end
if isnumeric(value)
    if isempty(value) || any(isnan(value(:))), value = 'not_available'; else, value = sprintf('%.12g', value(1)); end
    return
end
value = char(string(value));
end
