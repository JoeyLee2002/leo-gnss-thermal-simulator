# 低轨卫星热仿真工作台

**当前发行版：[LEOTherm v1.5](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/tag/v1.5)。**

下载[带图解手册的 Windows 发行包](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/download/v1.5/LEOTherm_1.5_windows_release_illustrated.zip)，完整解压，先打开 `START_HERE.html`，再运行 `LEOTherm.exe`。需要另行安装免费的 **MATLAB Runtime R2021b**，无需 MATLAB 许可证；发行包不包含 Runtime。

[中文图解用户手册](docs/usage_v1.5_zh.md) · [English User Manual](docs/quickstart_v1.5.md) · [中文论文复现](docs/reproduce_paper_v1.5_zh.md) · [English Paper Reproduction](docs/reproduce_paper_v1.5.md)

用户手册每种语言有13幅标注图，论文复现各有4幅；包内同时提供离线 HTML 和 PDF。页面自己的按钮只计算当前模块，上方完整任务区执行所选阶段并生成报告。见[发行验证记录](docs/verification_v1.5_release.md)与[图解手册补丁说明](patches/PATCH_v1.5_illustrated_manuals.md)。

v1.5 提供中英文进度、协作式停止与关闭、英文生成文件名、文件选择框后的窗口恢复及隐藏报告绘图。发行记录包括444项完成的测试、7个直接 Runtime 检查模式和40个论文求解任务；MATLAB 开发环境的退出异常单独记录，不计作通过。

高级页面与图表按需加载。图解包的可执行程序与实测版逐字节一致，没有删除或修改 Runtime 文件。

## 当前版本怎么用

源码：在仓库根目录的MATLAB中执行 `addpath('src')`，再执行 `leotherm.runPaperStudy(fullfile(pwd,'results','my_paper_run'),'both')`。
图形界面：快速开始选择“复现论文：参考任务与36工况”，点击“复现论文并生成报告”，选择保存位置即可。
Windows程序需免费的MATLAB Runtime R2021b，不需要MATLAB许可证。

[中文示例报告](examples/reports/thermal_report_v1.5_zh.pdf) · [English report](examples/reports/thermal_report_v1.5_en.pdf) · [术语和指标定义](docs/术语与指标.md) · [本版补丁](patches/PATCH_v1.5.md) · [本版测试记录](docs/verification_v1.5.md)

## 历史版本与资料

[v1.2.10 标签](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/tree/v1.2.10)及381项测试记录继续原样保留。新运行使用 v1.5 及其图解说明；旧源码、研究数据和发行版均保留，便于追溯。
在发布页 Assets 中下载 Windows 应用包，配合免费的 MATLAB Runtime R2021b 使用。
不需要购买 MATLAB；已有兼容 Runtime 无需重装。
旧免安装整包仍为 1.2.1，不是本次新版；其[使用说明](docs/免安装版使用.md)保留供旧版用户参考。

**历史 v1.2.10 资料：**[中文使用教程](docs/使用教程_v1.2.10.md) ·
[English guide](docs/quickstart_v1.2.10.md) ·
[下载 Windows 独立版 v1.2.10](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/download/v1.2.10/LEOTherm_1.2.10_windows.zip)。
独立版不需要购买 MATLAB，但必须安装免费的 MATLAB Runtime R2021b；
安装步骤见[英文独立版使用说明](docs/standalone_en.md)，启动后可切换中文。

历史 **1.2.9**：删除开头的“关键发现与解读”，保留章节分析与末尾总结；正文两端对齐，删除说明性页脚，页码居中。热仿真计算不变。见[历史更新说明](patches/PATCH_v1.2.9.md)。
见[新版报告使用说明](docs/详细分析报告_v1.2.2.md)。启动界面和内置示例默认使用英文，可切换中文。
[英文介绍视频（v1.2.1 录制）](tutorial/english_intro_v1_2_1/LEOTherm_English_Introduction.mp4)和[中文完整教程（v1.2.0 录制）](tutorial/v1_2_0_full/README_CN.md)保留供学习流程；当前报告样式及导出步骤以 v1.2.9 文字教程为准。
基础仿真始终运行，扫描、三维耦合、遥测对比和设备标定均可按需勾选或跳过；完成的阶段会进入[分析报告](docs/任务分析报告_v1.2.0.md)。
先看[新版中文报告](examples/reports/thermal_report_v1.2.9_zh.pdf)，本例使用参考热网络和已有四组时间网格结果。
没有 MATLAB 的 Windows 用户可使用[独立版安装说明](docs/独立版使用_v1.2.0.md)；
需要另装免费的 MATLAB Runtime R2021b。
本版专项测试与独立 Runtime 检查见[验收记录](docs/verification_v1.2.9.md)。
论文的**36工况轨道与等效热导研究**提供[完整数据、图形及复现教程](studies/softwarex/sweep36/README_CN.md)，
见[研究材料发布页](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/tag/v1.2.9-sweep36.1)。
重复的旧六工况示例已由 `leotherm.runPaperStudy` 替代；已发表的 v1.2.9 归档原样保留。
第一次使用请看[统一任务流水线指南](docs/统一任务流水线_v1.1.0.md)。
发布测试与适用边界见[软件验收记录](docs/软件验收_v1.0.0.md)。
场景、扫描、热网络、
遥测和标定统一作为一个仿真任务的配置。每次运行都可以冻结为带任务 ID 和输入指纹的快照。
v1 改动见[补丁说明](patches/PATCH_v1.0.0.md)。
独立版改动见[v1.0.1 补丁说明](patches/PATCH_v1.0.1.md)。
v0.5.1 的论文一实验和 0.4.5 的项目保存、精确 UTC 时间、
过期结果保护、遥测预检和可取消扫描继续保留。
任务对象、冻结快照、运行历史和输入指纹的说明见[任务工作台说明](docs/易用性改进_v0.7.0.md)。

0.4.3 新增“设备标定”：用户设备标称参数、明确的硬范围、参数偏移惩罚和冻结后的整日检查。
默认锁定全部参数，不会为贴合遥测自动扩大范围。参见[设备受约束标定使用说明](docs/设备受约束标定使用说明.md)。
0.4.3 的历史验收见[验收报告](docs/软件验收报告_v0.4.3.md)。

真实在轨温度检验入口：[MinXSS 实测验证](studies/minxss/README_CN.md)。
实验直接调用热求解器，按日期隔离训练与测试，保留全部成功和失败结果；不把数据导入测试当作物理验证。

这是一个完全使用 MATLAB 实现、无第三方运行依赖的低轨卫星热仿真项目，主要研究：

- 轨道高度、倾角、RAAN、日期和姿态如何决定 β角与入影结构；
- 太阳直射、地球反照和地球红外如何作用于卫星不同表面；
- 多节点热容和节点间导热如何产生加热、冷却滞后；
- GNSS天线、射频前端、振荡器和数字板温度如何映射为半仿真的码偏差。

## 快速运行

推荐第一次使用直接启动图形界面。启动后默认进入“快速开始”，不需要先理解全部专业参数：

```matlab
cd('项目所在目录')
launch_gui
```

快速开始页新增“任务向导”。用户可以选择内置 JSON 模板，也可以选择自己复制修改的模板；
向导只要求任务名、仿真时长和时间步长，需要遥测时再选择 CSV。模板通过严格校验后可以立即运行，
不需要在高级 GUI 中逐项填写全部参数。模板位于 `templates/`，说明见
[任务向导与模板](docs/任务向导与模板.md)。

图形界面首先提供“快速开始、仿真、结果与导出”三个主区域。选择“高级仿真”后，可进入单场景仿真、参数扫描、热网络编辑、三维几何、遥测与验证和设备标定配置页。
所有输入仍使用核心求解器的严格校验，不会绕过物理约束。
顶部语言选项可在中文和英文之间切换；切换时保留当前场景、热网络和已有结果。
中文版的界面、状态、表格和图表使用中文，英文版全部使用英文。所有诊断图都带有
与当前语言一致的图例。

三维几何工作区支持导入 STL/OBJ 表面网格、单位转换、网格质量统计、三维旋转预览，以及在当前
太阳姿态下查看面片太阳直射和总外部辐射功率，并运行包含面片间红外交换的三维面片热仿真。可在
三维几何页开启太阳自遮挡，程序会对每个面片中心向太阳发射射线并记录逐面片可见率。节点温度
求解仍使用集中参数热网络；面片求解尚未包含三维实体导热。结果会分别保存地影可见率和叠加结构
自遮挡后的逐面片可见率。

同时提供独立的 Gmsh ASCII 2.x 四面体体网格导入和有限元导热 API，用于三维实体内部导热验证。该路径
也可以在三维几何页通过 GUI 导入、设置材料并运行；使用共形边界网格时还可以运行表面—体耦合示例。它暂不自动连接面片太阳、地球红外、面间辐射
边界；材料密度、比热和导热系数必须由用户提供。多材料体网格可通过四面体 Physical Tag 和
`material.regionProperties` 显式分区；缺失或未匹配的标签会报错。当前不支持 Gmsh 二进制文件、
MSH 4.x 或高阶单元。

命令行 API 还提供严格的研究级表面到体网格热载荷耦合、接触热导/热流账本、外部轨道姿态任务包导入
以及统一中英文结果报告。耦合默认只接受共节点、共边界三角形的精确匹配，不对非匹配网格偷偷插值；
外部任务包要求 UTC、严格递增历元和明确的姿态四元数约定。

`leotherm.simulateSurfaceVolumeScenario` 可把轨道/姿态驱动的面片外部辐射热流、精确表面—体边界匹配、
体内有限元导热、显式接触和固定温度边界串成一个可重复工作流。当前采用守恒的单向耦合：面片外部辐射
作为体网格输入热流，面片温度只作为独立预览，不反馈到体网格。可用
`leotherm.writeSurfaceVolumeScenarioResult` 一键导出耦合诊断、体网格时序和中英文报告。

## 成熟热软件接入与用户扩展

本版本提供 `leotherm.adapter.v1` 适配器 SDK。用户可以注册 MATLAB handler，或从 JSON/MAT
元数据描述文件加载适配器后，在 MATLAB 代码中显式附加 handler：

```matlab
adapter = leotherm.adapter.get('generic_exchange');
[model, audit] = leotherm.adapter.execute(adapter, 'readModel', 'model.json');
```

同时提供 Thermal Desktop、ESATAN-TMS、SINDA/FLUINT 和 OpenFOAM 的受控接入配置档。它们要求用户使用
官方导出器或许可的 batch 接口生成明确的交换文件或 case，再由
`leotherm.io.runExternalThermalSolver` 运行。运行器不经过 shell，拒绝命令元字符，限制输出目录，
保存 stdout/stderr、退出码、超时状态和 SHA-256 文件指纹。`leotherm.report.writeThermalSimulationReport`
可生成中英文 Markdown、CSV、MAT 审计数据和 JSON manifest。

这表示“可接入标准交换格式、官方导出器和受控命令行接口”，不表示已经原生解析这些软件的专有格式；
文件交换成功、数值一致或外部命令返回 0，也不等于热真空、在轨或物理正确性验证。完整边界见
[适配器开发指南](docs/适配器开发指南.md)。

命令行方式：

```matlab
cd('项目所在目录')
startup
leotherm.version
leotherm.selfTest
run_baseline
run_beta_altitude_sweep
addpath(fullfile(pwd, 'studies', 'paper1'))
run_paper1_experiments('smoke')
```

命令行示例默认生成中文图，也可以显式选择英文：

```matlab
run_baseline('en')
run_beta_altitude_sweep('en')
leotherm.plotScenario(result, 'summary.png', 'zh')
leotherm.plotSweep(summary, 'sweep.png', 'en')
```

结果写入 `results/`，包括：

- 完整MATLAB结果文件；
- 可直接用于论文统计的CSV；
- 节点参数和导热矩阵；
- 场景时序图和高度—β角汇总图。

## 示例项目

首次使用也可以在“快速开始”页点击“打开示例项目”，直接载入完整的 MAT 工作区：

- `examples/projects/01_first_simulation.mat`：第一次仿真；
- `examples/projects/02_thermal_lag_24h.mat`：24 小时热滞后分析；
- `examples/projects/03_physical_sweep.mat`：日期、倾角、RAAN 和高度扫描；
- `examples/projects/04_telemetry_validation.mat`：内置合成遥测导入和验证流程；
- `examples/projects/05_3d_geometry.mat`：STL/OBJ 面片和 Gmsh 四面体体网格。

这些项目用于学习和功能演示，不代表真实卫星标定结果。工程模型交换示例
`examples/projects/06_engineering_model_exchange.json` 只用于字段和单位检查。
详细说明见
[示例项目说明](examples/projects/README.md)。

## 工程热模型接入

“仿真”区域新增“工程热模型”页，可导入或导出 `leotherm.thermal_model.v1`
格式的 MAT/JSON 模型。导入前会检查 schema、SI 单位、UTC 时间、有限数值和输入
指纹；失败时不会替换当前工作区。模型摘要会显示来源、节点数、材料数和校验状态。
材料库中的数值均为带来源标记的参考值，不能直接解释为某颗卫星的实测材料参数。
完整字段和适用边界见[热模型扩展工作流](docs/热模型扩展工作流.md)。

## 遥测驱动与验证

0.4.0新增“遥测与验证”页，可导入CSV并指定时间、单位、质量标记和传感器对应节点。
支持轨道遥测驱动、逐节点热功率驱动、已有单场景结果与测温对比三种工作流。
轨道模式要求同一J2000地心惯性系下的轨道和太阳位置；不自动转换地固系。
坏数据和过大间隔断段，不补齐、不插值。温度仅作验证，除非明确选择用首值初始化。
输出包括偏差、平均绝对误差、均方根误差、逐样本采用记录及完整输入归档。
不能把电压当热功率，也不能把较小的误差自动解释为物理正确。

详细步骤见[遥测导入与验证](docs/遥测导入与验证.md)。合成示例可运行
`run_telemetry_demo`，明确标注为功能演示，不是卫星实测验证。
真实GRACE-FO数据准备与结论边界见[真实遥测案例](studies/telemetry/README_CN.md)。

## 两类轨道实验

### 严格控制的高度—β角实验

`leotherm.runBetaAltitudeSweep` 根据日期、倾角和目标β角反求RAAN。若该倾角在该日期不可能达到目标β角，程序会标记为 `inaccessible`，不会插值，也不会用邻近β角代替。

### 真实几何实验

`leotherm.runPhysicalSweep` 直接输入日期、轨道高度、倾角和RAAN，β角是仿真输出。这适合分析季节、倾角和RAAN怎样共同改变光照结构。

`leotherm.simulateTrajectory` 可以直接接收外部ECI轨道和姿态历史，因此后续可接入精密轨道、任务姿态遥测或独立生成的Basilisk/SPICE结果，同时保持本项目代码为纯MATLAB。

软件会在积分前检查场景单位范围、轨道历元维数、有限值以及姿态矩阵的正交性和右手性。非法输入会返回稳定的 `leotherm:*` 错误标识，不会静默生成结果。

## 默认多节点网络

默认模型包含11个节点：

1. 六个卫星外表面；
2. 卫星主体结构；
3. GNSS天线；
4. GNSS射频前端；
5. 频率基准/振荡器；
6. 接收机数字板。

所有热容、导热系数、光学参数、内部功耗和温度—码偏差灵敏度都集中在 `leotherm.defaultReceiverNetwork` 中，便于做参数不确定性分析和任务标定。

## 结果边界

默认网络是物理上合理的参考模型，但不是KOMPSAT-5或其他卫星的已标定热模型。因此它可以用于：

- 热滞后机制分析；
- 检测边界半仿真；
- 模型失配与消融；
- POD影响桥接前的真值生成。

它不能直接证明某颗真实卫星的部件温度或码偏差幅值。任务级结论需要热真空试验、温度遥测或公开结构参数进行标定。

## 开源准备

项目采用MIT许可证。SATMO、Corpino等人的论文和Basilisk只作为方法与验证依据，没有复制或重新分发其源代码。详细边界见 `NOTICE.md`、`docs/model.md` 和 `docs/validation.md`。

完整操作步骤、参数表和问题排查见 `docs/用户使用说明书.md`。
图形工作台的逐页说明见 `docs/图形界面使用说明.md`。

每次更新前必须运行 `tools/create_version_snapshot.m` 保存旧版本，并在
`patches/` 中新增补丁说明。具体规则见 `docs/versioning.md`。

SATMO式七节点趋势基准可通过 `run_satmo_style_benchmark` 运行；该案例不等同于
使用相同输入和输出完成的严格SATMO数值复现。

第一篇热滞后机理论文的完整实验设计、断点续跑和结果输出见
`studies/paper1/README_CN.md`。正式配置包含965个确定性工况和150个配对不确定性
样本，所有失败或不可达状态均保留且不插值。

用于检查热储存来源和数值敏感性的补强实验见
`studies/paper1/run_gap_experiments.m`，结果写入新的
`results/paper1_gap_v0_5_1_paper`目录，不覆盖历史论文结果。
