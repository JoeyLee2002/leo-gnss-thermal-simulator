# LEOTherm v1.2.7

## 中文

本次发布汇总 v1.2.0 之后的报告、指标、元数据与 Windows 运行改进。

- 报告增加节点名称、热输入构成、实际导热路径、周期热响应、网格复核与任务总结。
- 按最新反馈删除开头的“关键发现与解读”；删除说明性页脚，页码居中；正文两端对齐、末行左对齐。
- 修正轨道坐标定义的记录与遥测比较状态，保留计算与数据来源。
- 初始界面默认英文，仍支持中文；附英文介绍与中文完整教程。
- 更新 v1.2.7 双语文字教程，应用包内提供 `USAGE_CN.md` 和 `USAGE_EN.md`；旧视频明确保留原录制版本。
- 提供中英文 19 页参考报告。参考模型案例不等同于在轨物理验证。

Windows 用户下载 `LEOTherm_1.2.7_windows.zip`，完整解压后启动 `LEOTherm.exe`。
需要免费的 MATLAB Runtime R2021b，不需要 MATLAB 许可证。
本包不包含 Runtime，不是旧的 1.2.1 免安装整包。旧报告不自动改写，请用新版重新导出。

本版 15 项专项测试通过，中英文 38 页完成渲染检查；独立 Runtime GUI 流水线与 PDF 导出退出码为 0。
这不是全部功能的无缺陷保证，也不是新的云端或实测物理验证。

## English

This release collects report, metric, metadata and Windows runtime improvements since v1.2.0.

- Task reports include named thermal nodes, heat-source shares, actual conductive paths, orbital thermal response, refinement checks and closing conclusions.
- The opening synthesis chapter and footer disclaimer are removed. Page numbers are centered; body paragraphs are justified except their final lines.
- Orbit coordinate definitions and telemetry-comparison status are recorded explicitly.
- New sessions start in English; Chinese remains available. English and Chinese tutorials are included in the repository.
- Updated v1.2.7 written guides are included as `USAGE_EN.md` and `USAGE_CN.md` in the application ZIP; existing videos retain their recording-version labels.
- Bilingual reference PDFs contain 19 pages each; these reference-model cases are not flight validation.

Download and extract `LEOTherm_1.2.7_windows.zip`, then start `LEOTherm.exe`.
Free MATLAB Runtime R2021b is required; a MATLAB license is not. Runtime is not bundled.
Re-export your task to obtain the updated report layout.

Validation: 15 targeted tests passed; all 38 reference-PDF pages were rendered and checked.
The independent Runtime GUI pipeline and PDF-export smoke test completed with exit code 0.
See `docs/verification_v1.2.7.md` for scope and evidence.
