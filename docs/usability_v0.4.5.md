# v0.4.5 workspace guide

Run `launch_gui('en')` from the project directory. The main Open project / Save
project actions now restore a complete workspace rather than only device parameters.

1. Set the UTC date and time explicitly, including fractional seconds when needed.
2. Configure the thermal network and run the scenario using the pinned Run button.
3. Check the result-status banner after editing inputs. Retained plots may be stale.
4. Save a MAT project. It includes embedded telemetry, mappings/options, calibration
   drafts and frozen results, scan inputs/results, scenario/network and language.
5. Open that project to resume, even after moving its original CSV telemetry source.

Use the Project menu for Save as or device-only configuration import/export.
Only open trusted MAT files. Old configuration MAT files are not workspace projects.
Overwrite saving retains one `.previous` copy; copy it to a new `.mat` name to recover.
Closing or opening another project asks about unsaved changes. There is no autosave.

Before running telemetry, use Preflight after setting mapping and workflow options.
It reports required-field problems, invalid drivers and usable segments without
interpolation or solver execution. It is not a physical-validation certificate.
Validation rejects a stale reference scenario; rerun the scenario first.

Sweep cancellation takes effect between cases. Completed results remain available;
unstarted cases are explicitly cancelled with missing metrics. The current case
must finish. Single-solve/calibration interruption and background/resume queues are
not implemented.

Exports retain original result inputs and include stale-state metadata. Saving a
project preserves work in progress; exporting a result produces analysis artifacts.
