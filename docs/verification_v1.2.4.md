# v1.2.4 verification record

## Scope

This iteration covers orbital thermal-response metrics, the relevant numerical
solver regressions, report content/figures and the PDF export path. It does not
represent a rerun of every historical software test or a new flight-validation
campaign. Reference temperatures and model parameters were not tuned for a
preferred phase estimate.

## Numerical checks

- 47 targeted tests passed in `results/report_v1_2_4_release.log`.
- The separate bilingual end-to-end report regression also passed with process
  exit 0 (`results/report_v1_2_4_pdf_regression.log`): 48 tests in this iteration.
- A single-node RC system was evaluated through `solveThermalNetwork` with a
  prescribed sinusoidal heat input and conductive boundary. Maximum temperature
  error was below 1e-4 K; orbital phase-delay error was below 0.005 s versus the
  analytic response.
- Known-delay, multiple-peak, trend, time-origin, phase-advance, constant-signal,
  missing-fundamental and sampling-gap cases are included.
- No interpolation of missing observations is used by the new estimator.
- The four archived independent sampling-grid runs give orbital phase delays
  of 2500.6911, 2500.6484, 2500.7023 and 2501.5741 s at 60, 30, 15 and 7.5 s.
  These are new, explicitly named frequency-domain descriptors, not renamed
  sampled-peak delays. The reference 60 s history gives a 2.6248 s difference
  between separately fitted first and second half-window phases.

## PDF export

Two development processes reproduced Windows exception 0xc0000374 while exporting
multi-page PDFs through the previous append path. This happened during export,
not merely on shutdown. Earlier reports attributing every occurrence to process
shutdown were therefore too narrow.

The report writer now exports independent pages and uses Runtime's existing
Apache PDFBox for one assembly. It reopens the assembled file and checks its page
count before publishing it. Twenty repeated PDF merges passed page-count and
page-order checks; overwrite/missing-input protection tests also passed.

After this change, the 47-test batch plus the bilingual reference report export
completed with process exit code 0. Both PDFs contain 18 pages. All 36 pages were
rendered for visual review; the text-boundary scan found no outside-page blocks.
The requested generic phrases and literal missing-delay units were absent.

Evidence: `results/report_v1_2_4_release/qa/checks.json`, rendered pages and contact
sheets, full MAT histories, grid-comparison CSV, node statistics and conductive
link CSV. The code bypasses the reproduced native export path; this is not a
claim to have repaired MathWorks' underlying native libraries.

## Standalone build

Official MATLAB Compiler CLI completed with exit code 0. The compiler emitted
its startup-path warning, so a deployed Runtime workflow was also executed.
Runtime was provided through a child-process PATH, excluding MATLAB paths.
The GUI smoke is programmatic: hidden app construction, simulation, pipeline
execution, PDF export and process exit, not a manual click-by-click UX audit.

Executable SHA-256:
`43e1e542f7b382a0713709369026cf402754cb5337d58cb7b846a0dd2e56b7c4`.

Runtime records are in `C:\LEOTherm_Report_Test_v1_2_4_pdf_fix`.
Two successive deployed GUI workflows completed and exited with code 0, each
producing its own English report and `outcome=complete` status record.
The new PDF writer's code-analyzer check passed; the 14-file source scan's only
two findings were dynamic-eval unused-variable warnings, then explicitly annotated.
The application ZIP reuses Runtime R2021b and does not bundle a full Runtime.
