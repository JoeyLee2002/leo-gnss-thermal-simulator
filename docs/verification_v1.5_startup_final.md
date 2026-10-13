# v1.5 Final Startup Build

Date: 2026-10-12. Build suffix: `startup_final`. The version remains 1.5 and the thermal solvers/project schema are unchanged.

## Changes And Performance

The final build retains deferred charts/advanced pages and the runtime resource allowlist described in `verification_v1.5_startup_optimized.md`. It additionally initializes the selected lazy page when a user cancels a deferred close request. This prevents a blank page after the computation has stopped, without delaying an accepted close.

Single development profiler observations: constructor 14.758 to 8.017 s; constructor plus first draw 33.031 to 18.745 s. These are diagnostic observations, not complete Runtime process-launch timings. Runtime initialization remains necessary, particularly on the first launch of a new release.

The executable decreased from about 98.6 MB to 3.9 MB. The distribution decreased from about 107.1 MB to 12.4 MB. Historical PDFs and experiment archives are excluded from the embedded runtime resources but are not deleted from the source workspace. Templates, six projects, mesh/CSV examples and live paper-reproduction scripts are retained. Runtime libraries are not modified.

## Verification Scope

The startup_optimized build passed 35 source tests and seven independent Runtime processes: startup, module routing, background figures, window restoration, stop/close, complete report and bilingual samples. Its complete-report check observed and retained a maximized owner. Records: `results/v1_5_startup_final_tests.log` and `C:/LEOTherm_Startup_Optimized_v1_5/`.

After the final close-cancel repair, the attempted source batch in `results/v1_5_startup_release_tests.log` hit the host's R2021b heap-corruption error during startup before producing test results. It is not counted as another 35-test pass. The revised App passed Code Analyzer and compilation; the rebuilt binary is checked again with:

```powershell
./tools/test_runtime_focus.ps1 -Destination C:/LEOTherm_Startup_Final_v1_5 -Version 1.5 -BuildSuffix startup_final -IncludeFigureCheck -Checks startup,progress,completion
```

These final checks cover page/state initialization, actual stop/close callbacks and a complete GUI PDF task with window/hidden-figure assertions. The seven-process base verification is not attributed to the slightly revised final binary. No full historical-suite or 36-case-study rerun is claimed.

Final binary result: **3/3 Runtime processes exited 0**. The startup check recorded a 5.515 s constructor and 15.829 s through first draw after entering MATLAB code, with no eager axes and unchanged inputs after loading all deferred views. Stop/close checkpoint observations were 1.06 s (English), 0.65 s (Chinese) and 1.35 s (English close request). The complete GUI task wrote its PDF and passed its hidden-figure and owner-window-state assertions. Runtime/bootstrap time is excluded from the UI timings.

The R2021b development host still exhibited heap corruption in exploratory long report tests and once after an isolated report test body passed. The targeted source tests and independent Runtime checks are reported separately; no claim is made that every development-host shutdown issue was eliminated.

Final executable SHA-256:

`D8DB70FB47B144240B0059BA57F47C97FC9F29C40199C8AFEEB11D03011C5C16`

## Use

Extract `results/LEOTherm_1.5_windows_startup_final.zip` into a new folder and run `LEOTherm.exe`. An existing free R2021b Runtime installation can be reused. Do not overwrite an older portable bundle with its own integrity checks. This is a local build; GitHub publication was not part of this task.
