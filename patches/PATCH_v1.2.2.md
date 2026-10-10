# v1.2.2: detailed analysis reports

Previous source snapshot: `leo-gnss-thermal-simulator_v1.2.1_before_report_expansion_20261010.zip` in the sibling versions directory.

The existing report command and GUI task pipeline now add eleven computed thermal analysis chapters and a complete node-statistics appendix. Enabled sweep, geometry, telemetry and calibration stages retain their own evidence-based sections. Missing stages are not invented to reach a page count. Telemetry-only reports remain proportional to the available evidence.

Temperature extrema use the entire retained time window. The new full peak-to-peak range is explicitly distinguished from the existing 95th-minus-5th percentile span. Mean temperatures and mean powers are time-weighted. Node plots select up to twelve nodes by full temperature range; the CSV retains every node. The conductance view displays up to thirty nodes.

The cumulative energy balance is rebased at analysis start. All solver energy histories are now trimmed with the same mask as temperature, preventing warmup accounting from being mixed with the retained interval. This fixes alignment, not the physics or thermal parameters.

Report text wraps without truncation. PDF page counts, detailed chapter identifiers, figures, CSV, Markdown and source MAT data are saved together. Existing PDFs are not modified; rerun a task or export its current results into a new directory.

The Runtime release is unchanged: R2021b (v911). A new application executable is required for standalone users; source changes do not update previously downloaded executables.
