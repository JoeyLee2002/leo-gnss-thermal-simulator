# Windows standalone: LEOTherm 1.2.10

The application ZIP includes `USAGE_EN.md` and `USAGE_CN.md` with the current step-by-step task and report workflow.

1. Install free MATLAB Runtime R2021b from the MathWorks MATLAB Runtime download page.
2. Extract LEOTherm_1.2.10_windows.zip to a writable directory.
3. Open LEOTherm.exe. The initial interface is English.
4. On Quick start, choose First simulation or open a saved project. Edit the duration and output interval when needed.
5. On Simulation, select optional stages, check the task, then run it in a new directory.
6. On Results and export, open the task PDF. Inspect stage findings, charts and acceptance status.

The language selector also supports Chinese. Saved projects restore their recorded language. MATLAB itself and a MATLAB license are not required for this executable. Runtime R2021b is required.

Each run retains its input snapshot, frozen model, numerical results, stage status, plots and analysis PDF. Reference models and synthetic examples teach the workflow; replace them with mission-specific inputs for satellite validation.

## Reproduce the SoftwareX Experiments

On Quick start, select **Paper: reference task and 36 cases**, then click **Reproduce paper and report**. Select a writable parent folder and wait for the calculation to finish. The application creates a new task folder containing the reference simulation, 36 periodically initialized conditions, three time-refinement cases and a combined report. The selected interface language determines the GUI report language.

To produce both language reports from the executable:

```powershell
.\LEOTherm.exe --paper-study "C:\LEOThermResults\new_run" both
```

The output directory must not already exist. Read `PAPER_REPRODUCTION_EN.md` or `PAPER_REPRODUCTION_CN.md` for the fixed inputs, output files and quantitative checks. Updated narrated tutorials with control highlights are linked in `TUTORIALS.md`.

Version 1.2.8 uses shared native MATLAB figure styling and annotates the conductance matrix with actual link values. Each report chart has PNG and vector PDF exports. The `publication_*` groups and companion source MAT files can be used directly in a manuscript. Temperature samples and physical parameters are unchanged. Sample reports and a plotting guide accompany the application package.

Version 1.2.9 reports a single per-orbit peak difference in text and omits empty peak-timing charts. Multiple scored orbits retain their signed values and original cycle numbers in a chart. Energy-balance publication figures remain available independently.

Version 1.2.7 removes the opening synthesis chapter and footer disclaimer, centers page numbers, and justifies body paragraphs except their final lines. Chapter interpretation and closing task conclusions remain, including quantitative external heat shares, response-component variation and actual mean conductive paths. Optional completed stages are included. The interpretation metrics are exported as CSV for audit. Re-export results into a new directory to obtain the new report structure.

Version 1.2.5 records the built-in orbit coordinate definition and separates telemetry comparison status from orbit metadata. Run a new task to capture coordinate metadata in old projects; exporting an unlabelled historical result does not invent a reference frame. No thermal parameters or numerical algorithms changed in this patch.

Version 1.2.4 adds orbital-frequency phase metrics, named thermal nodes, conductive-network diagrams and explicit zero values. Report sections depend on the available task histories. Existing PDFs remain unchanged: run a new task or re-export current results into a new directory.

Keep an existing compatible Runtime installation. This small application package does not contain Runtime. Older portable bundles perform integrity checks, so do not overwrite their application files by hand.

Version 1.2.3 audits signed peak phases across orbits. Mixed advance/delay phases are not reduced to a positive-only median. The report recomputes this diagnostic from raw results, so older cached metrics cannot override the revised assessment. Optional supplied grid-refinement reruns add exact-epoch numerical comparisons; no interpolation or automatic convergence pass is used.
