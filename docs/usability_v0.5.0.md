# v0.5.0 usability guide

The GUI follows one product flow: configure a simulation, run it, then inspect or
export results. Only `Simulation` and `Results and export` are top-level areas.

Inside Simulation, the five configuration sections are Single scenario, Parameter
sweep, Thermal network, Telemetry and validation, and Device calibration. They remain
separate MATLAB panel objects for compatibility, but are inputs to the simulation.

Visible primary actions are intentionally short: Save/Open project, Run scenario,
Run parameter sweep, Import CSV, Preflight, Export result, Prepare calibration, and
Calibrate to new run. Low-frequency actions are under Project, Tools, or More actions.

The Project menu contains Save as and device-configuration import/export. Tools
contains Self-test and About. Telemetry More actions contains templates, synthetic
demo, and mapping import/export. Calibration More actions contains device/profile/day
operations. Network and Results also use More actions for restore and clear.

This release changes navigation and action grouping only. Project files, stale-result
protection, exact UTC time, telemetry preflight, no-gap-filling behavior, and
calibration safeguards remain unchanged.
