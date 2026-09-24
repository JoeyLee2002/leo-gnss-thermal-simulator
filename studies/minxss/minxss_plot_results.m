function minxss_plot_results(runDir,metrics,predictions,records,frozen,p,language)
%MINXSS_PLOT_RESULTS Every held-out arc is plotted, without outcome selection.
isZh = strcmp(language,'zh');
if isZh
    font='Microsoft YaHei';
    modelLabels={'未标定物理先验','单节点热模型','双节点热模型','无储热稳态对照','初始温度保持'};
    yLabel='温度（摄氏度）'; xLabel='弧段内经过时间（分钟）';
    panelLabels={'负 Y 方向展开板','正 Y 方向展开板'};
    observed='实测温度'; selected='所选热模型预测'; prior='未标定物理先验'; steady='无储热稳态对照';
else
    font='Arial';
    modelLabels={'Uncalibrated prior','One-node thermal','Two-node thermal','No storage','Initial-value hold'};
    yLabel='Temperature (deg C)'; xLabel='Elapsed time (min)';
    panelLabels={'-Y deployed panel','+Y deployed panel'};
    observed='Measured'; selected='Selected thermal prediction'; prior='Uncalibrated prior'; steady='No storage';
end
out=fullfile(runDir,['figures_' language]); if ~isfolder(out),mkdir(out);end
color=[0 0 0;0.00 0.45 0.70;0.90 0.62 0.00;0.35 0.35 0.35;0.00 0.62 0.45];
f=figure('Visible','off','Color','w','Position',[100 100 1120 600]);
clean=onCleanup(@()close(f));
ax=axes(f); hold(ax,'on');
test=metrics(strcmp(metrics.split,'test'),:);
for j=1:numel(p.modelNames)
    t=test(strcmp(test.model,p.modelNames{j}),:);
    values=t.rmse_K;
    scatter(ax,j*ones(size(values)),values,30,color(j,:),'filled','DisplayName',modelLabels{j});
    plot(ax,[j-.22 j+.22],[mean(values) mean(values)],'Color',color(j,:), ...
        'LineWidth',2.2,'HandleVisibility','off');
end
yline(ax,p.acceptance.rmseK,'--','Color',[0.5 0.5 0.5],'HandleVisibility','off');
set(ax,'FontName',font,'FontSize',11,'XTick',1:5,'XTickLabel',modelLabels, ...
    'TickDir','out','Box','off','XLim',[0.5 5.5]);
xtickangle(ax,15);
if isZh
    ylabel(ax,'留出弧段均方根误差（开尔文）'); title(ax,'全部留出弧段：两块展开板的温度预测误差');
else
    ylabel(ax,'Held-out arc RMSE (K)'); title(ax,'Temperature prediction errors: all held-out arcs and both panels');
end
legend(ax,'Location','northoutside','NumColumns',3,'Box','off');
exportgraphics(f,fullfile(out,'Fig01_Heldout_Model_Comparison.png'),'Resolution',180);
exportgraphics(f,fullfile(out,'Fig01_Heldout_Model_Comparison.pdf'),'ContentType','vector');
clear clean
indices=find(strcmp({records.split},'test'));
for i=1:numel(indices)
    k=indices(i); r=records(k); pred=predictions(k);
    f=figure('Visible','off','Color','w','Position',[100 100 1040 760]);
    clean=onCleanup(@()close(f));
    layout=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
    for panel=1:2
        ax=nexttile(layout); hold(ax,'on'); t=r.input.elapsedS/60;
        plot(ax,t,r.temperatureK(:,panel)-273.15,'Color',[0 0 0],'LineWidth',1.4,'DisplayName',observed);
        plot(ax,t,pred.(frozen.selected)(:,panel)-273.15,'Color',color(2,:), ...
            'LineWidth',1.4,'DisplayName',selected);
        plot(ax,t,pred.literature_prior(:,panel)-273.15,':','Color',color(4,:), ...
            'LineWidth',1.2,'DisplayName',prior);
        plot(ax,t,pred.no_storage(:,panel)-273.15,'--','Color',color(5,:), ...
            'LineWidth',1,'DisplayName',steady);
        xline(ax,p.excludeInitialS/60,':','Color',[0.5 0.5 0.5],'HandleVisibility','off');
        set(ax,'FontName',font,'FontSize',11,'TickDir','out','Box','off','XLim',[t(1) t(end)]);
        title(ax,[r.day ' | ' panelLabels{panel}]); xlabel(ax,xLabel); ylabel(ax,yLabel);
        legend(ax,'Location','northoutside','NumColumns',2,'Box','off');
    end
    stem=sprintf('Fig%02d_Heldout_%s',i+1,r.id);
    exportgraphics(f,fullfile(out,[stem '.png']),'Resolution',180);
    exportgraphics(f,fullfile(out,[stem '.pdf']),'ContentType','vector');
    clear clean
end
end
