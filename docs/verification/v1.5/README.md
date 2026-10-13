# v1.5 Public Verification Records

These are archived records of the already-tested Windows release, not new test runs performed
during publication. The illustrated-manual update and publication do not rebuild the executable.

- `verification_v1_5_status.txt`: full-suite completion counters (444/444).
- `release_gate2.log`: the corresponding MATLAB verification log; read the host-teardown caveat in
  `../../verification_v1.5_release.md` together with this log.
- `paper_results.csv`, `audit.csv`, `paper_study_status.json`, `time_refinement.csv`: output of the
  completed 40-job Runtime reproduction. `case_count` is 36 and the four Boolean protocol flags are 1.
- `runtime_status_read_audit.json`: 19,505 status reads and zero parsing failures.
- `runtime_checks/`: small status/manifest records from direct Runtime checks; this directory is
  not a substitute for the detailed description of exit codes in the release verification guide.
- `documentation_qa.json`: image/link/PDF checks and the unchanged-source/executable check.
- `package_audit.json`: the illustrated ZIP and executable hashes.
- `publication_source_manifest.json`: copied release-source hashes, including normalized LF hashes
  for cross-platform Git line-ending comparison. No credentials or private repository data are included.

The experimental quantities have different meanings: RF P95-P5 is a percentile temperature span;
phase delay is relative to absorbed power at the orbital frequency; energy closure is a numerical
accounting check. The reference configuration and tiny geometry examples are tutorial inputs.
