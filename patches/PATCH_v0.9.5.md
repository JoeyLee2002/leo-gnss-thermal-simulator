# Patch v0.9.5: Gmsh volume conduction foundation

This patch adds a separate volume-mesh thermal path based on the documented
ASCII Gmsh 2.x format and the standard linear-tetrahedron Galerkin heat
conduction form used by MOOSE's heat-conduction module.

The new APIs are `readVolumeMesh`, `validateVolumeMesh`,
`assembleVolumeThermalModel`, and `solveVolumeThermal`. The path supports
linear tetrahedra, lumped nodal capacity, theta integration, and fixed
temperature nodes. It is intentionally not coupled to the surface radiation
solver until boundary-face mapping and surface energy accounting are added.
