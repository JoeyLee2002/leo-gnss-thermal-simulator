# Adapter Development Guide

The extension contract is `leotherm.adapter.v1`. An adapter converts a vendor
model or user dataset into the canonical model/result contracts. It must not
silently convert units, sort records, interpolate, fill missing data, or infer
node correspondences.

Enabled capabilities require MATLAB function handles. JSON descriptors may
store metadata, versions, formats and provenance, but never executable
function handles.

Execute a capability through the common entry point:

```matlab
[model, audit] = leotherm.adapter.execute('my_exchange', 'readModel', 'model.json');
```

Metadata-only JSON/MAT descriptors can be registered with handlers attached in
MATLAB code:

```matlab
[adapter, descriptorReport] = leotherm.adapter.registerFromFile( ...
    'my_adapter.json', 'Handlers', struct('readModel', @myReadModel));
```

Descriptor files must not contain non-empty `handlers` fields or function
handles. Descriptor provenance is retained in the registered adapter.

Common external profiles are provided for Thermal Desktop, ESATAN-TMS,
SINDA/FLUINT and OpenFOAM. They are exchange/command profiles, not claims of
native proprietary-format parsing. Use an official exporter or licensed batch
interface, then run the controlled command adapter and import the explicit
result.

`leotherm.io.runExternalThermalSolver` rejects shell metacharacters, isolates
the output directory, enforces a timeout, records stdout/stderr and exit code,
and hashes input/output artifacts. Non-zero exits, timeouts, and missing expected
outputs are returned as complete failure records for reporting. Configuration
and safety errors remain hard failures. `leotherm.report.writeThermalSimulationReport`
creates bilingual Markdown, CSV metrics, MAT audit data and a JSON manifest.

For the internal 3-D surface-to-volume workflow, use
`leotherm.writeSurfaceVolumeScenarioResult` to export the coupled result,
conservation diagnostics, volume time series, and bilingual report in one call.
The current coupling is explicitly one-way; the report records that face
temperature feedback is not enabled.

Successful exchange or numerical agreement is not physical validation. A user
adapter must retain source, software version, units, transformations and
input/output fingerprints.
