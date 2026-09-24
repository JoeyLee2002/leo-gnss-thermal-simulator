# v0.7.0 mature simulation workbench

Date: 2026-09-14. Development base: v0.6.0.

## Product architecture

The workbench now has a first-class simulation task model. A task groups the scenario,
thermal network, telemetry state, calibration state, scan settings and run mode. Before
a calculation, the task is validated and frozen with a UUID and SHA-256 input fingerprint.

Scenario results carry the task ID and input fingerprint. The application records the
task ID, run type, status, timestamps and fingerprint in its workspace state. This makes
it possible to distinguish two results that use similar names but different scientific
inputs.

## Public task API

- `leotherm.createSimulationTask` creates a task structure.
- `leotherm.validateSimulationTask` checks required sections and stale warnings.
- `leotherm.freezeSimulationTask` creates a reproducible run snapshot.
- `leotherm.runSimulationTask` executes a frozen scenario task.
- `leotherm.simulationTaskFingerprint` computes the input identity.

## Scope

This release is the architecture foundation for a mature research workbench. Existing
GUI panels and project files remain available. The task object does not claim to add
background execution, automatic model calibration, physical validation, or a new thermal
equation; those require separate evidence and implementation.
