# v0.4.5 usability patch

Date: 2026-09-14. Previous release: v0.4.4.

## Recovery snapshot

Before editing, the source was archived to:

`H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.4.4_before_v045_usability_20260914.zip`

The adjacent `.zip.manifest.txt` records the snapshot inventory. Existing scientific
run directories were not replaced. This source archive is not a backup of all
large historical experiment datasets.

## Changes

- The main Open/Save buttons now operate on complete workspace projects. Device-only
  import/export remains in the Project menu. CSV telemetry is embedded for portability.
- Projects contain editable inputs, results, scan settings, language, telemetry
  mappings/options and calibration profiles, day assignments and frozen results.
- Saving stages and validates a new MAT file before installation. An overwritten
  project is copied to `.previous`; this is a single previous-save copy, not a history.
- Closing or opening another project prompts about unsaved changes.
- An explicit UTC time field preserves fractional seconds across language switching.
- Input changes label retained results stale. Export metadata records that state;
  exported scenario inputs come from the actual result, not the edited draft.
- Telemetry validation rejects a stale reference scenario. Preflight checks available
  fields and usable driving segments without filling gaps or proving physical validity.
- Scans display completed-case progress and allow cancellation between cases. Remaining
  cases have `cancelled` status and missing metrics, not fabricated numerical results.
- The single-scenario Run button stays visible while the parameter list scrolls.

## Limits

MAT projects should be opened only from trusted sources. MAT loading is not a
security sandbox. The GUI remains synchronous: cancellation waits for the current
scan case to finish and is not available inside a single solve or calibration.
No autosave, crash recovery, background queue or resume-after-restart is provided.
Preflight is a data-readiness check; calibration fit is not flight validation.

See `docs/易用性改进_v0.4.5.md` and `docs/usability_v0.4.5.md` for operation.
