# Patch v0.16.0: coupled surface-volume workflow

## What changed

- Added `leotherm.simulateSurfaceVolumeScenario` as a public end-to-end
  workflow from orbit/attitude-driven face radiation to exact boundary mapping
  and volume finite-element conduction.
- Added explicit optional contact interfaces and fixed-temperature volume
  boundaries to the workflow.
- Added `leotherm.writeSurfaceVolumeScenarioResult` for complete MAT, CSV,
  diagnostics, volume-result, and bilingual report export.
- Added independent coupling rows to the unified report for matching method,
  matched boundary faces, maximum closure error, and contact-pair count.
- Added regression tests for execution, energy transfer, mesh rejection,
  fixed boundaries, and exported artifacts.

## Verification

- Coupled workflow and export tests: 4/4 passed.
- Existing unified-report tests: 2/2 passed.
- Changed MATLAB files: static analysis passed with 0 findings.

## Boundary

This release provides a conservative one-way coupling. External face radiation
is applied to the volume state; the independent face-temperature preview is not
fed back into the volume solve. A monolithic nonlinear surface-radiosity,
surface-to-solid conduction solve remains a separate future model, not an
implicit claim of this release.
