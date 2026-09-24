# Thermal-model extensibility and exchange (v1)

This guide is for a new user who needs to attach an engineering team's
equivalent thermal model to the simulator. It documents the **exchange
adapter** contract, not a qualification or flight-thermal standard. The
Chinese workflow is in [热模型扩展工作流](热模型扩展工作流.md), and a small,
synthetic JSON fixture is in
[`examples/projects/06_engineering_model_exchange.json`](../examples/projects/06_engineering_model_exchange.json).

## Two related interfaces

There are two intentionally separate representations:

* `leotherm.io.importThermalModel` / `exportThermalModel` exchange a record
  bundle (`leotherm.thermal_model.v1`) in JSON or MAT.
* `leotherm.model.normalize` / `leotherm.model.validate` build and check the
  canonical solver-facing model. The normalized form has `network`,
  `geometry`, `volumeMesh`, `material`, `units`, `connectivity`,
  `provenance`, and `uncertainty` fields.

The adapter does not turn `nodes` or `components` into a solver network and
does not silently apply a component patch. A project integration must make
that mapping explicit, review it, and then call the normalizer/validator.
See [Thermal model contract v1](thermal_model_schema_v1.md) for the latter
API.

## Exchange contract

The top-level JSON/MAT object must contain all of these fields:

`schema`, `metadata`, `nodes`, `materials`, `components`, `contacts`,
`boundaries`, `provenance`, and `uncertainty`.

`schema` is exactly `leotherm.thermal_model.v1`. `metadata` requires a
non-empty `modelId`, a UTC timestamp (`YYYY-MM-DDTHH:mm:ss[.fff]Z`), and the
following canonical SI declarations:

| field | unit |
|---|---|
| `length` | `m` |
| `mass` | `kg` |
| `time` | `s` |
| `temperature` | `K` |
| `power` | `W` |
| `heatCapacity` | `J/K` |
| `conductance` | `W/K` |
| `area` | `m^2` |

Record arrays may be empty, but keeping array order is important to an
engineering review. The adapter checks container shape and finite numeric
values; it does not infer missing physics. Use stable IDs and refer to them
from `nodeIds` in contacts, boundaries, and components. Typical node fields
are `id`, `name`, `positionM`, `capacityJK`, `initialTemperatureK`, and
`internalPowerW`; typical material fields are the identifiers and properties
described below. Project-specific fields can be added: JSON round-trips retain
unknown fields.

For MAT exchange, save the object as variable `thermalModel`:

```matlab
thermalModel = myExchangeStruct;
leotherm.io.exportThermalModel(thermalModel, 'model.mat');
```

The importer also accepts a variable named `model`, or one unambiguous
variable in a legacy MAT file. JSON is read with `jsondecode`; both formats
are validated by `leotherm.io.validateThermalModel` before a model is
returned. A report includes format, schema, the current container byte
fingerprint, and the fact that unknown fields were retained. If the model
declares `provenance.inputFingerprint`, it is also reported as
`sourceFingerprint`. The two values have different meanings: `inputFingerprint`
hashes the bytes of the JSON/MAT container currently being imported, while
`sourceFingerprint` is the upstream source digest carried inside the model.
Reformatting or re-exporting can change the former without changing the
latter. Neither value is a physical-validation or qualification result.

## Materials: reference values versus project evidence

`leotherm.materialLibrary()` contains four built-in engineering references:

| id | conductivity (W/(m·K)) | density (kg/m³) | specific heat (J/(kg·K)) |
|---|---:|---:|---:|
| `aluminum_6061` | 167 | 2700 | 896 |
| `aluminum_7075` | 130 | 2810 | 960 |
| `stainless_steel_304` | 16.2 | 8000 | 500 |
| `peek` | 0.25 | 1320 | 1100 |

These values also carry `isReferenceValue=true`,
`provenance='reference_only'`, a source note, and indicative uncertainty.
They are not measurements of a particular spacecraft. Before a mission
analysis, replace or supplement them with a traceable supplier datasheet,
coupon test, thermal-vacuum result, or approved project database record.

Registering a custom material uses `leotherm.materialLibrary('register', m)`.
Every material needs non-empty `id`, `name`, `source`, `confidence`, and
`uncertainty`; positive conductivity, density, and specific heat; and optical
properties in `[0,1]` when supplied. A temperature-dependent material may use
an increasing `temperatureK` grid with tabulated positive properties, or
MATLAB `...Fcn` handles. Function handles are MATLAB-only and are **not a
portable JSON exchange representation**; use a documented table for JSON.
Temperatures are Kelvin and must be inside `temperatureRangeK` when a curve is
evaluated.

## Equivalent components and node mapping

Create a component with `leotherm.componentModel(spec)` and map it with
`leotherm.componentModel(spec, network)` (or `leotherm.componentModel('map',
component, network)`). Required traceability fields are `id`, `name`,
`source`, `confidence`, and `uncertainty`, plus `nodeIndex` or `nodeName`.
Provide either:

* `capacityJK`, or
* `massKg` plus a material (the equivalent capacity is mass × specific heat;
  a temperature-dependent material is evaluated at 293.15 K for this
  reduction).

`internalPowerW`, `contactConductanceWK`, `projectedAreaM2`, and
`radiatingAreaM2` are non-negative; `capacityJK` is positive; absorptivity
and emissivity are in `[0,1]`. Mapping returns `nodeIndex`, `nodeName`, and a
`networkPatch` record but does not mutate the supplied network. Apply and
review that patch explicitly before solving.

## Provenance, units, and fingerprints

Write where every engineering value came from: document or database ID,
revision, date, test temperature, and any transformation (lumping,
rounding, or reduction). Put a concise summary in `provenance.source` and
the details in `provenance.transformations` or extension fields. If
`provenance.inputFingerprint` is present, it is a 64-character
case-insensitive SHA-256 digest of the upstream source bytes. It is provenance,
not a digest of the newly exported MAT/JSON container, so export/import
round-trips preserve it. The import report exposes the current container digest
as `inputFingerprint` for backward compatibility and the declared upstream
digest as `sourceFingerprint`; use `RequireFingerprint=true` when a workflow
requires a declared source digest.

Do not submit millimetres, centimetres, Celsius, hours, or `W/m^2` while
declaring SI. No automatic conversion, interpolation, sorting, padding, or
deletion is performed. Convert upstream, record the conversion, and verify
the resulting SI values. `uncertainty` must remain explicit; the normalized
contract currently supports only the `stratified_uniform` sampler.

## What v1 does not support

* It does not import arbitrary thermal-control software formats directly;
  write a deliberate JSON/MAT adapter layer.
* It does not infer contacts, boundary conditions, node connectivity,
  material regions, or missing parameters from names or geometry.
* It does not exchange MATLAB function handles in JSON, nor does it execute
  vendor scripts during import.
* It does not automatically couple surface radiation to a volume FEM mesh or
  perform non-matching-mesh interpolation.
* It does not perform thermal-vacuum correlation, sensor calibration,
  qualification margins, hot/cold-case certification, or flight-data
  validation.

## A safe hand-off sequence

1. Export the team's reduced model to the v1 fields and canonical units.
2. Attach source, revision, transformation, confidence, and uncertainty
   records; mark reference values explicitly.
3. Run `leotherm.io.validateThermalModel` (or `importThermalModel`) and fix
   every reported error.
4. Map components to an existing network, review the returned `networkPatch`,
   and construct a canonical model with `leotherm.model.normalize`.
5. Run connectivity, conservation, sensitivity, and independent correlation
   checks before using results in an engineering decision.

Passing an exchange validation is only a data-integrity check. It is not
evidence that the equivalent model is an accepted spacecraft thermal-control
model.
### GUI explicit network mapping

After importing a valid MAT/JSON exchange model, the Engineering thermal model tab
offers an explicit mapping loop: load a `leotherm.thermal_model_mapping.v1` file or
generate a minimal template, preview the proposed writes, inspect changed fields,
unmapped nodes, conflicts, and fingerprints, then confirm before applying. The apply
action reconnects the resulting network to the current simulation task and invalidates
stale results. A rollback control restores the network captured immediately before model
import. Import and mapping failures are atomic and leave the active state unchanged.

The GUI never guesses by node name, interpolates values, or auto-completes mappings.
The Chinese interface exposes the same controls and safeguards as the English interface.
