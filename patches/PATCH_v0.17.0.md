# Patch v0.17.0: task wizard and editable templates

## What changed

- Added a Task wizard on the Quick start page.
- Added four versioned JSON task templates under `templates/`.
- Users can copy a built-in template or choose any compatible JSON template.
- The wizard exposes only task name, duration, time step, and required input
  files; advanced parameters remain editable in the JSON or Advanced simulation.
- Template provenance is embedded in saved workspace projects.
- The immutable software version is cached after a bounded-retry first read,
  avoiding repeated removable-drive access inside long calibration loops.
- The release gate explicitly releases its large summary tables before
  MATLAB R2021b teardown.

## Safety and reproducibility

- Templates are declarative JSON and cannot contain MATLAB function handles.
- Every template declares `templateVersion` and `engineApi`.
- Unknown network presets, unsupported engine APIs, invalid scenarios, and
  invalid thermal networks are rejected before workspace mutation.
- Telemetry remains subject to existing mapping and preflight rules; missing
  samples are not interpolated or filled.

## Verification

- Focused template and GUI tests: 14/14 passed.
- Static analysis of changed MATLAB files: 0 findings.
- Full isolated release-gate results are written to the v0.17.0 status file.
