# LEO GNSS Thermal Simulator

**Start here:** [Chinese video walkthrough (v1.1.0 UI)](tutorial/LEOTherm_v1.1.0_中文统一任务教程.mp4) ·
[Unified task guide](docs/统一任务流水线_v1.1.0.md) ·
[Windows standalone package v1.2.0](downloads/LEOTherm_1.2.0_windows.zip).
The standalone build requires the free MATLAB Runtime R2021b, not a MATLAB license.
See the [installation guide](docs/独立版使用_v1.2.0.md).

Current release: **1.2.0**. Completed optional stages now add quantitative
findings and charts to the [task analysis report](docs/任务分析报告_v1.2.0.md).
See the [five-page Chinese sample PDF](examples/reports/参考网络_多工况扫描_报告样例_v1.2.0.pdf),
based on the reference network rather than flight validation.
Windows users without MATLAB can use the
[standalone release guide](docs/独立版使用_v1.2.0.md) with free MATLAB Runtime R2021b.
Build checks and the remaining Runtime-only-machine test are documented in
[standalone acceptance](docs/独立版验收_v1.2.0.md).
The GUI opens with a Quick start area, followed by
Simulation and Results. Scenario, sweep, thermal network,
telemetry and calibration are configuration sections of one simulation task.
Each run can be frozen with a task ID and input fingerprint. See
[the patch notes](patches/PATCH_v0.7.0.md) and [the usage guide](docs/usability_v0.7.0.md).
The v0.5.1 paper-1 gap studies and earlier usability protections remain in place.

Quick start now includes a Task wizard backed by versioned, human-editable JSON
templates under `templates/`. A beginner selects a template, changes only task
name, duration, and time step, supplies a CSV when required, and can run after
strict validation. Saved projects embed the template snapshot for reproducibility.
Results export creates a multipage PDF analysis report alongside the raw MAT,
CSV, figures, Markdown, and an audit manifest. The Chinese first-run-to-report
guide is [here](docs/统一任务流水线_v1.1.0.md).
Release checks and limits are recorded in [v1 acceptance](docs/软件验收_v1.0.0.md).

Version 0.4.3 adds a device-calibration workbench with immutable nominal
parameters, evidence-based hard limits, prior penalties and frozen whole-day
checks. See [the calibration guide](docs/device_calibration.md) or
[the Chinese instructions](docs/设备受约束标定使用说明.md).
Prescribed thermal boundaries remain available in [the boundary guide](docs/thermal_boundaries.md).
Previously inspected MinXSS dates are now development data, not a new blind test.

An actual MinXSS-1 held-out flight-temperature study is available through
`examples/run_minxss_flight_validation.m`. It uses the production thermal
solver, chronological splits, frozen parameters and complete failure reporting.
See [the study guide](studies/minxss/README_CN.md) for its limited validation scope.

A pure-MATLAB, dependency-free simulator for studying how orbit geometry,
attitude, eclipse structure, and multi-node heat transfer create thermal lag in
LEO GNSS receiver hardware.

The project connects four layers:

1. circular LEO propagation with optional secular J2 drift;
2. Sun geometry, beta angle, conical umbra/penumbra, and spacecraft attitude;
3. face-resolved direct solar, Earth albedo, and Earth infrared heat loads;
4. a configurable nonlinear thermal network and temperature-induced code bias.

It is designed for reproducible parameter studies rather than spacecraft
qualification. The included GNSS receiver network is a documented reference
model and must be calibrated before making mission-specific claims.

## Requirements

- MATLAB R2021b or newer;
- no Aerospace Toolbox or third-party runtime dependency.
- Optional Optimization Toolbox enables `fmincon` calibration; `fminsearch`
  remains available in base MATLAB. Pin the solver for reproducible fits.

## Quick start

Graphical workbench:

```matlab
cd('/path/to/leo-gnss-thermal-simulator')
launch_gui
```

The language selector switches the complete interface, tables, status text,
plots, and legends between Chinese and English while retaining the active
scenario, network, and results. A language can also be selected at launch:

```matlab
launch_gui('en')
launch_gui('zh')
```

Command-line workflows:

```matlab
cd('/path/to/leo-gnss-thermal-simulator')
startup
leotherm.version
leotherm.selfTest
run_baseline
run_beta_altitude_sweep
```

The example scripts accept the same language codes. All generated diagnostic
panels include legends:

```matlab
run_baseline('en')
run_beta_altitude_sweep('zh')
leotherm.plotScenario(result, 'summary.png', 'en')
leotherm.plotSweep(summary, 'sweep.png', 'zh')
```

Generated tables, MAT files, and figures are written under `results/`, which is
ignored by Git.

The graphical workbench provides seven configuration tabs: single-scenario
simulation, controlled/physical parameter sweeps, editable thermal networks,
3-D geometry, engineering thermal-model exchange, telemetry and validation,
and device calibration, followed by result inspection/export. It uses the same validated core APIs as the
command-line workflows.

The Engineering thermal model workspace imports and exports the
`leotherm.thermal_model.v1` MAT/JSON contract with strict SI-unit, UTC, finite
value, and provenance checks. Built-in material values are reference values,
not spacecraft measurements. See `docs/thermal_model_extensibility.md` for the
exchange workflow and current limitations.

## External software adapters

Release 0.15.0 adds the `leotherm.adapter.v1` adapter SDK. Users can register
MATLAB handlers, or load a JSON/MAT metadata descriptor and attach executable
handlers explicitly in MATLAB:

```matlab
adapter = leotherm.adapter.get('generic_exchange');
[model, audit] = leotherm.adapter.execute(adapter, 'readModel', 'model.json');
```

Controlled integration profiles are provided for Thermal Desktop, ESATAN-TMS,
SINDA/FLUINT, and OpenFOAM. They require an official exporter or licensed batch
interface to produce explicit exchange files or case directories, followed by
`leotherm.io.runExternalThermalSolver`. The runner avoids shell execution,
rejects shell metacharacters, isolates output directories, enforces a timeout,
and records stdout/stderr, exit status, timeout state, and SHA-256 artifact
fingerprints. `leotherm.report.writeThermalSimulationReport` exports bilingual
Markdown, CSV metrics, MAT audit data, and a JSON manifest.

These are controlled exchange and command profiles, not claims of native
proprietary-format parsing. Successful file exchange, numerical agreement, or
an external process exit code of zero is not thermal-vacuum, flight, or physical
validity evidence. See [the adapter development guide](docs/adapter_development.md).

The public `leotherm.simulateSurfaceVolumeScenario` workflow connects
orbit/attitude-driven face radiation, exact surface-to-volume boundary
matching, volume finite-element conduction, declared contacts, and fixed
temperature boundaries. `leotherm.writeSurfaceVolumeScenarioResult` exports
the coupled result, conservation diagnostics, volume time series, and bilingual
report in one call. The current coupling is explicitly one-way: face external
radiation is applied to the volume state and face temperature is not fed back.

## Telemetry and validation

Version 0.4.0 adds explicitly mapped CSV telemetry, orbit-driven or absorbed-heat
driven simulations, and comparison with existing scenario results. Orbit and Sun
vectors must share geocentric J2000 ECI. Rejected rows and excessive intervals
break arcs; no missing data are interpolated or filled. Temperatures are withheld
from driving unless measured initialization is explicitly enabled. Exact UTC
matching, signed errors, per-sample audit, bilingual figures, and complete input
archives support reproducible assessment, not automatic physical qualification.
See [the telemetry guide](docs/telemetry.md). `run_telemetry_demo` is synthetic,
not flight validation. A public GRACE-FO IHK1B reader and real-data readiness
audit are included under `studies/telemetry`; sensor locations and mission
thermal parameters must be established before claiming model validation.

## Reference model

The default network contains 11 nodes:

- six external spacecraft faces;
- spacecraft structure;
- GNSS antenna;
- RF front end;
- frequency-reference/oscillator assembly;
- receiver digital board.

All capacities, conductances, optical properties, powers, and code-bias
sensitivities are exposed in `leotherm.defaultReceiverNetwork`.

## Parameter studies

`leotherm.runBetaAltitudeSweep` solves the RAAN required to reach a requested
beta angle at a specified epoch and inclination. It marks geometrically
inaccessible cases instead of interpolating or silently replacing them.

`leotherm.runPhysicalSweep` accepts dates, inclinations, RAANs, and altitudes.
In this mode beta angle is an output of physical Sun-orbit geometry rather than
an independently imposed variable.

`leotherm.simulateTrajectory` accepts an externally generated ECI position,
velocity, epoch, and optional body-frame history. This provides the integration
point for precise orbit products, mission attitude telemetry, or independently
generated Basilisk/SPICE histories without adding a Python runtime dependency.
Trajectory dimensions, finite values, epoch counts, and body-frame
orthonormality are validated before thermal integration.

## Reproducibility boundaries

- circular orbit with optional secular J2 rates;
- analytical low-precision solar ephemeris, adequate for thermal trade studies;
- nadir-pointing, Sun-pointing, or inertially fixed attitude;
- spherical Earth and Sun with conical umbra/penumbra overlap;
- diffuse, gray thermal-node assumptions;
- approximate albedo based on the sub-satellite solar zenith angle.

See `docs/model.md` and `docs/validation.md` before interpreting results.
The scoped same-input comparison with SATMO v1.5.0 is documented in
`docs/satmo_external_validation.md`; it can be reproduced with
`studies/softwarex/validate_satmo_reference.m` after adding that directory to
the MATLAB path.
The complete Chinese operating manual is provided in
`docs/用户使用说明书.md`.

## License and attribution

MIT License. Methodological influences and third-party references are listed in
`NOTICE.md`. `LICENSE` and the journal-compatible `Licence.txt` contain the
same license text. No SATMO or Basilisk source code is redistributed.

## Version updates

Before changing an analysis-used version, run `tools/create_version_snapshot.m`,
increment `VERSION`, and add a patch note under `patches/`. See
`docs/versioning.md`.
