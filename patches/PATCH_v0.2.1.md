# Patch v0.2.1

Release date: 2026-09-02

## Previous-version snapshot

- Version: `v0.2.0`
- Archive: `H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.2.0_release_20260902.zip`
- SHA-256: `262A98DA91D9CFA8CB4973616399F7A72D789E00D140627546B5B815BE28DAEF`
- The archive was verified before any v0.2.1 source modification.

## Fixed

- Rejected external trajectories whose epoch vector does not match the state
  history instead of allowing a malformed result structure.
- Rejected non-orthonormal or left-handed external body-frame histories before
  heat-load computation.
- Rejected non-finite or non-unit surface normals and invalid code-bias vector
  dimensions before simulation.
- Prevented zero or negative time settings from reaching array allocation or
  producing low-level indexing errors.
- Made `plotScenario` use generic network roles, so the public seven-node model
  and user-defined networks no longer require hard-coded GNSS node names.
- Rejected sweep plots with no complete cases instead of exporting a plausible
  but empty figure.
- Made paper-suite progress reporting non-fatal when a headless host closes the
  MATLAB standard output stream.

## Added

- Public `validateScenario` and `validateTrajectory` APIs.
- Stable `leotherm:Invalid*` error identifiers and clearer user messages.
- Per-case failure isolation and diagnostic messages in public physical sweeps.
- `leotherm.version` and `leotherm.selfTest` convenience entry points.
- Machine-readable release-verification status files for headless runs.
- Nine regression tests covering the confirmed acceptance-test findings.
- A Chinese software acceptance report and updated v0.2.1 operating manual.

## Compatibility and science

- No orbit, eclipse, heat-load, thermal-network, lag-metric, or code-bias
  equation was changed.
- Existing v0.2.0 paper results remain scientifically comparable.
- Sweep tables add diagnostic columns; code that selects existing named columns
  remains compatible.
- Inputs that were malformed but silently accepted in v0.2.0 now fail early.

## Verification

- MATLAB R2021b Code Analyzer findings: 0.
- Automated tests: 29/29 passed.
- Black-box workflow and invalid-input acceptance tests: 18/18 passed.
- SATMO-style seven-node trend benchmark: 6/6 cases completed.
- Paper-suite smoke run: 42/42 cases complete; immediate checkpoint rerun
  executed zero simulation cases.
