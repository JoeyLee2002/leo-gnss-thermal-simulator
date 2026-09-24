# Patch v0.9.2: auditable mesh thermal inputs

## Scope

Imported surface meshes now carry explicit reference face heat capacities,
initial temperatures, a zero face-to-face conductance matrix, and a provenance
label. The face solver uses these values when no runtime override is supplied
and reports the source of every thermal input.

## User-visible changes

- Added `app.setSurfaceMeshThermal` for programmatic use.
- Added validation for face thermal vectors, symmetric conductance, and
  provenance text.
- Added thermal-source diagnostics to the face solver.
- Hand-built meshes without emissivity now receive the same explicit reference
  emissivity default as imported meshes, with its source reported.
- Solar self-shadow diagnostics now report blocked fraction among illuminated
  faces, rather than among all mesh faces.

## Compatibility and boundary

Legacy hand-built mesh structures without the new fields remain valid and use
the former area-scaled capacity, uniform initial temperature, and zero
conductance defaults. This patch still does not provide material inference,
solid finite-element conduction, thermal contacts, or flight calibration.

## Verification

Added tests for imported defaults and solver source reporting. The prior v0.9.1
self-shadowing tests remain part of the regression suite.
