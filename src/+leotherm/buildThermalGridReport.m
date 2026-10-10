function [item, rows] = buildThermalGridReport(bundle)
%BUILDTHERMALGRIDREPORT Compare supplied reruns on exact common epochs only.
item = struct('stage',{},'titleZh',{},'titleEn',{},'linesZh',{}, ...
    'linesEn',{},'figureStem',{},'charts',{});
rows = table;
if ~isfield(bundle,'gridRefinement') || isempty(bundle.gridRefinement), return; end
runs = bundle.gridRefinement;
if ~iscell(runs) || numel(runs) < 2
    error('leotherm:ReportGridStudy','Grid study must contain at least two full simulation results.');
end
base = runs{1};
if ~isequaln(base.timeS,bundle.scenario.timeS) || ...
        ~isequaln(base.temperatureK,bundle.scenario.temperatureK)
    error('leotherm:ReportGridStudy','The first refinement result must be the reported scenario.');
end
n = numel(base.network.nodeNames); differences = zeros(n,numel(runs)-1);
values = zeros(numel(runs)-1,7); labels = cell(1,numel(runs)-1);
if isfield(base.network,'roles') && isfield(base.network.roles,'response')
    response = base.network.roles.response;
else
    response = find(strcmp(base.network.nodeNames,'gnss_rf_frontend'),1);
end
if isempty(response), error('leotherm:ReportGridStudy','A response node is required.'); end
for k = 1:numel(runs)-1
    a = runs{k}; b = runs{k+1};
    if ~isequaln(a.network,b.network) || ...
            ~isequaln(rmfield(a.scenario,'timeStepS'),rmfield(b.scenario,'timeStepS')) || ...
            a.scenario.timeStepS <= b.scenario.timeStepS
        error('leotherm:ReportGridStudy','Refinement must keep model and scenario fixed and reduce timeStepS.');
    end
    [matched,index] = ismember(a.timeS,b.timeS);
    if ~all(matched) || any(~isfinite(a.temperatureK(:))) || any(~isfinite(b.temperatureK(:)))
        error('leotherm:ReportGridStudy','All coarse epochs must exist exactly in the finer finite history.');
    end
    delta = abs(a.temperatureK-b.temperatureK(index,:));
    differences(:,k) = max(delta,[],1)';
    pa = leotherm.reportHarmonicResponse(a); pb = leotherm.reportHarmonicResponse(b);
    values(k,:) = [a.scenario.timeStepS,b.scenario.timeStepS,numel(a.timeS), ...
        max(delta(:)),max(delta(:,response)),pa.phaseDelayS,pb.phaseDelayS];
    labels{k} = sprintf('%g / %g s',a.scenario.timeStepS,b.scenario.timeStepS);
end
rows = array2table(values,'VariableNames',{'coarse_step_s','fine_step_s','shared_epochs', ...
    'maximum_temperature_difference_k','response_maximum_difference_k','coarse_orbital_phase_delay_s','fine_orbital_phase_delay_s'});
zh = {'仅比较相同设备、相同场景的独立加密重算；粗网格历元必须在细网格中精确存在。'};
en = {'Independent reruns keep the model and scenario fixed and compare exact common epochs.'};
for k = 1:size(values,1)
    zh{end+1} = sprintf('%g/%g s 网格：全节点最大差 %.4g K，响应节点最大差 %.4g K。',values(k,[1 2 4 5])); %#ok<AGROW>
    en{end+1} = sprintf('%g/%g s grids: maximum difference %.4g K; response-node difference %.4g K.',values(k,[1 2 4 5])); %#ok<AGROW>
    if all(isfinite(values(k,6:7)))
        zh{end+1}=sprintf('两网格基频相位时延分别 %.2f、%.2f s。',values(k,6:7)); %#ok<AGROW>
        en{end+1}=sprintf('Orbital-frequency delays: %.2f and %.2f s.',values(k,6:7)); %#ok<AGROW>
    end
end
zh{end+1} = sprintf('最细一组网格的全节点最大差为 %.4g K，响应节点最大差为 %.4g K；以上是本次步长敏感性复核的实测差值。',values(end,4:5));
en{end+1} = sprintf('The finest pair differs by up to %.4g K across all nodes and %.4g K at the response node; these are measured refinement differences.',values(end,4:5));
zhNames = leotherm.nodeDisplayNames(base.network.nodeNames,'zh');
enNames = leotherm.nodeDisplayNames(base.network.nodeNames,'en');
c = struct('kind','bar','x',(1:n)','y',differences, ...
    'xZh','节点编号','xEn','Node ID','yZh','共同历元最大温差 / K', ...
    'yEn','Maximum common-epoch difference / K','legendZh',{labels},'legendEn',{labels}, ...
    'nodeLabelsZh',{zhNames},'nodeLabelsEn',{enNames});
item = struct('stage','grid_refinement','titleZh','时间网格加密复核', ...
    'titleEn','Time-grid refinement audit','linesZh',{zh},'linesEn',{en}, ...
    'figureStem','detail_grid_refinement','charts',c);
end
