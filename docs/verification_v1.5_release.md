# v1.5 Release Build

Date: 2026-10-13. Build suffix: `release`. The version remains 1.5. The thermal solvers, the
project schema and the programmatic APIs are unchanged from the previous 1.5 build.

## What this build changes

Relative to the `startup_final` build:

- Window-state checks wait for the window manager to settle. A requested state is applied
  asynchronously, so the value read back immediately after the request can still be the previous
  one. The wait is passive — it never re-requests the state — so a state the window manager never
  applies still fails the check. This affects the background-figure check and the picker check, in
  the test suite and in the shipped `--gui-figure-smoke` / `--gui-window-smoke` entry points alike.
- Paper-study and pipeline status JSON are published by same-directory atomic replacement, so a
  reader never observes a truncated record and a failed replacement retains the previous one.
- English user manual and English paper-reproduction guide are included in the Windows
  distribution as `USAGE_EN.md` and `PAPER_REPRODUCTION_EN.md`.
- Distribution guide cross-references are rewritten during packaging so the renamed files remain
  mutually reachable.

## Verification scope

**Static analysis.** Code Analyzer over every `.m` file in the repository: **0 findings**.

**Full suite, single process.** `TEST_TOTAL=444 TEST_PASSED=444`, `TEST_FAILED=0`,
`TEST_INCOMPLETE=0`. Benchmark rows: 6. Status record: `results/verification_v1_5_status.txt`
(`outcome=complete`).

**R2021b host behaviour — disclosed, not counted as a pass.** The release verification was
attempted twice on this development host. The first attempt reached `test_thermal_pipeline` and was
aborted by the host's native heap-corruption error (`0xC0000374`); it produced no results and is not
counted. The second attempt completed every check and printed `FINAL_VERIFICATION_OK`, writing the
status record above, and was then aborted by the same host error during process shutdown. The
verification result stands on the run that completed; no claim is made that the development host's
shutdown issue was eliminated.

Separately, an isolated one-process-per-test-file harness was run earlier. Batches 1–69 passed with
all assertions satisfied. Batch 70 was aborted by the same `0xC0000374` error at teardown and
produced no result; it is not counted as a pass. The publication gate is the single-process suite
above.

**Packaged executable, direct Runtime checks.** Each mode was invoked directly and its exit code
observed first-hand; all returned **0**.

| Mode | Result |
| --- | --- |
| `--gui-startup-smoke` | `outcome=passed`; constructor 20.73 s, through first draw 47.21 s, 0 eager axes, inputs preserved |
| `--gui-figure-smoke` | `outcome=passed`; export figures created hidden, no leak, owner state `maximized` |
| `--gui-window-smoke` | `outcome=passed`; `normal`/`maximized` restored, cancel and error restored, hidden window preserved |
| `--gui-module-smoke` | exit 0 |
| `--gui-progress-smoke` | exit 0 |
| `--sample-reports` | exit 0; bilingual report pair written |
| `--gui-report-window-smoke` | exit 0; complete task, PDF written |

The startup timings above are single observations on this development host and include Runtime
bootstrap; the first launch of a new release extracts the Runtime cache and is slower.

**Paper reproduction from the packaged executable.** `--paper-study` on a clean directory:
**40 of 40 jobs, final status `complete`**. The status JSON was read continuously during the run —
**19,505 successful reads, 0 parse errors** — which is the direct check on atomic publication; a
non-atomic writer is observable as a parse failure under that polling rate.

Every published value was reproduced by the packaged executable:

| Quantity | Published | This build |
| --- | --- | --- |
| Cases | 36 | 36 |
| RF-node P95−P5 | 0.995 – 6.048 K | 0.9951 – 6.0476 K |
| Orbital-frequency phase delay | 37.18 – 43.43 min | 37.18 – 43.43 min |
| Harmonic fit available | all cases | `harmonic_available = 1` for all 36 |
| Eclipsing pairs, conductance 0.31 → 1.24 W/K | +8.4 % to +39.7 % | +8.38 % to +39.72 % (9 pairs) |
| Continuous-sunlight pairs | −10.5 % to −12.1 % | −10.54 % to −12.08 % (3 pairs) |
| Phase-delay reduction | 36.8 – 131.0 s | 36.8 – 131.0 s (12 pairs) |
| Warmup orbits | 16 – 19 | 16 – 19 |
| Periodic error | ≈ 5.1 × 10⁻⁴ K | 5.115 × 10⁻⁴ K |
| Time refinement, largest temperature difference | 0.219 K (case 2) | 0.21921 K |
| Reference task, integrated net heat | −1765.6 kJ | −1765.6 kJ |
| Reference task, largest interval residual | ≈ 2.0 × 10⁻⁹ J | 2.0009 × 10⁻⁹ J |
| Audit flags | all 1 | all 5 flags = 1 |
| `max_energy_closure_j` | ≈ 6.5 × 10⁻⁸ J | 6.4686 × 10⁻⁸ J |
| `max_endpoint_difference_k` | ≈ 5.3 × 10⁻⁴ K | 5.3334 × 10⁻⁴ K |

`max_energy_closure_j` is the cumulative closure over a whole sweep; it is a different quantity from
the reference task's per-interval residual above. They are not comparable.

The procedures behind these checks are in `reproduce_paper_v1.5.md`, included in this package as
`PAPER_REPRODUCTION_EN.md`.

## Tooling caveat

`tools/test_runtime_focus.ps1` and `tools/test_runtime_paper_study.ps1` report a spurious failure
after a check that in fact passed. `Start-Process -PassThru` without `-Wait` does not populate
`ExitCode` in this environment, and `WaitForExit()` does not populate it afterwards; the scripts
therefore compare an empty value against zero and throw. The checks themselves completed and wrote
their result files. The exit codes recorded above were obtained by invoking the executable directly,
not through those scripts.

## Executable

`results/standalone_v1_5_release/LEOTherm.exe`, 3,883,431 bytes.

SHA-256:

`CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE`

## Use

Extract `LEOTherm_1.5_windows_release.zip` into a new folder and run `LEOTherm.exe`. A free
compatible R2021b Runtime installation may be reused. Do not extract over an older portable bundle
that carries its own integrity checks. To reproduce the published study, see
`PAPER_REPRODUCTION_EN.md`; to use the software, see `USAGE_EN.md`.
