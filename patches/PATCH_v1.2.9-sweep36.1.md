# Supplemental study package v1.2.9-sweep36.1

Date: 2026-10-11.

The preceding published repository was saved to a version snapshot before
these additions. The engine version remains 1.2.9; `src/`, `VERSION` and the
Runtime executable are unchanged.

The new `studies/softwarex/sweep36/` package publishes the 36-case experiment
and three temporal refinements, with preserved original data, human-readable
parameters, complete CSV temperature histories and native MATLAB figures.
The public scripts resolve source paths from their package location and accept
separate output directories. Cached runs are checked against complete inputs,
saved outputs and a SHA-256 fingerprint of the engine source. Archive writes
are rejected. The current manuscript's two-hour reference task is separate
from the periodically initialized sweep.

Validation: see `studies/softwarex/sweep36/verification.json` and its README.
The original six-case example remains available for the preceding report demo.
