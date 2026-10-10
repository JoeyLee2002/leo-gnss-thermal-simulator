# LEOTherm English introduction

**Recording version: v1.2.1.** For the current application, follow the
[v1.2.7 guide](../../docs/quickstart_v1.2.7.md) and inspect the
[updated English report](../../examples/reports/thermal_report_v1.2.7_en.pdf).
The video has not been re-recorded for v1.2.7: opening synthesis is removed,
page numbers are centered and body paragraphs are justified in the new reports.

Open `LEOTherm_English_Introduction.mp4`: approximately 5 minutes 25 seconds, 1920 x 1080, English narration, burned-in English subtitles and four chapters. An external subtitle file is also provided.

The video follows a task from Quick start through thermal simulation and optional stages to its analysis PDF. It uses real application captures and reports; computation waits are edited out. Report findings and charts are enlarged as excerpts for readability. It is an edited introduction, not a continuous mouse recording. Narration uses the local Microsoft Zira synthetic English voice.

The base two-hour simulation, six-case sweep, ten-minute geometry task and synthetic telemetry comparison were actually executed. Calibration is described using its configuration page; no fitted device model is claimed. Model exchange is shown without executing a commercial solver. The current surface-volume coupling is one-way. A known geometry-panel refresh issue is explained, and new results are shown from the actual task report.

## Follow the example

1. Start the new executable with MATLAB Runtime R2021b, or run `launch_gui` from the source directory. New sessions start in English.
2. Open the First simulation template. Run the task in a new output directory.
3. Add optional stages only when their inputs are available.
4. Open the analysis PDF from Results and export. Check the completed stages and numerical acceptance, then review the assumptions and data provenance.
5. Save your project. Project language is restored when reopening it; Chinese remains available from the language selector.

`examples_and_reports.zip` contains the four actual run directories and the English demonstration projects. These are reference/synthetic examples for learning the workflow, not mission validation.

## Reproduce the video

Use `capture_english_intro.m` with a new output directory to generate production screenshots and actual reports. `narrate.ps1` creates the local narration. `render_intro.py` assembles the introduction, subtitles and chapters. `review_intro.py` checks decode, dimensions, audio levels, duration and source task status, and creates sampled frames for visual review. `verification.json` records this delivery.
