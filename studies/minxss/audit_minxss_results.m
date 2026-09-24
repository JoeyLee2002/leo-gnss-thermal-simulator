function audit = audit_minxss_results(runDir)
%AUDIT_MINXSS_RESULTS Recompute exported errors and probe unmeasured initial states.
s=load(fullfile(runDir,'results.mat'));
p=s.frozen.protocol;
indices=find(strcmp({s.records.split},'test'));
target=s.metrics(strcmp(s.metrics.split,'test') & strcmp(s.metrics.model,s.frozen.selected),:);
maximumMetricDifference=0;
rows=cell(0,4);
latentMinimum=Inf; latentMaximum=-Inf;
for k=indices
    r=s.records(k);
    tableData=readtable(fullfile(runDir,[r.id '_predictions.csv']));
    w=[diff(tableData.elapsed_s);0]; w(tableData.elapsed_s<p.excludeInitialS)=0; w=w/sum(w);
    for j=1:2
        suffix='minus_y'; if j==2,suffix='plus_y';end
        e=tableData.([s.frozen.selected '_' suffix '_C'])-tableData.(['measured_' suffix '_C']);
        expected=target(strcmp(target.arc,r.id) & target.panel==j,:);
        maximumMetricDifference=max(maximumMetricDifference,abs(sqrt(sum(w.*e.^2))-expected.rmse_K));
    end
    if strcmp(s.frozen.selected,'two_node')
        pars=s.frozen.two.parameters;
    else
        pars=s.frozen.one.parameters;
    end
    [nominal,details]=minxss_panel_predict(r.input,pars,s.frozen.selected,p);
    latentMinimum=min(latentMinimum,min(details.trajectoryK,[],'all'));
    latentMaximum=max(latentMaximum,max(details.trajectoryK,[],'all'));
    perturbation=0;
    if strcmp(s.frozen.selected,'two_node')
        for offset=[-10 10]
            net=details.network;
            net.initialTemperatureK([1 3])=net.initialTemperatureK([1 3])+offset;
            env.deepSpaceK=p.deepSpaceK;
            limits.minimumTemperatureK=80; limits.maximumTemperatureK=600;
            forcing.holdPrevious=true; forcing.maxStepS=p.maximumStepS;
            changed=leotherm.solveThermalNetwork(r.input.elapsedS,details.netAppliedW,net,env,limits,forcing);
            difference=changed(w>0,details.targetNodes)-nominal(w>0,:);
            perturbation=max(perturbation,max(abs(difference),[],'all'));
        end
    end
    rows(end+1,:)={r.id,r.day,max(diff(r.input.elapsedS)),perturbation}; %#ok<AGROW>
end
assert(maximumMetricDifference<1e-8,'Exported predictions disagree with reported RMSE.');
allRows=vertcat(s.records.sourceRows);
assert(numel(allRows)==numel(unique(allRows)),'A source row occurs in multiple arcs.');
for labels={'train','validation';'train','test';'validation','test'}'
    first={s.records(strcmp({s.records.split},labels{1})).day};
    second={s.records(strcmp({s.records.split},labels{2})).day};
    assert(isempty(intersect(first,second)),'Dates overlap across splits.');
end
assert(max(s.numerics.maximum_10s_vs_1s_difference_K)<0.01,'Timestep convergence did not meet audit limit.');
state=cell2table(rows,'VariableNames',{'arc','day','maximum_gap_s','max_latent_initial_shift_effect_K'});
writetable(state,fullfile(runDir,'latent_initial_state_sensitivity.csv'));
audit.exportedMetricMaximumDifferenceK=maximumMetricDifference;
audit.noDuplicatedSourceRows=true;
audit.noSharedDatesBetweenSplits=true;
audit.maximumLatentInitialShiftEffectK=max(state.max_latent_initial_shift_effect_K);
audit.predictedAllNodeMinimumC=latentMinimum-273.15;
audit.predictedAllNodeMaximumC=latentMaximum-273.15;
audit.testDates=numel(unique(target.day));
audit.testArcs=numel(unique(target.arc));
audit.totalTemperatureTargets=sum(target.score_samples);
dark=target(strcmp(target.illumination,'eclipse'),:);
audit.eclipseArcs=numel(unique(dark.arc)); audit.eclipseDates=numel(unique(dark.day));
audit.eclipseMinusYMeanRMSEK=mean(dark.rmse_K(dark.panel==1));
audit.eclipsePlusYMeanRMSEK=mean(dark.rmse_K(dark.panel==2));
days=s.summary(s.summary.selected_model,:);
audit.daysPassingAllTargets=sum(days.all_absolute_pass & days.all_amplitude_pass);
audit.fullPhysicalValidationPassed=false;
audit.interpretation='limited_conditional_flight_agreement_not_whole_spacecraft_certification';
fid=fopen(fullfile(runDir,'posthoc_integrity_audit.json'),'w','n','UTF-8');
assert(fid>=0); clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(audit,'PrettyPrint',true));
clear clean
minxss_write_report(runDir,s.metrics,s.summary,s.numerics,s.frozen,p);
fid=fopen(fullfile(runDir,'诊断与结论边界.md'),'w','n','UTF-8');
assert(fid>=0); clean=onCleanup(@()fclose(fid));
fprintf(fid,'# 实测检验后的独立完整性审查\n\n');
fprintf(fid,'这是冻结参数后的诊断，未重新拟合、改变测试样本或修改通过阈值。\n\n');
fprintf(fid,'## 可以确定的结果\n\n');
fprintf(fid,'- 从逐点导出 CSV 重新计算的 RMSE 与报告最大差异：%.3g K。\n',maximumMetricDifference);
fprintf(fid,'- 训练、模型选择和测试之间无重复原始记录、无共享日期。\n');
fprintf(fid,'- 测试覆盖 %d 个日期、%d 个有效段、%d 个温度评分点；这些点不是独立重复。\n',audit.testDates,audit.testArcs,audit.totalTemperatureTargets);
fprintf(fid,'- %d/%d 个日期同时满足预设绝对误差和幅度目标，不能宣布全面通过。\n',audit.daysPassingAllTargets,audit.testDates);
fprintf(fid,'- 未观测的电池片初温人为扰动正负 10 K，在排除前 10 分钟后，对预测基板温度的最大影响为 %.4f K。这是敏感性检查，不是传感器不确定度区间。\n',audit.maximumLatentInitialShiftEffectK);
fprintf(fid,'- 所有预测节点温度范围 %.2f 至 %.2f 摄氏度。未测量节点的温度仍只是模型输出，不是额外的实测验证。\n\n',audit.predictedAllNodeMinimumC,audit.predictedAllNodeMaximumC);
fprintf(fid,'## 阴影失败集中在哪里\n\n');
fprintf(fid,'阴影留出数据只有 %d 段、%d 个日期。负 Y 面板平均 RMSE %.3f K，正 Y 面板 %.3f K。不能用日照段多数通过来代替阴影条件验证。\n\n', ...
    audit.eclipseArcs,audit.eclipseDates,audit.eclipseMinusYMeanRMSEK,audit.eclipsePlusYMeanRMSEK);
fprintf(fid,['两侧差异提示优先检查实际地球视因子、铰链导热及面板辐射属性。' ...
    '当前模型用每板一个常量等效环境热输入，没有显式表示这些随轨道变化的边界。' ...
    '这是有证据支持的排查方向，不是已查明的唯一原因。\n\n']);
fprintf(fid,'## 仍然存在的建模限制\n\n');
fprintf(fid,['- 太阳吸收率接近参数上界，不能把拟合参数当成已独立测定的材料属性。\n' ...
    '- 两个优化任务达到迭代预算，结果是受限预算下的候选解，不是已证明的全局最优。\n' ...
    '- 采用实测首温初始化，因此检验的是条件预测，不是冷启动绝对温度。\n' ...
    '- 缺失/不一致的光照转换附近数据没有补点，当前不能检验完整入影出影时序。\n' ...
    '- 面板热动态得到的实测支持不能自动扩展到整星、GNSS 接收机或 POD。\n\n']);
fprintf(fid,'## 下一轮独立检验规则\n\n');
fprintf(fid,['若根据本次失败案例修改环境或导热模型，这些已看过的测试日期就属于开发资料。' ...
    '下一轮必须另外锁定未查看的数据或其他任务，不能继续把相同样本称为新的独立测试。\n']);
disp(audit);
end
