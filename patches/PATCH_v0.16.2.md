# Patch v0.16.2: explicit coupling-boundary GUI

## What changed

- Added a compact GUI dialog for explicit contact and fixed-temperature
  boundary settings.
- Saved these settings in the workspace state and restored them with strict
  validation against the loaded volume mesh.
- Added a normalization layer so older calls with an empty options structure
  remain valid without silently inventing contacts or boundaries.

## Verification

- Coupling-option parser/validation tests: 4/4 passed.
- GUI coupled workflow test: passed.
- Static analysis of changed MATLAB files: 0 findings.
- Full isolated release gate: 285/285 tests passed, 0 static-analysis findings,
  6 benchmark rows, and 45 child MATLAB processes returned status 0.

The isolated gate now launches one test file per MATLAB child process because
MATLAB R2021b can fail during teardown of mixed export/graphics test batches
after all assertions have passed. This preserves per-file results and makes a
native crash attributable to one test file.

## Boundary

The dialog only accepts explicit node indices and conductance values. It does
not infer contacts, material properties, boundary faces, or physical validity.
