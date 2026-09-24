# Patch v0.16.1: runnable coupled example

## What changed

- Added `examples/projects/06_surface_volume_coupled.mat`.
- Added a conforming six-face OBJ boundary for the two-tetrahedron Gmsh mesh.
- The example explicitly configures a contact interface and a fixed-temperature
  node so that a new user can inspect the full coupling path without hidden
  inference.
- Extended the example-project tests to verify the saved coupled result and
  zero conservation closure.

## Verification

- Example-project, coupled-scenario, and GUI coupled workflow tests: 6/6 passed.
- Full isolated release gate after this patch remains required before release.

## Boundary

The example exercises the existing conservative one-way coupling. It does not
claim surface-temperature feedback or physical validation against a spacecraft.
