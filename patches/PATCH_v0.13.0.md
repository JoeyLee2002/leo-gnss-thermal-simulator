# Patch v0.13.0: engineering thermal-model extensibility

## What changed

- Added the `leotherm.thermal_model.v1` canonical model contract.
- Added canonical model normalisation for the existing network, surface
  geometry, and volume-mesh paths.
- Added reference-only materials, temperature-dependent property evaluation,
  equivalent components, and explicit node mapping.
- Added MAT/JSON import and export with SI-unit checks, UTC checks, SHA-256
  input reports, and preservation of unknown extension fields.
- Added the bilingual Engineering thermal model workspace in the GUI.
- Added documentation and the synthetic fixture
  `examples/projects/06_engineering_model_exchange.json`.

## Verification

- Thermal-model, material/component, and exchange tests: 14/14 passed.
- GUI thermal-model tests: 2/2 passed.
- Full release verification is required before this version is treated as a
  final release.

## Scientific and engineering boundary

Built-in material values are reference values, not measurements for any
particular spacecraft. Importing a model successfully does not certify a
thermal-control design, reproduce a thermal-vacuum test, or validate a flight
model. The exchange layer does not infer contacts, perform hidden mesh
interpolation, or convert units implicitly.
