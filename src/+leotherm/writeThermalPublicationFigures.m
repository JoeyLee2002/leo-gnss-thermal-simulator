function manifest=writeThermalPublicationFigures(items, directory, language)
%WRITETHERMALPUBLICATIONFIGURES Native chart groups shared by reports and papers.
% Uses exactly the same chart arrays and renderer as individual report figures.
groups={ 'model_inputs', {'capacity','optics'}; ...
    'environment', {'illumination','heat_inputs'}; ...
    'temperature_response', {'temperatures','initial_state'}; ...
    'conductive_paths', {'conductance','gradients'}; ...
    'response_diagnostics', {'lag_detail','energy_balance'}};
manifest=struct('figure',{},'stages',{},'sourceCharts',{});
for k=1:size(groups,1)
    stages=groups{k,2}; at=zeros(1,numel(stages));
    for j=1:numel(stages)
        found=find(strcmp({items.stage},stages{j}),1);
        if ~isempty(found), at(j)=found; end
    end
    if strcmp(groups{k,1},'response_diagnostics')
        stages=stages(at~=0); at=at(at~=0);
    end
    if isempty(at) || any(at==0), continue; end
    charts=[];
    for j=1:numel(at)
        c=items(at(j)).charts;
        for m=1:numel(c)
            c(m).panelLabel=char('a'+j-1);
            if numel(c)>1, c(m).panelLabel=sprintf('%s%d',c(m).panelLabel,m); end
        end
        charts=[charts c]; %#ok<AGROW>
    end
    if numel(charts)==1, charts.panelLabel=''; end
    item=items(at(1)); item.charts=charts;
    stem=['publication_' groups{k,1} '_' language];
    leotherm.plotThermalReportDetail(item,fullfile(directory,[stem '.png']),language);
    save(fullfile(directory,[stem '_source.mat']),'item');
    manifest(end+1)=struct('figure',stem,'stages',{stages}, ...
        'sourceCharts',numel(charts)); %#ok<AGROW>
end
fid=fopen(fullfile(directory,['publication_figures_' language '.json']),'w');
if fid<0, error('leotherm:ReportExport','Cannot write figure manifest.'); end
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(manifest));
end
