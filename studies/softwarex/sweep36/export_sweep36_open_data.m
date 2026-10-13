function export_sweep36_open_data(dataDirectory,outputDirectory,progress)
%EXPORT_SWEEP36_OPEN_DATA Export parameters and all six-orbit temperature arcs.
if nargin<1, dataDirectory=[]; end
if nargin<3, progress=[]; end
[~,~,defaultOutput]=sweep36_paths;
if isempty(dataDirectory), dataDirectory=defaultOutput; end
if nargin<2 || isempty(outputDirectory), outputDirectory=fullfile(defaultOutput,'open_data'); end
outputDirectory=sweep36_safe_output(outputDirectory);
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
p=load(fullfile(dataDirectory,'protocol.mat'),'protocol');
sweep36_write_json(fullfile(outputDirectory,'protocol.json'),sweep36_readable_protocol(p.protocol));
n=p.protocol.network;
nodes=table((1:11)',n.nodeNames(:),n.capacityJK,n.internalPowerW, ...
    n.projectedAreaM2,n.radiatingAreaM2,n.solarAbsorptivity,n.irEmissivity, ...
    'VariableNames',{'node_id','node_name','capacity_j_per_k','internal_power_w', ...
    'projected_area_m2','radiating_area_m2','solar_absorptivity','ir_emissivity'});
writetable(nodes,fullfile(outputDirectory,'reference_nodes.csv'));
[i,j]=find(triu(n.conductanceWK,1)>0);
links=table(i,j,n.conductanceWK(sub2ind([11 11],i,j)), ...
    'VariableNames',{'node_i','node_j','reference_conductance_w_per_k'});
writetable(links,fullfile(outputDirectory,'reference_links.csv'));
summary=readtable(fullfile(dataDirectory,'sweep36_summary.csv'));
for k=1:height(summary)
    leotherm.notifyProgress(progress,'export_data',k-1,height(summary), ...
        sprintf('导出工况 %d / %d 的温度和热流时序。',k,height(summary)), ...
        sprintf('Exporting temperature and heat-flow histories: case %d / %d.',k,height(summary)));
    row=summary(k,:);
    filename=sprintf('case_%02d_h%d_b%02d_g%.2f',row.case_id,row.altitude_km,row.target_beta_deg,row.conductance_wk);
    saved=load(fullfile(dataDirectory,[filename '.mat']),'result');
    r=saved.result;
    names=arrayfun(@(id) sprintf('node_%02d_temperature_k',id),1:11,'UniformOutput',false);
    history=array2table([r.timeS r.temperatureK sum(r.loads.totalExternalW,2)], ...
        'VariableNames',[{'elapsed_s'} names {'total_external_power_w'}]);
    writetable(history,fullfile(outputDirectory,[filename '.csv']));
end
fprintf('SWEEP36_OPEN_DATA_EXPORTED=%d\n',height(summary));
end
