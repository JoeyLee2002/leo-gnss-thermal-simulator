function item = buildPaperStudyReport(bundle)
%BUILDPAPERSTUDYREPORT Derive study plots and conclusions from this run only.
item=struct('stage',{},'titleZh',{},'titleEn',{},'linesZh',{},'linesEn',{},'figureStem',{},'charts',{});
if ~isstruct(bundle.metadata) || ~isfield(bundle.metadata,'paperStudy'), return; end
p=bundle.metadata.paperStudy; t=struct2table(p.summary);
heights=[400 600 800]; betas=[0 30 60 75]; gs=[0.31 0.62 1.24];
required={'altitude_km','target_beta_deg','conductance_wk','rf_span_k','harmonic_delay_s','harmonic_available','eclipse_fraction','periodic_error_k'};
if ~all(ismember(required,t.Properties.VariableNames)) || height(t)~=36
    error('leotherm:PaperStudyReport','The report requires the complete 36-case study.');
end
if any(~isfinite(t.rf_span_k) | ~isfinite(t.harmonic_delay_s) | ~t.harmonic_available | t.periodic_error_k>1e-3)
    error('leotherm:PaperStudyReport','Study results failed numeric or periodic checks.');
end
charts=struct('kind',{},'x',{},'y',{},'xZh',{},'xEn',{},'yZh',{},'yEn',{},'legendZh',{},'legendEn',{},'panelLabel',{});
changes=zeros(12,4); pair=0;
for h=1:3
    spans=zeros(4,3); delays=spans;
    for b=1:4
        pair=pair+1; eclipses=zeros(1,3);
        for g=1:3
            row=t(t.altitude_km==heights(h) & t.target_beta_deg==betas(b) & abs(t.conductance_wk-gs(g))<1e-9,:);
            if height(row)~=1, error('leotherm:PaperStudyReport','Each factor combination must occur exactly once.'); end
            spans(b,g)=row.rf_span_k; delays(b,g)=row.harmonic_delay_s/60;
            eclipses(g)=row.eclipse_fraction;
        end
        if spans(b,1)<=0, error('leotherm:PaperStudyReport','A positive baseline percentile difference is required.'); end
        changes(pair,:)=[100*(spans(b,3)/spans(b,1)-1), ...
            60*(delays(b,1)-delays(b,3)),100*(1-delays(b,3)/delays(b,1)),all(eclipses>0)];
        if any(eclipses>0) && ~all(eclipses>0), error('leotherm:PaperStudyReport','Illumination classification changed with conductance.'); end
    end
    labels=cellstr(compose('G = %.2f W/K',gs));
    c=struct('kind','line','x',betas(:),'y',spans,'xZh','目标 β 角 / °','xEn','Target beta angle (deg)', ...
        'yZh','射频前端温度百分位差 / K','yEn','RF temperature P95-P5 (K)', ...
        'legendZh',{labels},'legendEn',{labels},'panelLabel',sprintf('%c  %d km','a'+h-1,heights(h)));
    charts(h)=c;
    c.y=delays; c.yZh='轨道基频相位时延 / min'; c.yEn='Orbital-frequency phase delay (min)';
    c.panelLabel=sprintf('%c  %d km','d'+h-1,heights(h)); charts(h+3)=c;
end
e=changes(changes(:,4)==1,:); s=changes(changes(:,4)==0,:);
if isempty(e) || isempty(s), error('leotherm:PaperStudyReport','Both illumination classes are required.'); end
zh={ '36 工况采用 400、600、800 km 高度，0°、30°、60°、75°目标 β 角，以及 0.31、0.62、1.24 W/K 结构—射频前端等效热导。其他设备参数保持相同。', ...
    '每个工况先达到周期温差不超过 0.001 K 的初始化条件，再分析 6 个轨道周期，每圈 360 个输出间隔。时延以所有节点吸收的外部功率总和为参考。', ...
    sprintf('射频前端温度百分位差 P95-P5 为 %.3f～%.3f K。',min(t.rf_span_k),max(t.rf_span_k)), ...
    sprintf('等效热导由 0.31 增至 1.24 W/K：入影工况温度百分位差增加 %.1f%%～%.1f%%，持续光照工况减少 %.1f%%～%.1f%%。',min(e(:,1)),max(e(:,1)),min(-s(:,1)),max(-s(:,1))), ...
    sprintf('12 组高度—β 角配对的轨道基频相位时延缩短 %.1f～%.1f s（%.1f%%～%.1f%%）。增大热导对温度波动的影响随光照条件改变，而相位时延在这些配对中均缩短。',min(changes(:,2)),max(changes(:,2)),min(changes(:,3)),max(changes(:,3))) };
en={ 'The 36 cases combine 400, 600 and 800 km altitudes, target beta angles of 0, 30, 60 and 75 deg, and effective structure-to-RF thermal conductances of 0.31, 0.62 and 1.24 W/K. Other equipment parameters remain fixed.', ...
    'Each case is initialized to a periodic temperature difference of at most 0.001 K, then analyzed over six orbits with 360 output intervals per orbit. Phase delay is referenced to total external power absorbed by all nodes.', ...
    sprintf('RF front-end temperature P95-P5 ranges from %.3f to %.3f K.',min(t.rf_span_k),max(t.rf_span_k)), ...
    sprintf('Increasing effective thermal conductance from 0.31 to 1.24 W/K increases P95-P5 by %.1f-%.1f%% in eclipsing cases and decreases it by %.1f-%.1f%% under continuous sunlight.',min(e(:,1)),max(e(:,1)),min(-s(:,1)),max(-s(:,1))), ...
    sprintf('Across the 12 altitude-beta pairs, orbital-frequency phase delay decreases by %.1f-%.1f s (%.1f-%.1f%%). Conductance affects temperature fluctuations differently across illumination conditions, whereas phase delay decreases in all tested pairs.',min(changes(:,2)),max(changes(:,2)),min(changes(:,3)),max(changes(:,3))) };
if isfield(p,'refinement') && ~isempty(p.refinement)
    r=struct2table(p.refinement);
    zh{end+1}=sprintf('预先指定的 3 个工况使用每圈 720 个间隔独立重算；温度百分位差最大变化 %.4g K，相位时延最大变化 %.4g s。',max(r.rf_span_difference_k),max(r.harmonic_delay_difference_s));
    en{end+1}=sprintf('Three prespecified cases are independently recomputed with 720 intervals per orbit; maximum changes are %.4g K in P95-P5 and %.4g s in phase delay.',max(r.rf_span_difference_k),max(r.harmonic_delay_difference_s));
end
item=struct('stage','paper_study','titleZh','轨道条件与等效热导：36 工况研究','titleEn','Orbit and effective thermal conductance: 36-case study', ...
    'linesZh',{zh},'linesEn',{en},'figureStem','publication_paper_study','charts',charts);
end
