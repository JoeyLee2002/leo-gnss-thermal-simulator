# Reproduce the paper (v1.2.10)

In **Quick start**, select **Paper: reference task and 36 cases**, click **Reproduce paper and report**, and choose an output parent directory. The program creates a fresh run folder, recomputes the reference task, 36 conditions and three refined cases, and opens the report. Existing workspace settings remain unchanged.

Source entry:

```matlab
addpath('src');
study = leotherm.runPaperStudy(fullfile(pwd,'results','my_paper_run'),'both');
```

Runtime entry (new executable and free MATLAB Runtime R2021b):

```powershell
.\LEOTherm.exe --paper-study "C:\LEOThermResults\paper_run_01" both
```

The output directory must not exist. Use `zh`, `en` or `both` for report languages.

The fixed study crosses three altitudes (400, 600, 800 km), four target beta angles (0, 30, 60, 75 deg), and three effective structure-to-RF thermal conductances (0.31, 0.62, 1.24 W/K). After periodic initialization to 0.001 K, six orbits are analyzed with 360 output intervals per orbit. Cases 2, 20 and 36 are independently recomputed with 720 intervals per orbit. The reference task is a separate 7200 s, 60 s-output transient run with the default 11-node network and no warmup.

Read `paper_study_status.json` for completion, `paper_results.csv` for case results, `audit.csv` for factor and numerical checks, and `sweep36/time_refinement.csv` for refinement differences. `open_data` contains all temperature histories. The task-specific reports are under `report/thermal_report_en.pdf` and `thermal_report_zh.pdf`. Publication plots use the same native MATLAB renderer as the software reports.

Temperature P95-P5 is the 95th minus 5th percentile, distinct from max-minus-min range. Orbital-frequency phase delay is referenced to external power absorbed by all nodes; it is not an intrinsic thermal time constant. See `report/thermal_metric_definitions.csv` for definitions.

Expected rounded results: 0.995–6.048 K for RF P95-P5; the 0.31-to-1.24 W/K change increases P95-P5 by 8.4–39.7% in eclipsing cases, reduces it by 10.5–12.1% under continuous sunlight, and reduces phase delay by 36.8–131.0 s across the 12 paired orbital conditions. Report conclusions are computed from the new run, not copied from the archive.

The v1.2.9 published archive remains unchanged. Existing script names and raw metric keys are retained as compatibility interfaces; new outputs provide standardized names and bilingual definitions.
