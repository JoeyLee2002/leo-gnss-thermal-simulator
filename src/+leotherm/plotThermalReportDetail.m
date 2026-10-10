function figureHandle = plotThermalReportDetail(item, path, language)
%PLOTTHERMALREPORTDETAIL Plot retained samples with a shared publication style.
% Returning a handle permits inspection; callers then own its lifetime.
language=leotherm.normalizeLanguage(language); zh=strcmp(language,'zh');
s=leotherm.thermalFigureStyle(language);
charts=expandCharts(item.charts); count=numel(charts);
barGrid=all(strcmp({charts.kind},'bar')) && count>1;
networkComposite=count==3 && strcmp(charts(1).kind,'network');
cols=1; if barGrid || count>=4, cols=2; end
if networkComposite, cols=2; end
rows=ceil(count/cols);
height=max(10.8,rows*7.0+1.5);
if barGrid || cols==2, height=max(13,rows*10.5); end
if count==1 && strcmp(charts(1).kind,'network'), height=15.5; end
if networkComposite, height=25; end
fig=figure('Visible','off','Color','w','Units','centimeters', ...
    'Position',[2 2 s.widthCm height],'MenuBar','none','ToolBar','none');
try
    layout=tiledlayout(fig,rows,cols,'TileSpacing','compact','Padding','loose');
    for k=1:count
        c=charts(k);
        if networkComposite && k==1, ax=nexttile(layout,[1 2]);
        else, ax=nexttile(layout); end
        hold(ax,'on'); ax.ColorOrder=s.colors;
        if zh, xl=c.xZh; yl=c.yZh; labels=c.legendZh;
        else, xl=c.xEn; yl=c.yEn; labels=c.legendEn; end
        labels=leotherm.thermalFigureLabels(labels);
        switch c.kind
            case 'network'
                drawNetwork(ax,c,zh,s);
            case 'phase'
                if isempty(c.y)
                    text(ax,0.5,0.5,pick(zh,'本段没有可绘制的逐圈峰值时间差', ...
                        'No per-orbit peak differences in this window'), ...
                        'Units','normalized','HorizontalAlignment','center', ...
                        'FontName',s.font,'FontSize',10);
                    axis(ax,'off'); labels={};
                else
                    stem(ax,c.x,c.y,'filled','Color',s.colors(1,:), ...
                        'LineWidth',1.5,'MarkerSize',6);
                    yline(ax,0,'Color',[0.5 0.5 0.5],'HandleVisibility','off');
                    ax.XTick=c.x; xlim(ax,[min(c.x)-0.6 max(c.x)+0.6]);
                end
            case 'matrix'
                imagesc(ax,c.x,c.x,c.y); axis(ax,'image');
                colormap(ax,parula(128)); cb=colorbar(ax);
                cb.Label.String=labels{1}; cb.FontName=s.font; cb.Label.Interpreter='none';
            case 'bar'
                b=barh(ax,c.y,0.68,'EdgeColor','none');
                ax.YTick=1:numel(c.x); ax.YDir='reverse'; ax.YTickLabel=string(c.x);
                if isfield(c,'nodeLabelsZh') && ~isempty(c.nodeLabelsZh)
                    if zh, ax.YTickLabel=c.nodeLabelsZh; else, ax.YTickLabel=c.nodeLabelsEn; end
                end
                ax.YTickLabel=leotherm.thermalFigureLabels(ax.YTickLabel);
                if barGrid && mod(k,2)==0 && isequal(c.x,charts(k-1).x), ax.YTickLabel={}; end
                for j=1:numel(b), b(j).FaceColor=s.colors(j,:); end
                if numel(b)==1 && numel(c.x)<=30
                    text(ax,b.YEndPoints,b.XEndPoints,compose('  %.3g',b.YData), ...
                        'FontName',s.font,'FontSize',8.5, ...
                        'VerticalAlignment','middle','Interpreter','none');
                elseif numel(b)>1
                    zeroRows=find(all(c.y==0,2));
                    text(ax,zeros(size(zeroRows)),zeroRows, ...
                        repmat({pick(zh,'  均为 0','  all zero')},size(zeroRows)), ...
                        'FontName',s.font,'FontSize',8.5,'Interpreter','none');
                end
                if all(c.y(:)>=0), xlim(ax,[0 max(1e-12,max(c.y(:)))*1.23]); end
                if isempty(labels), labels={yl}; end
                xl=yl; yl=''; ax.XGrid='on'; ax.YGrid='off';
            otherwise
                for j=1:size(c.y,2)
                    index=j;
                    if j<=numel(labels)
                        id=regexp(labels{j},'^\d+','match','once');
                        if ~isempty(id), index=str2double(id); end
                    end
                    color=s.nodeColors(mod(index-1,size(s.nodeColors,1))+1,:);
                    lineStyle=s.lineStyles{1+mod(j-1,4)};
                    if size(c.y,2)>4, lineStyle=s.lineStyles{1+mod(floor((j-1)/3),4)}; end
                    plot(ax,c.x,c.y(:,j),'Color',color,'LineWidth',1.55,'LineStyle',lineStyle);
                end
                if numel(c.x)>1 && max(c.x)>min(c.x), xlim(ax,[min(c.x) max(c.x)]); end
                if ~isempty(c.sharedLimits), ylim(ax,c.sharedLimits); end
                ax.YGrid='on'; ax.XGrid='off';
        end
        xlabel(ax,xl,'Interpreter','none'); ylabel(ax,yl,'Interpreter','none');
        panelTitle='';
        if isfield(c,'panelLabel') && ~isempty(c.panelLabel)
            panelTitle=c.panelLabel;
        elseif count>1
            panelTitle=char('a'+k-1);
        end
        if ~isempty(panelTitle), title(ax,panelTitle,'HorizontalAlignment','left'); end
        if ~isempty(labels) && ~ismember(c.kind,{'matrix','network'})
            columns=min(2,numel(labels));
            if cols==2, columns=1; end
            legend(ax,labels,'Location','southoutside','Orientation','horizontal', ...
                'NumColumns',columns,'Interpreter','none');
        end
    end
    leotherm.exportThermalFigure(fig,path,language);
catch exception
    close(fig); rethrow(exception);
end
if nargout>0, figureHandle=fig; else, close(fig); end
end

function charts=expandCharts(input)
input(1).sharedLimits=[]; charts=input([]);
for k=1:numel(input)
    c=input(k); n=size(c.y,2);
    if strcmp(c.kind,'line') && n>6
        bounds=[min(c.y(:)) max(c.y(:))];
        pad=max(0.5,0.05*diff(bounds)); bounds=bounds+[-pad pad];
        for first=1:6:n
            at=first:min(first+5,n); part=c;
            part.y=c.y(:,at); part.legendZh=c.legendZh(at); part.legendEn=c.legendEn(at);
            if isfield(c,'panelLabel') && ~isempty(c.panelLabel)
                part.panelLabel=sprintf('%s%d',c.panelLabel,ceil(first/6));
            end
            part.sharedLimits=bounds; charts(end+1)=part; %#ok<AGROW>
        end
    else
        c.sharedLimits=[]; charts(end+1)=c; %#ok<AGROW>
    end
end
end

function drawNetwork(ax,c,zh,s)
% An adjacency matrix shows every reciprocal link without edge crossings.
G=c.y; n=size(G,1);
im=imagesc(ax,1:n,1:n,G); im.AlphaData=double(G>0);
ax.Color=[0.97 0.975 0.98]; ax.YDir='reverse';
axis(ax,'image'); xlim(ax,[0.5 n+0.5]); ylim(ax,[0.5 n+0.5]);
ax.XTick=1:n; ax.YTick=1:n;
if zh, labels=c.nodeLabelsZh; else, labels=c.nodeLabelsEn; end
labels=leotherm.thermalFigureLabels(labels);
ax.YTickLabel=labels; ax.XTickLabel=string(c.x);
light=[0.88 0.94 0.96]; dark=s.colors(1,:);
u=linspace(0,1,128)'; colormap(ax,light+(dark-light).*u);
largest=max(G(:)); if largest<=0, largest=1; end
caxis(ax,[0 largest]);
for row=1:n
    for col=1:n
        if G(row,col)<=0, continue; end
        color=[0.12 0.18 0.21]; if G(row,col)>0.55*largest, color=[1 1 1]; end
        text(ax,col,row,sprintf('%.3g',G(row,col)), ...
            'HorizontalAlignment','center','FontName',s.font,'FontSize',8.5,'Color',color);
    end
end
for edge=0.5:1:n+0.5
    plot(ax,[0.5 n+0.5],[edge edge],'Color','w','LineWidth',0.65);
    plot(ax,[edge edge],[0.5 n+0.5],'Color','w','LineWidth',0.65);
end
reference=leotherm.defaultReceiverNetwork;
if isfield(c,'nodeKeys') && isequal(string(c.nodeKeys(:)),string(reference.nodeNames(:)))
    for edge=[6.5 7.5]
        plot(ax,[0.5 n+0.5],[edge edge],'Color',[0.4 0.46 0.5],'LineWidth',0.7);
        plot(ax,[edge edge],[0.5 n+0.5],'Color',[0.4 0.46 0.5],'LineWidth',0.7);
    end
end
cb=colorbar(ax); cb.Label.String=pick(zh,'热导 / (W/K)','Conductance (W/K)');
cb.FontName=s.font; cb.FontSize=9; cb.Label.FontName=s.font;
ax.UserData=struct('conductanceMatrix',G,'nodeKeys',{c.nodeKeys});
end

function out=pick(zh,a,b)
if zh, out=a; else, out=b; end
end
