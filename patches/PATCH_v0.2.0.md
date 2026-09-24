# Patch v0.2.0

Release date: 2026-09-02

## Previous-version snapshot

- Version: `v0.1.0`
- Archive: `H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.1.0_20260901.zip`
- SHA-256: `B6811C98711A0131DCC2639D33E78205EB10F38F3EB3E2FDE402EF30B450A2DA`
- The archive was created before any v0.2.0 source modification.

## Added

- Automatic periodic thermal-state initialization with convergence diagnostics.
- Strictly symmetric reference network and controlled asymmetry constructors.
- Physical and normalized forcing-temperature hysteresis-loop metrics.
- Per-orbit heat-peak to response-peak and trough-to-trough lag metrics with
  explicit modulo-period event definitions.
- Toolbox-free stratified uncertainty ensemble generation.
- Paired uncertainty design that reuses identical thermal-parameter samples
  across representative beta-angle regimes.
- SATMO-style seven-node benchmark network and benchmark matrix.
- Paper-1 experiment drivers for controlled altitude-beta, physical orbit
  accessibility, and signed-beta symmetry breaking.
- Generic node roles so non-GNSS benchmark networks can select their own
  response, antenna, and oscillator nodes.
- Controlled frozen-Sun mode for repeatable mechanism experiments.
- Cross-track roll attitude tests and mirror-preserving pitch/null controls.
- Release verification entry points that combine static analysis, all unit
  tests, and the seven-node benchmark.
- Version snapshot utility for preserving the previous source tree before each
  future update.

## Changed

- `simulateScenario` now initializes the thermal state through a repeatable
  orbital forcing cycle by default. Fixed warm-up propagation remains available
  as a compatibility mode.
- Sweep tables include convergence, hysteresis, and transition-lag diagnostics.
- No-eclipse transition metrics are reported as missing values rather than
  fabricated or interpolated events.
- The paper experiment suite checkpoints every ten cases, resumes incomplete
  batches, and retains failed or inaccessible statuses explicitly.
- Documentation distinguishes numerical verification, mechanism assessment,
  and mission-level validation.

## Paper-1 production run

- Controlled altitude-absolute-beta experiment: 85/85 complete cases.
- Physical season-inclination-RAAN experiment: 720/720 complete cases.
- Signed-beta symmetry-breaking experiment: 160/160 complete cases forming
  80 paired comparisons.
- Paired thermal-parameter uncertainty experiment: 150/150 complete runs from
  50 shared samples across three beta regimes.
- Total: 965 deterministic cases plus 150 uncertainty runs; no interpolation
  and no failed run.
- Maximum periodic-state mismatch over all production cases: 0.00323 K against
  the 0.005 K acceptance threshold.

## Verification

- MATLAB Code Analyzer findings: 0.
- Automated tests: 20/20 passed.
- SATMO-style seven-node trend benchmark: 6/6 cases completed.
- The benchmark checks interfaces and expected trends; it is not an exact
  external SATMO reproduction under identical inputs.

## Scientific interpretation

The new outputs remain predictions of a reduced thermal network. They support
controlled mechanism studies but do not constitute flight validation for a
specific spacecraft until the network is correlated against telemetry or
thermal-vacuum measurements.
