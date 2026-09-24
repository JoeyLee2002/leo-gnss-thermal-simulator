# Contributing

Contributions should preserve the project's separation between geometry,
environmental forcing, thermal dynamics, and observation-domain mapping.

Before opening a change:

1. run `run_tests` in MATLAB R2021b or newer;
2. add a focused verification case for changed physics;
3. document assumptions and units at the public function boundary;
4. do not add proprietary spacecraft parameters or redistribute third-party
   source without confirming its license;
5. keep mission-calibrated configurations separate from the public reference
   model unless those parameters can be lawfully released.

New validation data should include provenance, generation settings, units, and
an explicit statement of whether it was used for parameter correlation.

