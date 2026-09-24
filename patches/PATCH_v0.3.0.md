# Patch v0.3.0

Release date: 2026-09-02

## Previous-version snapshot

- Version: `v0.2.1`
- Archive: `H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.2.1_release_20260902.zip`
- SHA-256: `8886F1F780FC6508F612C94AE9115425B64DFF3AC32AD5688207562BC4A1E6B3`
- The archive was verified before any v0.3.0 source modification.

## Added

- `launch_gui` and `leotherm.launchApp` graphical entry points.
- Four workflow tabs for single scenarios, parameter sweeps, network editing,
  and result inspection/export.
- Immediate scenario plots for eclipse, heat loads, key-node temperatures, and
  semi-synthetic code bias.
- Controlled beta-altitude and physical date-inclination-RAAN scan controls.
- Editable node properties, optical coefficients, code-bias sensitivities,
  role assignments, and symmetric conductance matrices.
- Automatic rollback and user-facing error dialogs after invalid network edits.
- MAT configuration import/export and timestamped result-package export.
- Built-in software version, self-test, progress, status, and interpretation
  boundary displays.
- Safe list/range and ISO date parsers without dynamic code evaluation.
- GUI smoke testing that launches the app, computes a scenario, renders all
  four tabs, and exports screenshots.

## Compatibility and science

- MATLAB R2021b is explicitly supported; newer-only `MinimumSize` UI behavior
  is not required.
- The command-line API remains available and unchanged.
- No orbit, eclipse, heat-load, thermal-network, lag, or bias equation changed.
- The GUI calls the same validation and simulation functions as command-line
  workflows and does not interpolate failed or inaccessible cases.

## Verification

- MATLAB Code Analyzer findings: 0.
- Automated tests: 35/35 passed.
- GUI smoke test: four tabs rendered; 121-epoch scenario finite and exportable.
- SATMO-style trend benchmark: six cases retained in release verification.
