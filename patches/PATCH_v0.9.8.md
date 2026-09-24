# Patch v0.9.8: result integrity and input safety

This release improves the reliability boundary of the research workbench.

The lumped thermal-network solver now records independent RK-stage integrals
for external, internal, radiative and boundary heat. It reports cumulative
energy-closure residuals by comparing these channels with the change in stored
thermal energy. The ledger is an accounting check, not an independent
validation of material parameters, forcing data or physical fidelity.

Mesh input validation now rejects duplicate Gmsh node IDs, invalid node and
element metadata, repeated tetrahedron or triangle nodes, duplicate boundary
facets, inconsistent surface face areas and normals, and non-integer OBJ face
indices. These checks prevent malformed geometry from being silently mapped to
another topology or radiative scale.

The GUI refreshes result-state and task-state indicators after editable network
changes, mesh loading/runs and configuration import. Existing results are
marked stale when their inputs no longer match, and the smoke test exercises an
edit-restore cycle.

Release verification now reports optional external-data checks as incomplete
when the provider archive is unavailable, while still failing on actual test
failures. MATLAB static-analysis issues found in the release script were
resolved without suppressing real diagnostics.
