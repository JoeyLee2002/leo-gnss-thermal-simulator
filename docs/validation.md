# Verification and validation plan

## Automated checks

The test suite verifies:

- RAAN-to-beta inversion and inaccessible-beta rejection;
- orthonormality of the nadir body frame;
- conical eclipse behavior against the circular cylindrical analytic limit;
- conservation of thermal energy for an isolated conductive network;
- convergence to the analytical radiative equilibrium of one node;
- finite, physically bounded output for the complete reference scenario.
- same-phase periodic thermal-state convergence;
- exact zero-effect controls for signed-beta symmetry;
- analytic unit-circle hysteresis area and known peak-to-peak lag;
- generic response-node execution without GNSS-specific node names;
- reproducibility of stratified uncertainty samples.
- rejection of malformed scenarios, trajectory epochs, non-orthonormal
  attitude matrices, invalid surface normals, and bias-dimension mismatches;
- generic role-based network plotting and empty-sweep rejection;
- per-case failure isolation in physical parameter sweeps;
- Chinese/English plot export and four-legend coverage for both figure types;
- language normalization and localized thermal-node labels;
- consistency between the package version and the release file.

Release v0.3.2 passes 38 automated tests, an 18-case core black-box acceptance
matrix, six SATMO-style benchmark cases, and a JVM-backed GUI launch, compute,
render, and export smoke test in both languages. Each GUI language produced
four workflow screenshots and eight plot legends.

## SATMO-aligned benchmark matrix

The example sweep includes the public SATMO Earth altitudes of 400 and 800 km
and controlled low-, intermediate-, and high-beta cases. SATMO's idealized
90-degree beta case is evaluated only when the selected date and inclination can
physically realize it; otherwise it is explicitly marked inaccessible. Agreement
is expected for qualitative eclipse and thermal trends, not exact node
temperatures, because geometry, optical properties, albedo treatment, and the
internal network differ.

## Validation boundary and required next steps

The current suite provides numerical verification, controlled mechanism tests,
and a scoped same-input comparison with SATMO v1.5.0. It does not provide
mission-level validation; the external comparison covers only the shared
direct-solar, conductive, internal-power, and space-radiation terms described
in `docs/satmo_external_validation.md`.

1. Extend the SATMO comparison to eclipse, albedo, and planetary infrared only
   after the environmental definitions can be made identical.
2. Compare orbit, beta angle, and eclipse intervals against an independent
   Basilisk or SPICE trajectory.
3. Correlate heat capacities and conductances against thermal-vacuum or flight
   telemetry for the target spacecraft.
4. Extend uncertainty ensembles to internal duty cycles and calibrated
   component-level parameter covariance.
5. Keep validation cases independent from any parameter-correlation cases.

`run_satmo_style_benchmark` remains a transparent seven-node trend benchmark;
the separate identical-input thermal-term comparison is the externally traced
validation case.
