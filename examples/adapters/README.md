# Generic exchange adapter example

`generic_exchange_adapter.m` is a deliberately small, dependency-free bridge
from a neutral MATLAB structure (or neutral JSON/MAT file) to
`leotherm.thermal_model.v1`. It copies declared records, checks the existing
exchange contract, and can write JSON or MAT through the public I/O API.

Run the synthetic demonstration from MATLAB R2021b or newer:

```matlab
addpath('src');
addpath('examples/adapters');
jsonPath = run_generic_exchange_adapter;
model = leotherm.io.importThermalModel(jsonPath);
```

No external thermal program is launched. The values are synthetic fixtures for
checking file shape, units, and provenance fields only; they do not validate a
physical model. This example intentionally does not parse Thermal Desktop,
ESATAN, SINDA, OpenFOAM, or any proprietary format. See
`docs/adapter_development.md` for the project adapter boundary and a command-
line hand-off pattern.
