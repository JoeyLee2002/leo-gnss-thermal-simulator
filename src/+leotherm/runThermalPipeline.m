function run = runThermalPipeline(task, outputDirectory)
%RUNTHERMALPIPELINE Execute one preflighted task into one immutable run folder.
if nargin < 2 || isempty(outputDirectory)
    error('leotherm:PipelineOutput', 'A new output directory is required.');
end
audit = leotherm.preflightThermalPipeline(task);
if ~audit.ready
    error('leotherm:PipelinePreflight', '%s', strjoin(cellstr(audit.errors), newline));
end
if isfile(outputDirectory) || isfolder(outputDirectory)
    error('leotherm:PipelineOutput', 'Run directory already exists: %s', outputDirectory);
end
[ok, message] = mkdir(outputDirectory);
if ~ok, error('leotherm:PipelineOutput', 'Cannot create run directory: %s', message); end

run = struct('schema', 'leotherm.pipeline_run.v1', ...
    'taskId', char(java.util.UUID.randomUUID), ...
    'inputFingerprint', leotherm.simulationTaskFingerprint(task), ...
    'startedUTC', datetime('now', 'TimeZone', 'UTC'), ...
    'completedUTC', [], 'status', 'running', ...
    'outputDirectory', char(outputDirectory), 'mode', 'pipeline', ...
    'input', task, 'preflight', audit, 'calibration', [], ...
    'frozenNetwork', [], 'frozenModelFingerprint', '', ...
    'scenario', [], 'surface', [], 'volume', [], 'coupled', [], ...
    'sweep', table, 'telemetry', [], 'acceptance', struct, ...
    'stages', struct('name', {}, 'status', {}, 'startedUTC', {}, ...
        'completedUTC', {}, 'message', {}));
currentStage = 'snapshot';
stageStart = datetime('now', 'TimeZone', 'UTC');
try
    save(fullfile(outputDirectory, 'input_snapshot.mat'), 'task', 'audit', '-v7.3');
    run = completeStage(run, currentStage, stageStart, 'Input frozen before computation.');
    network = task.network;

    if task.calibration.enabled
        currentStage = 'calibration';
        stageStart = datetime('now', 'TimeZone', 'UTC');
        c = task.calibration;
        calibrationData = leotherm.readTelemetry(c.source, c.mapping, network);
        run.calibration = leotherm.calibrateTelemetry(calibrationData, ...
            task.scenario, network, c.profile, c.split, c.settings, ...
            fullfile(outputDirectory, 'calibration'));
        if ~run.calibration.passed
            error('leotherm:PipelineCalibration', ...
                'Calibration did not pass declared criteria (%s); model was not adopted.', ...
                run.calibration.status);
        end
        network = run.calibration.profileAfter.calibratedNetwork;
        leotherm.validateNetwork(network);
        run = completeStage(run, currentStage, stageStart, ...
            'Training fit accepted; calibrated network available for downstream stages.');
    else
        run = skipStage(run, 'calibration', 'Calibration was not selected.');
    end

    currentStage = 'freeze_model';
    stageStart = datetime('now', 'TimeZone', 'UTC');
    run.frozenNetwork = network;
    run.frozenModelFingerprint = leotherm.simulationTaskFingerprint( ...
        struct('scenario', task.scenario, 'network', network));
    frozenModel = struct('scenario', task.scenario, 'network', network, ...
        'fingerprint', run.frozenModelFingerprint, ...
        'calibrationApplied', task.calibration.enabled);
    save(fullfile(outputDirectory, 'frozen_model.mat'), 'frozenModel', '-v7.3');
    run = completeStage(run, currentStage, stageStart, ...
        'Model parameters frozen after optional calibration.');

    currentStage = 'nodal_simulation';
    stageStart = datetime('now', 'TimeZone', 'UTC');
    run.scenario = leotherm.simulateScenario(task.scenario, network);
    run = completeStage(run, currentStage, stageStart, ...
        'Orbit, environmental loads, nodal temperatures and lag metrics computed.');

    if task.sweep.enabled
        currentStage = 'batch_simulation';
        stageStart = datetime('now', 'TimeZone', 'UTC');
        s = task.sweep;
        if strcmp(s.mode, 'beta_altitude')
            run.sweep = leotherm.runBetaAltitudeSweep(task.scenario, network, ...
                s.altitudeKm, s.betaDeg, s.branch);
        else
            run.sweep = leotherm.runPhysicalSweep(task.scenario, network, ...
                s.dates, s.altitudeKm, s.inclinationDeg, s.raanDeg);
        end
        run = completeStage(run, currentStage, stageStart, ...
            'All declared sweep cases processed.');
    else
        run = skipStage(run, 'batch_simulation', 'Parameter sweep was not selected.');
    end

    if task.geometry.enabled
        currentStage = 'geometry_simulation';
        stageStart = datetime('now', 'TimeZone', 'UTC');
        if strcmp(task.geometry.solver, 'coupled')
            options = leotherm.normalizeCouplingOptions( ...
                task.couplingOptions, task.volumeMesh);
            run.coupled = leotherm.simulateSurfaceVolumeScenario( ...
                task.scenario, task.surfaceMesh, task.volumeMesh, ...
                task.material, options);
            run.surface = run.coupled.surface;
            run.volume = run.coupled.volume;
        else
            run.surface = leotherm.simulateSurfaceMeshScenario( ...
                task.scenario, task.surfaceMesh, struct);
        end
        run = completeStage(run, currentStage, stageStart, ...
            'Optional geometry solver completed on the same scenario.');
    else
        run = skipStage(run, 'geometry_simulation', 'Three-dimensional analysis was not selected.');
    end

    currentStage = 'telemetry_comparison';
    stageStart = datetime('now', 'TimeZone', 'UTC');
    if task.telemetry.enabled && task.calibration.enabled ...
            && isequaln(task.calibration.source, task.telemetry.source)
        c = run.calibration;
        run.telemetry = struct('result', c.prediction{3}, ...
            'report', c.reports{3}, ...
            'data', struct('source', c.source));
        run = completeStage(run, currentStage, stageStart, ...
            'Frozen calibration model evaluated on declared test days.');
    elseif task.telemetry.enabled
        t = task.telemetry;
        data = leotherm.readTelemetry(t.source, t.mapping, network);
        if strcmp(t.workflow, 'validation')
            prediction = run.scenario;
            message = 'Scenario temperatures compared at exact UTC epochs.';
        else
            prediction = leotherm.simulateTelemetry(data, ...
                task.scenario, network, t.options);
            message = 'Frozen network simulated under measured drivers and compared.';
        end
        comparison = leotherm.validateTelemetry(prediction, data, t.options);
        run.telemetry = struct('result', prediction, 'report', comparison, ...
            'data', data);
        run = completeStage(run, currentStage, stageStart, message);
    else
        run = skipStage(run, currentStage, ...
            'Telemetry was not selected; physical validation is not claimed.');
    end

    currentStage = 'numerical_acceptance';
    stageStart = datetime('now', 'TimeZone', 'UTC');
    run.acceptance = leotherm.checkThermalPipelineResult(run);
    if ~run.acceptance.passed
        error('leotherm:PipelineAcceptance', '%s', ...
            strjoin(cellstr(run.acceptance.errors), newline));
    end
    run = completeStage(run, currentStage, stageStart, ...
        'Numerical and data-quality checks passed; not a claim of physical validity.');

    currentStage = 'report';
    stageStart = datetime('now', 'TimeZone', 'UTC');
    bundle = reportBundle(run, network);
    leotherm.writeThermalReport(bundle, fullfile(outputDirectory, 'report'), task.language);
    run = completeStage(run, currentStage, stageStart, ...
        'Task-specific PDF and audit tables written.');
    run.status = 'complete';
    run.completedUTC = datetime('now', 'TimeZone', 'UTC');
    persistRun(run);
catch exception
    entry = stageEntry(currentStage, 'failed', stageStart, exception.message);
    run.stages(end+1) = entry;
    run.status = 'failed';
    run.completedUTC = datetime('now', 'TimeZone', 'UTC');
    run.failure = struct('identifier', exception.identifier, ...
        'message', exception.message);
    persistRun(run);
    rethrow(exception)
end
end

function run = completeStage(run, name, startTime, message)
run.stages(end+1) = stageEntry(name, 'complete', startTime, message);
persistRun(run);
end

function run = skipStage(run, name, message)
run.stages(end+1) = stageEntry(name, 'skipped', ...
    datetime('now', 'TimeZone', 'UTC'), message);
persistRun(run);
end

function entry = stageEntry(name, status, started, message)
entry = struct('name', char(name), 'status', char(status), ...
    'startedUTC', started, ...
    'completedUTC', datetime('now', 'TimeZone', 'UTC'), ...
    'message', char(message));
end

function persistRun(run)
save(fullfile(run.outputDirectory, 'pipeline_run.mat'), 'run', '-v7.3');
status = struct('schema', run.schema, 'taskId', run.taskId, ...
    'inputFingerprint', run.inputFingerprint, 'mode', run.mode, ...
    'status', run.status, 'stages', {stageSummary(run.stages)});
if isfield(run, 'failure'), status.failure = run.failure; end
fid = fopen(fullfile(run.outputDirectory, 'pipeline_status.json'), 'w', 'n', 'UTF-8');
if fid < 0
    error('leotherm:PipelineOutput', 'Cannot write pipeline_status.json.');
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(status, 'PrettyPrint', true));
end

function stages = stageSummary(entries)
stages = struct('name', {}, 'status', {}, 'startedUTC', {}, ...
    'completedUTC', {}, 'message', {});
for k = 1:numel(entries)
    stages(k) = entries(k);
    stages(k).startedUTC = char(string(entries(k).startedUTC));
    stages(k).completedUTC = char(string(entries(k).completedUTC));
end
end

function bundle = reportBundle(run, network)
bundle = struct('scenarioResult', run.scenario, 'surfaceResult', run.surface, ...
    'volumeResult', run.volume, 'sweep', run.sweep, ...
    'telemetry', run.telemetry, 'calibration', run.calibration);
bundle.metadata = struct('taskId', run.taskId, ...
    'inputFingerprint', run.inputFingerprint, ...
    'frozenModelFingerprint', run.frozenModelFingerprint, ...
    'taskMode', run.mode, 'pipelineStatus', 'accepted_before_report', ...
    'calibrationApplied', ~isempty(run.calibration), ...
    'calibrationStatus', 'not_run', 'physicalValidationEstablished', false, ...
    'oneWaySurfaceVolumeCoupling', ~isempty(run.coupled), ...
    'stages', {stageSummary(run.stages)});
if ~isempty(run.calibration)
    bundle.metadata.calibrationStatus = run.calibration.status;
    bundle.metadata.calibrationParameterCount = ...
        sum(run.calibration.profileBefore.parameters.estimate);
end
if ~isempty(run.sweep)
    bundle.sweepContext = struct('scenario', run.input.scenario, ...
        'network', network, 'mode', run.input.sweep.mode, ...
        'scanSettings', run.input.sweep);
end
if ~isempty(run.coupled)
    bundle.volumeResult.couplingDiagnostics = ...
        run.coupled.couplingDiagnostics;
end
end
