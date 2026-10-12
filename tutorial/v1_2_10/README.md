# v1.2.10 paper reproduction tutorials

- [中文视频](LEOTherm_v1.2.10_paper_tutorial_zh.mp4) (3:16) / [中文字幕](LEOTherm_v1.2.10_paper_tutorial_zh.srt)
- [English video](LEOTherm_v1.2.10_paper_tutorial_en.mp4) (2:49) / [English captions](LEOTherm_v1.2.10_paper_tutorial_en.srt)
- Chapter timing: [Chinese](timeline_zh.json), [English](timeline_en.json).

The bilingual tutorials demonstrate the production GUI, highlight the controls to select, and show reports and plots from a newly completed reference + 36-case + three-refinement run. A highlighted control indicates where the viewer should click. These are narrated GUI-state captures with instructional click-location overlays, not a continuous recording of physical mouse events. Computation time is omitted; the captions say when to wait.

Source reproduction:

```matlab
addpath('src');
study=leotherm.runPaperStudy(fullfile(pwd,'results','my_paper_run'),'both');
```

See `docs/reproduce_paper_v1.2.10.md` and the Chinese counterpart for the full protocol, inputs, outputs and quantitative checks. Older full-function tours remain archived and cover the optional geometry, telemetry and calibration workflows; this version prioritizes reproducing the experiments actually reported in the paper.

Build the videos with `capture_paper_tutorial`, `render_paper_tutorial.py --prepare`, `narrate.ps1`, then `render_paper_tutorial.py`. Each video has narration, burned-in captions, a separate SRT and chapter timing JSON.
