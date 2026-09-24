# Patch v0.3.2

Release date: 2026-09-02

## Previous-version snapshot

- Version: `v0.3.1`
- Archive: `leo-gnss-thermal-simulator_v0.3.1_before_bilingual_ui.zip`
- Manifest: `leo-gnss-thermal-simulator_v0.3.1_before_bilingual_ui.zip.manifest.txt`
- The archive was created before any v0.3.2 source modification.

## Added

- A Chinese/English language selector in the graphical workbench.
- Optional language arguments for `launch_gui`, `leotherm.launchApp`,
  `leotherm.plotScenario`, `leotherm.plotSweep`, `run_baseline`, and
  `run_beta_altitude_sweep`.
- Localized thermal-node display names and table headers.
- A legend in every single-scenario and parameter-sweep plot panel.
- Regression checks for language aliases, localized node names, bilingual
  figure export, and legend counts.

## Behavior

- Chinese mode uses Chinese controls, messages, metrics, plot labels, and
  legends. English mode uses their English counterparts.
- Switching languages preserves the active scenario, edited thermal network,
  completed single-scenario result, completed sweep, and selected sweep mode.
- Internal field names, exported numerical columns, solver equations, and
  scientific results are unchanged.
- Configuration and result exports record the selected display language.

## Verification

- MATLAB Code Analyzer: zero findings after the final release check.
- Automated tests: 38/38 passed.
- Chinese GUI smoke test: four tabs rendered, eight plot legends found.
- English GUI smoke test: four tabs rendered, eight plot legends found.
- Both GUI runs completed the single-scenario and two-case sweep workflows.
