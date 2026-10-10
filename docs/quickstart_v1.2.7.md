# LEOTherm v1.2.7 User Guide

## Install and start

Download `LEOTherm_1.2.7_windows.zip` from the Assets section of the
[release page](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/tag/v1.2.7).
Install free MATLAB Runtime R2021b, extract the entire application package to a writable directory, and start `LEOTherm.exe`.
No MATLAB license is required. Reuse an existing compatible Runtime installation.
The GitHub Source code archive is not the executable package; Runtime cannot execute `.m` source files.
The older 1.2.1 portable bundle is a different distribution and does not include this update.

Wait for first-launch Runtime initialization rather than repeatedly starting the application.
New sessions start in English. The language selector supports Chinese, and saved projects restore their stored language.
MATLAB users can instead run `launch_gui` from the source root.

## First complete task

1. Open **Quick start → Task wizard**.
2. Choose **First simulation**.
3. Enter task name `my_first_task`, duration `2` hours and step `60` seconds.
4. Choose **Load only** to configure the unified task before running.
5. Under **Simulation**, leave sweep, 3-D coupling, telemetry comparison and calibration unchecked for this first task.
6. Select **Check task** and resolve any reported input requirements.
7. Select **Run task**, choose an output location and wait for completion.
8. Under **Results and export**, select **Open this run PDF**.

This reference-node task needs neither a mesh nor telemetry. The two-hour duration is the analysis window, not an estimate of wall-clock execution time.
The template also uses one fixed warmup orbit; fixed warmup is not an automatic periodic-convergence result.
**Use template and run** is an alternative quick action. If only a single module has been run, the export button may instead read **Generate analysis PDF**.

## Reuse an editable template

Copy `templates/01_first_simulation.json`, then edit only the fields needed for your task.

| Field | Meaning | Example |
| --- | --- | --- |
| `scenario.name` | Task name | `my_first_task` |
| `scenario.durationS` | Duration in seconds | `7200` |
| `scenario.timeStepS` | Step in seconds | `60` |
| `scenario.warmupOrbits` | Fixed warmup orbits | `1` |

The wizard uses hours for duration, whereas JSON uses seconds.
Keep the schema, template-version and engine-API declarations. Choose another JSON template in the wizard to open your copy.
Templates do not execute arbitrary MATLAB code. For a custom thermal network, configure the nodes and connections and save a project.

## Optional stages

The base nodal simulation always runs. Configure the inputs, enable the relevant stage, check the task, then run a new task.

| Stage | Required configuration | Report focus |
| --- | --- | --- |
| Sweep | Mode and altitude/beta or date/inclination/RAAN lists | Case count and response changes; one case cannot establish a trend |
| 3-D coupling | Surface and volume meshes, materials and coupling boundary | Temperatures, mapped heat flow and conservation; current surface-to-volume driving is one-way |
| Telemetry | Declared time, units, node mapping and coverage | Matched samples, RMSE, residuals and independence |
| Calibration | Nominal parameters, allowed ranges and training/validation/test splits | Parameter shifts and separate training/held-out errors |

Importing telemetry alone does not perform a comparison. Synthetic examples do not constitute flight validation.
When calibration and comparison share a data source, downstream comparison uses the retained test days; preflight rejects overlapping-data configurations where applicable.
Do not expect missing observations to be filled by automatic interpolation.

## Read the report

Start with task inputs, then heat inputs, temperatures and conductive paths, response metrics, numerical checks and the closing conclusions.

- Check the task identity and analysis window before interpreting a plot.
- Read hot/cold extrema separately from temperature variation and target-component temperature.
- Read conductive direction from computed heat flow, not line thickness alone.
- Distinguish orbital-frequency phase from per-orbit peak timing.
- Refinement comparisons appear only when corresponding rerun results are supplied.
- Optional-stage analysis appears only for executed stages.

Version 1.2.7 removes the opening synthesis chapter and explanatory footer. Page numbers are centered; non-final paragraph lines are justified.
The two release reference reports contain 19 pages each. Actual task reports vary with data and completed stages.
Numerical checks concern computation; equipment operating-temperature compliance requires its declared design limits.

## Retain and audit the task

| Output | Purpose |
| --- | --- |
| `input_snapshot.mat` | Task inputs |
| `frozen_model.mat` | Frozen model |
| `pipeline_run.mat`, `pipeline_status.json` | Results and stage status |
| `report/thermal_report_en.pdf` or `_zh.pdf` | Report in the task language |
| `report/thermal_report_data.mat` | Report data bundle |
| `report/thermal_interpretation_evidence.csv` | Derived metrics, units and sources |
| `report/thermal_node_statistics.csv` | Nodal statistics |

Verify completion, check configuration and plots, read numerical checks, inspect enabled-stage results, then retain the complete output directory.
After changing configuration or upgrading, run a new task in a new directory. Opening an old PDF does not recalculate or reformat it.

## Troubleshooting and video versions

- No initial window: allow Runtime initialization and check the complete extraction and R2021b Runtime installation.
- Old PDF layout: verify that the running executable is 1.2.7 and that you opened a newly exported task.
- Missing optional analysis: check whether that stage was enabled and completed.
- Missing **Generate analysis PDF** button: a completed pipeline uses **Open this run PDF** instead.
- Videos show earlier layouts: the Chinese full tutorial was recorded with v1.2.0 and the English introduction with v1.2.1. They remain workflow references; this guide covers current report behavior.

This release updates bilingual written tutorials and report examples, not a newly recorded video.
