% LEO GNSS Thermal Simulator package.
%
% Scenario and network
%   defaultScenario             - Reference orbit/environment configuration.
%   defaultReceiverNetwork      - Reference 11-node GNSS thermal network.
%   symmetricReceiverNetwork    - Strict signed-beta symmetry control.
%   applyThermalAsymmetry       - Controlled symmetry-breaking perturbation.
%   satmoStyleNetwork           - Public seven-node benchmark box.
%   validateNetwork             - Validate thermal-network inputs.
%   validateScenario            - Validate orbit/environment configuration.
%   validateTrajectory          - Validate external ECI and attitude histories.
%   version                     - Return the installed software version.
%   selfTest                    - Run the installed automated verification suite.
%   launchApp                   - Open the interactive graphical workbench.
%   parseNumericList            - Parse safe GUI vector and range inputs.
%   parseDateList               - Parse comma-separated UTC dates.
%
% Geometry and environment
%   readVolumeMesh              - Read an ASCII Gmsh 2.x tetrahedral mesh and tags.
%   validateVolumeMesh          - Validate a tetrahedral volume mesh.
%   assembleVolumeThermalModel  - Assemble linear-tetrahedron FEM matrices.
%   solveVolumeThermal          - Solve transient tetrahedral conduction.
%   plotVolumeMesh               - Render a tetrahedral mesh with nodal data.
%   writeVolumeThermalResult     - Export tetrahedral conduction results.
%   coupleSurfaceToVolumeThermal - Conservatively map face loads to volume nodes.
%   writeSurfaceVolumeCouplingResult - Export surface-volume coupling loads.
%   assembleContactThermalInterfaces - Assemble conservative contact conductance.
%   applyContactThermalInterfaces - Add contact conductance to a volume model.
%   contactHeatLedger             - Audit signed contact heat transfer.
%   assembleThermalBoundaryConditions - Assemble flux/Robin boundary operators.
%   importExternalTask            - Import strict orbit/attitude/telemetry bundle.
%   quaternionToBodyAxes          - Convert explicit ECI-to-body quaternions.
%   propagateCircularOrbit      - Circular orbit with optional secular J2.
%   solarVectorECI              - Analytical geocentric Sun vector.
%   solveRaanForBeta            - RAAN inversion for a requested signed beta.
%   conicalShadowFraction       - Umbra/penumbra solar visibility.
%   meshSolarVisibility         - Per-face centroid-ray solar self-shadowing.
%   bodyFrame                   - Nadir, Sun-pointing, or inertial body axes.
%   environmentHeatLoads        - Face-resolved external heat inputs.
%
% Thermal and observation models
%   solveThermalNetwork         - Nonlinear transient thermal integration.
%   initializePeriodicState     - Converged same-phase thermal initialization.
%   temperatureCodeBias         - Semi-synthetic code-bias mapping.
%   computeMetrics              - Temperature, lag, eclipse, and bias metrics.
%   hysteresisLoopMetrics       - Physical and normalized orbital loop areas.
%   positivePhaseLag            - Alias-limited forcing-response phase lag.
%   orbitalPeakLagMetrics       - Per-orbit peak and trough event lags.
%
% Workflows
%   simulateScenario            - End-to-end internally propagated scenario.
%   simulateTrajectory          - End-to-end external trajectory interface.
%   simulateSurfaceVolumeScenario - Surface radiation to volume conduction workflow.
%   writeSurfaceVolumeScenarioResult - Export coupled result and report.
%   runBetaAltitudeSweep        - Controlled beta-altitude parameter study.
%   runPhysicalSweep            - Date/inclination/RAAN/altitude study.
%   runUncertaintyEnsemble      - Reproducible stratified parameter ensemble.
%   writeScenario               - MAT/CSV result export.
%   writeSurfaceMeshResult      - Export face properties and thermal time series.
%   plotScenario                - Four-panel scenario summary.
%   plotSweep                   - Parameter-sweep summary.
%   writeThermalReport          - Export a unified bilingual thermal report.
%
% Adapter and external-solver SDK
%   leotherm.adapter.list       - List built-in and user-supplied adapters.
%   leotherm.adapter.execute    - Execute a registered adapter capability.
%   leotherm.adapter.registerFromFile - Load metadata and attach handlers.
%   leotherm.io.runExternalThermalSolver - Run a controlled external solver.
%   leotherm.report.writeThermalSimulationReport - Export external-run report.
%
% Device-constrained calibration
%   deviceCalibrationProfile    - Locked nominal device and evidence template.
%   validateDeviceCalibrationProfile - Physical limits and stale-device checks.
%   applyDeviceCalibrationProfile - Apply bounded free values without rebasing.
%   deviceCalibrationOptions    - Prior, sensor and acceptance settings.
%   calibrationDaySplit         - Explicit whole-day role assignment template.
%   deviceCalibrationDemo       - Synthetic constrained-calibration inputs.
%   calibrateTelemetry          - Training-only fit followed by frozen checks.
%   writeDeviceCalibrationResults - Auditable bilingual device reports.
%   plotDeviceCalibration       - Complete day/node plots with gap breaks.
