# Prescribed thermal boundaries and calibration

Version 0.4.2 adds exogenous conductive boundaries without changing the default
model. These features have software verification, not new flight qualification.

## Telemetry boundary channels

Map a pair of columns for each connected receiving node:

```text
boundary_temperature_k_gnss_rf_frontend
boundary_conductance_wk_gnss_rf_frontend
```

Temperature may also use `boundary_temperature_c_*` (degC). Conductance is W/K.
The added heat flow is `G*(T_boundary-T_node)`, positive into the modeled node.
Boundary temperature must be positive in kelvin; conductance must be nonnegative.
Unmapped nodes are disconnected. Remove or ignore both template columns for
unused nodes. A partially mapped pair is rejected.

Bad rows and excessive gaps split segments. Boundaries are held at the left
sample within valid intervals; no interpolation, resampling or gap filling is
performed. Internal integration steps are not additional observations. Strong
conductive boundaries impose an additional conservative RK4 step limit. This is
not an implicit stiff solver; very strong coupling can be expensive.

The GUI's CSV template dialog can include boundary columns. Its synthetic demo
contains a varying boundary and a labeled temperature curve. Language switching
retains the inputs, selected node and computed results.

`thermal_boundaries.csv` exports the prescribed inputs and instantaneous heat
flow at sample epochs, not interval-average power or integrated energy.
`manifest.json` includes the conditioning and sampling policy.

## Interpretation

A prescribed temperature is an external reservoir: the simulated node does not
change that reservoir's temperature. For two-way spacecraft dynamics, represent
the body as a node with heat capacity and symmetric network conductance instead.

Use an independently located body/hinge sensor or a justified external physical
model. Never duplicate the target temperature series into a boundary channel.
Agreement under prescribed boundaries does not validate the whole spacecraft,
the reservoir prediction, or the uniqueness of the thermal parameters.

The MinXSS panel API additionally accepts epoch-by-two `environmentPowerW`,
`boundaryTemperatureK`, and `hingeConductanceWK`. The last two form a mandatory
pair. For the two-node model, environment power and hinge conduction act on the
substrates. Columns are minus-Y, plus-Y. When prescribing environment power,
set the two constant environment parameters to zero and exclude them from the
free calibration vector; otherwise the predictor rejects double counting.
The archived flight study does not automatically enable these inputs because
verified hinge sensor correspondence and conductance are still unavailable.

## Calibration

`leotherm.fitThermalParameters(objective,bounds,settings,checkpointPrefix)` uses
training data through a user-supplied finite scalar objective. Bounds contain
`lower`, `upper`, and `initial`; all free parameter ranges must be nonzero.
Fix other parameters inside the objective's model-vector assembly.

Set `settings.solver` to `fmincon` or `fminsearch` for reproducibility. `auto`
uses licensed Optimization Toolbox when available, otherwise base MATLAB's
simplex optimizer with a normalized box penalty. Multistart initial points are
deterministic; explicit `settings.initialPoints` is also supported.

The fit records every start, exit flags, a finite-difference projected-gradient
diagnostic, near-bound flags, and parameter spread among near-optimal starts.
It does not establish identifiability or a global optimum. Budget exhaustion
does not count as convergence. `leotherm.requireCalibrationConvergence(fit)`
blocks freezing incomplete fits. Checkpoints refuse overwrites.

The old MinXSS dates have already been inspected during model development.
Current reruns are labeled development analyses, not fresh independent tests.
New flight evidence requires new, previously unused data and pre-fixed protocols.
