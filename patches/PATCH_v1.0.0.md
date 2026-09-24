# Patch v1.0.0: task-to-report workflow

Previous-version snapshot:
`H:\paper\leo-gnss-thermal-simulator_versions\leo-gnss-thermal-simulator_v0.17.1_before_v1_report_20260924.zip`.

## Changes

- Added a MATLAB-native multipage analysis PDF for actual task outputs.
- Report pages adapt to scenario, sweep, surface, volume, and telemetry results.
- The GUI exposes one primary report command and offers to open the PDF.
- Removed the unused results-action dropdown, its clear-only callback, and
  duplicate GUI-panel images; the report's plotted figures remain available.
- Export keeps MAT, CSV, figures, Markdown, and manifest for audit.
- Telemetry-only runs can export, while an imported but untested CSV is never
  marked as validated.
- PDF text is paginated by available page height; section headings stay with
  their following content instead of creating an almost empty continuation page.

## Scientific boundary

Numerical checks, input currency, and telemetry-comparison state are reported
separately. A reference thermal network or a synthetic observation mapping is
not described as a calibrated flight model.

## Verification

See `docs/软件验收_v1.0.0.md` for focused tests, full suite, PDF rendering,
and the final known limits.
