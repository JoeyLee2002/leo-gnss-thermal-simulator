# v0.5.0 GUI hierarchy patch

Date: 2026-09-14. Previous release: v0.4.5.

## Recovery snapshot

Before editing, the v0.4.5 source was archived to:

`H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.4.5_before_v050_ui_restructure_20260914.zip`

The adjacent `.zip.manifest.txt` records the source inventory. Historical result
directories were not replaced.

## Design decision

The product's main function is simulation. Models, telemetry and calibration are
inputs or preparation for a simulation, not peer-level destinations. The GUI now
shows two top-level areas:

- `Simulation`: configuration sections for single scenario, parameter sweep,
  thermal network, telemetry/validation and device calibration.
- `Results and export`: simulation outputs and export actions.

The underlying MATLAB panel objects remain separate so numerical code, project
state, and existing programmatic interfaces do not need a rewrite.

## Interaction changes

- The header keeps Save project and Open project. Self-test and About are in Tools.
- Telemetry keeps Import CSV, Preflight, node selection and Export result visible.
  Template, synthetic demo, and mapping import/export are in More actions.
- Calibration keeps Prepare calibration and Calibrate to new run visible. Device
  load, profile import/export and telemetry-day loading are in More actions.
- Network restore and result clearing are More actions, reducing accidental clicks.
- The Run scenario action remains visible outside its scrolling parameter list.

## Compatibility and limits

Existing project files, numerical solvers, result structures, telemetry rules,
calibration rules and no-interpolation policy are retained. This is a GUI hierarchy
release, not a change to the physical model. Internal tab handles remain available
to current MATLAB automation scripts, although their parent is now the Simulation
tab. The GUI still has no background queue, autosave or resume-after-restart.
