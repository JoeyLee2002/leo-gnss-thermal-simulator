# v1.5 Startup Optimization

Date: 2026-10-12. Build suffix: `startup_optimized`. Version, thermal equations, solver tolerances and project schema remain unchanged. Previous packages and the pre-edit source snapshot are retained.

## Changes

- Create scenario/sweep axes and geometry, engineering-model, telemetry and calibration views on first use.
- Preserve state snapshots, saved projects, stale checks and preflight before those views exist. Repeated visits do not duplicate controls.
- Protect the owner's window state during first chart rendering. Do not create editable pages from tab-change callbacks while a computation is busy; prepare the selected page after completion.
- Compile a file allowlist retaining sources, templates, six projects, mesh/CSV inputs and live paper-reproduction scripts. Historical PDFs and archived experiment results stay in the repository, outside the executable.
- Do not delete or modify MATLAB Runtime libraries. New releases still require initial Runtime cache extraction.

## Measurements

Single diagnostic profiler runs in the development environment:

| Measurement | Before | After |
| --- | ---: | ---: |
| GUI constructor | 14.758 s | 8.017 s |
| Constructor and first draw | 33.031 s | 18.745 s |

These are observations, not repeated statistical benchmarks or full process-launch timings. Logs: `results/v1_5_startup_profile.log` and `results/v1_5_startup_optimized_profile.log`. The final source regression recorded 4.781 s in the constructor and 13.491 s through first draw without the profiler.

Selected resource payload decreased from approximately 135.81 MiB to 4.93 MiB. The original executable is 98,566,147 bytes; the final executable is 3,881,649 bytes. Resource payload and compressed executable size are different quantities.

The final new-cache Runtime process recorded a 5.855 s GUI constructor and 16.307 s through first draw, after entering MATLAB code. Runtime/bootstrap initialization is not included. Its startup check confirmed zero eagerly created axes, unchanged task inputs and idempotent loading of all six deferred workspace views.

## Source Verification

Final source batch: **35/35 passed**, process exit 0. Log: `results/v1_5_startup_final_tests.log`.

| Test File | Passed |
| --- | ---: |
| test_gui_startup | 6 |
| test_lazy_panels | 8 |
| test_module_run_buttons | 4 |
| test_gui_support | 11 |
| test_standalone_resources | 6 |

Ten implementation/test files had zero Code Analyzer findings; the revised App, startup check, entry point and startup tests were checked again before the final compiler process, which exited 0.

An exploratory long report batch and an isolated report run encountered the development host's R2021b heap-corruption problem. The isolated scenario-report test body passed before its process failed during cleanup. This has not been described as a successful full report-closure batch. The final targeted source batch completed normally; compiled report paths are checked separately below. No full historical-suite or 36-case-study rerun is claimed.

## Runtime Verification

```powershell
./tools/test_runtime_focus.ps1 -Destination C:/LEOTherm_Startup_Optimized_v1_5 -Version 1.5 -BuildSuffix startup_optimized -IncludeStartupCheck -IncludeFigureCheck -IncludeModuleCheck
```

This uses free Runtime R2021b with MATLAB installation paths excluded from process PATH and a new component cache. Records are under `C:/LEOTherm_Startup_Optimized_v1_5/`. The complete-report window check records the state actually established before plotting and checks that it remains unchanged, instead of assuming that an asynchronous maximization request was already honored. A separate minimal-owner check exercises maximized-window restoration.

The earlier candidate's PDF pipeline completed, but its test's hard-coded maximized-state assertion failed. That result was not counted as a passing Runtime regression. The final build adds first-render guards and records the window precondition explicitly.

The final complete-report check requested and observed `maximized`, preserved that state during first scenario plotting and PDF export, and completed the 120 s task with `status=complete`. Record: `completion/standalone_gui_status.txt`.

Final Runtime suite: **7/7 independent processes exited 0**: startup, module routing, background figures, file-dialog window restoration, progress/stop/close, complete report and bilingual sample reports. The English and Chinese PDFs were generated successfully. Generated filenames/cache resource basenames passed the ASCII scan. The application-cache resource directory contains zero PDFs.

Recorded cancellation checkpoint latencies were 0.87 s (English), 0.39 s (Chinese) and 0.89 s (English close request); English displayed `Stopping...`. These timings are observations on this host, not a universal cancellation deadline.

Final executable SHA-256:

`E45BFB9689E4EDCCCE42A5644FD3354080D0794DE1D6A4E6BFE796787521EA7D`

## Distribution

Package: `results/LEOTherm_1.5_windows_startup_optimized.zip`.

The final package is approximately 12.4 MB versus 107.1 MB for the previous distribution. Its external guides/sample reports do not increase application-cache extraction work.

Extract into a new folder and run `LEOTherm.exe`. Reuse an existing R2021b Runtime installation. Do not replace files in an older portable bundle with its own integrity checks. Guides, labelled tutorial videos and sample PDFs remain ordinary external package files, not application-cache resources. This build is local and has not been uploaded to GitHub.
