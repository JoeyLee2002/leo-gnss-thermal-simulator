function snapshot = freezeSimulationTask(task)
audit = leotherm.validateSimulationTask(task);
if ~audit.ready
    error('leotherm:InvalidSimulationTask','Cannot freeze an invalid simulation task.');
end
snapshot = task;
if isempty(snapshot.taskId)
    snapshot.taskId = char(java.util.UUID.randomUUID);
end
snapshot.createdUTC = datetime('now', 'TimeZone', 'UTC');
snapshot.frozenUTC = snapshot.createdUTC;
snapshot.isFrozen = true;
snapshot.inputFingerprint = leotherm.simulationTaskFingerprint(snapshot);
end
