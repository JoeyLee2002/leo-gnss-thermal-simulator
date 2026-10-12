# Audited v1.2.10 source and verification record

This release restores the archived v1.2.10 source used for the paper. Its 60 test files contain 381 test functions. The recorded run on 11 October 2026 passed 381/381 tests in 60 isolated MATLAB batches with zero Code Analyzer findings.

- `verification_v1_2_10_status.txt`: original machine-readable result.
- `verification_v1_2_10_resumed2.log`: original final release-gate log.
- `source_manifest.json`: hashes of all restored source and test files, plus the historical snapshot hash.

The records describe the archived run. Publishing this tag does not constitute a new test execution. Later development versions have separate test suites.

For reproduction, check out `v1.2.10` and follow `docs/reproduce_paper_v1.2.10.md`. The original 36-case study archive remains at `v1.2.9-sweep36.1`.
