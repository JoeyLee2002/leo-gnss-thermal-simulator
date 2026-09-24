# v0.7.0 simulation task object

Each simulation is represented by a task containing the scenario, thermal network,
telemetry state, calibration state, scan settings, and run mode. The task is validated,
then frozen before a calculation. A frozen task receives a UUID and SHA-256 input
fingerprint, and scenario results carry both values.

The application also records task identity, run type, status, timestamps, and input
fingerprint in its workspace state. Existing GUI configuration sections remain available;
the task object is the common foundation beneath them.
