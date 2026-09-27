function audit = checkThermalPipelineResult(run)
%CHECKTHERMALPIPELINERESULT Numerical acceptance, not physical validation.
audit = struct('passed', true, 'errors', strings(0,1), ...
    'warnings', strings(0,1), 'physicalValidationEstablished', false);
if ~isempty(run.scenario)
    if isempty(run.scenario.temperatureK) ...
            || any(~isfinite(run.scenario.temperatureK), 'all')
        audit.errors(end+1) = "Scenario temperatures are empty or non-finite.";
    end
end
if ~isempty(run.surface)
    if isempty(run.surface.temperatureK) ...
            || any(~isfinite(run.surface.temperatureK), 'all')
        audit.errors(end+1) = "Surface temperatures are empty or non-finite.";
    end
end
if ~isempty(run.volume)
    if isempty(run.volume.temperatureK) ...
            || any(~isfinite(run.volume.temperatureK), 'all')
        audit.errors(end+1) = "Volume temperatures are empty or non-finite.";
    end
end
if ~isempty(run.coupled)
    closure = run.coupled.couplingDiagnostics.maximumAbsoluteClosureW;
    scale = max(1, max(abs(run.coupled.nodalPowerW), [], 'all'));
    if ~isfinite(closure) || closure > 1e-8 * scale
        audit.errors(end+1) = "Surface-volume heat-flow mapping does not close.";
    end
    audit.warnings(end+1) = "Coupling is one-way; face temperatures do not feed back.";
end
if ~isempty(run.sweep)
    if ~istable(run.sweep) || height(run.sweep) == 0 ...
            || ~all(strcmp(run.sweep.status, 'complete'))
        audit.errors(end+1) = "One or more sweep cases are incomplete or failed.";
    end
end
if ~isempty(run.telemetry)
    comparison = run.telemetry.report;
    if ~isfield(comparison, 'metrics') || isempty(comparison.metrics) ...
            || sum(comparison.metrics.used_samples) == 0 ...
            || any(~isfinite(comparison.metrics.rmse_k( ...
                comparison.metrics.used_samples > 0)))
        audit.errors(end+1) = "Telemetry comparison has no finite scored samples.";
    end
    audit.warnings(end+1) = ...
        "Agreement with telemetry does not establish physical correctness.";
end
if ~isempty(run.calibration) && ~run.calibration.passed
    audit.errors(end+1) = "Calibration was not accepted under declared criteria.";
end
audit.passed = isempty(audit.errors);
end
