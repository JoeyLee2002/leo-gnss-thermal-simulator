function plotThermalReportDetail(item, path, language)
%PLOTTHERMALREPORTDETAIL Draw report-only diagnostics from actual result arrays.
fig = figure('Visible','off','Color','w','Position',[100 100 1200 800], ...
    'MenuBar','none','ToolBar','none');
cleanup = onCleanup(@() close(fig));
layout = tiledlayout(fig,numel(item.charts),1,'TileSpacing','compact','Padding','compact');
zh = strcmp(language,'zh');
for k = 1:numel(item.charts)
    c = item.charts(k); ax = nexttile(layout);
    ax.ColorOrder = lines(max(7,size(c.y,2)));
    if zh
        xl = c.xZh; yl = c.yZh; labels = c.legendZh;
    else
        xl = c.xEn; yl = c.yEn; labels = c.legendEn;
    end
    switch c.kind
        case 'network'
            g = graph(c.y,'upper');
            p = plot(ax,g,'Layout','circle','NodeLabel',{},'MarkerSize',8, ...
                'NodeColor',[0.12 0.48 0.42],'EdgeColor',[0.40 0.46 0.48]);
            if ~isempty(g.Edges.Weight)
                p.LineWidth = 0.8+3*g.Edges.Weight/max(g.Edges.Weight);
            end
            reference = leotherm.defaultReceiverNetwork;
            if isfield(c,'nodeKeys') && isequal(string(c.nodeKeys(:)),string(reference.nodeNames(:)))
                p.XData = [zeros(1,6),2.2,4.2,4.6,3.3,5.0];
                p.YData = [5:-1:0,2.3,5,3.2,1.2,0];
                xlim(ax,[-0.3 7.3]); ylim(ax,[-0.7 5.7]);
            end
            if zh, nl=c.nodeLabelsZh; else, nl=c.nodeLabelsEn; end
            text(ax,p.XData+0.08,p.YData+0.16,nl,'Interpreter','none', ...
                'FontName','Microsoft YaHei','FontSize',13,'BackgroundColor','w','Margin',1);
            axis(ax,'off');
        case 'phase'
            if isempty(c.y)
                text(ax,0.5,0.5,pick(zh,'本段没有可绘制的逐圈峰值时间差', ...
                    'No per-orbit peak differences in this window'), ...
                    'Units','normalized','HorizontalAlignment','center', ...
                    'FontName','Microsoft YaHei','FontSize',14);
                axis(ax,'off'); labels={};
            else
                bar(ax,c.x,c.y,'FaceColor',[0.18 0.49 0.62]); grid(ax,'on');
                yline(ax,0,'k-','HandleVisibility','off');
                ax.XTick=c.x;
            end
        case 'matrix'
            imagesc(ax,c.x,c.x,c.y); axis(ax,'image');
            cb = colorbar(ax); cb.Label.String = labels{1};
            cb.FontName = 'Microsoft YaHei'; cb.Label.Interpreter = 'none';
        case 'bar'
            b = barh(ax,c.y); ax.YTick = 1:numel(c.x);
            ax.YTickLabel = string(c.x); ax.YDir='reverse'; grid(ax,'on');
            if isfield(c,'nodeLabelsZh') && ~isempty(c.nodeLabelsZh)
                if zh, ax.YTickLabel=c.nodeLabelsZh; else, ax.YTickLabel=c.nodeLabelsEn; end
            end
            for j=1:numel(b)
                if numel(c.x)<=30
                    at=true(size(b(j).YData));
                    if numel(b)>1, at=~all(c.y==0,2)'; end
                    text(ax,b(j).YEndPoints(at),b(j).XEndPoints(at), ...
                        compose(' %.3g',b(j).YData(at)),'FontSize',11, ...
                        'VerticalAlignment','middle','Interpreter','none');
                end
            end
            if numel(b)>1
                rows=find(all(c.y==0,2));
                text(ax,zeros(size(rows)),rows,repmat({pick(zh,'均为 0','all 0')},size(rows)), ...
                    'FontSize',11,'VerticalAlignment','middle','Interpreter','none');
            end
            if all(c.y(:)>=0), xlim(ax,[0 max(1e-12,max(c.y(:)))*1.18]); end
            if isempty(labels), labels = {yl}; end
            temp=xl; xl=yl; yl=temp;
        otherwise
            plot(ax,c.x,c.y,'LineWidth',1.4); grid(ax,'on');
    end
    ax.FontName = 'Microsoft YaHei'; ax.FontSize = 12;
    ax.Toolbar.Visible = 'off'; ax.TickLabelInterpreter = 'none';
    xlabel(ax,xl,'Interpreter','none'); ylabel(ax,yl,'Interpreter','none');
    if ~isempty(labels) && ~ismember(c.kind,{'matrix','network'})
        legend(ax,labels,'Location','southoutside','Orientation','horizontal', ...
            'NumColumns',min(2,numel(labels)),'Interpreter','none','FontSize',11);
    end
end
exportgraphics(fig,path,'Resolution',160);
end

function out = pick(zh,a,b)
if zh, out=a; else, out=b; end
end
