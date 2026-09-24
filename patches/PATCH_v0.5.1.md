# v0.5.1: Paper-1 Gap Experiments

## Previous version

The complete v0.5.0 source tree was archived before this study update as
`leo-gnss-thermal-simulator_v0.5.0_before_paper1_gap_experiments_20260914.zip`
with its manifest in the sibling version archive directory. Existing results
are not overwritten.

## Scientific additions

`studies/paper1/run_gap_experiments.m` adds two bounded studies:

1. `storage_isolation`: three controlled beta regimes and five global thermal-
   capacity factors. Every factor receives the same geometry and the same
   sampled node-resolved external forcing as its dynamic counterpart. A
   per-epoch nonlinear algebraic equilibrium is calculated from that forcing as
   a no-storage reference. The comparison is labelled a storage contribution
   diagnostic, not a complete causal decomposition of all thermal pathways.
2. `numerical_stability`: three controlled beta regimes at 30, 15 and 7.5 s
   input/output sampling. Adaptive internal RK4 remains active. Results include
   peak-phase status, accepted cycles, event status and metric changes relative
   to the 7.5 s run.

The study uses the v0.5.1 finite-Earth-disk infrared model and the current
ambiguous-phase and truncated-event handling. It does not modify the historical
v0.2.0 paper-1 CSV files.

## Interpretation boundary

Changing heat capacity while holding forcing fixed is a direct test of stored
thermal energy, but not a replacement for a calibrated spacecraft model. The
quasi-static reference still includes instantaneous conductive redistribution
and radiation, and therefore its forcing-response peak need not be zero. A
non-identifiable peak is retained as missing; it is never replaced by zero.

The timestep study checks numerical sensitivity of the declared sampled-input
experiment. It cannot recover events that were absent from the input sampling,
validate the solar or Earth-radiation model, or prove task-level temperature
accuracy.

## Verification

Run `run_gap_experiments('paper')` from the simulator root after `startup`.
The run writes a new timestamped result folder and a manifest with version,
configuration, seed, input hashes and status counts. Historical result folders
remain unchanged. The normal release test suite is required before publishing
the updated software version.
