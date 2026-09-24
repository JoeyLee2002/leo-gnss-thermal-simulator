# v0.6.0 simulation-task workbench

Date: 2026-09-14. Previous release: v0.5.1.

## Recovery snapshot

Before editing, the source was archived to:

`H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.5.1_before_v060_simulation_workbench_20260914.zip`

The adjacent `.zip.manifest.txt` records the source inventory. Existing results and
the v0.5.1 paper-1 gap study were not overwritten.

## Product model

The software is presented as a low-Earth-orbit satellite thermal simulation-task
workbench. A task combines input data, thermal model, orbit/environment settings,
solver settings, optional telemetry validation and optional device calibration.
The output is one traceable simulation result or sweep result.

## GUI changes

- The top level remains `Simulation` and `Results and export`.
- A persistent task summary reports scenario, thermal network, node count, telemetry,
  calibration, solver settings and result freshness.
- Task-level primary actions are Check configuration, Run simulation, Run parameter
  sweep and View results.
- Existing detailed panels remain available as configuration sections, preserving
  their programmatic handles and existing project state.
- Configuration changes continue to invalidate old results; no result is silently
  relabeled as belonging to a new task.

## Scope

This release reorganizes the user workflow and adds task-level status. It does not
change the physical thermal equations, telemetry no-gap-filling policy, calibration
acceptance rules, project schema, or paper-1 experiment calculations.
