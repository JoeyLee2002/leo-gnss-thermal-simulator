function state = readWorkspaceProject(path)
%READWORKSPACEPROJECT Reject incompatible projects before changing a workspace.
loaded = load(path,'project');
if ~isfield(loaded,'project') || ~isstruct(loaded.project) || ~isscalar(loaded.project) ...
        || ~isfield(loaded.project,'schemaVersion') || ~isequal(loaded.project.schemaVersion,1) ...
        || ~isfield(loaded.project,'state')
    error('leotherm:ProjectFormat','Unsupported project. Device configurations belong in Import device configuration.');
end
state = loaded.project.state;
required = {'scenario','network','result','sweep','sweepMode','sweepContext', ...
    'scanSettings','language','telemetry','calibration'};
if ~isstruct(state) || ~isscalar(state) || ~all(isfield(state,required))
    error('leotherm:ProjectFormat','The project is missing required workspace sections.');
end
if isfield(state,'task')
    leotherm.validateSimulationTask(state.task);
end
if isfield(state,'geometry') && ~isempty(state.geometry)
    leotherm.validateSurfaceMesh(state.geometry);
end
if isfield(state,'volumeMesh') && ~isempty(state.volumeMesh)
    leotherm.validateVolumeMesh(state.volumeMesh);
end
if isfield(state,'taskHistory') && ~isstruct(state.taskHistory)
    error('leotherm:ProjectFormat','The task history section must be a structure array.');
end
leotherm.validateScenario(state.scenario);
leotherm.validateNetwork(state.network);
leotherm.normalizeLanguage(state.language);
if ~istable(state.sweep) || ~isstruct(state.scanSettings) ...
        || ~isstruct(state.telemetry) || ~isstruct(state.calibration)
    error('leotherm:ProjectFormat','Invalid workspace section types.');
end
end
