# v0.6.0 simulation-task workbench guide

The GUI follows one workflow: configure a simulation task, check it, run it, and
inspect the result. The top level has only `Simulation` and `Results and export`.

The Simulation area keeps detailed sections for Single scenario, Parameter sweep,
Thermal network, Telemetry and validation, and Device calibration. These sections
are inputs to one task, not separate peer products.

The persistent task summary reports the active scenario, network, node count,
telemetry and calibration state, solver settings, and result freshness. Its primary
actions are Check configuration, Run simulation, Run parameter sweep, and View results.

Low-frequency actions remain under Project, Tools, or More actions. Existing project
files, numerical solvers, no-gap-filling telemetry behavior, calibration safeguards,
paper-1 studies, and stale-result protection are preserved.
