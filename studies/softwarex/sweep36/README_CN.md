# SoftwareX 论文：36工况公开复现材料

本目录提供论文使用的36工况完整数据、输入参数、运行脚本和原生 MATLAB 绘图程序。
`archive/` 是原LEOTherm 1.2.9公开数据，保留 `v1.2.9-sweep36.1` 标签与校验值。
新计算使用当前安装版本；v1.2.10推荐入口为 `leotherm.runPaperStudy`，同时完成
参考任务、36工况、三个步长加密算例及综合报告，详见[新版复现说明](../../../docs/论文结果复现_v1.2.10.md)。

## 不运行软件也能看结果

- [36工况汇总表](archive/sweep36/sweep36_summary.csv)。
- [完整模型与实验参数](archive/open_data/protocol.json)。
- [节点编号、名称及参数](archive/open_data/reference_nodes.csv)和[导热连接](archive/open_data/reference_links.csv)。
- [36工况逐时刻温度与外部总热流 CSV](archive/open_data/)。
- [论文图5](archive/figures/Figure_5_sweep36.png)、[矢量 PDF](archive/figures/Figure_5_sweep36.pdf)及[中文版图](archive/figures/Figure_5_sweep36_zh.png)。
- [三组时间步加密结果](archive/sweep36/time_refinement.csv)及[独立数据检查](archive/sweep36/audit.csv)。
- [公开脚本复现验证记录](verification.json)。

`archive/sweep36/` 保留36个原始 MAT 文件、3个加密 MAT 文件、协议和汇总 MAT。
每个工况中都有场景、网络、轨道、热载荷、温度、指标、预热收敛记录和数值诊断。
CSV 提供跨软件可读的时间序列；MAT 保留完整计算结构。所有归档文件均有
`archive/manifest.json` 中的 SHA-256 校验值。

## 运行环境

复算与重绘使用 **Windows 上的 MATLAB R2021b（桌面及 JVM 环境）**。
本实验不使用 Aerospace Toolbox 或 Optimization Toolbox，图形完全由 MATLAB 原生生成。
Runtime不能直接执行可编辑的 `.m` 脚本；v1.2.10编译程序已包含完整论文复现入口，
可从快速开始选择论文任务，或使用 `LEOTherm.exe --paper-study 新目录 both`。
源代码采用仓库 MIT 许可证；本目录原始仿真数据及图形采用 [CC BY 4.0](DATA_LICENSE.md)。

## 先校验数据，再重绘图5

在 MATLAB 中打开下载的仓库根目录，执行：

```matlab
addpath(fullfile(pwd,'src'),fullfile(pwd,'studies','softwarex','sweep36'));
verify_sweep36_archive;
study = fileparts(which('verify_sweep36_archive'));
make_sweep36_figure_v129(fullfile(study,'archive','sweep36'));
```

归档校验程序检查原文件SHA-256；新计算的参数组合、收敛情况和模型一致性由独立结果审计检查。
重绘结果写入 `results/softwarex_sweep36/figures/`，包含中英文 PNG、矢量 PDF、
可编辑 FIG 和图形数据 MAT。程序不会向归档目录写入。

## 从零复算论文任务

```matlab
addpath(fullfile(pwd,'src'));
study = leotherm.runPaperStudy(fullfile(pwd,'results','my_paper_run'),'both');
```

程序先运行两小时参考任务并生成 PDF 分析报告，然后计算36个周期初始化工况、
3个时间步加密工况，检查结果并生成图5及综合报告。输出为 `results/my_paper_run/`。
整个论文复现任务要求新的输出目录；第二次运行可以指定：

```matlab
study = leotherm.runPaperStudy(fullfile(tempdir,'leotherm_manuscript_run_02'),'both');
```

加入研究脚本路径后，程序根据自身位置寻找计算引擎，不依赖某个盘符，也不依赖
MATLAB 后续的当前目录。输入配置和新结果不覆盖归档数据。

## 只复算36工况，或断点续跑

```matlab
studyOutput = fullfile(tempdir,'leotherm_sweep36_run_01');
summary = run_paper_sweep36_v129(studyOutput);
audit_sweep36_v129(studyOutput);
make_sweep36_figure_v129(studyOutput);
export_sweep36_open_data(studyOutput);
```

想先试3个工况，可执行 `run_paper_sweep36_v129(studyOutput,3)`，随后使用不带数量
参数的命令完成其余工况。只有完整实验参数、计算源代码指纹、已存输入和汇总指标
一致时才复用结果；不一致会提示换一个输出目录。计算不插值、不补齐样本。

## 实验参数

| 变量 | 设置 |
| --- | --- |
| 轨道高度 | 400、600、800 km |
| 目标有符号 beta 角 | 0、30、60、75 度 |
| 主体结构（7）与射频前端（9）等效热导 | 0.31、0.62、1.24 W/K |

合计 3 × 4 × 3 = **36个确定性工况**。只改变7—9的双向导热连接；其他热容、
功耗、光学参数和热导均相同。三档热导分别为参考值的一半、原值和两倍，属于
参数研究设置。

历元为2024-03-20 12:00:00 UTC，倾角97.6度，对地姿态。根据目标 beta 角反求
升交点赤经并检查可达性；固定历元太阳向量，关闭 J2 漂移。
预热至少5圈、至多80圈，连续两圈同相位节点最大温差小于0.001 K 后进入分析。
分析覆盖6个完整轨道周期，每圈360个等时间间隔。
预先指定第2、20、36工况，将每圈间隔数加密到720并重新初始化。

射频温度P95−P5为第95百分位数减第5百分位数，单位K；轨道基频相位时延相对于卫星吸收的外部
总功率计算，CSV 为秒，图5显示为分钟。两小时参考任务未预热，单独展示初始
温度调整过程，与36工况的周期响应属于两种分析设置。

## 怎么理解结果

36工况全部在16—19圈内收敛。射频温度P95−P5为0.995—6.048 K，轨道基频相位时延37.18—43.43 min。
在本次参考网络中，beta角0、30、60度时，增大等效热导会增大温度P95−P5；
75度持续光照时趋势反转。在全部12个高度与 beta 角组合中，增强热导都会缩短
轨道基频相位时延。这些结论对应本研究的参考网络及已计算的轨道条件。

加密检查中，所有节点温度的最大差为0.219 K，射频温度跨度差小于0.0006 K，
谐波时延差小于0.13 s。能量闭合指标检查的是数值能量账目。

`elapsed_wall_s` 是原始工况的计算耗时，取决于机器性能，不参与物理结果一致性
比较。CSV 列名包含单位；`eclipse_fraction` 是按时间加权的地影占比；布尔列为0/1。
逐时刻 CSV 中的节点编号对应 `reference_nodes.csv`。

## 验证一份新下载的源代码

```matlab
verify_sweep36_release(fullfile(tempdir,'leotherm_release_check_01'));
```

该命令在新的输出目录完成参考任务、36工况、3个加密工况和绘图，并逐列比较
复算指标与公开归档；同时检查断点续跑、错误参数缓存和归档写保护。
每次验证请使用新的目录。完整英文说明见 [README.md](README.md)。
