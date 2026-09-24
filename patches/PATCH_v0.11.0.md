# Patch v0.11.0: quick-start workspace

## User-facing changes

- Added a default Quick start area with three task templates:
  first simulation, thermal-lag analysis, and telemetry validation.
- Added an Advanced simulation action that opens the existing full configuration workspace.
- The first two templates apply documented reference scenarios and run the normal
  production solver. The telemetry template only opens the telemetry workflow and
  never fabricates a validation result.
- Updated GUI smoke expectations and documentation for three main areas.
- Added a confirmation before a template replaces unsaved scenario or network settings.

## Scientific boundary

This release changes the first-use workflow and does not change orbit propagation,
environmental heat loads, thermal integration, telemetry processing, or calibration.
