function report = validateTelemetry(result, data, options)
%VALIDATETELEMETRY Compare temperatures at exact UTC epochs, without fitting.
if nargin < 3, options = struct; end
options = leotherm.telemetryOptions(options);
if isfield(result, 'epoch')
    epoch = result.epoch;
elseif isfield(result, 'orbit') && isfield(result.orbit, 'epoch')
    epoch = result.orbit.epoch;
else
    error('leotherm:TelemetryReference', 'Reference result has no epoch vector.');
end
if ~isdatetime(epoch) || ~iscolumn(epoch) || isempty(epoch.TimeZone) ...
        || ~isequal(size(result.temperatureK), [numel(epoch), numel(result.network.nodeNames)])
    error('leotherm:TelemetryReference', 'Reference requires zoned epochs and a matching temperature matrix.');
end
epoch.TimeZone = 'UTC';
validEpoch = ~isnat(epoch);
if ~any(validEpoch) || any(diff(epoch(validEpoch)) <= seconds(0))
    error('leotherm:TelemetryReference', 'Reference epochs must be unique and increasing.');
end
segment = ones(numel(epoch), 1);
if isfield(result, 'segmentId'), segment = result.segmentId; end
eligible = false(numel(epoch), 1);
for id = unique(segment(segment > 0))'
    rows = find(segment == id & validEpoch);
    elapsed = seconds(epoch(rows) - epoch(rows(1)));
    eligible(rows) = elapsed > 0 & elapsed >= options.excludeInitialS;
end
[matched, index] = ismember(data.epoch, epoch);
matched = matched & ~isnat(data.epoch);
index(~matched) = 1;
names = find(data.hasTemperature);
metrics = table('Size', [numel(names), 10], ...
    'VariableTypes', {'string','double','double','double','double','double','double','double','double','string'}, ...
    'VariableNames', {'node','valid_measured','exact_matches','used_samples','bias_k', ...
    'mae_k','rmse_k','max_abs_k','correlation','assessment'});
sampleTables = cell(numel(names), 1);
for k = 1:numel(names)
    node = names(k); nodeName = string(data.nodeNames{node});
    refNode = find(strcmp(result.network.nodeNames, nodeName), 1);
    observed = data.temperatureK(:, node);
    predicted = nan(size(observed));
    if ~isempty(refNode)
        predicted(matched) = result.temperatureK(index(matched), refNode);
    end
    valid = data.accepted & isfinite(observed) & observed > 0;
    reason = repmat("used", numel(observed), 1);
    reason(~eligible(index)) = "initial_or_excluded_window";
    reason(~isfinite(predicted) | predicted <= 0) = "invalid_or_missing_prediction";
    reason(~matched) = "no_exact_epoch_match";
    reason(~isfinite(observed) | observed <= 0) = "invalid_temperature";
    reason(~data.accepted) = data.audit.reason(~data.accepted);
    used = valid & matched & isfinite(predicted) & predicted > 0 & eligible(index);
    residual = predicted - observed;
    metrics.node(k) = nodeName;
    metrics.valid_measured(k) = sum(valid);
    metrics.exact_matches(k) = sum(valid & matched & isfinite(predicted));
    metrics.used_samples(k) = sum(used);
    metrics{k, 5:9} = NaN;
    metrics.assessment(k) = "insufficient_samples";
    if any(used)
        delta = residual(used);
        metrics.bias_k(k) = mean(delta);
        metrics.mae_k(k) = mean(abs(delta));
        metrics.rmse_k(k) = sqrt(mean(delta.^2));
        metrics.max_abs_k(k) = max(abs(delta));
    end
    if sum(used) >= 3
        metrics.assessment(k) = "comparison_only";
        if std(observed(used)) > 0 && std(predicted(used)) > 0
            r = corrcoef(observed(used), predicted(used));
            metrics.correlation(k) = r(1, 2);
        end
        if isfinite(options.rmseToleranceK)
            if metrics.rmse_k(k) <= options.rmseToleranceK
                metrics.assessment(k) = "within_user_rmse_limit";
            else
                metrics.assessment(k) = "outside_user_rmse_limit";
            end
        end
    end
    sampleTables{k} = table((1:numel(observed))', data.epoch, ...
        repmat(nodeName, numel(observed), 1), observed, predicted, residual, used, reason, ...
        'VariableNames', {'source_row','epoch_utc','node','observed_k', ...
        'predicted_k','residual_k','used','reason'});
    sampleTables{k}.segment_id = zeros(numel(observed),1);
    sampleTables{k}.segment_id(matched) = segment(index(matched));
end
report.metrics = metrics;
report.samples = vertcat(sampleTables{:});
if isempty(sampleTables)
    report.samples = table;
end
report.options = options;
report.softwareVersion = leotherm.version;
report.source = data.source;
report.datasetKind = data.datasetKind;
report.alignment = 'exact_utc_only';
report.residualSign = 'simulation_minus_measurement';
report.statisticsWeighting = 'sample_weighted_not_independent_replicates';
report.interpolation = false;
report.fittedToValidation = false;
report.independence = 'not_established_user_must_confirm_held_out_data';
if isfield(result, 'provenance') ...
        && strcmp(result.provenance.initialization, 'measured_initial_temperature_conditioned')
    report.independence = 'conditioned_on_measured_initial_state';
end
if strcmp(data.datasetKind, 'synthetic_demo_not_flight_data')
    report.independence = 'synthetic_not_independent_validation';
end
report.boundaryConditioning = isfield(result, 'provenance') ...
    && isfield(result.provenance, 'boundaryConditioning') && result.provenance.boundaryConditioning;
if report.boundaryConditioning && ~strcmp(data.datasetKind, 'synthetic_demo_not_flight_data')
    report.independence = 'conditioned_on_prescribed_boundary_not_whole_spacecraft_validation';
end
report.conclusion = ['Agreement assessment, not proof of physical correctness. ' ...
    'This function does not fit parameters, offsets, gains, or time shifts. ' ...
    'Sensor uncertainty, calibration independence, and mission coverage require separate evidence.'];
end
