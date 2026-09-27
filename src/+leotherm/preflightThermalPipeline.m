function audit = preflightThermalPipeline(task)
%PREFLIGHTTHERMALPIPELINE Check all declared stages before creating output.
audit = struct('ready', false, 'errors', strings(0,1), ...
    'warnings', strings(0,1), 'stages', strings(0,1));
try
    if ~isstruct(task) || ~isscalar(task) || ~isfield(task, 'schema') ...
            || ~strcmp(task.schema, 'leotherm.pipeline_task.v1')
        error('leotherm:PipelineTask', 'Unsupported pipeline task schema.');
    end
    required = {'mode','scenario','network','surfaceMesh','volumeMesh', ...
        'material','couplingOptions','geometry','sweep','telemetry','calibration','language'};
    if ~all(isfield(task, required))
        error('leotherm:PipelineTask', 'A required pipeline section is missing.');
    end
    if ~strcmp(task.mode, 'pipeline')
        error('leotherm:PipelineTask', 'A pipeline task must use pipeline mode.');
    end
    leotherm.validateScenario(task.scenario);
    leotherm.validateNetwork(task.network);
    leotherm.normalizeLanguage(task.language);
    audit.stages(end+1) = "preflight";

    if ~isstruct(task.calibration) || ~isscalar(task.calibration) ...
            || ~isfield(task.calibration, 'enabled')
        error('leotherm:PipelineTask', 'Calibration configuration is invalid.');
    end
    if task.calibration.enabled
        c = task.calibration;
        if ~all(isfield(c, {'source','mapping','profile','split','settings'})) ...
                || isempty(c.source) || isempty(c.profile) || isempty(c.split)
            error('leotherm:PipelineTask', ...
                'Calibration requires telemetry, a device profile and a day split.');
        end
        leotherm.validateDeviceCalibrationProfile(c.profile, task.network);
        leotherm.deviceCalibrationOptions(c.settings, numel(task.network.nodeNames));
        audit.stages(end+1) = "calibration";
    end

    audit.stages(end+1) = "nodal_simulation";
    s = task.sweep;
    if ~isstruct(s) || ~isscalar(s) || ~isfield(s, 'enabled')
        error('leotherm:PipelineTask', 'Sweep configuration is invalid.');
    end
    if s.enabled
        if ~isfield(s, 'mode')
            error('leotherm:PipelineTask', 'Sweep mode is missing.');
        end
        if strcmp(s.mode, 'beta_altitude')
            if ~all(isfield(s, {'altitudeKm','betaDeg','branch'})) ...
                    || isempty(s.altitudeKm) || isempty(s.betaDeg)
                error('leotherm:PipelineTask', 'Altitude-beta sweep inputs are missing.');
            end
        elseif strcmp(s.mode, 'physical')
            if ~all(isfield(s, {'dates','altitudeKm','inclinationDeg','raanDeg'})) ...
                    || isempty(s.dates) || isempty(s.altitudeKm) ...
                    || isempty(s.inclinationDeg) || isempty(s.raanDeg)
                error('leotherm:PipelineTask', 'Physical sweep inputs are missing.');
            end
        else
            error('leotherm:PipelineTask', 'Unsupported sweep mode.');
        end
        audit.stages(end+1) = "batch_simulation";
    end

    g = task.geometry;
    if ~isstruct(g) || ~isscalar(g) || ~isfield(g, 'enabled')
        error('leotherm:PipelineTask', 'Geometry configuration is invalid.');
    end
    if g.enabled
        leotherm.validateSurfaceMesh(task.surfaceMesh);
        if ~isfield(g, 'solver')
            error('leotherm:PipelineTask', 'Geometry solver is missing.');
        end
        if strcmp(g.solver, 'coupled')
            leotherm.validateVolumeMesh(task.volumeMesh);
            if ~isstruct(task.material) || isempty(fieldnames(task.material))
                error('leotherm:PipelineTask', ...
                    'Coupled analysis requires declared material properties.');
            end
            leotherm.normalizeCouplingOptions(task.couplingOptions, task.volumeMesh);
            audit.stages(end+1) = "surface_volume_simulation";
            audit.warnings(end+1) = ...
                "Surface-to-volume coupling is one-way; face temperatures do not feed back.";
        elseif strcmp(g.solver, 'surface')
            audit.stages(end+1) = "surface_simulation";
        else
            error('leotherm:PipelineTask', 'Unsupported geometry solver.');
        end
    end

    if task.telemetry.enabled
        t = task.telemetry;
        if ~all(isfield(t, {'source','mapping','options','workflow', ...
                'independentHoldoutConfirmed'})) || isempty(t.source)
            error('leotherm:PipelineTask', 'Telemetry settings or source are missing.');
        end
        data = leotherm.readTelemetry(t.source, t.mapping, task.network);
        driverAudit = leotherm.telemetryPreflight(data, t.options, t.workflow);
        if ~driverAudit.ready
            error('leotherm:PipelineTelemetry', ...
                'Telemetry preflight failed: %s', strjoin(cellstr(driverAudit.codes), ', '));
        end
        if ~ismember(string(t.workflow), ["orbit","heat","validation"])
            error('leotherm:PipelineTask', 'Unsupported telemetry workflow.');
        end
        if task.calibration.enabled
            c = task.calibration;
            if ~isequaln(c.source, t.source)
                calibrationData = leotherm.readTelemetry(c.source, c.mapping, task.network);
                if ~isempty(intersect(calibrationData.epoch, data.epoch))
                    error('leotherm:PipelineDataLeakage', ...
                        'Validation telemetry shares epochs with calibration data.');
                end
            else
                audit.warnings(end+1) = ...
                    "Calibration test days, not training days, will be used for telemetry acceptance.";
            end
        end
        if task.calibration.enabled && ~t.independentHoldoutConfirmed
            audit.warnings(end+1) = ...
                "Calibration holdout independence is not confirmed by the user.";
        end
        audit.stages(end+1) = "telemetry_comparison";
    end
    audit.stages(end+1) = "numerical_acceptance";
    audit.stages(end+1) = "report";
    audit.ready = true;
catch exception
    audit.errors(end+1) = string(exception.message);
    audit.errorIdentifier = string(exception.identifier);
end
end
