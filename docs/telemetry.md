# Telemetry and validation (0.12.0)

Launch `launch_gui('en')` and open **Telemetry and validation**. Choose a workflow,
export an empty CSV template, import your observations, and explicitly review
the source-column, quantity, thermal-node, and unit mapping. The synthetic demo
is a known 0.2 K offset test, not satellite validation.

## Workflows

- **Orbit telemetry**: UTC epochs, position, velocity, and geocentric Sun vectors
  in the same J2000 ECI frame. Optional ECI-to-body direction cosine matrices
  must be orthonormal and right-handed; otherwise the scenario attitude is an
  explicit assumption. External heat loads are computed by the environment model.
- **Measured heat loads**: absorbed external power in watts for every node,
  including explicit zeros. Optional mapped internal powers override network
  settings. Bus voltage, electrical generation, and irradiance are not absorbed
  heat powers and must not be substituted without a justified conversion.
- **Validate current scenario**: compare an already computed scenario against
  mapped measured temperatures at exactly matching UTC epochs. No resampling,
  time shift, offset fitting, or gain fitting is performed.

## Input contract

CSV files and MATLAB tables are supported. UTC strings use ISO 8601 with a
trailing `Z`, optionally fractional seconds, such as
`2024-01-01T00:00:06.986915Z`. Zoned MATLAB datetimes are also accepted by the API.
At least two valid, increasing, unique epochs are required. Unsorted and
duplicate times are not repaired.

Canonical column names include `epoch_utc`, `quality`, `x_eci_m`, `y_eci_m`,
`z_eci_m`, `vx_eci_mps`, `vy_eci_mps`, `vz_eci_mps`, `sun_x_eci_m`,
`sun_y_eci_m`, `sun_z_eci_m`, and `eci_to_body_11` through `eci_to_body_33`.
Node-specific columns use `temperature_k_<node>`, `temperature_c_<node>`,
`external_power_w_<node>`, or `internal_power_w_<node>`.
Explicit mappings additionally support km, km/s, K, degC, and W. Do not infer
sensor locations from similarity to simulated curves.

If quality is mapped, only a finite value of 1 is accepted. Omitting the column
means no source quality-flag screening, not a guarantee of good data. Invalid
driver rows or gaps beyond the chosen maximum interval split the trajectory.
Rejected rows are never silently bridged. An isolated sample cannot define an
integration segment. Failed segments remain audited.

Within each valid interval, the left-sample heat input is held constant for RK4
substeps. This numerical forcing convention does not interpolate or fill missing
telemetry. Set the maximum interval according to the instrument cadence.

## Independence and interpretation

Each segment starts from the configured network initial state; no artificial
periodic warm-up is performed. Measured temperatures do not drive the model
unless **Initialize from measured temperatures** is selected. That option is
explicitly labelled conditional validation. Unmeasured nodes retain configured
initial states. The first sample and the chosen initial exclusion window of
every segment are withheld from scoring. The default 600 s exclusion is not a
universal thermal settling time and must not be tuned to improve test scores.

Residuals are prediction minus measurement. Bias, MAE, RMSE, maximum absolute
error, correlation, and sample dispositions are exported. Fewer than three
usable pairs are labelled insufficient. Samples are not independent replicates.
A user RMSE limit is a user criterion, not proof of physical validity. Parameter
calibration must use different days or operating conditions from evaluation.

Export to a new empty directory. The MAT bundle contains raw input, mappings,
model and options. CSVs contain original rows, audit, segment status, predictions,
paired errors, and metrics. Bilingual plots include legends, and a Markdown
summary states assumptions and evidence boundaries. Raw source identifiers and
machine-readable field names remain unchanged across display languages.

## API

### External orbit/attitude task bundle

For reproducible ingestion, `leotherm.importExternalTask` accepts a scalar
MATLAB structure or a `.json`/`.mat` carrier using schema
`leotherm.external_task.v1`. The required sections are:

```json
{"schema":"leotherm.external_task.v1",
 "time":{"system":"UTC","elapsed_unit":"s",
         "epoch_utc":["2024-01-01T00:00:00Z","2024-01-01T00:00:10Z"],
         "elapsed_s":[0,10]},
 "orbit":{"position_m":[[7000000,0,0],[6999000,100000,0]],
          "velocity_mps":[[0,7500,0],[-100,7499,0]],
          "sun_position_m":[[149600000000,0,0],[149600000000,0,0]]},
 "attitude":{"representation":"quaternion",
              "convention":"ECI_TO_BODY_WXYZ",
              "values":[[1,0,0,0],[1,0,0,0]]}}
```

`representation` may be `quaternion` (N-by-4 scalar-first WXYZ) or `dcm`
(N-by-3-by-3, or N-by-9 row-major elements). Quaternions must already be
unit length; the adapter rejects non-unit values rather than silently
normalizing. The returned `task.trajectory` can be passed directly to
`simulateTrajectory`. An optional `telemetry` section is retained verbatim
and its declared `epoch_utc` is checked for exact equality with orbit epochs;
the report marks mismatches and never interpolates, sorts, or shifts rows.

```matlab
[task, quality] = leotherm.importExternalTask('mission_task.json');
result = leotherm.simulateTrajectory(task.trajectory, scenario, network);
disp(quality.synchronization); % exact_epoch_match or mismatch_rejected_no_interpolation
```

```matlab
network = leotherm.defaultReceiverNetwork;
scenario = leotherm.defaultScenario;
data = leotherm.readTelemetry('my_data.csv', [], network);
options = leotherm.telemetryOptions(struct('mode','orbit','frame','J2000_ECI'));
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
leotherm.writeTelemetryResults(result, report, data, 'results/new_run', 'en');
```

`leotherm.readGracefoIhk` reads real public GRACE-FO RL04 IPU housekeeping. The
included two-date study audits real measurements without claiming validation
of the generic reference network: sensor installation locations, thermal
parameters, power allocation, and asynchronous orbit epochs remain unresolved.
