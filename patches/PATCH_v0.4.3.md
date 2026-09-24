# v0.4.3: Device-Constrained Calibration

## Previous Version

The complete source/docs/tests/tools tree of v0.4.2 was saved before this update
as `leo-gnss-thermal-simulator_v0.4.2_before_device_calibration_v0_4_3.zip`, with
its file manifest, in the sibling version archive directory. Existing results
are deliberately excluded from source snapshots and remain in place unchanged.

## Changes

- Add a separate device-calibration workflow. Existing unconstrained-study
  scripts and the low-level bounded optimizer retain their existing behavior.
- Default every device parameter to fixed. Users explicitly declare the free
  parameters, hardware bounds, uncertainty scales, sources, and whether each
  value is physical or model-effective. Geometry and optical endpoints obey
  their physical domains; conductance edges stay symmetric.
- Penalize deviations from the immutable nominal device; enforce hard bounds
  independently of that penalty. Never derive hardware limits from check errors.
- Fit only chronological training days. Validation and final-check days are
  both evaluated after freezing, without any automatic hyperparameter selection.
- Preserve original epochs and source rows. Invalid target measurements split
  calibration segments; candidate failures cannot change eligible scoring pairs.
- Require solver convergence and a training-only integration convergence check
  before freezing. Report local sensitivity rank separately from regularization.
- Export original/adjusted devices separately, profiles, input/protocol/frozen
  snapshots, every check day/node, bilingual reports/plots and artifact hashes.

## Deliberate Boundaries

The software cannot certify user-entered equipment values, provenance, sensor
positions, noise assumptions or prior use of heldout data. Rank diagnostics are
local and are not parameter confidence intervals. This release does not add a
new independent MinXSS flight validation or change earlier flight conclusions.
Measured drivers are not free calibration parameters. A prescribed boundary is
not a two-way spacecraft thermal model. Previously fitted effective parameters
are not imported as if they were measured equipment properties.

See `docs/device_calibration.md` and `docs/设备受约束标定使用说明.md`.

## Verification

Final release: 148/148 tests, zero Code Analyzer findings, six complete legacy
benchmark cases, and successful bilingual GUI calibration checks at 1380x860
and 1120x780. Final artifacts are in `results/release_v0_4_3`; see
`docs/软件验收报告_v0.4.3.md` for evidence and validation boundaries.
