# LEOTherm 1.2.9: reproducible 36-case study

Supplemental release tag: `v1.2.9-sweep36.1`.
Engine version: **1.2.9**, based on solver commit
`ea8a6b2d739ac709028a9a4d09e00fe9b449ed43`.

This release adds the SoftwareX manuscript's 36-case orbital and mounting
study without changing the engine, GUI or Runtime application.

- Three altitudes, four beta angles and three structure--RF conductances.
- All original results and three refined results, including full MAT records.
- Open CSV histories, explicit JSON inputs, model tables and SHA-256 manifest.
- Native MATLAB English/Chinese PNG, vector PDF and editable FIG outputs.
- Scripts for an independent two-hour reference report and the periodic study.
- Fresh recomputation, archive audit, safe resume and incompatible-cache checks.
- Bilingual reproduction instructions.

Start with [the study README](../studies/softwarex/sweep36/README.md) or
[中文复现教程](../studies/softwarex/sweep36/README_CN.md).

The release asset `LEOTherm_v1.2.9_sweep36_reproduction.zip` contains the engine
source and the complete study package in the expected folder layout. It uses
MATLAB R2021b for editable-script execution. The Windows Runtime application
remains available under the original `v1.2.9` release.

The 36 simulated reference-network cases support the reported orbital and
mounting comparisons. They do not contain satellite telemetry.
