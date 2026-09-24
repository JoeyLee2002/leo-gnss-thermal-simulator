# Patch v0.9.3: auditable face-result export

## Scope

Face-only simulations are now first-class exportable results. The export
contains a MAT result, a face property table, a wide time-series CSV, and
metadata including solver diagnostics and thermal-parameter provenance.

## Compatibility

Node and sweep exports are unchanged. The existing face-result MAT file is
still written inside the `surface_mesh` export directory. No numerical solver
behavior was changed by this patch.

The GUI now recognizes a face-only result as exportable and includes it in the
Results action, task summary, and clear-results workflow. Older face-result
structures without the newer shadow-count field remain readable.
