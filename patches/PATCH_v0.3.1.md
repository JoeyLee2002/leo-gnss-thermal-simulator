# Patch v0.3.1

Release date: 2026-09-02

## Previous-version snapshot

- Version: `v0.3.0`
- Archive: `leo-gnss-thermal-simulator_v0.3.0_before_satmo_validation_patch.zip`
- Manifest: `leo-gnss-thermal-simulator_v0.3.0_before_satmo_validation_patch.zip.manifest.txt`
- The archive was created before any v0.3.1 source modification.

## Added

- A versioned SATMO v1.5.0 reference trace for a strictly matched seven-node
  thermal case.
- A path-independent MATLAB validation script that recomputes this software's
  temperatures and reports node-wise RMSE and maximum absolute differences.
- Provenance metadata and a scope statement for the external comparison.
- `Licence.txt` as a journal-template-compatible alias of the MIT license.

## Validation scope

The comparison isolates direct solar heating, node-to-node conduction,
constant internal power, and radiation to deep space. Eclipse, albedo,
planetary infrared heating, heaters, and solar panels are disabled because the
two programs define those terms differently. The archived SATMO source was
v1.5.0 downloaded from its public GitHub repository on 2026-09-02. No SATMO
source code is redistributed.

## Results

- Seven-node temperature RMSE: 0 to 0.003376 K.
- Maximum absolute temperature difference: 0.008827 K.
- Internal isolated node: exact agreement.
- No scientific equation in this software changed in this patch.
