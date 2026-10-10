# v1.2.4 - Thermal response metrics and readable reports

## Calculation changes

- Add `orbitalHarmonicResponse`: joint, trapezoid-weighted least squares for offset,
  trend and three orbital harmonics at the actual epochs, without resampling.
- Extract the signed principal phase difference of the orbital fundamental.
  The phase delay is `-angle(Y1/X1) / omega`, within half an orbital period.
  It describes the two thermal histories; it is not a pure transport delay or
  a material time constant. Total external heat is the reference signal.
- New results and sweeps expose `orbitalPhaseDelayS` / `orbital_phase_delay_s`.
  Existing peak-based fields, including `forcingToResponseLagS` and
  `forcingToRfLagS`, keep their original definitions for compatibility.
  Reports use the explicitly named orbital-frequency metric as the primary
  periodic-response descriptor and recompute both diagnostics from raw histories.
  Old archived metrics are not relabelled as frequency-domain estimates.
- Constant signals, absent fundamental components, short windows and large
  sampling gaps produce structured applicability status, never invented delays.
- Add tests for known delay, advance, multiple peaks, trends, time origin,
  sampling gaps and analytical RC response through the actual heat solver.

## Presentation changes

- Export each PDF page independently, then assemble once with the Apache PDFBox
  already bundled in MATLAB/Runtime. Reopen and check page count before publishing.
  This removes repeated native `exportgraphics(..., Append=true)` calls from the
  report path where development-process heap corruption was reproduced.
- The PDF assembler has repeated-merge, page-order and overwrite-protection tests.
- Remove the generic Interpretation paragraph and constant-spacing figure.
- Label nodes by ID and component name in plots and legends.
- Replace the conductance matrix picture with a thermal connectivity diagram;
  export all conductive links and conductances in a CSV.
- Label zero-valued optical properties/areas and identify zero-exposure nodes.
- Replace generic caveats with measured quantities, node identities and event counts.
- Separate numerical checks from device temperature-limit qualification.
- Compare orbital phase delays in the existing independently rerun grid study.

## Method reference

MathWorks, *Frequency Response Estimation Basics*:
https://www.mathworks.com/help/slcontrol/ug/what-is-a-frequency-response-model.html

MathWorks, *Group Delay and Phase Delay*:
https://www.mathworks.com/help/signal/ug/delay.html

The implementation uses base MATLAB least squares and does not require Signal
Processing Toolbox or System Identification Toolbox. No thermal network
parameters or recorded temperatures were changed to obtain a preferred delay.

PDF assembly uses the existing Runtime Java environment and its Apache PDFBox
2.x library, via the documented PDFMergerUtility API:
https://pdfbox.apache.org/docs/2.0.13/javadocs/org/apache/pdfbox/multipdf/PDFMergerUtility.html
No additional Runtime download or external application is needed.
