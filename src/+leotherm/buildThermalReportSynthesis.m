function synthesis = buildThermalReportSynthesis(bundle, report)
%BUILDTHERMALREPORTSYNTHESIS Link measured results to task-specific conclusions.
synthesis = struct('overview', section('关键发现与解读','Key findings and interpretation'), ...
    'conclusion', section('任务总结','Task conclusions'), ...
    'details', struct('stage',{},'linesZh',{},'linesEn',{}), 'evidence', table);
records = cell(0,4);
r = getField(bundle,'scenario',[]);
if isstruct(r) && isscalar(r) && all(isfield(r,{'timeS','temperatureK','network'}))
    nodal(r);
end
% Optional-stage findings come from the same scored records used in their chapters.
if isfield(report,'analysis')
    for k=1:numel(report.analysis)
        item=report.analysis(k);
        if ~ismember(item.stage,{'sweep','geometry','calibration','telemetry'}), continue; end
        count=2;
        if strcmp(item.stage,'calibration'), count=5; end
        if strcmp(item.stage,'sweep'), count=3; end
        if strcmp(item.stage,'geometry'), count=4; end
        zh=strjoin(item.linesZh(1:min(count,numel(item.linesZh))),' ');
        en=strjoin(item.linesEn(1:min(count,numel(item.linesEn))),' ');
        overview([item.titleZh '：' zh],[item.titleEn ': ' en]);
        conclusion([item.titleZh '：' zh],[item.titleEn ': ' en]);
    end
end
calibration=getField(bundle,'calibration',[]);
metrics=getField(calibration,'stageMetrics',table);
required={'role','used_samples','baseline_rmse_k','calibrated_rmse_k'};
if istable(metrics) && all(ismember(required,metrics.Properties.VariableNames))
    roles={'train','validation','test'}; labels={'训练','验证','测试'};
    for k=1:numel(roles)
        valid=strcmp(string(metrics.role),roles{k}) & isfinite(metrics.used_samples) ...
            & metrics.used_samples>0 & isfinite(metrics.baseline_rmse_k) ...
            & isfinite(metrics.calibrated_rmse_k) & metrics.baseline_rmse_k>=0 ...
            & metrics.calibrated_rmse_k>=0;
        if ~any(valid), continue; end
        weights=metrics.used_samples(valid); weights=weights/sum(weights);
        before=sqrt(sum(weights.*metrics.baseline_rmse_k(valid).^2));
        after=sqrt(sum(weights.*metrics.calibrated_rmse_k(valid).^2));
        change=after-before;
        if change<0
            actionZh='降低'; actionEn='decreased';
        elseif change>0
            actionZh='增加'; actionEn='increased';
        else
            actionZh='变化'; actionEn='changed';
        end
        zh=sprintf('标定效果：%s集 RMSE %s %.4g K（%.4g → %.4g K）。',labels{k},actionZh,abs(change),before,after);
        en=sprintf('Calibration effect: %s RMSE %s by %.4g K (%.4g to %.4g K).',roles{k},actionEn,abs(change),before,after);
        suffixZh=''; suffixEn='';
        if before>0
            suffixZh=sprintf('相对标称模型变化幅度为 %.1f%%。',100*abs(change)/before);
            suffixEn=sprintf(' Change magnitude relative to the nominal model: %.1f%%.',100*abs(change)/before);
        end
        overview([zh suffixZh],[en suffixEn]); conclusion([zh suffixZh],[en suffixEn]);
        record(['calibration_' roles{k} '_rmse_change'],change,'K','sample-weighted pooled RMSE after minus before');
    end
end
grid=getField(report,'gridComparison',table);
if istable(grid) && ~isempty(grid)
    last=grid(end,:);
    zh=sprintf('步长复核：最细一对 %g/%g s 的全节点最大温差 %.4g K，响应节点 %.4g K。该差值用于衡量本次结果对时间步长的敏感程度。', ...
        last.coarse_step_s,last.fine_step_s,last.maximum_temperature_difference_k,last.response_maximum_difference_k);
    en=sprintf('Step-size check: the finest %g/%g s pair differs by up to %.4g K across nodes and %.4g K at the response node, quantifying time-step sensitivity for this task.', ...
        last.coarse_step_s,last.fine_step_s,last.maximum_temperature_difference_k,last.response_maximum_difference_k);
    conclusion(zh,en);
    record('finest_grid_maximum_difference',last.maximum_temperature_difference_k,'K','report.gridComparison');
end
synthesis.evidence=cell2table(records,'VariableNames',{'metric','value','unit','source'});

    function nodal(result)
        t=result.timeS(:); T=result.temperatureK; n=result.network;
        if numel(t)<2 || size(T,1)~=numel(t) || any(~isfinite(t)) || ...
                any(diff(t)<=0) || any(~isfinite(T(:)))
            error('leotherm:ReportHistory','Synthesis requires finite, ordered thermal histories.');
        end
        duration=t(end)-t(1);
        namesZh=leotherm.nodeDisplayNames(n.nodeNames,'zh');
        namesEn=leotherm.nodeDisplayNames(n.nodeNames,'en');
        span=max(T,[],1)-min(T,[],1);
        [hot,hotNode]=max(max(T,[],1)); [cold,coldNode]=min(min(T,[],1));
        [largest,variableNode]=max(span);
        record('maximum_temperature',hot,'K','scenario.temperatureK');
        record('minimum_temperature',cold,'K','scenario.temperatureK');
        record('largest_nodal_range',largest,'K','scenario.temperatureK');
        record('hottest_node_id',hotNode,'node','scenario.network.nodeNames');
        record('coldest_node_id',coldNode,'node','scenario.network.nodeNames');
        record('largest_range_node_id',variableNode,'node','scenario.network.nodeNames');
        zh=sprintf('温度水平与温度波动需分开看：最高温出现在%s（%.2f K），最低温出现在%s（%.2f K）；峰峰差最大的是%s（%.2f K）。', ...
            namesZh{hotNode},hot,namesZh{coldNode},cold,namesZh{variableNode},largest);
        en=sprintf('Temperature level and variation describe different demands: the maximum is at %s (%.2f K), the minimum at %s (%.2f K), and the largest full range at %s (%.2f K).', ...
            namesEn{hotNode},hot,namesEn{coldNode},cold,namesEn{variableNode},largest);
        overview(zh,en); detail('temperatures',zh,en);
        conclusion(sprintf('后续设计复核可分别聚焦%s的高温水平、%s的低温水平，以及%s的温度波动；本次对应极值 %.2f/%.2f K、最大峰峰差 %.2f K。', ...
            namesZh{hotNode},namesZh{coldNode},namesZh{variableNode},hot,cold,largest), ...
            sprintf('Prioritize the high-temperature level at %s, low-temperature level at %s, and variation at %s in design review: extrema %.2f/%.2f K and largest range %.2f K.', ...
            namesEn{hotNode},namesEn{coldNode},namesEn{variableNode},hot,cold,largest));
        loads=getField(result,'loads',struct);
        keys={'directSolarW','albedoW','earthIRW'};
        if all(isfield(loads,keys))
            q=zeros(numel(t),3);
            for j=1:3
                values=loads.(keys{j});
                if size(values,1)~=numel(t) || any(~isfinite(values(:))) || any(values(:)<0)
                    error('leotherm:ReportHistory','Heat-source histories must be finite, nonnegative and epoch aligned.');
                end
                q(:,j)=sum(values,2);
            end
            means=trapz(t,q,1)/duration;
            if sum(means)>0
                shares=100*means/sum(means); [~,dominant]=max(shares);
                sourcesZh={'太阳直射','地球反照','地球红外'};
                sourcesEn={'direct solar','Earth albedo','Earth infrared'};
                zh=sprintf('外部吸热的时间积分占比为：太阳直射 %.1f%%、地球反照 %.1f%%、地球红外 %.1f%%。%s贡献最大；这是外部吸热构成，不把功率占比直接等同于温度变化贡献。',shares,sourcesZh{dominant});
                en=sprintf('Time-integrated external heat shares are %.1f%% direct solar, %.1f%% albedo and %.1f%% Earth infrared. %s contributes most to external absorption; these are heat-input shares, not temperature-response attribution.',shares,sourcesEn{dominant});
                overview(zh,en); detail('heat_inputs',zh,en);
                conclusion(sprintf('环境输入复核优先关注%s：其占外部吸热 %.1f%%；温度响应同时结合下述传热通道与周期相位判断。',sourcesZh{dominant},shares(dominant)), ...
                    sprintf('Prioritize %s in environmental-input review: it supplies %.1f%% of absorbed external heat. Interpret temperature response together with the heat-transfer paths and orbital phase.',sourcesEn{dominant},shares(dominant)));
                for j=1:3, record(['external_share_' keys{j}],shares(j),'percent','trapz(timeS, absorbed power)'); end
            end
        end
        response=getField(getField(n,'roles',struct),'response',[]);
        if isempty(response), response=find(strcmp(n.nodeNames,'gnss_rf_frontend'),1); end
        if isnumeric(response) && isscalar(response) && isfinite(response) && ...
                response>=1 && response<=size(T,2) && response==fix(response)
            if largest>0
                ratio=100*span(response)/largest;
                record('response_to_largest_nodal_range',ratio,'percent','full peak-to-peak ranges');
                zh=sprintf('%s的完整峰峰差为 %.3f K，是全网最大峰峰差的 %.1f%%。因此评估接收机温度稳定性应直接看该节点，不能用外表面或全网极值代替。',namesZh{response},span(response),ratio);
                en=sprintf('%s has a full range of %.3f K, %.1f%% of the largest nodal range. Assess response-node stability directly rather than substituting exterior or network-wide extremes.',namesEn{response},span(response),ratio);
                overview(zh,en); detail('temperatures',zh,en);
                conclusion(sprintf('响应部件%s在本窗口的温度范围为 %.3f 至 %.3f K，峰峰差 %.3f K；这些数值与整星极值分开用于设备复核。', ...
                    namesZh{response},min(T(:,response)),max(T(:,response)),span(response)), ...
                    sprintf('The response component %s spans %.3f to %.3f K, with a full range of %.3f K. Use these component values separately from spacecraft extrema.', ...
                    namesEn{response},min(T(:,response)),max(T(:,response)),span(response)));
            end
            G=getField(n,'conductanceWK',[]);
            if isequal(size(G),[size(T,2),size(T,2)]) && all(isfinite(G(:)))
                neighbors=find(G(response,:)>0);
                if ~isempty(neighbors)
                    flow=(T(:,response)-T(:,neighbors)).*G(response,neighbors);
                    net=trapz(t,flow,1)/duration;
                    [peak,at]=max(abs(net));
                    if peak>1e-12
                        peer=neighbors(at);
                        from=response; to=peer;
                        if net(at)<0, from=peer; to=response; end
                        zh=sprintf('对%s相连的导热路径积分后，平均净传热量最大的路径是%s → %s，为 %.3f W；该节点向相邻节点的平均净导热总量为 %.3f W（正值向外）。这比只数连接条数更能定位本次实际传热通道。', ...
                            namesZh{response},namesZh{from},namesZh{to},peak,sum(net));
                        en=sprintf('Among links connected to %s, the largest absolute mean net transfer is %s to %s at %.3f W. Total mean net conduction from the response node is %.3f W (positive outward). This identifies an active path using heat flow rather than link count.', ...
                            namesEn{response},namesEn{from},namesEn{to},peak,sum(net));
                        overview(zh,en); detail('conductance',zh,en);
                        conclusion(sprintf('安装接触与热导参数复核可优先检查%s与%s之间的连接：本次平均净热流为 %.3f W；此排序依据实际热流，不代表改动热导后的灵敏度试验。',namesZh{from},namesZh{to},peak), ...
                            sprintf('Prioritize the %s / %s contact in conductance review: mean net transfer is %.3f W. This ranking uses observed model heat flow, not a conductance-perturbation experiment.',namesEn{from},namesEn{to},peak));
                        record('response_mean_net_conduction_outward',sum(net),'W','trapz(timeS, G*(T_response-T_neighbor))/duration');
                        record('largest_response_link_mean_net_flow',peak,'W','maximum absolute mean net response-link flow');
                        record('response_link_from_node',from,'node','scenario.network.nodeNames');
                        record('response_link_to_node',to,'node','scenario.network.nodeNames');
                    end
                end
            end
        end
        harmonic=getField(report,'harmonicResponse',[]);
        period=getField(getField(result,'orbit',struct),'periodS',NaN);
        if isstruct(harmonic) && ~isempty(harmonic) && harmonic.available && ...
                isscalar(period) && isfinite(period) && period>0
            delay=harmonic.phaseDelayS; fraction=100*abs(delay)/period;
            if delay>=0, directionZh='滞后'; directionEn='lags';
            else, directionZh='超前'; directionEn='leads'; end
            zh=sprintf('轨道基频上，响应温度相对全网络外部吸热%s %.2f min，相当于一个轨道周期的 %.1f%%。这说明只按同一时刻的热流大小解释温度会遗漏周期相位差；此数值是基频相位关系，不是热量传播耗时。',directionZh,abs(delay)/60,fraction);
            en=sprintf('At the orbital fundamental, response temperature %s total external absorption by %.2f min, or %.1f%% of an orbit. Same-time heat-input comparisons omit this phase relationship; the value is not a heat-transport travel time.',directionEn,abs(delay)/60,fraction);
            overview(zh,en); detail('orbital_response',zh,en); conclusion(zh,en);
            record('orbital_phase_fraction',fraction,'percent','abs(phaseDelayS)/periodS');
        end
    end
    function overview(zh,en)
        synthesis.overview.linesZh{end+1}=zh;
        synthesis.overview.linesEn{end+1}=en;
    end
    function conclusion(zh,en)
        synthesis.conclusion.linesZh{end+1}=zh;
        synthesis.conclusion.linesEn{end+1}=en;
    end
    function detail(stage,zh,en)
        synthesis.details(end+1)=struct('stage',stage,'linesZh',{{zh}},'linesEn',{{en}});
    end
    function record(metric,value,unit,source)
        records(end+1,:)={metric,value,unit,source};
    end
end

function item=section(zh,en)
item=struct('titleZh',zh,'titleEn',en,'linesZh',{{}},'linesEn',{{}});
end

function value=getField(source,key,fallback)
value=fallback;
if isstruct(source) && isscalar(source) && isfield(source,key), value=source.(key); end
end
