function paths = plotDeviceCalibration(result, directory, language)
%PLOTDEVICECALIBRATION Show all checks without bridging missing samples.
language = leotherm.normalizeLanguage(language);
target = java.io.File(char(directory));
if ~target.isAbsolute(), target = java.io.File(fullfile(pwd,char(directory))); end
directory = char(target.getCanonicalPath());
if ~target.mkdirs()
    error('leotherm:DeviceCalibrationExport','Figure directory must be new.');
end
zh = strcmp(language,'zh'); font = 'Arial'; if zh, font = 'Microsoft YaHei'; end
synthetic = strcmp(result.datasetKind,'synthetic_demo_not_flight_data');
paths = strings(0,1); roles = ["train","validation","test"];
network = result.profileBefore.referenceNetwork;
nodes = unique(result.stageMetrics.node,'stable');
colors = [0.25 0.25 0.25;0.78 0.38 0.12;0.08 0.48 0.60];
for nodeIndex = 1:numel(nodes)
    node = nodes(nodeIndex);
    labels = leotherm.nodeDisplayNames(cellstr(node),language);
    if synthetic && node == "device"
        labels = {'Synthetic device'}; if zh, labels = {'合成设备'}; end
    end
    m = result.dayMetrics(result.dayMetrics.node == node,:);
    fig = figure('Visible','off','Color','w','Position',[80 80 1040 470]);
    cleanup = onCleanup(@()close(fig));
    ax = axes(fig,'FontName',font,'FontSize',11,'Box','off', ...
        'Position',[0.10 0.22 0.86 0.70]); hold(ax,'on');
    plot(ax,1:height(m),m.baseline_rmse_k,'o-','Color',colors(2,:),'LineWidth',1.5);
    plot(ax,1:height(m),m.calibrated_rmse_k,'s-','Color',colors(3,:),'LineWidth',1.5);
    ticks = m.day_utc;
    tickIndex = unique([1:ceil(height(m)/6):height(m),height(m)]);
    set(ax,'XTick',tickIndex,'XTickLabel',ticks(tickIndex),'XTickLabelRotation',0);
    xlim(ax,[0 height(m)+1]);
    for tick = tickIndex
        text(ax,tick/(height(m)+1),-0.12, ...
            leotherm.deviceCalibrationText(m.role(tick),language), ...
            'Units','normalized','HorizontalAlignment','center','FontName',font, ...
            'FontSize',10,'Clipping','off','Interpreter','none');
    end
    if zh
        ylabel(ax,'温度均方根误差（K）'); title(ax,[labels{1} '：逐日误差']);
        legend(ax,{'原始设备参数','受约束标定参数'},'Location','best');
    else
        ylabel(ax,'Temperature RMSE (K)'); title(ax,[labels{1} ': daily errors']);
        legend(ax,{'Original device parameters','Constrained calibration'},'Location','best');
    end
    paths = [paths; exportFigure(fig,directory,sprintf('Fig_C1_node_%02d_daily_errors',nodeIndex))]; %#ok<AGROW>
    clear cleanup
    for r = 1:3
        report = result.reports{r}; prior = result.baseline{r}; prediction = result.prediction{r};
        column = find(strcmp(network.nodeNames,node),1);
        s = report.samples(report.samples.node == node,:);
            epoch = prediction.epoch;
            epoch.TimeZone = 'UTC';
        date = dateshift(epoch,'start','day'); date.Format = 'yyyy-MM-dd';
        dayKeys = string(date);
        days = result.split.day_utc(result.split.role == roles(r));
        for d = 1:numel(days)
            at = dayKeys == days(d) & ~isnat(epoch);
            t = seconds(epoch(at)-epoch(find(at,1)))/60;
            ids = prediction.segmentId(at);
            observed = s.observed_k(at); observed(~s.used(at)) = NaN;
            y = [observed,prior.temperatureK(at,column),prediction.temperatureK(at,column)];
            y(ids == 0,:) = NaN;
            [x,y] = breakLines(t,y,ids);
            fig = figure('Visible','off','Color','w','Position',[80 80 1040 470]);
            cleanup = onCleanup(@()close(fig));
            ax = axes(fig,'FontName',font,'FontSize',11,'Box','off'); hold(ax,'on');
            for series = 1:3
                plot(ax,x,y(:,series)-273.15,'Color',colors(series,:),'LineWidth',1.4);
            end
            if zh
                xlabel(ax,'距当日首个记录的时间（分钟）'); ylabel(ax,'温度（摄氏度）');
                observedLabel = '有效实测温度'; if synthetic, observedLabel = '合成观测温度'; end
                legend(ax,{observedLabel,'标定前预测','受约束标定后预测'},'Location','best');
            else
                xlabel(ax,'Minutes since first record of day'); ylabel(ax,'Temperature (deg C)');
                observedLabel = 'Scored measurements'; if synthetic, observedLabel = 'Synthetic observations'; end
                legend(ax,{observedLabel,'Before calibration','Constrained prediction'},'Location','best');
            end
            title(ax,sprintf('%s | %s | %s',labels{1},days(d),leotherm.deviceCalibrationText(roles(r),language)), ...
                'Interpreter','none');
            name = sprintf('Fig_C2_node_%02d_%s_%s',nodeIndex,roles(r),erase(days(d),'-'));
            paths = [paths; exportFigure(fig,directory,name)]; %#ok<AGROW>
            clear cleanup
        end
    end
end
end

function [x,out] = breakLines(t,y,ids)
cut = [false; diff(ids) ~= 0];
count = numel(t)+sum(cut);
x = nan(count,1); out = nan(count,size(y,2)); j = 0;
for k = 1:numel(t)
    if cut(k), j = j+1; end
    j = j+1; x(j) = t(k); out(j,:) = y(k,:);
end
end

function paths = exportFigure(fig,directory,name)
paths = [string(fullfile(directory,[name '.png']));string(fullfile(directory,[name '.pdf']))];
exportgraphics(fig,paths(1),'Resolution',180);
exportgraphics(fig,paths(2),'ContentType','vector');
end
