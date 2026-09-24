# Patch v0.14.0: engineering model integration

## What changed

- Fixed `componentModel('create', spec)` so the documented creation entry point
  works without accidentally treating the component as a network.
- Made exchange-model uncertainty explicitly scalar and rejected tabulated
  temperature curves without a temperature grid.
- Clarified source and container fingerprint semantics so MAT/JSON round trips
  preserve upstream provenance.
- Added explicit thermal-model-to-network mapping preview, conflict reporting,
  confirmation-gated application, provenance, and rollback in the bilingual GUI.
- Added v0.14 regression and release QA documentation.

## Verification

- v0.14 regression gate: 6/6 passed, 0 failed, 0 incomplete.
- Mapping, thermal-model I/O, material/component, and GUI focused tests passed.
- Full release verification and GUI smoke results are recorded with the final
  release artifacts.

## Boundary

Exchange validation and mapping are not physical validation. The software does
not infer contacts, boundaries, units, missing data, or non-matching mesh
correspondence. MATLAB graphics-heavy calibration export should still be run in
a clean MATLAB process or CI worker when testing the complete suite.
