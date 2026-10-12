# SoftwareX: 36 orbital and mounting conditions

This package contains the complete study used in LEOTherm's SoftwareX manuscript.
The historical `archive/` was calculated with **LEOTherm 1.2.9** and retains its
original hashes and supplemental release tag `v1.2.9-sweep36.1`. New calculations
use the installed engine version. In v1.2.10 the recommended entry is
`leotherm.runPaperStudy(newDirectory,'both')`; see
[current reproduction instructions](../../../docs/reproduce_paper_v1.2.10.md).

## Start with the published results

No MATLAB is needed to read these files:

- [36-case summary](archive/sweep36/sweep36_summary.csv).
- [Full model and protocol](archive/open_data/protocol.json).
- [Reference nodes](archive/open_data/reference_nodes.csv) and
  [conductive links](archive/open_data/reference_links.csv).
- [Six-orbit CSV histories for every case](archive/open_data/).
- [Figure 5](archive/figures/Figure_5_sweep36.png) and
  [vector PDF](archive/figures/Figure_5_sweep36.pdf).
- [Three time-grid refinement checks](archive/sweep36/time_refinement.csv).
- [Independent saved-result audit](archive/sweep36/audit.csv).
- [Public-script verification](verification.json).

`archive/sweep36/` also contains all 36 original MAT results, three refined MAT
results, the exact protocol and the aggregate MAT file. Each case stores its
scenario, network, trajectory, absorbed heat, node temperatures, metrics,
periodic-initialization diagnostics and numerical diagnostics. `manifest.json`
records SHA-256 hashes of the evidence files. Original files are preserved;
new calculations and plots go to a separate `results/` directory.
The archive's Git attributes disable line-ending conversion, preserving hashes
when the repository is cloned or downloaded.

## Requirements

Recomputation and figure generation use **MATLAB R2021b** with a desktop/JVM
installation on Windows, as verified for this release. No Aerospace or
Optimization Toolbox is used. All plots are native MATLAB plots.
MATLAB Runtime alone cannot execute these editable `.m` scripts. The v1.2.10
Windows executable includes the full paper-study workflow via the GUI and
`LEOTherm.exe --paper-study NEW_DIRECTORY both`.
Source and study code use the repository's MIT license; simulated data and
original figures are shared under [CC BY 4.0](DATA_LICENSE.md).

## Inspect, audit and redraw

Open the downloaded repository root in MATLAB and execute:

```matlab
addpath(fullfile(pwd,'src'),fullfile(pwd,'studies','softwarex','sweep36'));
verify_sweep36_archive;
study = fileparts(which('verify_sweep36_archive'));
make_sweep36_figure_v129(fullfile(study,'archive','sweep36'));
```

The archive verifier checks original file hashes; the saved-result audit checks
physical study settings for newly calculated results.
The plotter writes PNG, vector PDF, editable FIG and source MAT files under
`results/softwarex_sweep36/figures/`, in both English and Chinese.

## Recompute the complete manuscript example

```matlab
addpath(fullfile(pwd,'src'));
study = leotherm.runPaperStudy(fullfile(pwd,'results','my_paper_run'),'both');
```

This starts a two-hour reference task, generates its PDF analysis report, solves
all 36 periodically initialized cases, repeats three cases with a finer time
grid, audits the results and exports Figure 5. The default destination is
`results/my_paper_run/`. The complete paper task requires a new destination.
To run it again, select a new directory:

```matlab
study = leotherm.runPaperStudy(fullfile(tempdir,'leotherm_manuscript_run_02'),'both');
```

All paths are resolved from the installed package, so changing MATLAB's current
directory after adding the study path does not break the calculations.

## Run or resume only the 36-case study

```matlab
studyOutput = fullfile(tempdir,'leotherm_sweep36_run_01');
summary = run_paper_sweep36_v129(studyOutput);
audit_sweep36_v129(studyOutput);
make_sweep36_figure_v129(studyOutput);
export_sweep36_open_data(studyOutput);
```

For a short first test, use `run_paper_sweep36_v129(studyOutput, 3)`, then call
`run_paper_sweep36_v129(studyOutput)` to finish. Complete cases are reused only
when the full protocol, engine-source fingerprint, saved case inputs and
derived summary agree. Incompatible caches cause an actionable error rather
than mixing results. No sample is interpolated or filled.

## Fixed experiment

| Factor | Values |
| --- | --- |
| Altitude | 400, 600, 800 km |
| Target signed beta angle | 0, 30, 60, 75 degrees |
| Structure (node 7) to RF front end (node 9) conductance | 0.31, 0.62, 1.24 W/K |

The experiment has 3 x 4 x 3 = **36 deterministic cases**. Only the reciprocal
7--9 link changes. The values are half, nominal and double the reference value,
not measured mounting parameters. Other model parameters are identical.

- Epoch: 2024-03-20 12:00:00 UTC; inclination: 97.6 degrees; nadir attitude.
- RAAN is solved for each target beta angle, with accessibility checked.
- The epoch Sun vector is held fixed; secular J2 drift is disabled.
- Periodic initialization: at least 5 and at most 80 cycles, two consecutive
  same-phase nodal changes below 0.001 K.
- Analysis: 6 complete orbits, 360 equal intervals per orbit.
- Refinement: case IDs 2, 20 and 36, 720 intervals per orbit, reinitialized.
- RF temperature P95-P5: 95th minus 5th percentile, K.
- Orbital-frequency phase delay: RF temperature relative to total absorbed external power, s;
  Figure 5 converts seconds to minutes.

The two-hour reference task uses prescribed initial temperatures without warmup
and is separate from this periodic study. Its results should not be combined
with periodic spans as if they used the same initialization.

## Reading the results

All 36 cases converged in 16--19 cycles. RF temperature P95-P5 is 0.995--6.048 K;
orbital-frequency phase delays are 37.18--43.43 min. Increasing the selected conductance raises P95-P5
at sampled beta angles 0, 30 and 60 degrees, but lowers it in the continuously
sunlit 75-degree cases. The larger conductance shortens orbital-frequency phase delay in all
12 altitude--beta combinations. These findings describe the specified reference
network and sampled orbital conditions.

Time refinement gives an all-node maximum temperature difference of 0.219 K,
an RF-span difference below 0.0006 K and a harmonic-delay difference below
0.13 s. Energy closure checks are numerical bookkeeping checks.

`elapsed_wall_s` records the original computation time for each saved case.
Legacy CSV names remain compatible; current `paper_results.csv` uses explicit
P95-P5, phase-delay and effective-conductance column names. Computation time
is machine-dependent and is excluded when comparing physical reproduction
results. CSV columns use unit suffixes; `eclipse_fraction` is a time-weighted
fraction and boolean columns use 0/1. Node IDs in history CSVs are resolved by
`reference_nodes.csv`. The JSON and MAT protocols contain the other parameters.

## Verify a fresh source download

```matlab
verify_sweep36_release(fullfile(tempdir,'leotherm_release_check_01'));
```

This performs a new reference run, recomputes every case and refinement,
compares all physical summary columns with the published archive, tests cache
resumption and rejection of incompatible inputs, exports the open data and
records the outcome. Use a new directory for each verification.

## Citation and version

Cite the engine version actually used (v1.2.10 for current reproduction), and identify the original dataset tag
[`v1.2.9-sweep36.1`](https://github.com/JoeyLee2002/leo-gnss-thermal-simulator/releases/tag/v1.2.9-sweep36.1).
The original solver release tag remains `v1.2.9`.
