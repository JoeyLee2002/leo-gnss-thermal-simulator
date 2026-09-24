# Task templates

These UTF-8 JSON files are user-facing simulation templates. Copy the closest
template, edit a few scenario fields, and open it from the GUI Task wizard.

Templates use `leotherm.simulation_template.v1`, declare `templateVersion` and
`engineApi`, and contain no executable MATLAB code. Missing values inherit from
validated defaults. The loader does not infer units, fill telemetry gaps, or
guess node mappings.
