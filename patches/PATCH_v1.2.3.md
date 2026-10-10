# v1.2.3: report-result audit

The previous source version is archived as `leo-gnss-thermal-simulator_v1.2.2_before_report_result_audit_20261010.zip` in the sibling versions directory.

The reference report's apparent 1980 s positive delay was not stable under forcing-grid refinement. The old algorithm excluded negative-phase cycles before computing a positive median. The revised aggregate is undefined when eligible cycles contain mixed phase signs. Per-cycle diagnostics are retained, and the report recomputes them from raw histories, including when re-exporting older results. Undefined lag is not absence of thermal inertia.

The report also fixes illumination-event counting (entries and exits are individual transitions), labels the fixed-warmup configuration separately from actual frozen-Sun initialization, and preserves source-row pairing when beta or response columns contain missing values.

Optional `gridRefinement` input is a cell array of full simulation results ordered from coarse to fine. Its first result must match the report scenario. All model and scenario parameters except `timeStepS` must match, and coarse epochs must exist exactly in the finer history. The report adds measured differences without inventing an acceptance threshold or interpolating missing samples. The original reruns are archived in the report MAT file.

These changes improve numerical interpretation. They do not validate the reference network as a flight-specific satellite, establish hardware operating limits, or replace independent telemetry.

Scenario integrated-energy CSV totals are rebased at the first retained epoch, consistently with the plot. Older unaligned energy histories are omitted rather than silently treated as analysis-window totals. The maximum interval closure remains a solver-run diagnostic and its scope is recorded separately in the manifest.
