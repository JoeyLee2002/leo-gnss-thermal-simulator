# Patch v0.15.0: external solver adapter SDK

## What changed

- Added `leotherm.adapter.execute` as the common, capability-gated entry point
  for user and built-in MATLAB adapters.
- Added `leotherm.adapter.registerFromFile` for JSON/MAT metadata descriptors.
  Descriptor files cannot provide executable handlers; handlers must be
  attached explicitly by MATLAB code and are validated before registration.
- Added `status` and `failureIsReturnedForReporting` to external-solver runs.
  A non-zero exit, timeout, or missing expected output now returns a complete
  audit record with `failed` or `timed_out` status. Invalid configuration and
  unsafe command construction still raise errors.
- Added provenance-preserving descriptor reports and expanded bilingual adapter
  documentation.

## Verification

- Adapter and external-solver focused tests: 8/8 passed.
- Full repository regression suite: 275/275 passed, 0 failed, 0 incomplete.
- Static analysis of the changed MATLAB files: 0 findings.

## Compatibility and boundaries

- MATLAB R2021b remains the supported baseline.
- Thermal Desktop, ESATAN-TMS, SINDA/FLUINT and OpenFOAM are supported as
  controlled exchange/command profiles. This release does not claim native
  proprietary-format parsers, automatic unit conversion, mesh interpolation,
  missing-data repair, node matching, or physical validation.
- External-process failure is now returned for reporting instead of thrown after
  execution. Configuration, path-safety, and shell-metacharacter errors remain
  hard failures.
