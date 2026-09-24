# Patch v0.10.0: complete thermal-chain building blocks

This release adds independently testable building blocks for a complete
research-grade low-Earth-orbit thermal workflow:

- conservative exact surface-to-volume heat-load mapping for matching boundary
  triangles and shared nodes;
- pairwise contact conductance assembly with a signed heat-flow ledger;
- fixed-temperature, prescribed-flux and linear Robin boundary operators;
- a strict `leotherm.external_task.v1` bundle for UTC orbit, attitude and
  telemetry inputs, including explicit quaternion convention handling;
- unified bilingual machine-readable and Markdown thermal-result reporting.

The coupling layer deliberately rejects nonconforming meshes and performs no
implicit interpolation. Radiation remains nonlinear and is not silently
linearized by the boundary-operator helper. The external-task adapter does not
sort, interpolate, fill gaps or shift epochs. These are research-grade
building blocks; the GUI and fully automatic surface-volume contact assembly
remain future integration work.
