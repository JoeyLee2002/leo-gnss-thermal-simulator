# LEOTherm 1.5 — Illustrated Windows Release

**从这里开始 / Start here:** double-click [START_HERE.html](START_HERE.html).

完整解压，安装免费的 MATLAB Runtime R2021b，双击 `LEOTherm.exe`。不需要 MATLAB 许可证。第一次运行要建立缓存；请等待主界面显示。

Extract the entire package, install free MATLAB Runtime R2021b, and launch `LEOTherm.exe`. No MATLAB licence is needed. The first launch builds the Runtime cache.

| Guide | Offline illustrated HTML | Printable PDF |
| --- | --- | --- |
| 中文用户手册 | [USAGE_CN.html](USAGE_CN.html) | [USAGE_CN.pdf](USAGE_CN.pdf) |
| English User Manual | [USAGE_EN.html](USAGE_EN.html) | [USAGE_EN.pdf](USAGE_EN.pdf) |
| 中文论文复现 | [PAPER_REPRODUCTION_CN.html](PAPER_REPRODUCTION_CN.html) | [PAPER_REPRODUCTION_CN.pdf](PAPER_REPRODUCTION_CN.pdf) |
| English Paper Reproduction | [PAPER_REPRODUCTION_EN.html](PAPER_REPRODUCTION_EN.html) | [PAPER_REPRODUCTION_EN.pdf](PAPER_REPRODUCTION_EN.pdf) |

用户手册每种语言包含13幅标注图；论文复现每种语言包含4幅图。橙框、编号及图下说明告诉你点击哪里、填什么、怎么核对。HTML里的图可以点击放大，不依赖联网。

Each user manual has 13 annotated figures; each reproduction guide has 4. Orange outlines, numbered controls and legends explain where to click, what to enter and what to check. Click an HTML image for full size; all assets are local.

## Choose the Right Run

- **Only one scenario:** Simulation > Single scenario > **Run single scenario**. No automatic PDF.
- **A complete task with report:** configure inputs, select needed stages, **Check complete task**, then **Run complete task and generate report**.
- **Export existing results:** Results and export > **Generate analysis PDF**.
- **Published paper:** Quick start > **Paper: reference task and 36 cases** > **Reproduce paper and report**.

For both paper-report languages in one run, use a **new, nonexistent** destination:

```powershell
.\LEOTherm.exe --paper-study "C:\LEOThermResults\paper_run_01" both
```

GUI folder pickers take an existing parent folder and create a new child; the command takes the new task directory itself.

Small tutorial meshes and a canonical model are included under `examples`. They demonstrate setup, not a real satellite. JSON templates remain under `templates`.

This update changes documentation and example inputs only. `LEOTherm.exe` is byte-for-byte identical to the tested v1.5 release:

```text
SHA-256 CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE
```

The original release and its verification record are preserved. See [REPORT_AUDIT_CN.md](REPORT_AUDIT_CN.md) and [PATCH_v1.5_illustrated_manuals.md](PATCH_v1.5_illustrated_manuals.md). Videos retain their v1.2.10 labels; current run buttons are documented in these illustrated manuals.

Keep `manual_images` beside the HTML/Markdown files. PDF files embed their images and can be viewed separately.
