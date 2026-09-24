# Device-Constrained Calibration

Version 0.4.3 adds a separate device profile workflow. The default network is a
hypothesis, not hardware ground truth. Every profile parameter starts locked.
The GUI Device calibration tab consumes the current thermal network and the
CSV mapping/options from Telemetry and validation. It never silently replaces
the current device with a calibrated model.

## Contract

`deviceCalibrationProfile(network)` creates a profile whose `parameters` table
contains `field`, `node`, `peer`, `unit`, `nominal`, `lower`, `upper`, `priorSigma`,
`estimate`, `evidence`, and `kind`. Supported network fields are heat capacity,
internal power, projected/radiating areas, solar absorptivity, IR emissivity,
and existing undirected conductive edges. `kind` is `unverified`, `physical`,
or `effective`. Free parameters need explicit evidence, meaning, positive prior
scale and nonzero-width physical bounds containing the unchanged nominal value.

The complete reference network is retained. A stale profile is rejected after
a device change. Initial state, sensor offset, scale, time shift, measured
power and measured boundary conductance are not fitted. Boundary temperature
is a prescribed input, not feedback from the target or a two-way reservoir.

```matlab
profile = leotherm.deviceCalibrationProfile(network);
% Set only independently justified limits/scales/evidence in profile.parameters.
split = leotherm.calibrationDaySplit(data);
% Assign every day: train, validation, test or exclude; no automatic split.
settings = leotherm.deviceCalibrationOptions(struct, numel(network.nodeNames));
% Explicit sensorEvidence, scales, confirmations and driver options are needed.
result = leotherm.calibrateTelemetry(data, scenario, network, ...
    profile, split, settings, newOutputDirectory);
```

`temperatureSigmaK` is a positive scalar or vector ordered as `network.nodeNames`.
It is a declared noise/model-error scale, not a learned covariance matrix.
The loss is the equal-weight mean of day/node standardized squared errors plus
`regularizationWeight * sum(((theta-nominal)./priorSigma).^2)`. It is deliberately
not interpreted as an independent-sample likelihood or used to claim confidence
intervals. The positive weight is fixed before fitting, not tuned on checks.

## Isolation and Numerical Safety

At least one whole UTC day belongs to each of train, validation and test, in
chronological order. No day is shared. Excluded/invalid rows are retained, not
deleted or bridged. Invalid mapped target temperatures also split segments.
Within a role, adjacent valid samples carry state across midnight; roles/gaps
restart from the declared initial-state policy. Measured initialization is
optional, explicitly conditional, and uses only the first sample per segment.

Every candidate predicts the same fixed training pairs. Integration failures
stop calibration instead of reducing the scoring denominator. Bounds provide
a conservative RK4 step cap; the fitted training prediction must pass step
halving before freezing. Solver convergence is mandatory before checks.

Training-only finite-difference sensitivities exclude prior-penalty rows.
Weak sensitivities, rank loss, near-bound parameters and near-optimal multistart
instability trigger review. Full local rank is not global identifiability.

Both validation and test are evaluated after freezing; neither selects a model
or hyperparameter in this workflow. Repeated inspection followed by tuning makes
those data development data, regardless of role names in the CSV.

## Output and Acceptance

Original and calibrated devices, unchanged priors, settings, input snapshot,
frozen scoring masks/weights, all date/node predictions and parameter changes
are saved separately. Each check date/node must meet the predeclared RMSE limit;
pooled error alone cannot pass a run. No criterion or unconfirmed provenance
means review, not success. Synthetic demonstrations cannot claim flight validity.

Reports and all day/node figures are exported in Chinese and English with
explicit legends, source tables and gap breaks. An artifact SHA-256 manifest
detects changes when checked, but is not an immutable cryptographic signature.
`calibrated_device.mat` is compatible with the main GUI's manual configuration
loader. Its profile retains original priors and the separate calibration status.

For detailed Chinese instructions, see `设备受约束标定使用说明.md`.

Run `examples/run_device_calibration_demo.m` for known-truth recovery and an
out-of-range counterexample. The six dates contain short synthetic transients,
not six complete flight days. This tests software behavior, not thermal-model
flight validity. Formula-like text is escaped in spreadsheet-facing CSV files;
the original text remains intact in MAT snapshots.
