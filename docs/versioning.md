# Versioning and patch policy

Before modifying a released or analysis-used version:

1. run `tools/create_version_snapshot.m` from MATLAB;
2. verify that the ZIP and manifest exist in the sibling `_versions` folder;
3. increment `VERSION`;
4. create `patches/PATCH_vX.Y.Z.md`;
5. record scientific changes, compatibility changes, and validation status;
6. rerun all tests and the frozen benchmark matrix;
7. never overwrite a previous archive.

Analysis results must record the software version, patch file, scenario
configuration, network parameters, and random seed where applicable.

