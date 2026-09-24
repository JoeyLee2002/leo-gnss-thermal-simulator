# v0.4.4 Reliability hardening

Previous version: 0.4.3. Update date: 2026-09-14.
Source snapshot and manifest: sibling `leo-gnss-thermal-simulator_versions`,
`leo-gnss-thermal-simulator_v0.4.3_before_v044_hardening_20260914.zip`.
Historical results were not overwritten or reclassified as new validation.

## Changes

- All thermal-solver entry points now use error-controlled RK4 step doubling,
  thermal-rate step caps, a finite internal-step budget and optional numerical
  diagnostics. Internal step control does not interpolate telemetry gaps.
- Peak-phase metrics reject constant/tiny signals, ambiguous extrema and apparent
  advances instead of assigning a positive delay. Signed phase, sample resolution
  and identifiable-cycle count are retained. Event windows truncated by the end
  of the record are excluded.
- New scenarios use finite apparent-Earth-disk integration for uniform IR.
  The GUI offers finite-disk and legacy-cosine modes in both languages.
  Old configurations with no model field use legacy cosine; the historical
  six-case benchmark explicitly retains legacy geometry. Albedo is unchanged.
- Missing target temperatures no longer interrupt valid driving data during
  calibration. Their own node scores are excluded without interpolation; other
  sensors remain usable. Invalid drivers still split segments. Measured-initial
  mode still requires valid mapped temperatures at each segment start.
- Calibration acceptance additionally checks each assigned day/node for actual
  scored duration, longest continuous scored interval, temperature span and sample
  count. Defaults: 1800 s, 600 s, 0.5 K, 30 samples. These are editable, predeclared
  engineering screens, not universal validation standards. Error criteria remain
  separately reported; insufficient coverage requires review.
- Bilingual coverage controls, a coverage result tab and coverage.csv/report
  exports expose the new checks. GUI missing metrics are localized.

## Compatibility and limits

Numerical temperatures and formerly ambiguous phase outputs can change. Do not
mix old/new scientific result tables silently; retain configuration and version.
The finite-disk mode is a uniform spherical-Earth IR model, not a full spacecraft
radiative geometry engine. The adaptive solver controls local integration error,
not telemetry sampling error. Sensitivity diagnostics remain local; parameter
confidence intervals and full mission-level physical validation are not added.
Cancellation/restart, general telemetry-format conversion, albedo-disk integration,
self-shadowing and inter-surface radiative exchange remain future work.

Verification results: `docs/软件验收报告_v0.4.4.md`.
