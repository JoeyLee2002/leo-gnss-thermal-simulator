# LEOTherm v1.5

Date: 2026-10-12. Previous stable local package: v1.3 figure repair.

## Two Explicit Run Levels

- Keep the complete-task area and its four optional-stage checkboxes available across Simulation pages. Rename its actions to `Check complete task` and `Run complete task and generate report`.
- Restore independent single-scenario, sweep, surface, volume, coupling, telemetry and calibration buttons inside their own pages. These callbacks do not dispatch to the complete pipeline.
- Keep single-scenario and sweep run buttons outside their scrollable input area; leave results on the module page.
- Local runs do not change the global stage choices or automatically generate a complete-task PDF. Explicit manual export of existing results remains available.
- Keep Quick start as a template shortcut, and add `Current configuration and report` without overwriting the current settings.
- Preserve numerical solvers, raw result structures, project schema and existing programmatic pipeline/export APIs. Update the six example projects to v1.5.

## Retained Repairs

App-owned bilingual stop controls, cooperative cancellation/close, ASCII generated basenames, native chooser restoration, hidden report figures and owner-scoped graphics window restoration remain included. Runtime R2021b is still required and is not bundled.

## Verification

See `docs/verification_v1.5.md` for the executed checks and their scope. Bundled videos keep their original v1.2.10 filenames; new button behavior is covered by the v1.5 written guides. Earlier packages and pre-edit source snapshots are retained.

## Startup Optimization Build

The `startup_final` build keeps version 1.5 and the same thermal solvers. Scenario/sweep charts, geometry, engineering-model, telemetry and calibration views are created when first used, rather than during Quick start. State snapshots, stale-result checks and task preflight work before these views exist. Page creation is idempotent and does not modify task inputs. Window-state guards cover first rendering; UI page changes do not build editable controls while a computation is busy. Canceling a deferred close initializes the selected page after clearing busy state.

The compiler uses a file allowlist retaining engine sources, templates, six projects, geometry/CSV examples and the live 36-case scripts. Historical PDFs and archived experiment results remain in the source workspace but are no longer embedded in the executable. No MATLAB Runtime files are removed. See `docs/verification_v1.5_startup_final.md` for current measurements and checks.
