function tests = test_simulation_task
tests = functiontests(localfunctions);
end

function testTaskHasStableRequiredSections(testCase)
scenario = leotherm.defaultScenario;
network = leotherm.defaultReceiverNetwork;
task = leotherm.createSimulationTask(scenario, network);
audit = leotherm.validateSimulationTask(task);
verifyTrue(testCase, audit.ready);
verifyEqual(testCase, task.schemaVersion, 1);
verifyEqual(testCase, task.runMode, 'scenario');
end

function testFreezeAddsIdentityAndFingerprint(testCase)
task = leotherm.createSimulationTask(leotherm.defaultScenario, ...
    leotherm.defaultReceiverNetwork);
snapshot = leotherm.freezeSimulationTask(task);
verifyTrue(testCase, snapshot.isFrozen);
verifyFalse(testCase, isempty(snapshot.taskId));
verifyEqual(testCase, numel(snapshot.inputFingerprint), 64);
verifyEqual(testCase, snapshot.inputFingerprint, ...
    leotherm.simulationTaskFingerprint(snapshot));
end

function testFingerprintChangesWithScientificInput(testCase)
task = leotherm.createSimulationTask(leotherm.defaultScenario, ...
    leotherm.defaultReceiverNetwork);
first = leotherm.simulationTaskFingerprint(task);
task.scenario.timeStepS = task.scenario.timeStepS + 1;
second = leotherm.simulationTaskFingerprint(task);
verifyNotEqual(testCase, first, second);
end

function testScenarioTaskRunsFromFrozenSnapshot(testCase)
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 20;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
task = leotherm.freezeSimulationTask(leotherm.createSimulationTask( ...
    scenario, leotherm.defaultReceiverNetwork));
result = leotherm.runSimulationTask(task);
verifyEqual(testCase, result.taskId, task.taskId);
verifyEqual(testCase, result.taskInputFingerprint, task.inputFingerprint);
verifyGreaterThan(testCase, numel(result.timeS), 1);
end

function testSweepTaskRequiresSweepRunner(testCase)
task = leotherm.freezeSimulationTask(leotherm.createSimulationTask( ...
    leotherm.defaultScenario, leotherm.defaultReceiverNetwork, struct, struct, ...
    struct('mode','beta_altitude'), 'sweep'));
verifyError(testCase, @() leotherm.runSimulationTask(task), ...
    'leotherm:InvalidSimulationTask');
end

function testTaskCarriesSurfaceMesh(testCase)
mesh = struct('vertices', [0 0 0; 1 0 0; 0 1 0], ...
    'faces', [1 2 3], 'faceNormals', [0 0 1], 'faceAreasM2', 0.5);
mesh.faceSolarAbsorptivity = 0.6;
mesh.faceIREmissivity = 0.8;
leotherm.validateSurfaceMesh(mesh);
task = leotherm.createSimulationTask(leotherm.defaultScenario, ...
    leotherm.defaultReceiverNetwork, struct, struct, struct, 'scenario', mesh);
audit = leotherm.validateSimulationTask(task);
verifyTrue(testCase, audit.ready);
verifyTrue(testCase, any(audit.codes == "mesh_preview_only"));
end
