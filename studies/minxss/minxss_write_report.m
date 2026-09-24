function minxss_write_report(runDir,metrics,summary,numerics,frozen,p)
%MINXSS_WRITE_REPORT Report failures and scope as prominently as successes.
path = fullfile(runDir,'实测独立检验结果.md');
development = isfield(p,'evidenceRole') && startsWith(p.evidenceRole,'development_');
if development, path = fullfile(runDir,'实测开发复算结果.md'); end
fid = fopen(path,'w','n','UTF-8'); assert(fid>=0,'Cannot write report.');
clean = onCleanup(@()fclose(fid));
if development
    fprintf(fid,['# MinXSS-1 太阳能板开发集复算\n\n' ...
        '**这些日期的结果已经在旧实验中被查看。本报告沿用历史时间分组，仅用于软件开发复算，' ...
        '不是新的独立验证。下文“留出”指原始分组标签，不代表数据对本次软件开发仍然盲测。**\n\n']);
else
    fprintf(fid,'# MinXSS-1 太阳能板独立实测检验\n\n');
end
fprintf(fid,'## 这次实际检验了什么\n\n');
fprintf(fid,['使用 NASA 发布的真实 MinXSS-1 遥测，调用本软件原有 `leotherm.solveThermalNetwork` ' ...
    '求解器预测两块展开式太阳能板温度。不是生成仿真真值后自测，也不是在同一批数据上拟合后打分。' ...
    '本次是任务专用简化热网络的实测检验，不是默认 GNSS 十一节点整星模型的直接认证。\n\n']);
fprintf(fid,'训练、模型选择、测试按时间分开：2016-09-01 之前训练，之后至 2016-10-20 之前选择模型，2016-10-20 起留出测试。跨边界弧段不使用。\n\n');
fprintf(fid,['**输入质量导致的协议修订：** 原拟检验至少 90 分钟连续弧段，但在光照转换附近剔除不一致输入后，' ...
    '没有弧段满足条件。因此在开始拟合之前，将首轮限定为至少 30 分钟的有效日照/阴影段内动态，' ...
    '排除前 10 分钟。未桥接被剔除的转换区间，本结果不能验证入影/出影瞬间的时序精度。\n\n']);
fprintf(fid,'模型选择仅依据验证集的等弧段权重平均 MSE 开平方：单节点 %.3f K，双节点 %.3f K；预先规定差异小于 0.2 K 时选择单节点。最终选择：**%s**。\n\n', ...
    frozen.validationOneRMSEK,frozen.validationTwoRMSEK,zhModel(frozen.selected));
for label={'train','validation','test'}
    t=metrics(strcmp(metrics.split,label{1}) & strcmp(metrics.model,frozen.selected),:);
    splitLabels=struct('train','训练集','validation','模型选择集','test','留出测试集');
    fprintf(fid,'- %s：%d 个弧段，%d 个不同日期，%d 个有效评分点（两块板合计）。\n', ...
        splitLabels.(label{1}),numel(unique(t.arc)),numel(unique(t.day)),sum(t.score_samples));
end
fprintf(fid,'\n## 留出测试结果\n\n');
fprintf(fid,'先在每条弧段按原始时间间隔加权计算误差，再按日期汇总；下表不同日期等权。不能将相邻温度记录数当成独立重复数。\n\n');
fprintf(fid,'| 模型 | 日期等权平均 RMSE / K | 通过绝对误差目标的日期 | 通过幅度目标的日期 |\n| --- | ---: | ---: | ---: |\n');
for k=1:numel(p.modelNames)
    t=summary(strcmp(summary.model,p.modelNames{k}),:);
    fprintf(fid,'| %s | %.3f | %d/%d | %d/%d |\n',zhModel(p.modelNames{k}),mean(t.mean_rmse_K), ...
        sum(t.all_absolute_pass),height(t),sum(t.all_amplitude_pass),height(t));
end
fprintf(fid,'\n| 留出日期 | 弧段数 | 所选模型平均 RMSE / K | 平均偏差 / K | 全部绝对误差目标通过 | 全部幅度目标通过 |\n');
fprintf(fid,'| --- | ---: | ---: | ---: | --- | --- |\n');
t=summary(summary.selected_model,:);
for k=1:height(t)
    fprintf(fid,'| %s | %d | %.3f | %.3f | %s | %s |\n',t.day{k},t.arcs(k), ...
        t.mean_rmse_K(k),t.mean_bias_K(k),yesNo(t.all_absolute_pass(k)),yesNo(t.all_amplitude_pass(k)));
end
fprintf(fid,'\n## 怎么判断结果\n\n');
fprintf(fid,'以下同时公开所选模型在日照和阴影段内的误差，不根据哪个子集表现好来改变主要结论。\n\n');
fprintf(fid,'| 光照条件 | 弧段数 | 两板逐段平均 RMSE / K | 两板逐段平均偏差 / K |\n| --- | ---: | ---: | ---: |\n');
for phase={'sunlight','eclipse','mixed'}
    subset=metrics(strcmp(metrics.split,'test') & strcmp(metrics.model,frozen.selected) ...
        & strcmp(metrics.illumination,phase{1}),:);
    if isempty(subset),continue;end
    labels=struct('sunlight','日照','eclipse','阴影','mixed','包含转换');
    fprintf(fid,'| %s | %d | %.3f | %.3f |\n',labels.(phase{1}),numel(unique(subset.arc)), ...
        mean(subset.rmse_K),mean(subset.bias_K));
end
fprintf(fid,'\n');
fprintf(fid,['在读取测试误差之前固定的工程目标为：每板每弧段 RMSE <= %.1f K、绝对偏差 <= %.1f K、' ...
    '95%% 绝对误差分位数 <= %.1f K；温度幅度误差 <= max(%.1f K, %.0f%% 实测幅度)。' ...
    '幅度定义为时间加权 95%% 与 5%% 温度分位数之差。\n\n'], ...
    p.acceptance.rmseK,p.acceptance.absoluteBiasK,p.acceptance.p95AbsoluteK, ...
    p.acceptance.amplitudeAbsoluteToleranceK,100*p.acceptance.amplitudeRelativeError);
fprintf(fid,['这些是本次预设的应用检验目标，不是传感器厂家精度或统一行业认证标准。' ...
    '未取得完整传感器校准不确定度，因此即使误差达标，也不能宣称计量溯源认证通过。' ...
    '所有原分组弧段均保留。是否属于开发复算，应以上方证据身份声明为准。\n\n']);
if all(t.all_absolute_pass & t.all_amplitude_pass)
    fprintf(fid,'**所选模型在本次所有留出日期上满足预设误差与幅度目标。证据仅限本简化面板模型和已覆盖工况。**\n\n');
else
    fprintf(fid,'**所选模型未在所有留出日期上满足目标，因此不能宣布物理检验全面通过。** 通过与失败的日期都已列出。\n\n');
end
fprintf(fid,'同时满足绝对误差与温度幅度目标的日期：**%d/%d**。\n\n',sum(t.all_absolute_pass & t.all_amplitude_pass),height(t));
fprintf(fid,'## 热方程与参数\n\n');
fprintf(fid,['单节点：`C dT/dt = alpha S A cos(theta) - P_electric + Q_env - epsilon_area sigma (T^4 - T_space^4)`。' ...
    '日影中直射项为零。双节点将电池片与基板分开，增加对称导热项 `G(T_cell-T_substrate)`，预测基板温度。' ...
    '环境项分别取每块板固定的非负功率，全部只在训练期标定。\n\n']);
fprintf(fid,'固定假设：单面面积 %.3f m²、正面发射率 %.2f、背面发射率 %.2f、电池片热容 %.1f J/K。面积和电池片热容是近似建模值，不是本机实测标定证书。\n\n', ...
    p.areaM2,p.frontEmissivity,p.backEmissivity,p.cellCapacityJK);
fprintf(fid,'| 参数 | 单节点 | 双节点 | 约束/单位 |\n| --- | ---: | ---: | --- |\n');
names={'基板热容','太阳吸收率','负 Y 板等效环境输入','正 Y 板等效环境输入','电池片至基板导热'};
units={'J/K','无量纲','W','W','W/K'};
for k=1:5
    first='不适用'; if k<=4, first=sprintf('%.6g',frozen.one.parameters(k)); end
    fprintf(fid,'| %s | %s | %.6g | %.4g 至 %.4g %s |\n',names{k},first, ...
        frozen.two.parameters(k),p.two.lower(k),p.two.upper(k),units{k});
end
fprintf(fid,'\n单节点参数接近边界：`%s`；双节点：`%s`。接近边界按允许范围的 2%% 判断，可能提示缺失物理项或可辨识性不足。\n\n', ...
    mat2str(frozen.one.nearBound),mat2str(frozen.two.nearBound));
fprintf(fid,'优化器退出标志：单节点 %d，双节点 %d。非正退出标志表示达到预算或未正常收敛，不得描述为已经找到最优参数。\n\n', ...
    frozen.one.exitflag,frozen.two.exitflag);
fprintf(fid,'## 数值与防泄漏检查\n\n');
fprintf(fid,'- 留出弧段积分步长由 10 s 缩小至 1 s，最大温差 %.6g K。此项只验证数值收敛，不等于实测一致性。\n',max(numerics.maximum_10s_vs_1s_difference_K));
fprintf(fid,'- 仅每条弧段的首个实测温度作为初始条件；前 %.0f 分钟不评分。未在弧段中途使用目标温度更新状态。\n',p.excludeInitialS/60);
fprintf(fid,'- 样本均使用原始时间戳；无插值、重采样、缺口补点或预测曲线时间平移。相邻输入间采用左端保持，这是离散输入近似，不是观测恢复。\n');
fprintf(fid,'- 任一坏行会分段；相邻间隔超过 %.0f 秒也会分段。短于 %.0f 分钟的段不进入实验。\n',p.maximumGapS,p.minimumArcS/60);
fprintf(fid,'- 先保存协议、弧段名单，再保存模型冻结文件，最后评分。最优模型仅由验证集选出，表中两个候选的测试结果均公开，不再据此换模型。\n');
fprintf(fid,'- 静态对照和初值保持对照用于排除“温度本来稳定”或“无需热容也能预测”的解释。\n\n');
fprintf(fid,['无储热对照保留单节点模型的训练参数，只去掉储热项，因此是参数固定的消融，' ...
    '不是单独重新标定后的最优静态模型。未标定先验结合文献光学属性与工程近似值，也不是参考论文完整模型的严格复现。\n\n']);
fprintf(fid,'## 仍然不能据此声称的内容\n\n');
fprintf(fid,['1. 不能把本结果当作整星、GNSS 接收机温度或 POD 效果的验证。\n' ...
    '2. 尚未重建轨道相关的地球红外、反照率和视因子；常数环境热输入只能近似这些效应，跨季节失败是重要模型证据。\n' ...
    '3. 未显式建模展开板铰链导热和空间温度梯度；太阳能板测点不能保证代表整个面板均温。\n' ...
    '4. 温度传感器精度、面积、热容和光学参数仍有不确定度；拟合得到的等效参数不能自动解释成材料本征参数。\n' ...
    '5. 当前是给定实际电输出、光照与起始温度的条件预测，不是完全不使用遥测的轨道驱动冷启动预测。\n' ...
    '6. `observed_segment_dynamics.csv` 记录原始离散观测窗口内的温度变化及极值位置；' ...
    '两端实际光照转换未同时观测到时，不把它解释为完整轨道相位滞后。没有插值得到亚采样精度，也没有移动预测曲线。\n\n']);
fprintf(fid,'## 来源与复现\n\n');
fprintf(fid,'- [NASA 原始遥测](https://spdf.gsfc.nasa.gov/pub/data/aaa_smallsats_cubesats/minxss/minxss-1/mission_netcdf/)\n');
fprintf(fid,'- [MinXSS 变量说明](https://lasp.colorado.edu/minxss/data/level-0c/)\n');
fprintf(fid,'- [任务热模型与在轨检验论文](https://doi.org/10.2514/1.T5169)\n');
fprintf(fid,'- [任务设计论文作者稿](https://arxiv.org/abs/1508.05354)\n\n');
fprintf(fid,'协议：`protocol_before_fit.json`；输入筛选：`row_audit.csv`；样本：`arc_manifest_before_fit.csv`；冻结参数：`frozen_models_before_test.json`；逐点预测：`arc_*_predictions.csv`。\n');
end

function text = zhModel(name)
switch name
    case 'literature_prior', text='未标定物理先验';
    case 'one_node', text='单节点热模型';
    case 'two_node', text='双节点热模型';
    case 'no_storage', text='无储热稳态对照';
    case 'persistence', text='初始温度保持';
end
end

function value = yesNo(flag)
if flag, value='是'; else, value='否'; end
end
