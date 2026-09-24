# Patch v0.9.7: Physical-Tag material regions

The volume-mesh reader now preserves the first element Physical Tag for every
linear tetrahedron as `mesh.tetraPhysicalTags`. Boundary-triangle tags remain
available separately as `mesh.boundaryPhysicalTags`.

The volume conduction assembler accepts an explicit structure array such as:

```matlab
material.regionProperties = struct( ...
    'physicalTag', {1, 2}, ...
    'conductivityWmK', {1.0, 0.2}, ...
    'densityKgM3', {2700, 1200}, ...
    'specificHeatJkgK', {900, 1500});
```

When this option is used, every tetrahedron must have a nonzero tag and every
tag must map to exactly one region entry. Missing and unmatched tags are hard
errors. Scalar and per-tetrahedron material vectors remain compatible for
single-material workflows.

Binary Gmsh and MSH 4.x input are rejected explicitly. The supported volume
scope remains ASCII MSH 2.x linear tetrahedra and boundary triangles. Exported
`volume_elements.csv` now includes the physical tag and the resolved material
values used in the assembled model.

The implementation follows the documented Gmsh MSH format and the standard
linear-tetrahedron heat-conduction formulation described by MOOSE; no
third-party source code is copied into the project.
