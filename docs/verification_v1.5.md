# v1.5 Verification

Date: 2026-10-12. Local package: `LEOTherm_1.5_windows.zip`.

## Behavior

The Simulation workspace retains the complete-task area and four optional stages. The global action explicitly says `Run complete task and generate report`. Each calculation module now exposes its own run button. The local scenario/sweep callbacks do not call the complete pipeline, do not change the global choices, do not automatically generate a report, and retain results on their own pages. Surface, volume, coupling, telemetry and calibration buttons retain their existing module-specific callbacks. Manual report export remains a separate deliberate action.

Quick start additionally offers `Current configuration and report`. The six example projects were regenerated with software version 1.5; the schema and core solvers are unchanged. Older executable packages and pre-edit source snapshots were preserved.

## Source Checks

- 15/15 module/GUI tests passed: four new module-button tests and eleven existing GUI support tests.
- 7/7 report-closure tests passed, including the retained explicit report/pipeline APIs and optional-stage checks.
- Seven changed implementation/test files had zero Code Analyzer findings. The standalone entry was checked again before compilation with zero findings.
- Both source test processes and the separate compiler process exited with code 0.
- Logs: `results/v1_5_module_tests.log`, `results/v1_5_report_closure.log`, `results/v1_5_examples_static.log`, `results/v1_5_build.log`.

The principal regression deliberately selects all four global stages with missing geometry/telemetry/calibration inputs. The full-task button is blocked, but the local single-scenario callback still produces one result. A configured one-case sweep then runs independently, retains that scenario's exact temperature array, leaves the stage selections unchanged and has only `scenario`/`sweep` task history. No PDF is created by these local callbacks.

## Runtime Checks

Executed:

```powershell
./tools/test_runtime_focus.ps1 -Destination C:/LEOTherm_Module_Test_v1_5 -Version 1.5 -BuildSuffix '' -IncludeFigureCheck -IncludeModuleCheck
```

The executable used free Runtime R2021b with MATLAB installation paths excluded from process PATH. Six separate processes exited with code 0:

1. Module-button test: actual local button callbacks passed the scenario/sweep isolation checks above. Record: `module/module_buttons_smoke.json`.
2. Background figures: chart creation was hidden, exports completed, and the visible owner remained maximized.
3. Window restoration: normal/maximized chooser-cleanup cases passed. This specific chooser test simulates the picker side effect, rather than physically clicking the Windows chooser.
4. Progress: actual English/Chinese stop-button callbacks and main-window close passed. Recorded checkpoint latencies were approximately 0.65 s, 0.44 s and 1.62 s. English controls showed `Stopping...`; cancelled tasks were not marked complete.
5. Complete report: a visible, maximized app completed the 120 s GUI pipeline and generated `completion/report/thermal_report_en.pdf`. Assertions checked hidden temporary figures and final maximized state.
6. Bilingual samples: the Runtime executable generated English/Chinese reports from a fresh 120 s reference scenario. These are packaged as illustrative startup samples, not the paper's 36-case results.

Runtime records are under `C:/LEOTherm_Module_Test_v1_5/`. The generated output/cache filename scan found no non-ASCII basenames. Only the scenario/sweep module computations were newly exercised end-to-end; the other restored local buttons were checked for visibility/language and retain existing solver callbacks. The full historical test suite and 36-case thermal study were not repeated for this UI-only change.

Executable SHA-256:

`D2FA46E8958EDF2FCFB898B8DE8BA5FF13B1C5F762854673BB8CDCDC788845CD`

## Visual And Distribution Checks

The Single scenario interface was rendered and inspected at 1380 by 860 pixels: the global task/report action and the fixed local run button are separate and their text fits. Image: `results/v1_5_single_scenario_ui.png`.

The archive excludes Runtime, retains the originally labelled v1.2.10 tutorial videos, and supplies updated bilingual v1.5 written guides. This local release has not been uploaded to GitHub.
