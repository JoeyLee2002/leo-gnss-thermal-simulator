# Windows standalone: LEOTherm 1.5

Current release: [LEOTherm v1.5](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/tag/v1.5). Download `LEOTherm_1.5_windows_release_illustrated.zip`. Run each module using its own page button, or explicitly choose the complete-task/report action with four optional stages. Historical releases remain available.

The application ZIP includes `START_HERE.html`, bilingual illustrated user/reproduction guides, and their HTML, Markdown and PDF editions. All guide images are local. Runtime is installed separately, not bundled in this ZIP.

1. Install free MATLAB Runtime R2021b from the MathWorks MATLAB Runtime download page.
2. Extract `LEOTherm_1.5_windows_release_illustrated.zip` to a writable directory and open `START_HERE.html`.
3. Open LEOTherm.exe. The initial interface is English.
4. On Quick start, choose First simulation for a template task/report or open a saved project. Use Advanced simulation to edit and run an individual scenario.
5. On a Simulation page, use its local run button for just that module. For a complete task, select optional stages in the separate complete-task area, check it, then use the explicitly labelled task/report button.
6. On Results and export, use Generate analysis PDF to export existing results, then open the generated PDF in its output folder. Complete-task runs generate their report automatically.

The language selector also supports Chinese. Saved projects restore their recorded language. MATLAB itself and a MATLAB license are not required for this executable. Runtime R2021b is required.

Each run retains its input snapshot, frozen model, numerical results, stage status, plots and analysis PDF. Reference models and synthetic examples teach the workflow; replace them with mission-specific inputs for satellite validation.

## Reproduce the SoftwareX Experiments

On Quick start, select **Paper: reference task and 36 cases**, then click **Reproduce paper and report**. Select a writable parent folder and wait for the calculation to finish. The application creates a new task folder containing the reference simulation, 36 periodically initialized conditions, three time-refinement cases and a combined report. The selected interface language determines the GUI report language.

To produce both language reports from the executable:

```powershell
.\LEOTherm.exe --paper-study "C:\LEOThermResults\new_run" both
```

The output directory must not already exist. Read `PAPER_REPRODUCTION_EN.md` or `PAPER_REPRODUCTION_CN.md` for the fixed inputs, output files and quantitative checks. The bundled v1.2.10 videos demonstrate the unchanged task settings; the v1.5 usage guides describe the new progress and stop controls.

## Progress and Stop

During paper reproduction, the progress dialog shows the current case, integration or initialization stage, and elapsed time. Completed thermal-solution jobs are counted out of 40 (one reference, 36 cases and three refinements); this is not a time-based percentage. Figure/PDF generation uses an indeterminate indicator and the actual section or page count. **Stop computation** requests a checkpoint stop. Closing the main window also stops the task before closing, and prompts for unsaved project changes when applicable. A native figure/PDF export already in progress finishes before the next checkpoint. Saved cases remain on disk; `paper_study_status.json` records `cancelled` rather than `complete`.

New filenames and generated child-directory names use ASCII in either language. A user-selected existing parent directory is preserved. Chinese GUI text and report contents are unaffected.

Version 1.2.8 uses shared native MATLAB figure styling and annotates the conductance matrix with actual link values. Each report chart has PNG and vector PDF exports. The `publication_*` groups and companion source MAT files can be used directly in a manuscript. Temperature samples and physical parameters are unchanged. Sample reports and a plotting guide accompany the application package.

Version 1.2.9 reports a single per-orbit peak difference in text and omits empty peak-timing charts. Multiple scored orbits retain their signed values and original cycle numbers in a chart. Energy-balance publication figures remain available independently.

Version 1.2.7 removes the opening synthesis chapter and footer disclaimer, centers page numbers, and justifies body paragraphs except their final lines. Chapter interpretation and closing task conclusions remain, including quantitative external heat shares, response-component variation and actual mean conductive paths. Optional completed stages are included. The interpretation metrics are exported as CSV for audit. Re-export results into a new directory to obtain the new report structure.

Version 1.2.5 records the built-in orbit coordinate definition and separates telemetry comparison status from orbit metadata. Run a new task to capture coordinate metadata in old projects; exporting an unlabelled historical result does not invent a reference frame. No thermal parameters or numerical algorithms changed in this patch.

Version 1.2.4 adds orbital-frequency phase metrics, named thermal nodes, conductive-network diagrams and explicit zero values. Report sections depend on the available task histories. Existing PDFs remain unchanged: run a new task or re-export current results into a new directory.

Keep an existing compatible Runtime installation. This small application package does not contain Runtime. Older portable bundles perform integrity checks, so do not overwrite their application files by hand.

Version 1.2.3 audits signed peak phases across orbits. Mixed advance/delay phases are not reduced to a positive-only median. The report recomputes this diagnostic from raw results, so older cached metrics cannot override the revised assessment. Optional supplied grid-refinement reruns add exact-epoch numerical comparisons; no interpolation or automatic convergence pass is used.
