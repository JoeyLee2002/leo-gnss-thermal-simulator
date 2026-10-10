# Verification record: v1.2.3

Date: 2026-10-10. Scope: detailed reporting, peak-phase interpretation, energy-accounting scope and the Windows standalone reporting workflow.

## Completed checks

- 36/36 isolated audit, report-detail, numerical-hardening and model-extension tests passed; process exit code 0. Evidence: `results/report_v1_2_3_isolated_tests.log` and its MAT result file.
- The combined scenario/sweep/surface/volume reporting test, including the new fixed-warmup energy-total assertion, passed. Its batch subsequently encountered a MATLAB shutdown heap error; this is not recorded as a clean process-level pass.
- The final 24 h Chinese and English reports were regenerated successfully in a clean run, process exit code 0. Each has 18 pages, including the actual 60/30/15/7.5 s grid-refinement audit. Evidence: `results/report_v1_2_3_release.log`.
- All final PDF pages were rendered and visually reviewed. Automated checks found no out-of-page text; the withdrawn 1980 s value is absent from rendered report text. Evidence: `results/report_v1_2_3_release/qa`.
- Windows application compiled using the official R2021b command-line compiler with absolute source/asset paths, exit code 0. Evidence: `results/build_v1_2_3_cli_absolute.log`.
- The extracted standalone was run from `C:\LEOTherm_Report_Test_v1_2_3` using the existing relocated Runtime v911, with MATLAB installation paths removed from the child PATH. The hidden GUI workflow created the interface, ran the task pipeline and produced a 17-page English PDF; process exit code 0. This is an automated workflow smoke test, not a manual test of every GUI control.
- The tested executable matches the release executable: SHA-256 `b0ccfd3bc003eb4c268284b7cc43a6cd25331011681a3f6cd0bf5a41222f09dd`.
- Small Windows archive: 9,469,632 bytes; SHA-256 `608c4d47e80cfc7ec584246924d5b914569d9197a41485a562d608f29aeeea59`. It reuses Runtime R2021b and does not include the full Runtime distribution.

## Known limits

Some local MATLAB R2021b development batches intermittently terminated with `0xc0000374` heap corruption, including runs whose assertions or PDF writes had completed. This was not silently reclassified as success and has not been proven resolved. The isolated numerical run, final PDF-generation run, command-line compilation and deployed Runtime smoke test above completed with exit code 0. No claim is made that every long-lived MATLAB session is stable.

The full historical project test suite was not rerun for this report-focused update. Existing optional-stage report tests were checked during the preceding report revision; the latest combined-stage report regression is recorded separately above.

This release does not establish flight-specific physical validity, independent telemetry agreement, device operating-temperature compliance, or an arbitrary grid-convergence tolerance. The archived reference result retains its original cached metrics; current phase interpretation is stored separately in `report.phaseDiagnostics` and identified by the report software version.
