# Changelog

## 1.2.0 - Stage-specific analysis reports (2026-09-27)

- Each completed stage now contributes computed findings and its own chart to the PDF and Markdown report. Unselected stages contribute no fabricated analysis.
- Scenario, sweep, three-dimensional geometry, telemetry comparison, and accepted calibration have separate evidence-aware interpretations.
- A one-case sweep uses a case-level metric chart and explicitly avoids trend or optimum claims.
- The PDF places stage interpretation and chart on the same page; Chinese labels no longer expose telemetry or calibration status codes.
- Reports flag no-warmup transients; unscored telemetry creates neither a residual chart nor a false validation flag.
- Added report-stage regression tests and kept the v1.1.0 release available as an archive.

## 1.1.0 - Optional stages in one task pipeline (2026-09-27)

- Added one preflighted task pipeline with input snapshot, model freeze, mandatory nodal simulation, numerical acceptance, and a task-specific PDF.
- Parameter sweep, surface-volume coupling, telemetry comparison, and constrained calibration are independent optional stages. Unselected stages require no inputs and are recorded as skipped.
- The GUI now offers four stage checkboxes and one Run task command. Previous module run buttons are hidden; module pages remain available for configuration.
- Saved projects retain stage choices and the last pipeline run. Results display the actual run and open its report in the language used at run time.
- Added pipeline and GUI regression coverage, including preflight rejection and telemetry/geometry/sweep runs.

## 1.0.1 - MATLAB Runtime desktop packaging (2026-09-24)

- Added a compiled desktop entry point and a repeatable Windows release build.
- Bundled version, task templates, and example projects for deployed use.
- Added a standalone smoke mode that checks templates, simulation, and PDF export.
- Added a GUI export smoke mode and a relocatable GitHub Release package.

## 1.0.0 - Task-to-report workflow (2026-09-24)

- Results export now creates a task-specific, multipage Chinese or English PDF
  with findings, inputs, generated plots, telemetry comparison where available,
  numerical checks, provenance, and interpretation limits.
- PDF, Markdown, CSV, MAT, figures, and a machine-readable manifest are exported
  together; report creation fails visibly if the PDF is missing or invalid.
- Telemetry-only runs can export a report. Importing data without a comparison
  no longer sets the manifest's telemetry-validation flag.
- The results page has one primary report action. The redundant clear-results
  action menu and duplicate GUI-panel image exports were removed.
- Rebranded the GUI as a LEO thermal simulation workbench and added a concise
  first-run-to-report guide.

## 0.17.1 - Closeout hardening (2026-09-24)

- Reject unsupported template modes, version families, required input kinds,
  and misspelled scenario fields before changing the GUI workspace.
- Apply the same template checks to JSON files and in-memory templates.
- Added a short current-version first-run guide and regression tests.
- Rechecked the first built-in template and the Chinese GUI smoke workflow.

## 0.17.0 - Task wizard and editable templates (2026-09-17)

- Added a guided task wizard to the Quick start page.
- Added versioned, human-editable JSON templates for first simulation,
  thermal-lag analysis, a SATMO-style benchmark, and telemetry input.
- Added template discovery and external JSON-template selection.
- Added strict schema, template-version, engine-API, scenario, and network
  validation before a template can modify the workspace.
- The wizard asks only for task name, duration, and time step; scenario
  templates can run immediately after validation.
- Telemetry templates open the CSV chooser, map columns, and run the existing
  preflight without filling gaps or guessing units.
- Workspace projects retain the template id, source path, and embedded
  template snapshot for reproducibility.
- Cached the immutable software version after its first successful read so
  long calibration loops do not repeatedly access a removable project drive;
  the initial read has three bounded retries.

## 0.16.2 - Explicit coupling-boundary GUI (2026-09-16)

- Added a focused GUI dialog for explicit contact-node pairs, contact
  conductance, fixed-temperature nodes, and fixed temperature.
- Persisted coupling-boundary settings in workspace projects and restored them
  with strict node-index validation.
- Added normalization for older programmatic calls that pass an empty options
  structure; missing optional boundaries remain disabled.
- Added parser/validation regression tests for partial options, list syntax,
  duplicate-free indices, and invalid partial contacts.

## 0.16.1 - Runnable coupled example (2026-09-16)

- Added `06_surface_volume_coupled.mat`, a portable example that runs the
  strict surface-volume workflow on conforming meshes.
- Added an explicit six-face boundary OBJ for the two-tetrahedron Gmsh mesh.
- The example declares one contact interface and one fixed-temperature node;
  neither is inferred by the GUI or solver.
- Extended example-project regression coverage to verify the coupled result,
  contact record, one-way provenance, and conservation closure.

## 0.16.0 - Coupled surface-volume workflow (2026-09-16)

- Added `leotherm.simulateSurfaceVolumeScenario`, a public workflow for
  orbit/attitude-driven face radiation, exact surface-to-volume boundary
  matching, volume finite-element conduction, explicit contacts, and fixed
  volume-temperature boundaries.
- Added `leotherm.writeSurfaceVolumeScenarioResult` for one-step export of the
  coupled result, conservation diagnostics, volume time series, and bilingual
  thermal report.
- Extended the unified report with coupling method, matched-face count,
  closure error, and contact-pair records.
- Added regression tests for coupled execution, exact energy transfer,
  nonconforming-mesh rejection, fixed boundaries, and complete export.

The workflow is explicitly conservative one-way coupling: external face
radiation is applied to the volume state. The independent face-temperature
preview is not fed back into the volume solve.

## 0.15.0 - External solver adapter SDK (2026-09-16)

- Added a versioned adapter execution entry point for registered MATLAB
  capabilities, with explicit capability gates and no implicit format, unit,
  sorting, interpolation, or node-mapping inference.
- Added JSON/MAT metadata-descriptor loading with explicit MATLAB handler
  injection. Executable function handles are rejected when embedded in a
  descriptor file.
- Changed external solver failures from thrown execution errors into complete
  `succeeded`, `failed`, or `timed_out` run records so failed runs can still be
  audited and included in reports. Configuration and safety errors remain hard
  failures.
- Extended adapter and external-solver regression coverage, including failure,
  timeout, descriptor provenance, execution, and unregister paths.
- Documented controlled integration profiles for Thermal Desktop, ESATAN-TMS,
  SINDA/FLUINT, and OpenFOAM. These remain profile-level integrations and do
  not claim native proprietary-format parsing or physical validation.

## 0.14.0 - Engineering model integration (2026-09-16)

## 0.14.0 - Engineering model integration (2026-09-16)

- Added a release-gate regression test for component creation, JSON/MAT
  round-trips, scalar uncertainty, temperature-curve grids, and explicit
  mapping preview/apply.
- Added `tools/verify_v014_release` and documented MATLAB R2021b/checkcode
  findings and remaining release boundaries.
- Clarified that `provenance.inputFingerprint` is an upstream source digest,
  while the import report's `inputFingerprint` hashes the current container;
  neither is physical-validation evidence.
- Added explicit engineering-model mapping preview, confirmation-gated apply,
  provenance, and rollback to the pre-import thermal network in the GUI.
- Added bilingual mapping workflow documentation and GUI regression coverage.

## 0.13.0 - 2026-09-16

- Added the `leotherm.thermal_model.v1` canonical model contract with strict
  SI-unit validation, provenance, uncertainty, and connectivity checks.
- Added a reference-only material library, equivalent component model, and
  explicit component-to-node mapping.
- Added traceable MAT/JSON thermal-model exchange with SHA-256 input reports
  and preservation of unknown extension fields.
- Added a bilingual Engineering thermal model workspace with atomic import
  failure behavior and validation summary.
- Added extensibility documentation and a synthetic exchange fixture.

## 0.12.0 - 2026-09-15

- Added five ready-to-open example projects covering first simulation,
  thermal-lag analysis, physical sweeps, telemetry validation, and 3-D input.
- Added an Open example project action to Quick start.
- Added beginner-oriented project documentation.

## 0.11.1 - 2026-09-15

- Added a plain-language conclusion area to the Results workspace.
- The conclusion distinguishes missing results, current results, and stale
  results before the detailed metrics table.
- Updated current documentation and telemetry guides.

## 0.11.0 - 2026-09-15

### Quick-start workspace

- Added a default Quick start area with first-simulation, thermal-lag, and
  telemetry-validation templates.
- Added an Advanced simulation action for the complete existing workbench.
- Template runs use the normal production solver; the telemetry template only
  opens the telemetry workflow and never fabricates validation results.
- Added a confirmation before replacing unsaved scenario or network settings.
- Updated GUI acceptance checks and onboarding documentation.

## 0.10.1 - 2026-09-15

- Initialized GUI task and result states on startup.
- Added independent stale-result indicators for scenario, sweep, surface mesh,
  and volume mesh results.
- Fixed result clearing and bilingual task diagnostics.

## 0.9.8 - 2026-09-15

- Added an independent RK-stage energy ledger for external, internal,
  radiative and boundary heat channels.
- Added auditable energy-closure residual diagnostics instead of using the
  state increment as a tautological closure check.
- Hardened Gmsh and surface-mesh input validation against duplicate IDs,
  repeated facets, degenerate elements and inconsistent geometric measures.
- Refreshed GUI stale-result state after network, geometry and configuration
  changes, with regression coverage for edit-and-restore workflows.
- Improved release verification to distinguish real failures from incomplete
  optional external-data checks and cleared MATLAB static-analysis findings.

## 0.10.0 - 2026-09-15

- Added strict, conservative surface-to-volume heat-load coupling for exactly
  matching boundary triangles and shared nodes; nonconforming meshes are
  rejected without implicit interpolation.
- Added pairwise contact conductance assembly, contact heat-flow ledger and
  linear heat-flux/Robin boundary-condition assembly for volume workflows.
- Added the `leotherm.external_task.v1` orbit-attitude-telemetry import schema,
  explicit quaternion convention handling and synchronization audit.
- Added a unified bilingual, machine-readable thermal-results report export.

## 0.9.7 - 2026-09-15

- Preserved Gmsh tetrahedron Physical Tags during ASCII MSH 2.x import.
- Added explicit multi-material volume-region assembly through
  `material.regionProperties`.
- Added hard failures for missing or unmatched volume Physical Tags.
- Rejected binary Gmsh input explicitly and retained the documented MSH 2.x
  scope.
- Added element tags and resolved material properties to volume CSV export.
- Added regression tests for region selection, tag errors and binary rejection.

## 0.9.6 - 2026-09-15

- Connected Gmsh volume-mesh conduction to the GUI geometry workspace.
- Added GUI material inputs, volume-node temperature visualization, project
  state retention and volume-only result export.
- Added stale-result handling when volume mesh material inputs change.
- Added volume-result export regression coverage.

## 0.9.5 - 2026-09-15

- Added ASCII Gmsh 2.x linear-tetrahedron volume-mesh import and validation.
- Added independent linear-tetrahedron Galerkin conduction assembly.
- Added theta-method transient volume conduction with fixed-temperature nodes.
- Documented the Gmsh/MOOSE source basis and the uncoupled volume-solver boundary.

## 0.9.4 - 2026-09-15

- Hardened STL/OBJ import when degenerate triangles are removed by keeping
  retained face geometry and thermal defaults aligned.

## 0.9.3 - 2026-09-15

- Added standalone face-result export with face properties, face time series,
  visibility diagnostics and thermal provenance metadata.
- Enabled the GUI Results and Export workflow for face-only simulations.
- Fixed alignment of face centroids and face thermal defaults after filtering
  degenerate imported triangles.

## 0.9.2 - 2026-09-15

- Added explicit, validated and provenance-tracked thermal defaults to imported
  surface meshes.
- Added `setSurfaceMeshThermal` for programmatic face thermal configuration.
- Added solver diagnostics for capacity, initial temperature and conductance
  sources.
- Refined self-shadow diagnostics to normalize blocked faces by illuminated
  faces.

## 0.9.1 - 2026-09-15

- Added optional triangle-centroid ray tracing for direct-solar mesh
  self-shadowing.
- Added separate Earth-eclipse and per-face structural visibility outputs.
- Added GUI control, task/project persistence, diagnostics, and regression
  tests for self-shadowing.

## 0.9.0 - 2026-09-15

- Added a face-resolved gray-body radiosity solver for imported STL/OBJ meshes.
- Added centroid differential-area view factors with optional ray blocking,
  reciprocity diagnostics and row-sum safeguards.
- Added independent face thermal simulation and GUI execution with final-face
  temperature coloring.
- Added public `loadSurfaceMesh` and `runSurfaceMesh` app APIs.
- Added bilingual GUI smoke coverage for mesh import, face simulation and export.
- Preserved the lumped receiver-network workflow and stated the remaining
  self-shadowing, solid-conduction and certification boundaries.

## 0.7.0 - 2026-09-14

- Archived v0.6.0 before adding the first-class simulation task model.
- Added task creation, validation, freezing, UUID identity and SHA-256 input fingerprints.
- Attached task identity to scenario results and recorded task run history in the workspace.
- Added a task-level scenario runner that executes only validated frozen snapshots.
- Added five task-object regression tests while preserving the v0.5.1 paper-1 studies.

## 0.6.0 - 2026-09-14

- Archived v0.5.1 before building the simulation-task workbench.
- Added a unified task summary for scenario, thermal network, telemetry,
  calibration, solver settings and current result state.
- Added task-level Check configuration, Run simulation, Run parameter sweep and
  View results actions while retaining the existing panel APIs.
- Kept Simulation and Results as the two user-facing areas and treated the
  existing configuration panels as inputs to one simulation task.
- Preserved the v0.5.1 paper-1 gap studies and previous numerical safeguards.

## 0.5.0 - 2026-09-14

- Archived v0.4.5 before editing the GUI hierarchy.
- Reorganized the user-facing GUI into two main areas: Simulation and Results.
- Kept scenario, sweep, thermal-network, telemetry and calibration panels as
  configuration sections inside Simulation; internal APIs and project schemas remain compatible.
- Reduced visible actions: low-frequency self-test/about, device configuration,
  mapping, templates, synthetic demo, profile preparation, network restore and
  result clearing are now grouped under menus or More actions controls.
- Added a unified simulation-oriented workflow while retaining existing result,
  stale-state, project, telemetry and calibration behavior.

## 0.5.1 - 2026-09-14

- Archived v0.5.0 before adding paper-1 gap experiments.
- Added a fixed-forcing storage-isolation study comparing dynamic heat-capacity
  factors with a per-epoch quasi-static thermal equilibrium.
- Added a timestep and metric-stability study for low, intermediate and high
  beta regimes; preserves original samples and reports non-identifiable phases.
- Added paired case manifests, source forcing exports, convergence diagnostics,
  and explicit interpretation boundaries. No historical paper-1 result is
  overwritten and no missing case is interpolated.

## 0.4.5 - 2026-09-14

- Archived v0.4.4 before editing. Added portable MAT workspace projects with
  embedded telemetry, calibration drafts/results, scan settings and language.
- Preserve the previous project on overwrite and prompt before leaving unsaved work.
- Preserve exact UTC time across language changes; do not silently force noon.
- Flag stale scenario/sweep/telemetry results; export original result inputs and
  reject a stale reference simulation for telemetry validation.
- Add bilingual telemetry preflight without interpolation or integration.
- Add determinate sweep progress and cancellation between cases, preserving
  completed results and explicit cancelled rows.
- Keep the scenario Run action visible outside the scrolling settings area.
- Add nine regression tests and portable-project GUI acceptance checks.

## 0.4.4 - 2026-09-14

- Archived v0.4.3 source before editing. Added adaptive RK4 accuracy control on
  all solver paths and numerical diagnostics; retained no-gap-filling telemetry.
- Reject unidentifiable/ambiguous positive phase claims and truncated event windows.
- Added finite-Earth-disk uniform IR and a bilingual GUI model selector; retained
  legacy cosine for old configurations and the historical benchmark matrix.
- Keep valid thermal driving through missing sensor targets; score each node separately.
- Added predeclared duration, continuity, temperature-span and sample-count coverage
  gates, bilingual GUI settings/results and exported coverage tables.
- Added analytical, missing-data, coverage and phase-ambiguity regression tests.


## 0.4.3 - 2026-09-03

- Saved v0.4.2 before adding device-specific constrained calibration.
- Added immutable nominal device profiles, explicit physical/effective parameter
  meaning, evidence, hard limits, prior scales and a deviation penalty. All
  parameters default to locked; bounds are never automatically widened.
- Added chronological whole-day train/validation/test assignment, fixed scoring
  pairs, missing-target segmentation, training-only sensitivity diagnostics,
  bound-aware integration steps and a step-halving check. Nonconverged runs
  cannot freeze or evaluate the check sets.
- Added a bilingual device-calibration GUI, original/adjusted device exports,
  frozen protocol and input snapshots, parameter/temperature reports, complete
  check-day plots, and SHA-256 artifact manifests. Original results stay intact.
- Acceptance is conditional on declared device evidence and unused check data;
  synthetic demonstrations and a good fit do not establish flight validity.

## 0.4.2 - 2026-09-03

- Added sampled prescribed-temperature conductive boundaries, strict paired
  telemetry mapping, invalid-row segmentation, boundary exports, bilingual
  controls, templates and legends. No interpolation or missing-data filling.
- Added optional time-varying environment and hinge-boundary inputs to the
  deployed-panel model, with double-counting and invalid-input checks.
- Added normalized bounded multistart calibration, optional fmincon and base
  MATLAB fallback, convergence and parameter-spread diagnostics. Incomplete
  calibrations cannot be frozen; completed checkpoints cannot be overwritten.
- Marked reruns of previously inspected MinXSS dates as development analyses,
  not new independent validation. Preserved the original results.
- Saved v0.4.1 before editing. Added analytical, integration and optimizer tests.
- See PATCH_v0.4.2.md and the versioned acceptance report for evidence limits.

## 0.4.1 - 2026-09-03

- Added an actual MinXSS-1 flight-temperature prediction study, with original
  Level 0C records, row-level rejection, chronological train/validation/test
  separation, frozen parameters, and complete held-out reporting.
- Added single-node and cell/substrate deployed-panel network configurations
  that use the existing nonlinear thermal solver. Electrical output is removed
  from absorbed solar energy; no target temperatures drive the thermal forcing.
- Added uncalibrated, no-storage, and initial-value baselines, original-epoch
  predictions, bilingual figures, timestep checks, and explicit engineering
  acceptance targets and physical-scope limitations.
- Hoisted invariant RK4 coefficients out of the derivative loop. Verified
  original sampled-input and varying-input reference predictions are unchanged.
- Added twelve physical-response, no-feedback, segmentation, split, optimizer
  checkpoint and checksum tests.
- Saved v0.4.0 before changes. This release does not claim whole-spacecraft,
  GNSS receiver, or POD flight validation from the deployed-panel experiment.

## 0.4.0 - 2026-09-03

- Added a bilingual telemetry workbench with explicit CSV quantity, unit, and
  thermal-node mapping, templates, reusable mappings, and traceable exports.
- Added orbit/Sun/attitude and absorbed-heat telemetry drivers, time-varying
  internal power, independent valid segments, and held-input RK4 substeps.
  Existing default integration behavior is retained.
- Added exact-UTC temperature comparison, initialization exclusion windows,
  conditional-initialization disclosure, row audits, error metrics, legends,
  and bilingual agreement reports. No missing telemetry is interpolated.
- Added a documented GRACE-FO RL04 IHK1B reader and real-flight data readiness
  study: two dates, two spacecraft, 17 temperature channels, 48,960 measurements.
  Unknown sensor locations and asynchronous orbit epochs are not guessed;
  no mission-specific physical-validation success is claimed.
- Kept synthetic demonstrations separate from actual flight evidence. Added
  telemetry, parser, rejection, no-leakage, and export regression coverage.
- Saved the complete v0.3.2 source snapshot before editing. See PATCH_v0.4.0.md.

## 0.3.2 - 2026-09-02

- Added a persistent Chinese/English display-language selector to the graphical
  workbench and language arguments to the public launch and plotting APIs.
- Localized controls, status messages, tables, metrics, node names, plot titles,
  axes, and series labels without changing machine-readable model fields.
- Added explicit legends to all four single-scenario panels and all four sweep
  panels in both the GUI and exported figures.
- Preserved the active scenario, thermal network, sweep mode, and computed
  results when switching languages; saved the display language in exports.
- Added bilingual figure and legend regression tests, bringing the suite to
  38 passing tests, plus Chinese and English GUI smoke tests with eight legends.

## 0.3.1 - 2026-09-02

- Added a reproducible same-input comparison against SATMO v1.5.0 for the
  direct-solar, conductive, internal-power, and space-radiation terms shared
  by both implementations.
- Archived the third-party reference trace, node-wise summary, provenance
  metadata, and a MATLAB script that independently recomputes this software's
  trajectory and comparison metrics.
- Added SoftwareX-oriented external-validation documentation and a British-
  spelling `Licence.txt` alias required by the journal template.
- No orbit, environment, thermal-network, lag, or code-bias equation changed.

## 0.3.0 - 2026-09-02

- Added a Chinese graphical workbench for single-scenario simulation,
  parameter sweeps, thermal-network editing, result inspection, and export.
- Added editable node and symmetric conductance-matrix tables with immediate
  physical validation and automatic rollback after invalid edits.
- Added configuration import/export, software self-test, version display,
  progress dialogs, friendly error alerts, and analysis-boundary reminders.
- Added safe numeric-range and UTC date-list parsers without `eval`.
- Added a root-level `launch_gui` entry point and GUI smoke-test tooling.
- Added six parser regression tests, bringing the automated suite to 35 tests.

## 0.2.1 - 2026-09-02

- Added explicit scenario, external-trajectory, attitude, thermal-network, and
  ensemble input validation with stable error identifiers.
- Prevented zero time steps from reaching oversized-array allocation.
- Made scenario plotting work with generic role-based thermal networks.
- Added diagnostic status/message columns and per-case failure isolation to
  public sweep workflows.
- Prevented an unavailable headless output stream from terminating paper batch
  execution during progress reporting.
- Added `leotherm.version` and `leotherm.selfTest` user entry points.
- Expanded automated verification from 20 to 29 tests and passed an 18-case
  black-box workflow and invalid-input acceptance matrix.

## 0.2.0 - 2026-09-02

- Added automatic periodic thermal convergence diagnostics.
- Added symmetric/asymmetric networks, hysteresis metrics, uncertainty tools,
  SATMO-style benchmarks, and the first-paper experiment suite.
- Added explicit per-orbit peak/trough lag metrics, generic response-node roles,
  controlled Sun geometry, and roll/pitch symmetry tests.
- Completed 965 deterministic and 150 paired uncertainty production runs with
  all cases converged and no interpolation.
- Verified the release with zero static-analysis findings, 20/20 tests, and six
  seven-node benchmark cases.
- Added mandatory pre-update snapshots and per-version patch documentation.

## 0.1.0 - 2026-09-01

- Added pure-MATLAB circular/J2 orbit and analytical solar ephemeris.
- Added signed beta-angle targeting through RAAN inversion.
- Added conical umbra and penumbra solar-disk visibility.
- Added nadir, Sun-pointing, and inertially fixed attitude modes.
- Added face-resolved solar, albedo, and Earth-IR loads.
- Added configurable 11-node spacecraft/GNSS receiver thermal network.
- Added semi-synthetic temperature-to-code-bias mapping and lag metrics.
- Added altitude-beta and physical orbit parameter sweeps.
- Added automated geometry, eclipse, conservation, equilibrium, and end-to-end
  verification tests.
## 0.10.1 - 2026-09-15

### Usability and result-state fixes

- Initialize the task and result status indicators during GUI startup.
- Show current or stale state independently for scenario, sweep, surface-mesh,
  and volume-mesh results.
- Clear volume-mesh results together with the other displayed results.
- Refresh task and result status after volume-material edits and result clearing.
- Show stale volume-mesh results explicitly in the geometry workspace.
- Align the English README and current user guides with the 0.10.x release.
