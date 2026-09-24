function result = runSimulationTask(task)
if nargin < 1 || isempty(task)
    error('leotherm:InvalidSimulationTask','A simulation task is required.');
end
if ~isfield(task,'isFrozen') || ~task.isFrozen
    task = leotherm.freezeSimulationTask(task);
else
    leotherm.validateSimulationTask(task);
end
if ~strcmp(task.runMode, 'scenario')
    error('leotherm:InvalidSimulationTask', ...
        'runSimulationTask executes scenario tasks; use the sweep runner for sweep tasks.');
end
result = leotherm.simulateScenario(task.scenario, task.network);
if isfield(task, 'geometry')
    result.geometry = task.geometry;
end
result.taskId = task.taskId;
result.taskInputFingerprint = task.inputFingerprint;
end
