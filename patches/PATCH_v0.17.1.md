# Patch v0.17.1: closeout hardening

Previous source snapshot:
`H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.17.0_before_closeout_20260924.zip`.

## Changes

- Templates now reject unsupported task modes, major versions, input kinds,
  unknown fields, and misspelled nested scenario keys before GUI state changes.
- File-backed and in-memory templates use one validator.
- Added a short current-version first-run guide. Older long manuals remain
  available as historical reference material.

## Verification

- Built-in first-simulation template: 121 finite time epochs.
- Chinese GUI smoke workflow: scenario, sweep, surface mesh, volume mesh,
  telemetry, results page, and screenshot export completed.
- Template, example-project, and GUI state regression: 19/19 passed.
- Full isolated release gate: 292/292 tests passed in 46 batches; static
  analysis reported 0 findings; six benchmark rows were generated. The outer
  MATLAB process exited with status 0.

## Known boundary

The reference receiver network is a research example and is not a calibrated
thermal model of a specific satellite. The GUI wizard's modal clicks still
need a human acceptance check on the target display; automated tests cover
template validation, GUI state, and the computation/export path.
