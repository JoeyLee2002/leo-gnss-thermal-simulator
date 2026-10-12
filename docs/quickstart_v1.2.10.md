# LEOTherm v1.2.10 quick start

To reproduce the paper, choose **Quick start → Paper: reference task and 36 cases → Reproduce paper and report**, then select an output parent directory. The report opens after recomputation. See [the full protocol and outputs](reproduce_paper_v1.2.10.md).

For a custom task, choose a template or existing project, edit orbital and thermal inputs in Simulation, and enable only the additional stages you need. Check the task, run into a new directory, then open the report in Results and export. Selected sweep, geometry, telemetry and calibration stages require their corresponding inputs. Reports describe the stages actually run.

Windows standalone users need the matching free MATLAB Runtime R2021b, not a MATLAB license. The paper-study command is:

```powershell
.\LEOTherm.exe --paper-study "C:\LEOThermResults\new_run" both
```

P95-P5 means the 95th minus 5th temperature percentile; full range means maximum minus minimum. Thermal conductance (W/K), conductivity (W/(m K)), peak time lag, orbital-frequency phase delay and thermal time constant are distinct quantities. Metrics CSVs include bilingual labels and definitions while retaining legacy machine keys.

All six built-in projects are regenerated for this version. Existing user projects remain readable; rerun them to create current reports without modifying old PDFs.
