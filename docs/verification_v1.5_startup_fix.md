# v1.5 Startup Optimization

Date: 2026-10-12. Build suffix: `startup_fix`. The version remains 1.5; the thermal equations, solver tolerances and project schema are unchanged. The previous executable/archive and the pre-edit source snapshot are retained.

## What Changed

- Scenario and sweep axes are created when visited or when results need plotting.
- Geometry, engineering-model, telemetry and calibration views are built once on first use. Reading, saving, restoring and auditing their state does not require building the view.
- Deferred views preserve settings, imported data, stale-result detection and task snapshots. Repeated page visits do not duplicate controls.
- The compiler embeds only explicit runtime inputs and live engine/paper scripts. It no longer embeds historical report PDFs, archived experiment outputs or unrelated documents. Source materials remain in the repository.
- MATLAB Runtime is not trimmed or modified. A new executable still requires an initial component-cache extraction.

## Measurements

Single development-environment profiler runs on this host:

| Measurement | Before | After |
| --- | ---: | ---: |
| GUI constructor | 14.758 s | 8.017 s |
| Constructor plus first `drawnow` | 33.031 s | 18.745 s |

These are diagnostic observations, not repeated statistical benchmarks or cold process-launch measurements. System load, graphics initialization and Runtime initialization affect observed launch time. Logs: `results/v1_5_startup_profile.log` and `results/v1_5_startup_optimized_profile.log`.

Embedded-resource selection decreased from approximately 135.81 MiB to 4.93 MiB. The original executable is 98,566,147 bytes; the new executable is 3,881,445 bytes. Resource payload and compressed executable size are different quantities.

The fresh-cache Runtime startup check recorded 11.400 s in the GUI constructor and 30.299 s through the first `drawnow`, measured after Runtime entered the check function. This excludes process/Runtime initialization, and was recorded alongside regression activity. It is not evidence that all cold launches take this duration. All deferred-page checks in that process passed.

## Source Verification

- `test_gui_support`: 11 tests passed.
- `test_module_run_buttons`: 4 tests passed.
- Final `test_gui_startup`: 5 tests passed, including loaded geometry projects and saving before advanced pages are opened.
- Final `test_lazy_panels`: 8 tests passed, including exact state comparisons, disabled controls, restored results and stale inputs.
- Ten changed implementation/test files: zero Code Analyzer findings.

Logs: `results/v1_5_startup_gui_tests.log` and `results/v1_5_startup_lazy_final.log`. The first lazy-panel run used a char assertion against MATLAB's `OnOffSwitchState` enum; those test assertions were corrected and all eight tests rerun successfully. No production behavior was changed to satisfy that type comparison.

The report/resource regression and independent Runtime suite are recorded separately below when completed. This is targeted verification, not a repeat of the full historical suite or the 36-case study.

## Runtime Verification

Command:

```powershell
./tools/test_runtime_focus.ps1 -Destination C:/LEOTherm_Startup_Test_v1_5 -Version 1.5 -BuildSuffix startup_fix -IncludeStartupCheck -IncludeFigureCheck -IncludeModuleCheck
```

The process PATH excludes MATLAB installation directories and uses free Runtime R2021b. The new cache contains templates, six projects, geometry, CSV inputs and live sources; its application resource directory contains no report PDFs or archived result directories.

Executable SHA-256:

`E3AB8DF6EB07D72D2EA9FBE1F1FD56137F1BA6FAB001DDBECFC8AF37992FCAA0`

## Local Distribution

Package: `results/LEOTherm_1.5_windows_startup_fix.zip`.

Extract it into a new folder and run `LEOTherm.exe`. An existing R2021b Runtime installation can be reused. Do not overwrite files in an older portable bundle with its own integrity checks. The package keeps the bilingual guides, labelled tutorial videos and sample PDFs as ordinary external files; those files are not extracted into the application cache at startup. This build is local and has not been published to GitHub.
