# Patch v0.9.4: degenerate-mesh import hardening

Fixed a geometry-alignment issue when STL/OBJ import filters degenerate
triangles. Face centroids, optical properties and thermal defaults now have
the same row count as the retained faces. Added a regression test covering a
degenerate triangle followed by a valid triangle.
