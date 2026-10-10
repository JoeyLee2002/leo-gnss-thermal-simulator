# LEOTherm Portable - Windows x64

## Start

1. Download the **portable** ZIP, not GitHub's source-code ZIP or the small Runtime-required package.
2. Extract **all** files to an English-only local path such as `C:\LEOTherm`. Leave the `app` and `runtime` directories beside `Start_LEOTherm.exe`.
3. Double-click **Start_LEOTherm.exe**. Read and accept the bundled MATLAB Runtime license on first use.
4. Select a template, check the task and run it. Selected optional stages add their results to the task report.
5. Open the PDF and retain the complete result directory. If Windows has no PDF reader, transfer the PDF to a computer with one or install a reader yourself.

No MATLAB installation, MATLAB license, separate Runtime installation, administrator elevation or Internet connection is required by the portable launcher. The complete Runtime remains necessary and is included. A first launch can be slow while Runtime extracts the compiled application's cache. The launcher waits for the application; do not repeatedly double-click it during startup.

## Scope

The launcher uses .NET Framework 4.x and Windows system components. It targets Windows x64 machines compatible with MATLAB Runtime R2021b. Windows 10/11 and Windows Server 2019 are the intended test targets, not an assertion that every Windows edition has been qualified. Antivirus/SmartScreen policy may require your organization's review of this unsigned research application. Do not disable security protection to run it.

This packaging update does not change thermal equations, eliminate previously recorded application bugs or establish flight validation. External solvers and user-supplied data are not bundled. Optional stages still require their own inputs and dependencies. Runtime files retain MathWorks' license; they are not covered by the project's open-source license.

## Files and local data

- `Start_LEOTherm.exe`: portable launcher and preflight checks.
- `app/LEOTherm.exe`: existing compiled thermal workbench, version 1.2.1.
- `runtime/v911/`: complete, unmodified MATLAB Runtime R2021b Update 8, including its legal notices.
- `portable_manifest.json`: application/runtime identity and critical-file SHA-256 hashes.
- `templates/`: editable task templates.

Only the child process receives the Runtime library paths. No system/user PATH or registry setting is changed. Logs, extraction cache and first-use license acknowledgement are written under `%LOCALAPPDATA%\LEOTherm\Portable`; simulation outputs go to the directory you select. Thus "portable" means no installer, not zero filesystem writes. Deleting the extracted package does not delete your reports or the cache.

## Diagnose

From a command prompt, `Start_LEOTherm.exe --diagnose C:\Temp\leotherm_check.json` checks the package without opening the workbench. The output parent directory must exist. This checks selected files, not every Runtime dependency or physical model validity.

Developer acceptance: `Start_LEOTherm.exe --smoke C:\Temp\new_smoke_directory` runs a small pipeline with a PDF; `--gui-smoke` also exercises GUI construction. These noninteractive tests assume the operator already has the right to use the Runtime, do not accept its license on an end user's behalf, and do not replace manual GUI acceptance. Output directories must be new.

If launch fails, keep the newest log under `%LOCALAPPDATA%\LEOTherm\Portable\logs`, the diagnostic JSON and the package SHA-256. Re-extract a complete official release before troubleshooting altered/missing files. Do not move `app/LEOTherm.exe` out of the package or mix different Runtime releases.

## Build and provenance

`tools/package_portable.ps1` builds the launcher, preserves the current compiled workbench and copies the complete installed Runtime into a ZIP without altering the Runtime. Pass an installed **MATLAB Runtime**, not a full MATLAB installation. The script checks R2021b Update 8, preserves licensing files, produces a ZIP checksum and records source Runtime identity. The archive is large and may exceed a hosting service's per-file limit; choose distribution storage accordingly. Never commit Runtime binaries to the source repository.

MathWorks documents copying an installed Runtime folder to another Windows machine without administrator installation: https://www.mathworks.com/help/mps/server/install-the-matlab-runtime.html . The launcher supplies the documented library path per process instead of modifying the user's persistent PATH.
