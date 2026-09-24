# Patch v0.9.1: face-level solar self-shadowing

## Scope

This patch adds optional direct-solar self-shadowing for imported STL/OBJ
surface meshes. For each triangle, a ray is cast from its centroid toward the
Sun. A hit on another triangle marks the face as geometrically shadowed.

## User-visible changes

- Added a three-dimensional geometry setting for solar self-shadowing.
- Added `leotherm.meshSolarVisibility` for programmatic use.
- `surfaceMeshLoads` now reports `faceVisibleFraction`, `selfShadowing`, and
  `shadowDiagnostics`.
- Face simulations separately retain `eclipseVisibleFraction` and
  `faceVisibleFraction`, plus per-epoch shadowed-face counts.
- Projects and task snapshots include the mesh setting through the geometry
  structure and therefore change their input fingerprint when it changes.

## Numerical boundary

The method is a binary centroid-ray approximation. It does not resolve partial
triangle coverage, grazing rays, penumbra geometry, or a finite solar disc.
The Earth eclipse fraction remains independent of the mesh self-shadowing
factor. The existing centroid view-factor approximation and absence of solid
3-D conduction are unchanged.

## Backward compatibility

The setting defaults to off. Existing meshes without the new field continue to
use the previous uniform Earth-eclipse factor. No node-network solver behavior
was changed.

## Verification

Added analytic parallel-plate tests for front/rear visibility, load separation,
invalid direction rejection, and end-to-end result diagnostics.

The public load API rejects ambiguous combinations of a per-face eclipse array
and geometric self-shadowing; the simulation path always supplies one scalar
Earth-eclipse factor per epoch.
