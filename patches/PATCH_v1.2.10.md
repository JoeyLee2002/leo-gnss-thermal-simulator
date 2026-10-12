# v1.2.10 补丁说明

本轮统一中英文物理术语，区分温度极差与 P95-P5、峰间时延与基频相位时延、热导与材料导热系数。软件界面、图形和报告共用指标名称，并随报告导出指标定义表。

旧版本源码已在修改前归档。热求解方程、输入参数、积分器与旧项目数据字段保留；有用的旧数据可继续读取。论文复现入口和中英文教程同时更新。
# Paper Reproduction And Tutorials

Added `leotherm.runPaperStudy` and `LEOTherm.exe --paper-study`, with the same entry available in Quick start. It recomputes the reference task, 36 conditions and three refined cases, exports full CSV histories, audits saved results, and generates bilingual reports with data-derived paired changes. All six examples are regenerated; the duplicate six-case paper example is removed. Paper and report use one six-panel renderer with a shared legend. Updated reviewer guides and bilingual narrated tutorials show control locations and actual new outputs.

