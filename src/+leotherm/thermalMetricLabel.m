function [label, definition] = thermalMetricLabel(name, language)
%THERMALMETRICLABEL Shared metric names; legacy data keys remain unchanged.
language = leotherm.normalizeLanguage(language);
key = lower(strrep(char(name), '_', ''));
label = ''; definition = '';
switch key
    case 'meanbetadeg'
        label=pick(language,'采样平均 β 角（°）','Sample-mean beta angle (deg)');
    case 'minimumbetadeg'
        label=pick(language,'最小 β 角（°）','Minimum beta angle (deg)');
    case 'maximumbetadeg'
        label=pick(language,'最大 β 角（°）','Maximum beta angle (deg)');
    case 'eclipsefraction'
        label=pick(language,'入影样本比例','Eclipsed-sample fraction');
        definition=pick(language,'太阳可见比例小于0.999的样本比例。','Fraction of samples with solar visibility below 0.999.');
    case 'umbrafraction'
        label=pick(language,'本影样本比例','Umbra-sample fraction');
    case 'penumbraepochs'
        label=pick(language,'半影样本数','Penumbra sample count');
    case 'eclipseentrycount'
        label=pick(language,'入影事件数','Eclipse-entry count');
    case 'eclipseexitcount'
        label=pick(language,'出影事件数','Eclipse-exit count');
    case 'illuminationtransitioncount'
        label=pick(language,'光照转换事件总数','Illumination-transition count');
    case 'eclipsetransitioncount'
        label=pick(language,'入影出影较小事件数','Minimum of entry and exit event counts');
    case 'hysteresiscompletecycles'
        label=pick(language,'滞回分析完整周期数','Complete orbits for hysteresis analysis');
    case {'antennatemperaturespank','responsetemperaturespank','rftemperaturespank','oscillatortemperaturespank'}
        switch key
            case 'antennatemperaturespank', nodeZh='天线'; nodeEn='Antenna';
            case 'oscillatortemperaturespank', nodeZh='振荡器'; nodeEn='Oscillator';
            case 'rftemperaturespank', nodeZh='响应节点'; nodeEn='Response node';
            otherwise, nodeZh='响应节点'; nodeEn='Response node';
        end
        label=pick(language,[nodeZh '温度百分位差 P95-P5（K）'], ...
            [nodeEn ' temperature P95-P5 (K)']);
        definition=pick(language,'温度第95与第5百分位数之差；不是最大值减最小值。', ...
            '95th minus 5th percentile of temperature, not maximum minus minimum.');
    case 'codebiasspanm'
        label=pick(language,'码偏差百分位差 P95-P5（m）','Code bias P95-P5 (m)');
        definition=pick(language,'仿真码偏差第95与第5百分位数之差。', ...
            '95th minus 5th percentile of simulated code bias.');
    case 'codebiasrmsm'
        label=pick(language,'去均值码偏差均方根（m）','Centered code-bias RMS (m)');
        definition=pick(language,'码偏差减去其均值后计算均方根。', ...
            'Root mean square after subtracting mean code bias.');
    case 'totalabsorbedheatspanw'
        label=pick(language,'总外部吸收功率 P95-P5（W）','Total absorbed external power P95-P5 (W)');
        definition=pick(language,'全网络外部吸收功率之和的第95与第5百分位数之差。', ...
            '95th minus 5th percentile of external absorbed power summed over all nodes.');
    case {'forcingpeaktoresponsepeaklags','forcingtoresponselags','forcingtorflags'}
        label=pick(language,'吸收功率至温度峰值时延（s）','Power-to-temperature peak time lag (s)');
        definition=pick(language,'总外部吸收功率峰与响应温度峰的时间差，按轨道周期折叠后汇总合格周期。', ...
            'Temperature-peak minus total-absorbed-power-peak time, wrapped by orbital period and summarized over eligible cycles.');
    case 'forcingtroughtoresponsetroughlags'
        label=pick(language,'吸收功率至温度谷值时延（s）','Power-to-temperature trough time lag (s)');
        definition=pick(language,'总外部吸收功率谷值与响应温度谷值的周期折叠时间差。', ...
            'Wrapped temperature-trough minus total-absorbed-power-trough time.');
    case 'forcingtocodebiaslags'
        label=pick(language,'吸收功率至码偏差峰值时延（s）','Power-to-code-bias peak time lag (s)');
        definition=pick(language,'总外部吸收功率峰与仿真码偏差峰的周期折叠时间差。', ...
            'Wrapped simulated-code-bias-peak minus total-absorbed-power-peak time.');
    case 'signedpeakphasemedians'
        label=pick(language,'周期折叠峰值时间差中位数（s）','Median wrapped peak time difference (s)');
        definition=pick(language,'保留正负号的峰值时间差；单位为秒而非角度。', ...
            'Signed peak time difference in seconds, not a phase angle.');
    case 'peakphaseidentifiable'
        label=pick(language,'峰值时延可计算','Peak time lag available');
    case 'peakphaseidentifiablecycles'
        label=pick(language,'峰值时延有效周期数','Eligible peak-time-lag cycles');
    case 'peakphasemixedsigns'
        label=pick(language,'峰值时间差包含正负号','Mixed-sign peak time differences');
    case 'peakphasesamplingresolutions'
        label=pick(language,'峰值时间差采样分辨率（s）','Peak-time sampling resolution (s)');
    case 'orbitalphasedelays'
        label=pick(language,'轨道基频相位时延（s）','Orbital-frequency phase delay (s)');
        definition=pick(language,'响应温度相对于总外部吸收功率的轨道基频相位差除以负角频率；不是热时间常数。', ...
            'Negative temperature-to-total-absorbed-power phase difference divided by orbital angular frequency; not a thermal time constant.');
    case 'orbitalphaseavailable'
        label=pick(language,'轨道基频相位时延可计算','Orbital-frequency phase delay available');
    case 'orbitalphasehalfwindowdifferences'
        label=pick(language,'前后半段相位时延差（s）','Half-window phase-delay difference (s)');
    case {'eclipseentrytotemperatureminimums','eclipseentrycoolinglags'}
        label=pick(language,'入影至温度极小时延（s）','Eclipse-entry-to-temperature-minimum lag (s)');
    case {'eclipseexittotemperaturemaximums','eclipseexitheatinglags'}
        label=pick(language,'出影至温度极大时延（s）','Eclipse-exit-to-temperature-maximum lag (s)');
    case {'responsehysteresisareawk','rfhysteresisareawk','oscillatorhysteresisareawk'}
        label=pick(language,'吸收功率-温度滞回面积（W K）','Absorbed-power-temperature hysteresis area (W K)');
        definition=pick(language,'完整轨道内功率-温度闭合曲线面积的中位数。', ...
            'Median closed power-temperature loop area over complete orbits.');
    case {'responsenormalizedhysteresisarea','rfnormalizedhysteresisarea','oscillatornormalizedhysteresisarea'}
        label=pick(language,'归一化吸收功率-温度滞回面积','Normalized power-temperature hysteresis area');
        definition=pick(language,'功率和温度分别除以其P95-P5后计算滞回面积。', ...
            'Loop area after scaling power and temperature separately by their P95-P5 differences.');
end
end

function value=pick(language,zh,en)
if strcmp(language,'zh'), value=zh; else, value=en; end
end
