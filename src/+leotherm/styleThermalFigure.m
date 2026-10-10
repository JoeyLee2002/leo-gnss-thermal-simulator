function styleThermalFigure(fig, language)
%STYLETHERMALFIGURE Apply local styling without changing root defaults or data.
s = leotherm.thermalFigureStyle(language);
axesList = findall(fig,'Type','axes');
for k=1:numel(axesList)
    ax=axesList(k);
    set(ax,'FontName',s.font,'FontSize',s.fontSize,'Box','off', ...
        'LineWidth',0.75,'TickDir','out','TickLength',[0.012 0.012], ...
        'GridColor',[0.4 0.45 0.5],'GridAlpha',0.14, ...
        'MinorGridAlpha',0.07,'TickLabelInterpreter','none','Layer','top');
    ax.Toolbar.Visible='off';
    ax.Title.FontName=s.font; ax.Title.FontSize=10; ax.Title.FontWeight='bold';
    ax.Title.Interpreter='none';
    ax.Title.Units='normalized';
    titlePosition=ax.Title.Position; titlePosition(1)=0;
    ax.Title.Position=titlePosition; ax.Title.HorizontalAlignment='left';
    ax.XLabel.FontName=s.font; ax.YLabel.FontName=s.font;
    ax.XLabel.FontSize=10; ax.YLabel.FontSize=10;
    ax.XLabel.Interpreter='none'; ax.YLabel.Interpreter='none';
end
legends=findall(fig,'Type','legend');
for k=1:numel(legends)
    set(legends(k),'FontName',s.font,'FontSize',s.legendSize, ...
        'Box','off','Interpreter','none');
end
end
