# v1.5 Illustrated Manuals — 2026-10-13

## Scope

Documentation-only follow-up to the verified `release` build. No changes to `src`, numerical solvers, project schemas, or the compiled executable. The existing release ZIP remains untouched; the illustrated edition has a separate ZIP and staging directory.

## Added

- Chinese and English user manuals: 13 annotated figures each, covering local vs complete-task runs, scenario inputs, results/PDF export, sweeps, network, geometry, engineering models, telemetry, calibration, template inputs, projects and stopping.
- Chinese and English paper-reproduction manuals: 4 figures each, covering entry, progress, actual output names, CSV fields and protocol checks.
- Offline HTML with an index, navigation and full-size image links; printable PDFs with embedded images.
- Two small example meshes and a canonical engineering-model JSON matching the illustrated input demonstration.
- Reproducible documentation capture, annotation, render and packaging tools; separate documentation audit and executable hash check.

## Evidence

UI images were captured from the current v1.5 MATLAB frontend. Tutorial scenario and two-case sweep were actually computed. The input dialog uses the actual software dialog helper. The progress image is from an actual task cancelled after capture. Completed-study data guides use the existing verified Runtime output; they are labelled as guides, not desktop screenshots or new validation runs.

Four guides require 13/13 and 4/4 images to load before PDF generation. Package verification checks archive integrity, relative assets, ASCII entry names and the preserved executable SHA-256. Full 444/444 numerical-release evidence remains the original release evidence; it is not claimed as a new full-suite run for a documentation update.

## Preserved Executable

`CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE`

Previous source and original release ZIP were saved in `leo-gnss-thermal-simulator_versions` before editing.
