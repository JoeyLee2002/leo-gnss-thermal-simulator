# Patch v0.9.6: volume conduction in the workbench

The Gmsh linear-tetrahedron conduction path is now connected to the existing
MATLAB GUI geometry workspace. Users can import a Gmsh 2.x volume mesh, enter
conductivity, density and specific heat, run the independent conduction solver,
view nodal temperatures and export auditable volume files.

Volume mesh state is retained in workspace projects and task snapshots. The
GUI reports a volume result as stale when the loaded mesh or material inputs
change. The path remains conduction-only and is not presented as an automatic
surface radiation coupling.
