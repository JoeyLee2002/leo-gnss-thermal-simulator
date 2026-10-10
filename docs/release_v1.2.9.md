# LEOTherm v1.2.9

## English

This release updates scientific figures and report presentation while retaining the thermal model and numerical solver.

- Native MATLAB figures share a consistent layout, colour scheme, named-node labels and legends; quantitative exports include 300 dpi PNG and vector PDF.
- The conductive network is presented as an annotated conductance matrix (W/K). The default model retains all 15 reciprocal links.
- A single eligible peak-delay value is reported in text instead of an almost empty chart. Multiple eligible cycles retain their signed values and original cycle identifiers.
- Reports and publication figures use the same exported graphics and retain their source data.
- Bilingual quick-start guides, example reports and a runnable six-case reference task accompany this release.

Verification: 41/41 targeted regression tests passed; Code Analyzer reported no findings in the three checked implementation files. The six-case reference task was rerun with v1.2.9 and its time axis, temperatures and sweep table matched the archived reference exactly. The compiled graphical pipeline completed under independent R2021b Runtime libraries on the development host. These checks are not a new full-suite, clean-OS or cross-platform validation.

For Windows without MATLAB, download `LEOTherm_1.2.9_windows.zip`, install MATLAB Runtime R2021b separately, extract the archive, and launch `LEOTherm.exe`. This ZIP does not include Runtime. Source users can open the repository root in MATLAB, add `examples` to the path and run `paper_example_v1_2_9`.

## 中文

本版统一原生 MATLAB 科研图形，改用带热导数值的连接矩阵，并将单个有效周期的峰值时延改为文字报告。模型、求解器及数值验收阈值不变。

发布附件包含 Windows 应用包、中英文示例报告和 SHA-256 校验值。应用包不包含 Runtime；无 MATLAB 的用户需另行安装 MATLAB Runtime R2021b。中英文教程已同步更新。六工况复现入口为 `examples/paper_example_v1_2_9.m`。

本版通过 41 项定向测试，六工况重跑结果与归档基准完全一致，并完成开发主机上的独立 Runtime 图形流水线测试。详细范围见 `docs/verification_v1.2.9.md`。
