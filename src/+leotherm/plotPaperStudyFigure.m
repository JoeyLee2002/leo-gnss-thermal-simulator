function fig=plotPaperStudyFigure(item,path,language)
%PLOTPAPERSTUDYFIGURE One shared legend for the six controlled-study panels.
language=leotherm.normalizeLanguage(language); zh=strcmp(language,'zh');
windowCleanup=leotherm.preserveAppWindows;
s=leotherm.thermalFigureStyle(language);
fig=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18.3 15.5]);
try
    handles=gobjects(3,1); markers={'o','s','^'}; lines={'-','--',':'};
    for k=1:6
        c=item.charts(k); col=mod(k-1,3); row=floor((k-1)/3);
        ax=axes(fig,'Units','normalized','Position',[0.11+col*0.30 0.61-row*0.42 0.235 0.29]);
        hold(ax,'on');
        for g=1:3
            handles(g)=plot(ax,c.x,c.y(:,g),'Color',s.colors(g,:), ...
                'LineStyle',lines{g},'Marker',markers{g},'MarkerSize',4.5, ...
                'MarkerFaceColor','w','LineWidth',1.3);
        end
        title(ax,c.panelLabel); xlim(ax,[-3 78]); ax.XTick=[0 30 60 75];
        ax.YGrid='on'; ax.XGrid='off';
        if row==0, ylim(ax,[0 6.5]); ax.YTick=0:2:6;
        else, ylim(ax,[35 45]); ax.YTick=35:2:45; end
        if zh, xlabel(ax,c.xZh); else, xlabel(ax,c.xEn); end
        if col==0
            if zh
                ylabel(ax,c.yZh);
            elseif row==0
                ylabel(ax,{'RF temperature','P95-P5 (K)'});
            else
                ylabel(ax,{'Orbital-frequency','phase delay (min)'});
            end
        end
    end
    legend(handles,item.charts(1).legendEn,'Orientation','horizontal', ...
        'NumColumns',3,'Units','normalized','Position',[0.12 0.025 0.83 0.045]);
    leotherm.exportThermalFigure(fig,path,language);
catch exception
    close(fig); rethrow(exception);
end
delete(windowCleanup);
end
