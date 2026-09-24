# Model definition

## Evidence chain

The simulator evaluates

```text
orbit/date/attitude
  -> Sun direction, beta angle, eclipse, incidence angle
  -> direct solar, albedo, and Earth-IR loads on each exposed node
  -> nonlinear multi-node temperatures
  -> configurable temperature-induced GNSS code bias
```

## Orbit and beta angle

The reference propagator uses a circular orbit. When J2 is enabled, secular
RAAN and argument-of-perigee rates are applied. The signed beta angle is

```text
beta = asin(h_hat dot s_hat),
```

where `h_hat` is the orbit-normal unit vector and `s_hat` points from Earth to
the Sun.

For a controlled beta study, the simulator analytically solves the two RAAN
branches that satisfy a requested beta. A case outside the inclination/date
accessible beta range is rejected and recorded as inaccessible.

For flight or high-fidelity studies, `simulateTrajectory` bypasses the internal
propagator. It accepts an ECI state history and an optional N-by-3-by-3 body-axis
history. The function requires strictly increasing epochs and deliberately does
not repair or interpolate missing trajectory records.

## Eclipse

The Earth and Sun are treated as apparent disks observed from the spacecraft.
Their angular radii and angular separation are used to compute the visible
fraction of the solar disk. The output therefore varies continuously through
penumbra instead of switching between binary sunlight and shadow.

## Environmental heat loads

For exposed node `i`, direct solar heating is

```text
Q_sun,i = alpha_i A_i S d_AU^-2 max(0, n_i dot s) V_sun.
```

Earth albedo is a reduced Lambertian approximation using the Earth view factor,
the local dayside factor, and face incidence. In v0.4.4, new scenarios use
`environment.earthIRModel = 'finite_disk'`: uniform Earth IR is integrated over
the apparent spherical Earth disk using analytic azimuth integration and
48-point Gauss-Legendre radial quadrature. A side-facing surface receives IR
from the visible part of Earth. For nadir-facing surfaces the factor is (R/r)^2;
for tangent-facing surfaces it is (alpha - sin(alpha)*cos(alpha))/pi, with
alpha = asin(R/r). The numerical quadrature is tested against both limits.
`legacy_cosine` preserves the previous geometry; old configurations without this
field also retain it. Albedo remains the reduced approximation in both modes.
Internal electrical
power is specified per node.

## Thermal network

The network solves

```text
C_i dT_i/dt = Q_ext,i + Q_int,i
              + sum_j K_ij (T_j - T_i)
              - epsilon_i sigma A_rad,i (T_i^4 - T_space^4).
```

A fourth-order Runge-Kutta integrator returns the requested output time grid,
with adaptive internal step doubling and a thermal-rate stability cap on every
path. Default local error scales are 1e-6 K absolute plus 1e-8 relative. The
limits structure optionally accepts absoluteToleranceK, relativeTolerance and
maximumInternalSteps. Diagnostics include accepted/rejected steps and an
independent RK-stage energy ledger (`integratedExternalHeatJ`,
`integratedInternalHeatJ`, `integratedRadiatedHeatJ`, and
`integratedBoundaryHeatJ`). The stored-energy change is compared with the
ledger's external + internal - radiated + boundary total and exposed as
`energyClosureResidualJ`/`maximumEnergyClosureJ`; conductive exchange cancels
globally for the symmetric network. This is an accounting check, not physical
validation of parameters or forcing. Adaptive integration does not recover
unsampled changes in forcing: output/forcing-grid convergence must still be
checked separately. Telemetry remains left-held on valid intervals with no gap
filling.
By default, a repeatable one-orbit forcing cycle is applied until the maximum
same-phase node-temperature error remains below the configured threshold for
the required number of cycles. Fixed warm-up orbits remain available only as a
compatibility mode.

## Thermal-lag and hysteresis metrics

Peak phase is evaluated independently for each adequately sampled orbit. Flat
or tiny signals, broad or repeated maxima, and negative signed peak phases do
not produce a positive thermal-delay claim. The signed phase remains available
as a diagnostic, and missing values remain NaN in numeric exports. The default
amplitude screen is max(1e-8, 1e-6 * maximum absolute signal); this is a numerical
screen, not a sensor-noise significance test. Sampling resolution and usable
cycle counts are reported. These are waveform phases, not heat-transfer time
constants or proof of causation. Eclipse-event metrics are the time from eclipse entry to the subsequent
temperature minimum and from eclipse exit to the subsequent temperature maximum.
They are missing for absent transitions, flat temperatures, truncated search
windows or extrema at window boundaries. They include illumination duration
and should not be interpreted as isolated material thermal time constants.

Thermal hysteresis is the absolute shoelace area of the closed absorbed-heat--
temperature curve for each complete orbit. The physical area retains W K units;
the normalized area divides each axis by its 5--95% span and must not be used to
imply a large absolute response when both spans are small.

## Code-bias mapping

The included mapping is a semi-synthetic observation model:

```text
b = sum_i gamma_i (T_i - median(T_i))
    + gamma_2 (Delta T_RF^2 - median(Delta T_RF^2)).
```

The default coefficients are hypotheses, not flight-calibrated constants. The
thermal results remain valid independently of this optional mapping.

## Surface-mesh radiation model (v0.9.4)

An imported STL/OBJ mesh can be evaluated independently from the lumped
receiver network. Each triangle has an area, outward normal, centroid,
absorptivity and infrared emissivity. External solar, reduced albedo and Earth
infrared loads are applied per face.

For face-to-face infrared exchange, the current preprocessor uses a centroid
differential-area estimate with optional triangle ray blocking. The matrix is
scaled to preserve the standard reciprocity relation

```text
A_i F_ij = A_j F_ji
```

and its rows are constrained not to exceed one; the remainder is treated as
deep-space view. The face solver uses the gray diffuse radiosity system

The default radiation side is the outward side of the imported mesh, which is
appropriate for an external spacecraft shell. Internal cavities can set
`mesh.radiationSide = 'inward'` or pass `thermal.radiationSide = 'inward'`.

```text
J_i = epsilon_i sigma T_i^4 + (1-epsilon_i) G_i
G_i = sum_j F_ij J_j + F_i,space sigma T_space^4
```

and couples the resulting net radiative exchange to a transient face thermal
balance. Direct solar can optionally use a binary centroid-to-Sun ray test for
mesh self-shadowing. The scalar Earth eclipse fraction and the geometric
face-visible fraction are retained as separate outputs (`eclipseVisibleFraction`
and `faceVisibleFraction`). This is a research-level
face model, not a replacement for a hemicube, Monte Carlo, exact surface integration or a certified engineering
radiation preprocessor. Solid 3-D conduction,
contact interfaces, thermal-control hardware and automatic mesh-to-component
mapping remain outside v0.10.0.

Face results can be exported with face properties, thermal time series, and a
metadata snapshot. This keeps the numerical result traceable to the mesh-level
thermal parameters used by the solver.

Imported meshes carry reference face heat capacities, initial temperatures and
a zero face-conductance matrix. These are explicit defaults and are reported in
the thermal solver diagnostics; they are not flight-calibrated material data.

## Volume-mesh conduction model (v0.10.0)

The volume path reads ASCII Gmsh 2.x linear tetrahedra and preserves the first
element Physical Tag as `tetraPhysicalTags`. Binary Gmsh, MSH 4.x and higher
order elements are rejected explicitly. Boundary-triangle Physical Tags remain
separate as `boundaryPhysicalTags`; they do not silently determine volume
materials.

Its conduction form
follows the standard heat equation used by the MOOSE heat-conduction module,
implemented independently here with linear tetrahedral shape functions:

```text
C dT/dt + K T = P
K_e = k V (B^T B)
C_e = rho cp V / 4 I   (lumped nodal capacity)
```

Transient integration uses the theta method with backward Euler as the default
(`theta = 1`). Fixed-temperature nodes are imposed by elimination. This is a
conduction-only volume solver and is not yet automatically coupled to the
surface mesh's solar, Earth-IR, radiosity or self-shadowing loads. Material
properties must be supplied by the user; the reference values are not mission
calibrated. A single scalar or per-tetrahedron material vector remains
supported. For multi-material meshes, pass an explicit `regionProperties`
structure array, for example:

```matlab
material.regionProperties = struct( ...
    'physicalTag', {1, 2}, ...
    'conductivityWmK', {1.0, 0.2}, ...
    'densityKgM3', {2700, 1200}, ...
    'specificHeatJkgK', {900, 1500});
```

Every tetrahedron must then have one nonzero tag and every tag must have a
matching region entry. Missing or unmatched tags are errors rather than a
fallback to an arbitrary material. Exported `volume_elements.csv` records the
tag and the three material values actually used by the assembly.

The v0.10.0 chain helpers add conservative exact surface-to-volume load
mapping, pairwise contact conductance, and fixed-temperature/flux/linear-Robin
boundary operators. Surface loads are face powers in watts (or explicit heat
fluxes in W/m^2); mapped volume loads are nodal powers in watts. Exact boundary
triangle and shared-coordinate matching is required. A mismatch is rejected;
the helper does not perform hidden nearest-neighbour or nonconforming-mesh
interpolation. Contact conductance uses `Q = G (T_left - T_right)` and its
assembled pair contribution is symmetric with zero row sum.

`importExternalTask` accepts the explicit `leotherm.external_task.v1` schema
with UTC, strictly increasing epochs and SI seconds. It can convert only the
declared `ECI_TO_BODY_WXYZ` quaternion convention and reports exact epoch
synchronization; it does not sort, interpolate, fill gaps or shift time.

`writeThermalReport` exports bilingual Markdown, stable English-key CSV files,
a JSON manifest and preserved MATLAB payloads. Missing telemetry, contact
data or other modules are reported as unavailable rather than inferred.
