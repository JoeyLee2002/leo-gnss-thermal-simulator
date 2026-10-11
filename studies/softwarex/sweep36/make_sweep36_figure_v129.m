function make_sweep36_figure_v129(dataDirectory, figureDirectory)
%MAKE_SWEEP36_FIGURE_V129 Plot every completed condition with native styles.
[~,~,defaultOutput]=sweep36_paths;
if nargin<1 || isempty(dataDirectory), dataDirectory=defaultOutput; end
if nargin<2 || isempty(figureDirectory), figureDirectory=fullfile(defaultOutput,'figures'); end
data=readtable(fullfile(dataDirectory,'sweep36_summary.csv'));
assert(height(data)==36 && all(data.harmonic_available));
out=sweep36_safe_output(figureDirectory);
if ~isfolder(out), mkdir(out); end
altitudes=[400 600 800]; conductance=[0.31 0.62 1.24];
markers={'o','s','^'}; lineStyles={'-','--',':'};
for language={'en','zh'}
    lang=language{1}; style=leotherm.thermalFigureStyle(lang);
    f=figure('Visible','off','Color','w','Units','centimeters','Position',[2 2 18.3 15.5]);
    figureCleanup=onCleanup(@() close(f));
    handles=gobjects(3,1);
    for row=1:2
        for col=1:3
            ax=axes(f,'Units','normalized', ...
                'Position',[0.105+(col-1)*0.30 0.61-(row-1)*0.42 0.235 0.29]);
            hold(ax,'on');
            for k=1:3
                selected=data.altitude_km==altitudes(col) & abs(data.conductance_wk-conductance(k))<1e-9;
                subset=sortrows(data(selected,:),'target_beta_deg');
                assert(height(subset)==4);
                if row==1, y=subset.rf_span_k; else, y=subset.harmonic_delay_s/60; end
                handles(k)=plot(ax,subset.target_beta_deg,y, ...
                    'Color',style.colors(k,:),'LineStyle',lineStyles{k}, ...
                    'Marker',markers{k},'MarkerFaceColor','w','MarkerSize',5,'LineWidth',1.25);
            end
            xlim(ax,[-3 78]); xticks(ax,[0 30 60 75]); ax.YGrid='on';
            title(ax,sprintf('%c  %d km',char('a'+(row-1)*3+col-1),altitudes(col)));
            if row==1, ylim(ax,[0 6.5]); yticks(ax,0:2:6); else, ylim(ax,[35 45]); yticks(ax,35:2:45); end
            if strcmp(lang,'en')
                xlabel(ax,'Beta angle (deg)');
                if col==1
                    if row==1, ylabel(ax,'RF temperature span (K)'); else, ylabel(ax,'Harmonic delay (min)'); end
                end
            else
                xlabel(ax,'目标 beta 角 (度)');
                if col==1
                    if row==1, ylabel(ax,'射频前端温度跨度 (K)'); else, ylabel(ax,'轨道谐波时延 (min)'); end
                end
            end
        end
    end
    labels=compose('G = %.2f W/K',conductance);
    legend(handles,labels,'Orientation','horizontal','Box','off', ...
        'Units','normalized','Position',[0.16 0.025 0.79 0.05]);
    if strcmp(lang,'en'), file='Figure_5_sweep36.png'; else, file='Figure_5_sweep36_zh.png'; end
    leotherm.exportThermalFigure(f,fullfile(out,file),lang);
    savefig(f,fullfile(out,strrep(file,'.png','.fig')));
    clear figureCleanup;
end
save(fullfile(out,'Figure_5_sweep36_source.mat'),'data');
fprintf('SWEEP36_NATIVE_FIGURES_COMPLETE\n');
end
