function writeDeviceCalibrationResults(result, directory)
%WRITEDEVICECALIBRATIONRESULTS Preserve priors, adjusted model, and audit tables.
root = java.io.File(char(directory));
if ~root.isAbsolute(), root = java.io.File(fullfile(pwd,char(directory))); end
directory = char(root.getCanonicalPath());
paths = {'parameter_changes.csv','stage_metrics.csv','day_metrics.csv', ...
    'scored_samples.csv','row_audit.csv','original_device.mat','calibrated_device.mat', ...
    'report_zh.md','report_en.md','artifact_manifest.csv','check_numerics.csv','coverage.csv'};
for k = 1:numel(paths)
    if isfile(fullfile(directory,paths{k}))
        error('leotherm:DeviceCalibrationExport','Refusing to overwrite an existing calibration artifact.');
    end
end
writeSafeTable(result.parameterReport,fullfile(directory,paths{1}));
writeSafeTable(result.stageMetrics,fullfile(directory,paths{2}));
writeSafeTable(result.dayMetrics,fullfile(directory,paths{3}));
writeSafeTable(result.samples,fullfile(directory,paths{4}));
writeSafeTable(result.rowAudit,fullfile(directory,paths{5}));
writeSafeTable(result.checkNumerics,fullfile(directory,'check_numerics.csv'));
writeSafeTable(result.coverage,fullfile(directory,'coverage.csv'));
scenario = result.protocol.scenario;
profile = result.profileBefore; network = profile.referenceNetwork;
softwareVersion = result.softwareVersion;
save(fullfile(directory,'original_device.mat'),'scenario','network','profile','softwareVersion');
profile = result.profileAfter; network = profile.calibratedNetwork;
calibrationStatus = result.status;
save(fullfile(directory,'calibrated_device.mat'),'scenario','network','profile','softwareVersion','calibrationStatus');
for language = {'zh','en'}
    lang = language{1};
    writeReport(result,fullfile(directory,['report_' lang '.md']),lang);
    leotherm.plotDeviceCalibration(result,fullfile(directory,['figures_' lang]),lang);
end
files = dir(fullfile(directory,'**','*')); files = files(~[files.isdir]);
names = strings(numel(files),1); hashes = names; bytes = zeros(numel(files),1);
prefix = [directory filesep];
for k = 1:numel(files)
    path = fullfile(files(k).folder,files(k).name);
    if ~startsWith(path,prefix,'IgnoreCase',true)
        error('leotherm:DeviceCalibrationExport','An artifact is outside the declared output directory.');
    end
    names(k) = string(path(numel(prefix)+1:end));
    hashes(k) = sha256(path); bytes(k) = files(k).bytes;
end
writeSafeTable(table(names,bytes,hashes,'VariableNames',{'file','bytes','sha256'}), ...
    fullfile(directory,'artifact_manifest.csv'));
end

function writeSafeTable(t,path)
% MAT snapshots retain originals; spreadsheet-facing text cannot run formulas.
names = t.Properties.VariableNames;
for k = 1:numel(names)
    values = t.(names{k});
    if isstring(values) || iscellstr(values)
        values = string(values);
        for row = 1:numel(values)
            if ~ismissing(values(row)) && ~isempty(regexp(char(values(row)),'^\s*[=+@-]','once'))
                values(row) = "'" + values(row);
            end
        end
        t.(names{k}) = values;
    end
end
writetable(t,path,'Delimiter',',');
end

function writeReport(r,path,lang)
fid = fopen(path,'w','n','UTF-8');
if fid < 0, error('leotherm:DeviceCalibrationExport','Cannot write report.'); end
cleanup = onCleanup(@()fclose(fid));
zh = strcmp(lang,'zh');
if zh
    fprintf(fid,'# 设备受约束标定报告\n\n');
    fprintf(fid,'结论：**%s**。软件版本：%s。\n\n',leotherm.deviceCalibrationText(r.status,lang),r.softwareVersion);
    fprintf(fid,['本报告只检查声明范围内的温度预测与参数一致性，不证明未知的真实设备参数已被恢复。' ...
        '参数范围和来源由用户声明，软件不能独立核验其真实性。\n\n']);
    fprintf(fid,'## 数据与边界\n\n');
    fprintf(fid,['按完整协调世界时日期依次划分标定、验证、最终检查。验证和最终检查均在冻结参数后计算，' ...
        '本次流程不利用它们选择正则权重、范围或模型。重复查看后再调参，会使该数据转为开发数据。\n\n' ...
        '缺测或无效目标测温仅排除对应节点评分；无效驱动才拆段，不插值、不补数。有效区间内的驱动按前值保持。' ...
        '同一角色中的相邻有效历元连续积分，角色改变或无效数据处重置，未默认按午夜重置状态。\n\n']);
    fprintf(fid,'测温不确定度依据：%s。\n\n',r.settings.sensorEvidence);
    fprintf(fid,'逐日逐节点覆盖要求：有效时长至少 %.6g 秒、连续评分至少 %.6g 秒、温度变化至少 %.6g K、评分至少 %d 点。覆盖不足需复核；小误差不代替动态覆盖。\n\n', ...
        r.settings.minimumCoverageS,r.settings.minimumContinuousS,r.settings.minimumTemperatureSpanK,r.settings.minimumScoredSamples);
    fprintf(fid,'正则权重：%.6g；积分最大子步长：%.6g 秒；步长减半最大差异：%.6g K。\n\n', ...
        r.settings.regularizationWeight,r.protocol.effectiveTelemetryOptions.maxStepS,r.diagnostics.stepHalvingMaxDifferenceK);
    fprintf(fid,['目标函数为日期与节点等权的标准化均方误差，加参数偏移惩罚，' ...
        '不是独立采样似然；未计算参数置信区间。数据项：%.8g；先验项：%.8g。\n\n'], ...
        r.trainingObjective.dataTerm,r.trainingObjective.priorTerm);
    fprintf(fid,'## 参数变化\n\n| 节点 | 参数 | 原始值 | 标定值 | 改变（%%） | 下界 | 上界 | 先验标准差 | 接近边界 |\n|---|---|---:|---:|---:|---:|---:|---:|---|\n');
else
    fprintf(fid,'# Physically Constrained Device Calibration\n\n');
    fprintf(fid,'Outcome: **%s**. Software version: %s.\n\n',leotherm.deviceCalibrationText(r.status,lang),r.softwareVersion);
    fprintf(fid,['This checks prediction and parameter consistency within a declared scope, not recovery of unknown true hardware parameters. ' ...
        'Parameter evidence and limits are user declarations, not independently verified evidence.\n\n']);
    fprintf(fid,'## Data and Scope\n\n');
    fprintf(fid,['Whole UTC dates are assigned chronologically to calibration, validation, and final check. ' ...
        'Both checks occur after freezing, without selecting weights, bounds, or model structure. Repeated use for tuning makes a check set development data.\n\n' ...
        'Invalid targets remove only their node scores; invalid drivers split segments. No interpolation or filling. Drivers are left-held within valid intervals. ' ...
        'Adjacent valid samples within a role carry state across midnight; role changes and invalid data restart segments.\n\n']);
    fprintf(fid,'Sensor uncertainty evidence: %s.\n\n',r.settings.sensorEvidence);
    fprintf(fid,'Per-day/node coverage: at least %.6g s scored duration, %.6g s continuous scoring, %.6g K temperature span and %d scored samples. Insufficient coverage requires review even with small errors.\n\n', ...
        r.settings.minimumCoverageS,r.settings.minimumContinuousS,r.settings.minimumTemperatureSpanK,r.settings.minimumScoredSamples);
    fprintf(fid,'Regularization weight: %.6g; maximum integration step: %.6g s; step-halving difference: %.6g K.\n\n', ...
        r.settings.regularizationWeight,r.protocol.effectiveTelemetryOptions.maxStepS,r.diagnostics.stepHalvingMaxDifferenceK);
    fprintf(fid,['The loss equally weights date/node standardized mean squared residuals, then adds a prior penalty. ' ...
        'It is not an independent-sample likelihood. No parameter confidence intervals are inferred. Data term: %.8g; prior term: %.8g.\n\n'], ...
        r.trainingObjective.dataTerm,r.trainingObjective.priorTerm);
    fprintf(fid,'## Parameter Changes\n\n| Node | Parameter | Nominal | Calibrated | Change (%%) | Lower | Upper | Prior SD | Near bound |\n|---|---|---:|---:|---:|---:|---:|---:|---|\n');
end
p = r.parameterReport(r.parameterReport.estimate,:);
labels = leotherm.nodeDisplayNames(cellstr(p.node),lang);
for k = 1:height(p)
    flag = 'No'; if p.near_bound(k), flag = 'Yes'; end
    if zh, flag = '否'; if p.near_bound(k), flag = '是'; end, end
    fprintf(fid,'| %s | %s (%s) | %.7g | %.7g | %.4g | %.7g | %.7g | %.7g | %s |\n', ...
        labels{k},leotherm.deviceCalibrationText(p.field(k),lang),p.unit(k), ...
        p.nominal(k),p.calibrated(k),p.change_percent(k),p.lower(k),p.upper(k),p.priorSigma(k),flag);
end
if zh
    fprintf(fid,'\n未列出的参数保持原值。完整表格保留单位、传热连接对、参数类别和依据；零标称值不计算相对百分比。\n\n');
    fprintf(fid,'## 温度误差\n\n| 数据角色 | 节点 | 统计样本数 | 标定前均方根误差（K） | 标定后均方根误差（K） |\n|---|---|---:|---:|---:|\n');
else
    fprintf(fid,'\nUnlisted parameters remain fixed. The full table retains units, edge peers, parameter kinds, and evidence. Relative percentages are undefined at zero nominal value.\n\n');
    fprintf(fid,'## Temperature Errors\n\n| Role | Node | Scored samples | Baseline RMSE (K) | Calibrated RMSE (K) |\n|---|---|---:|---:|---:|\n');
end
m = r.stageMetrics; labels = leotherm.nodeDisplayNames(cellstr(m.node),lang);
for k = 1:height(m)
    fprintf(fid,'| %s | %s | %d | %.6g | %.6g |\n',leotherm.deviceCalibrationText(m.role(k),lang), ...
        labels{k},m.used_samples(k),m.baseline_rmse_k(k),m.calibrated_rmse_k(k));
end
if zh
    fprintf(fid,['\n上表按样本汇总，不代表独立重复次数。验收针对每个预先指定的检查日期与节点，' ...
        '不只看总体平均值。日期级结果见日统计表。\n\n## 风险提示\n\n']);
else
    fprintf(fid,['\nThe table is sample weighted, not a count of independent replicates. Acceptance checks every predeclared ' ...
        'validation/test date and node, not only the pooled mean. See day_metrics.csv.\n\n## Review Flags\n\n']);
end
for k = 1:numel(r.warningCodes), fprintf(fid,'- %s\n',leotherm.deviceCalibrationText(r.warningCodes(k),lang)); end
if zh
    fprintf(fid,['\n标定数据灵敏度矩阵秩：%d/%d。该检查不包含正则项；' ...
        '秩充分也不证明全局可辨识。不得将等效总热导与单个连接器热导直接比较。\n\n' ...
        '若受约束模型无法解释测温，应检查热网络、边界、功耗、传感器位置与时间基准，不得自动扩大范围。' ...
        '原设备、标定设备、冻结快照、输入快照、逐行记录及校验摘要均单独保存。\n'], ...
        r.diagnostics.rank,r.diagnostics.parameterCount);
else
    fprintf(fid,['\nTraining sensitivity rank: %d/%d, excluding regularization rows. Full rank does not prove global identifiability. ' ...
        'An effective total conductance must not be compared directly with one connector conductance.\n\n' ...
        'If a constrained model cannot explain measurements, inspect heat paths, boundaries, power, sensor mapping, and time. ' ...
        'Never automatically relax hardware bounds. Original/calibrated devices, frozen/input snapshots, row audits, and artifact hashes are preserved separately.\n'], ...
        r.diagnostics.rank,r.diagnostics.parameterCount);
end
end

function value = sha256(path)
md = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path,'rb');
if fid < 0, error('leotherm:DeviceCalibrationExport','Cannot hash calibration artifact.'); end
cleanup = onCleanup(@()fclose(fid));
while ~feof(fid)
    bytes = fread(fid,1024*1024,'*uint8');
    if ~isempty(bytes), md.update(typecast(bytes,'int8')); end
end
value = string(lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2)',1,[])));
end
