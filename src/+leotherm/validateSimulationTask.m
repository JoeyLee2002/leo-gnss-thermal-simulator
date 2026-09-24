function audit = validateSimulationTask(task)
required = {'schemaVersion','taskId','createdUTC','runMode','scenario','network', ...
    'telemetry','calibration','scanSettings'};
if ~isstruct(task) || ~isscalar(task) || ~all(isfield(task, required))
    error('leotherm:InvalidSimulationTask','The simulation task is missing required sections.');
end
if ~isequal(task.schemaVersion, 1) || ~(ischar(task.runMode) || (isstring(task.runMode) && isscalar(task.runMode)))
    error('leotherm:InvalidSimulationTask','Unsupported simulation task schema or run mode.');
end
leotherm.validateScenario(task.scenario);
leotherm.validateNetwork(task.network);
if ~ismember(string(task.runMode), ["scenario","sweep"])
    error('leotherm:InvalidSimulationTask','Run mode must be scenario or sweep.');
end
audit = struct('ready', true, 'errors', strings(0,1), 'warnings', strings(0,1), ...
    'codes', strings(0,1), 'taskId', string(task.taskId));
if isempty(task.taskId)
    audit.warnings(end+1) = "Task has not been frozen; a run snapshot will be created.";
    audit.codes(end+1) = "task_not_frozen";
end
if ~isstruct(task.telemetry) || ~isstruct(task.calibration) || ~isstruct(task.scanSettings)
    audit.ready = false;
    audit.errors(end+1) = "Telemetry, calibration and scan settings must be structures.";
    audit.codes(end+1) = "invalid_configuration_sections";
end
if isfield(task, 'geometry') && ~isempty(task.geometry)
    leotherm.validateSurfaceMesh(task.geometry);
    audit.warnings(end+1) = "A surface mesh is loaded; the node solver remains active and the face solver can be run separately.";
    % Keep this diagnostic code stable for saved-workspace compatibility.
    audit.codes(end+1) = "mesh_preview_only";
end
if isfield(task, 'volumeMesh') && ~isempty(task.volumeMesh)
    leotherm.validateVolumeMesh(task.volumeMesh);
    audit.warnings(end+1) = "A tetrahedral volume mesh is loaded for conduction-only volume analysis.";
    audit.codes(end+1) = "volume_mesh_loaded";
end
if strcmp(task.runMode, 'sweep') && isempty(fieldnames(task.scanSettings))
    audit.ready = false;
    audit.errors(end+1) = "Sweep mode requires scan settings.";
    audit.codes(end+1) = "missing_scan_settings";
end
if isfield(task.telemetry, 'resultStale') && task.telemetry.resultStale
    audit.warnings(end+1) = "Telemetry results are stale and will not be used as current validation.";
    audit.codes(end+1) = "telemetry_result_stale";
end
if isfield(task.calibration, 'resultStale') && task.calibration.resultStale
    audit.warnings(end+1) = "Calibration results are stale and will not be used as the current model.";
    audit.codes(end+1) = "calibration_result_stale";
end
end
