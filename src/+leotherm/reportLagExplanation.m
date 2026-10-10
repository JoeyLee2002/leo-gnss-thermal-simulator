function text = reportLagExplanation(phase, language)
%REPORTLAGEXPLANATION Explain a missing aggregate using the measured phases.
zh = strcmp(language,'zh');
if isempty(phase)
    text = pick(zh,'未计算：结果中缺少响应节点或所需时序。', ...
        'Not calculated: the response node or required histories are absent.');
elseif isfinite(phase.peakToPeakLagMedianS)
    if phase.identifiablePeakCycles==1
        text = sprintf(pick(zh,'峰值时延 %.5g s（1 个有效周期）。', ...
            'Peak delay %.5g s (1 eligible cycle).'),phase.peakToPeakLagMedianS);
    else
        text = sprintf(pick(zh,'峰值时延 %.5g s（%d 个有效周期）。', ...
            'Peak delay %.5g s (%d eligible cycles).'), ...
            phase.peakToPeakLagMedianS,phase.identifiablePeakCycles);
    end
elseif phase.mixedPhaseSigns
    v = phase.signedPeakPhaseByCycleS;
    text = sprintf(pick(zh, ...
        '%d 圈温度峰值在热流峰值之后，%d 圈在之前，%d 圈同一采样时刻；逐圈折叠时间差为 %.0f 至 %.0f s，采用逐圈图展示。', ...
        'Temperature peaks follow heat peaks in %d cycles, precede them in %d, and coincide in %d; wrapped differences range from %.0f to %.0f s and are shown per cycle.'), ...
        nnz(v>0),nnz(v<0),nnz(v==0),min(v),max(v));
elseif phase.completeCycles == 0
    text = pick(zh,'未计算峰值时延：本段没有覆盖至少 90% 轨道周期且含至少 8 个采样点的周期。', ...
        'Peak delay not calculated: no cycle covers at least 90% of an orbit with at least 8 samples.');
elseif ~isempty(phase.signedPeakPhaseByCycleS) && all(phase.signedPeakPhaseByCycleS < 0)
    v = phase.signedPeakPhaseByCycleS;
    if numel(v)==1
        text = sprintf(pick(zh,'折叠峰值时间差 %.5g s（1 个周期）；负值表示温度峰值较早，不是正向响应时延。', ...
            'Wrapped peak difference %.5g s (1 cycle); the negative sign indicates an earlier temperature peak, not a positive response delay.'),v);
    else
        text = pick(zh,'各圈折叠峰值时间差均为负，不能作为热流到温度的正向响应时延；逐圈结果见图。', ...
            'All wrapped peak differences are negative; they do not yield a positive heat-to-temperature delay. See the per-cycle results.');
    end
else
    text = sprintf(pick(zh,'检查了 %d 个周期，但没有通过峰值时延筛选的周期（需信号有变化、采样连续、峰值唯一且时间差非负）。', ...
        '%d cycles checked; none meets the peak-delay criteria: varying signals, continuous sampling, unique peaks and nonnegative phase.'),phase.completeCycles);
end
end

function out = pick(zh,a,b)
if zh, out = a; else, out = b; end
end
