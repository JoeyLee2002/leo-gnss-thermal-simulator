# MinXSS 真实在轨温度独立检验

这不是数据导入演示。脚本使用真实遥测、实际热求解器、独立留出数据计算温度预测误差。
结果可能通过，也可能不通过；软件会保留全部结果与限制说明。

## 运行

在项目目录启动 MATLAB：

```matlab
startup
addpath('examples')
runDir = run_minxss_flight_validation;
```

大型原始文件放在 `results/minxss_physical_validation/raw`。首次获取地址：
[NASA Level 0C netCDF](https://spdf.gsfc.nasa.gov/pub/data/aaa_smallsats_cubesats/minxss/minxss-1/mission_netcdf/minxss1_solar-sxr_level0c_20160516_v002.ncdf)。

也可以分阶段执行，方便检查协议和冻结参数：

```matlab
addpath('studies/minxss')
runDir = run_minxss_validation('prepare');
run_minxss_validation('fit', runDir);
run_minxss_validation('score', runDir);
```

每次创建新结果目录；不会覆盖已评分的结果。重复运行相同日期的留出集不会产生新的独立验证证据。

## 模型

- 单节点展开板：吸收直射太阳辐射，扣除实测电输出，加入常数环境热输入，向外辐射散热。
- 双节点展开板：区分电池片与基板，用对称导热项连接，输出基板温度。
- 未标定先验、无储热稳态和初温保持：用于判断标定和热容是否真正带来预测价值。

没有使用接收机温度通道驱动面板温度，没有拟合后对测试曲线做平移、偏置校正或幅值缩放。

## 数据规则

必须具备有效包校验、时间、姿态、参考状态、科学模式、温度与电功率。
日照时要求太阳方向合理；日影状态与显著电输出冲突的记录剔除。
保留原始顺序和原始时间戳，坏行即断开，相邻间隔超过 60 秒即断开。

输入质量筛查后，合格长段主要是单独的日照或阴影片段。因此首轮使用至少 30 分钟的有效段、排除前 10 分钟，检验段内升温或降温。
不填补日影转换附近的无效记录，不把当前结果当作完整入影出影时序验证。

按日期分组：2016-09-01 前为训练集，2016-09-01 至 2016-10-20 前为模型选择集，2016-10-20 起为留出测试集。
同一天不分给不同集合；共享热记忆的近邻片段不随机交叉划分。

## 输出

- 旧版归档使用 `实测独立检验结果.md`；v0.4.2 起的新运行使用 `实测开发复算结果.md`。
  这些日期已经用于模型调试，沿用原分组不等于获得新的独立测试证据。
- `protocol_before_fit.json`：拟合之前的协议。
- `arc_manifest_before_fit.csv`、`row_audit.csv`：样本清单与每条原始数据的筛查原因。
- `frozen_models_before_test.json`：测试之前固定的参数和模型选择。
- `all_arc_metrics.csv`、`heldout_day_summary.csv`：所有模型逐段与按日误差。
- `arc_*_predictions.csv`：每一个原始历元的实测值、预测值及驱动信息。
- `observed_segment_dynamics.csv`：原始采样窗口内的动态变化，不是插值获得的精确相位滞后。
- `timestep_convergence.csv`：10 秒与 1 秒积分步长的对比。
- `figures_zh`、`figures_en`：全部留出段图片，中英图例分别完整。
- `posthoc_integrity_audit.json`、`诊断与结论边界.md`：从逐点导出重新计算误差，检查分组隔离与未测量初始状态敏感性；不再拟合参数。

## 结论范围

这是给定实测输入与首个实测温度的条件预测。缺少真实几何视因子、铰链导热和完整传感器不确定度，不能等同整星或 GNSS 接收机的完整认证。
模型参数只能在训练集拟合；参考测试结果后再修改模型，必须另找未查看数据才能再次声称独立验证。
