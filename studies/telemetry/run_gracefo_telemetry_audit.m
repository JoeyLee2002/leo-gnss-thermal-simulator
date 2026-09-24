function summary = run_gracefo_telemetry_audit(rawDirectory, outputDirectory)
%RUN_GRACEFO_TELEMETRY_AUDIT Real measurements: data readiness, not model validation.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(root); startup;
if nargin < 1 || isempty(rawDirectory), rawDirectory = fullfile(root,'results','flight_telemetry','raw'); end
if nargin < 2 || isempty(outputDirectory)
    outputDirectory = fullfile(root,'results','flight_telemetry', ...
        ['audit_' datestr(now,'yyyymmdd_HHMMSS')]);
end
if isfolder(outputDirectory)
    files = dir(outputDirectory);
    assert(all(ismember({files.name},{'.','..'})), 'Use a new or empty audit directory.');
else
    mkdir(outputDirectory);
end
% MATLAB dir does not implement character classes on every platform.
files = dir(fullfile(rawDirectory,'IHK1B_2024-01-0*_*_04.txt'));
keep = ~cellfun(@isempty,regexp({files.name},'^IHK1B_2024-01-0[12]_[CD]_04\.txt$','once'));
files = files(keep);
assert(numel(files)==4, 'Expected the two spacecraft on both preselected dates, 2024-01-01 and 2024-01-02.');
summary = table; allRecords = table; metadata = cell(numel(files),1);
sourceHashes = strings(numel(files),1);
for f = 1:numel(files)
    path = fullfile(files(f).folder,files(f).name);
    [records, metadata{f}] = leotherm.readGracefoIhk(path);
    sourceHashes(f) = fileHash(path);
    records.source_file = repmat(string(files(f).name),height(records),1);
    allRecords = [allRecords; records]; %#ok<AGROW>
    orbitName = strrep(files(f).name,'IHK1B','GNI1B');
    orbitTimes = readOrbitTimes(fullfile(rawDirectory,orbitName));
    sensors = unique(records.sensor_id(records.sensor_type=="T"),'stable');
    for k = 1:numel(sensors)
        channel = records(records.sensor_type=="T" & records.sensor_id==sensors(k),:);
        valid = channel.accepted;
        values = channel.temperature_k(valid)-273.15;
        interval = seconds(diff(channel.epoch_utc));
        exact = channel.gps_microseconds==0 & ismember(channel.gps_seconds,orbitTimes);
        row = table(string(files(f).name),channel.spacecraft(1),sensors(k), ...
            height(channel),sum(valid),sum(~valid),min(values),max(values),std(values), ...
            median(interval),max(interval),sum(interval>121),sum(exact & valid), ...
            'VariableNames',{'source_file','spacecraft','sensor_id','records','accepted', ...
            'rejected','minimum_degC','maximum_degC','std_K','median_interval_s', ...
            'maximum_interval_s','gaps_over_121s','exact_orbit_matches'});
        summary = [summary;row]; %#ok<AGROW>
        % Deliberately non-canonical temperature column: physical node mapping awaits evidence.
        exported = table(string(channel.epoch_utc),double(valid),channel.source_value, ...
            channel.quality_bits,channel.source_record, ...
            repmat("GRACEFO_IHK1B_real_flight",height(channel),1), ...
            'VariableNames',{'epoch_utc','quality',['sensor_' char(sensors(k)) '_degC'], ...
            'original_quality_bits','source_record','dataset_type'});
        name = [erase(files(f).name,'.txt') '_sensor_' char(sensors(k)) '.csv'];
        writetable(exported,fullfile(outputDirectory,name));
    end
end
writetable(summary,fullfile(outputDirectory,'temperature_channel_summary.csv'));
writetable(allRecords,fullfile(outputDirectory,'all_records_with_quality.csv'));
save(fullfile(outputDirectory,'flight_telemetry_audit.mat'), ...
    'summary','allRecords','metadata','sourceHashes','-v7.3');
manifest = struct('softwareVersion',leotherm.version,'datasetKind','real_flight_telemetry', ...
    'doi','10.5067/GFJPL-L1B04','preselectedDates',{{'2024-01-01','2024-01-02'}}, ...
    'spacecraft',{{'C','D'}},'sourceFiles',{{files.name}},'sha256',{cellstr(sourceHashes)}, ...
    'downloadRoot','https://isdc-data.gfz.de/grace-fo/Level-1B/JPL/INSTRUMENT/RL04/2024/', ...
    'interpolation',false,'temperatureNodeMappingConfirmed',false, ...
    'modelCalibrationPerformed',false,'physicalValidationComplete',false);
fid = fopen(fullfile(outputDirectory,'provenance.json'),'w','n','UTF-8');
assert(fid>=0); cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(manifest,'PrettyPrint',true));
for language = {'zh','en'}
    plotMeasurements(allRecords,outputDirectory,language{1});
end
writeReport(summary,outputDirectory);
fprintf('FLIGHT_AUDIT_COMPLETE: %d satellite-days, %d channel-days, %d valid temperatures\n', ...
    numel(files),height(summary),sum(summary.accepted));
fprintf('EXACT_ORBIT_MATCHES=%d PHYSICAL_VALIDATION_COMPLETE=0\n',sum(summary.exact_orbit_matches));
end

function values = readOrbitTimes(path)
fid = fopen(path,'r');
assert(fid>=0,'Missing accompanying GNI1B orbit file.');
cleanup = onCleanup(@() fclose(fid));
line = fgetl(fid);
while ischar(line) && ~strcmp(strtrim(line),'# End of YAML header'), line=fgetl(fid); end
assert(ischar(line),'Missing orbit header terminator.');
data = textscan(fid,'%f%*[^\n]');
values = data{1};
assert(~isempty(values) && all(isfinite(values)) && all(diff(values)>0),'Invalid orbit epochs.');
end

function value = fileHash(path)
fid=fopen(path,'rb'); assert(fid>=0); cleanup=onCleanup(@() fclose(fid));
engine=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid), engine.update(fread(fid,1024*1024,'*uint8')); end
digest=typecast(engine.digest(),'uint8');
value=string(lower(reshape(dec2hex(digest,2)',1,[])));
end

function plotMeasurements(records, outputDirectory, language)
chinese = strcmp(language,'zh');
figureHandle = figure('Visible','off','Color','w','Position',[50 50 1400 1000]);
cleanup = onCleanup(@() close(figureHandle));
layout = tiledlayout(figureHandle,3,2,'TileSpacing','compact','Padding','compact');
ids = unique(records.sensor_id(records.sensor_type=="T"),'stable');
colors = lines(6); zero = datetime(2024,1,1,'TimeZone','UTC');
for group=1:3
    chosen = ids((group-1)*6+1:min(group*6,numel(ids)));
    for craft=1:2
        ax=nexttile(layout); hold(ax,'on');
        names=strings(numel(chosen),1); handles=gobjects(numel(chosen),1);
        for k=1:numel(chosen)
            at=records.spacecraft==string(char('B'+craft)) & records.sensor_type=="T" ...
                & records.sensor_id==chosen(k) & records.accepted;
            handles(k)=scatter(ax,hours(records.epoch_utc(at)-zero), ...
                records.temperature_k(at)-273.15,5,colors(k,:),'filled');
            if chinese, names(k)="传感器"+chosen(k); else, names(k)="Sensor "+chosen(k); end
        end
        title(ax,"GRACE-FO "+string(char('B'+craft))); grid(ax,'on'); box(ax,'on');
        xlim(ax,[0 48]);
        if chinese
            ax.FontName='Microsoft YaHei';
            xlabel(ax,'自二〇二四年一月一日零时起的协调世界时小时数');
            ylabel(ax,'实测温度（摄氏度）');
        else
            ax.FontName='Arial'; xlabel(ax,'Hours since 2024-01-01 00:00 UTC');
            ylabel(ax,'Measured temperature (degC)');
        end
        legend(ax,handles,names,'Location','best','NumColumns',2);
    end
end
if chinese
    title(layout,'真实仪器遥测：仅显示原始有效采样，不连接或填补缺测', ...
        'FontName','Microsoft YaHei','FontSize',14);
else
    title(layout,'Real instrument telemetry: original accepted samples, no gap filling','FontSize',14);
end
exportgraphics(figureHandle,fullfile(outputDirectory,['gracefo_measured_temperature_' language '.png']), ...
    'Resolution',180);
end

function writeReport(summary,directory)
fid=fopen(fullfile(directory,'真实遥测数据检查报告.md'),'w','n','UTF-8');
assert(fid>=0); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'# GRACE-FO真实遥测数据检查\n\n');
fprintf(fid,'数据来自NASA/JPL发布、GFZ托管的GRACE-FO RL04 IHK1B，DOI：10.5067/GFJPL-L1B04。\n\n');
fprintf(fid,'预先选定2024年1月1日至2日，C、D两颗卫星，共4个卫星日；未按仿真效果挑选日期。\n\n');
fprintf(fid,'## 检查结果\n\n');
fprintf(fid,'- 共%d个温度通道日，%d条测温记录，其中%d条通过本次质量检查，%d条被拒绝。\n', ...
    height(summary),sum(summary.records),sum(summary.accepted),sum(summary.rejected));
fprintf(fid,'- 覆盖%d个传感器编号；逐通道统计见temperature_channel_summary.csv。\n',numel(unique(summary.sensor_id)));
fprintf(fid,'- GPS时刻转换为协调世界时，保留微秒；2024年的GPS减UTC为18秒。\n');
fprintf(fid,'- 本次仅接受原始八位质量标记全零、时间合法且温度有效的记录；拒绝记录仍在总表中。\n');
fprintf(fid,'- 与随附整秒GNI1B轨道完全重合的有效温度记录为%d条。不做四舍五入、近邻匹配或插值。\n\n', ...
    sum(summary.exact_orbit_matches));
fprintf(fid,'## 当前能做什么\n\n');
fprintf(fid,'真实遥测已完成下载、解析、单位与时间转换、质量统计、逐通道CSV导出及中英文原始测温图。');
fprintf(fid,'这是实际数据接入与质检，不是物理模型通过验证。CSV可在“遥测与验证”页导入；');
fprintf(fid,'温度列故意不自动分配节点，确认传感器位置后再映射为温度并选择对应热节点，单位为摄氏度。\n\n');
fprintf(fid,'## 尚不能声称的结论\n\n');
fprintf(fid,'1. 编号05等尚未获得可靠的安装位置对应表，不能直接改名为天线、射频前端或振荡器。\n');
fprintf(fid,'2. 本软件默认11节点网络不是已标定的GRACE-FO热网络，不能靠重命名完成任务验证。\n');
fprintf(fid,'3. 电压遥测不是节点耗散功率；本数据缺少足以重建全部节点热输入的功率分配。\n');
fprintf(fid,'4. 温度时刻与轨道时刻异步；严格不插值时，需要同历元动力学计算或同历元外部产品。\n');
fprintf(fid,'5. 本次没有运行虚构任务参数的物理对比，也没有拟合后原地打分，不报告虚假的验证RMSE。\n\n');
fprintf(fid,'下一步应补齐传感器位置、任务热网络和驱动条件，再把第一天用于必要标定、第二天锁定为留出评估。');
fprintf(fid,'这只是预定划分，不表示已完成标定或验证；两天也不能支撑跨季节普适结论。\n\n');
fprintf(fid,'原始产品和数据政策保留在文件头；本软件MIT许可证不替代NASA数据使用政策。');
fprintf(fid,'文件来源与SHA-256见provenance.json。\n');
end
