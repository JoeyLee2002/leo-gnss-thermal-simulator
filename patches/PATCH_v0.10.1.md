# Patch v0.10.1: customer-facing usability fixes

This patch addresses the first-use and result-interpretation issues identified
in a read-only customer-manager review of v0.10.0.

## Changes

- The simulation task status is populated immediately when the GUI opens.
- Scenario, sweep, surface-mesh, and volume-mesh result states are reported
  independently instead of overwriting one another.
- Clearing displayed results also clears the volume-mesh result and refreshes
  all result indicators.
- Editing volume material parameters now refreshes task and result state.
- A volume result whose mesh or material inputs changed is visibly marked stale.
- Current README and user guides identify v0.10.1; historical release notes
  remain unchanged.

## Scientific boundary

This patch changes GUI state communication and documentation only. It does not
change the orbit propagation, heat-load equations, thermal integrator, mesh
solver, telemetry model, or calibration algorithm.

## Verification

The release gate is the full MATLAB test suite, static inspection, and both
Chinese and English GUI smoke tests. The generated status files are kept under
`results/`.
