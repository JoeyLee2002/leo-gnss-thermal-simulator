function outputs = run_gap_experiments(profile)
%RUN_GAP_EXPERIMENTS Fill paper-1 storage and numerical-sensitivity gaps.
% Results are written to a new versioned directory; historical CSV files are
% never overwritten and no missing case or sample is filled.

if nargin < 1 || isempty(profile), profile = 'paper'; end
assert(strcmpi(profile, 'paper'), 'Only the paper profile is supported.');
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'src'));
config = gap_config(root);
outDir = config.outputDirectory;
if ~exist(outDir, 'dir'), mkdir(outDir); end
write_gap_manifest(outDir, config);

network = leotherm.symmetricReceiverNetwork;
outputs.storageIsolation = run_storage_isolation(config, network, outDir);
outputs.numericalStability = run_numerical_stability(config, network, outDir);
save(fullfile(outDir, 'gap_experiments.mat'), 'outputs', 'config', '-v7.3');
fprintf('Gap experiments written to %s\n', outDir);
end

function config = gap_config(root)
version = strtrim(fileread(fullfile(root, 'VERSION')));
config.version = version;
config.study = 'paper1_gap_experiments';
config.seed = 20260914;
config.outputDirectory = fullfile(root, 'results', ...
    ['paper1_gap_v' strrep(version, '.', '_') '_paper']);
config.epoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
config.altitudeKm = 600;
config.inclinationDeg = 90;
config.targetBetaDeg = [0, 30, 70];
config.capacityFactors = [0.05, 0.25, 1, 4, 16];
config.timeStepsS = [30, 15, 7.5];

base = leotherm.defaultScenario;
base.name = 'paper1_gap_controlled';
base.startEpoch = config.epoch;
base.durationS = 6 * 3600;
base.timeStepS = config.timeStepsS(1);
base.orbit.altitudeM = config.altitudeKm * 1000;
base.orbit.inclinationDeg = config.inclinationDeg;
base.orbit.argumentLatitudeDeg = 0;
base.orbit.useJ2 = false;
base.attitude.mode = 'nadir';
base.attitude.eulerOffsetDeg = [0, 0, 0];
base.environment.freezeSunAtEpoch = true;
base.convergence.minimumCycles = 5;
% The 16x capacity stress case has a longer thermal settling time. Keep the
% failure rule, but allow enough cycles to test it instead of discarding it
% solely because the legacy paper configuration used 60 cycles.
base.convergence.maximumCycles = 400;
base.convergence.requiredStableCycles = 2;
base.convergence.toleranceK = 5e-3;
base.convergence.failOnNonConvergence = true;
config.baseScenario = base;
end

function [scenario, accessible] = controlledScenario(config, beta, step)
scenario = config.baseScenario;
scenario.name = sprintf('paper1_gap_beta_%+g_step_%g', beta, step);
scenario.timeStepS = step;
scenario.orbit.raanDeg = 0;
[raan, accessible] = leotherm.solveRaanForBeta(config.epoch, ...
    config.inclinationDeg, beta, 1);
if accessible, scenario.orbit.raanDeg = raan; end
end

function summary = run_storage_isolation(config, baseNetwork, outDir)
nRows = numel(config.targetBetaDeg) * (numel(config.capacityFactors) + 1);
rows = repmat(emptyStorageRow, nRows, 1);
count = 0;
for beta = config.targetBetaDeg
    [scenario, accessible] = controlledScenario(config, beta, config.timeStepsS(1));
    assert(accessible, 'Configured beta is inaccessible.');
    baseline = leotherm.simulateScenario(scenario, baseNetwork);
    forcing = baseline.loads.totalExternalW;
    baseTemperature = quasi_static_temperature(forcing, baseline.network, ...
        scenario.environment, scenario.integration);
    baseMetrics = leotherm.orbitalPeakLagMetrics(baseline.timeS, ...
        sum(forcing, 2), baseTemperature(:, baseNetwork.roles.response), ...
        baseline.orbit.periodS);
    write_forcing(outDir, beta, baseline);
    for factor = [NaN, config.capacityFactors]
        count = count + 1;
        row = emptyStorageRow;
        row.beta_deg = beta;
        row.capacity_factor = factor;
        row.case_type = 'dynamic';
        if isnan(factor)
            row.case_type = 'quasi_static_reference';
            row.temperature_span_k = percentile_span(baseTemperature(:, baseNetwork.roles.response));
            row.peak_lag_s = baseMetrics.peakToPeakLagMedianS;
            row.peak_phase_identifiable = baseMetrics.identifiable;
        else
            network = baseNetwork;
            network.capacityJK = baseNetwork.capacityJK * factor;
            result = leotherm.simulateScenario(scenario, network);
            response = network.roles.response;
            row.temperature_span_k = result.metrics.responseTemperatureSpanK;
            row.peak_lag_s = result.metrics.forcingPeakToResponsePeakLagS;
            row.peak_phase_identifiable = result.metrics.peakPhaseIdentifiable;
            row.quasi_static_rms_k = sqrt(mean((result.temperatureK(:, response) - ...
                baseTemperature(:, response)).^2));
            row.quasi_static_difference_span_k = percentile_span(result.temperatureK(:, response) - ...
                baseTemperature(:, response));
            row.periodic_error_k = result.convergence.periodicErrorK;
            row.convergence_cycles = result.convergence.cycles;
        end
        rows(count) = row;
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'storage_isolation.csv'));
end

function summary = run_numerical_stability(config, baseNetwork, outDir)
nRows = numel(config.targetBetaDeg) * numel(config.timeStepsS);
rows = repmat(emptyNumericalRow, nRows, 1);
count = 0;
for beta = config.targetBetaDeg
    results = cell(numel(config.timeStepsS), 1);
    for index = 1:numel(config.timeStepsS)
        step = config.timeStepsS(index);
        [scenario, accessible] = controlledScenario(config, beta, step);
        assert(accessible, 'Configured beta is inaccessible.');
        results{index} = leotherm.simulateScenario(scenario, baseNetwork);
    end
    reference = results{end};
    refTemp = reference.temperatureK(:, baseNetwork.roles.response);
    for index = 1:numel(config.timeStepsS)
        result = results{index};
        count = count + 1;
        row = emptyNumericalRow;
        row.beta_deg = beta;
        row.time_step_s = config.timeStepsS(index);
        row.temperature_span_k = result.metrics.responseTemperatureSpanK;
        row.peak_lag_s = result.metrics.forcingPeakToResponsePeakLagS;
        row.peak_phase_identifiable = result.metrics.peakPhaseIdentifiable;
        row.signed_peak_phase_s = result.metrics.signedPeakPhaseMedianS;
        row.sampling_resolution_s = result.metrics.peakPhaseSamplingResolutionS;
        row.hysteresis_area_wk = result.metrics.responseHysteresisAreaWK;
        row.periodic_error_k = result.convergence.periodicErrorK;
        row.accepted_internal_steps = result.numerics.acceptedSteps;
        row.rejected_internal_steps = result.numerics.rejectedSteps;
        if index < numel(config.timeStepsS)
            stride = round(config.timeStepsS(index) / config.timeStepsS(end));
            compare = result.temperatureK(:, baseNetwork.roles.response);
            referenceOnCoarseGrid = refTemp(1:stride:end);
            if numel(compare) == numel(referenceOnCoarseGrid)
                row.temperature_rmse_vs_7p5s = sqrt(mean((compare - referenceOnCoarseGrid).^2));
            end
            row.peak_lag_change_vs_7p5s = signed_difference(row.peak_lag_s, ...
                results{end}.metrics.forcingPeakToResponsePeakLagS);
            row.hysteresis_change_vs_7p5s = signed_difference(row.hysteresis_area_wk, ...
                results{end}.metrics.responseHysteresisAreaWK);
        else
            row.temperature_rmse_vs_7p5s = 0;
            row.peak_lag_change_vs_7p5s = 0;
            row.hysteresis_change_vs_7p5s = 0;
        end
        rows(count) = row;
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'numerical_stability.csv'));
end

function temperatureK = quasi_static_temperature(externalW, network, environment, limits)
% Per-epoch algebraic equilibrium with the same sampled node-resolved forcing.
c = leotherm.constants;
nEpoch = size(externalW, 1);
nNode = size(externalW, 2);
laplacian = diag(sum(network.conductanceWK, 2)) - network.conductanceWK;
emission = network.irEmissivity(:) .* c.sigma .* network.radiatingAreaM2(:);
spaceFourth = environment.deepSpaceK^4;
temperatureK = zeros(nEpoch, nNode);
state = network.initialTemperatureK(:);
for k = 1:nEpoch
    state = max(limits.minimumTemperatureK, min(limits.maximumTemperatureK, state));
    for iteration = 1:80
        residual = externalW(k, :)' + network.internalPowerW(:) ...
            - laplacian * state - emission .* (state.^4 - spaceFourth);
        jacobianNegative = laplacian + diag(4 * emission .* state.^3);
        stepK = jacobianNegative \ residual;
        if norm(stepK, inf) < 1e-10 * max(1, norm(state, inf)), break; end
        scale = 1;
        while scale > 1/1024
            candidate = state + scale * stepK;
            candidate = max(limits.minimumTemperatureK, ...
                min(limits.maximumTemperatureK, candidate));
            nextResidual = externalW(k, :)' + network.internalPowerW(:) ...
                - laplacian * candidate - emission .* (candidate.^4 - spaceFourth);
            if norm(nextResidual, inf) <= norm(residual, inf), break; end
            scale = scale / 2;
        end
        state = candidate;
    end
    if iteration == 80 && norm(residual, inf) > 1e-7
        error('leotherm:QuasiStaticFailed', 'No equilibrium at forcing epoch %d.', k);
    end
    temperatureK(k, :) = state';
end
end

function write_forcing(outDir, beta, result)
tableOut = table(result.timeS, sum(result.loads.totalExternalW, 2), ...
    result.loads.visibleFraction, 'VariableNames', ...
    {'time_s','total_external_heat_w','solar_visibility'});
writetable(tableOut, fullfile(outDir, sprintf('forcing_beta_%+03d.csv', beta)));
end

function value = percentile_span(values)
values = sort(values(:));
value = percentile(values, 95) - percentile(values, 5);
end

function value = percentile(values, percentage)
position = 1 + (numel(values) - 1) * percentage / 100;
lo = floor(position); hi = ceil(position);
if lo == hi, value = values(lo); else
    value = values(lo) * (hi - position) + values(hi) * (position - lo);
end
end

function value = signed_difference(a, b)
if isfinite(a) && isfinite(b), value = a - b; else, value = NaN; end
end

function row = emptyStorageRow
row.beta_deg = NaN; row.capacity_factor = NaN; row.case_type = '';
row.temperature_span_k = NaN; row.peak_lag_s = NaN;
row.peak_phase_identifiable = false; row.quasi_static_rms_k = NaN;
row.quasi_static_difference_span_k = NaN; row.periodic_error_k = NaN;
row.convergence_cycles = NaN;
end

function row = emptyNumericalRow
row.beta_deg = NaN; row.time_step_s = NaN; row.temperature_span_k = NaN;
row.peak_lag_s = NaN; row.peak_phase_identifiable = false;
row.signed_peak_phase_s = NaN; row.sampling_resolution_s = NaN;
row.hysteresis_area_wk = NaN; row.periodic_error_k = NaN;
row.accepted_internal_steps = NaN; row.rejected_internal_steps = NaN;
row.temperature_rmse_vs_7p5s = NaN; row.peak_lag_change_vs_7p5s = NaN;
row.hysteresis_change_vs_7p5s = NaN;
end

function write_gap_manifest(outDir, config)
fid = fopen(fullfile(outDir, 'run_manifest.txt'), 'w');
assert(fid >= 0, 'Cannot write manifest.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Study: %s\nVersion: %s\nSeed: %d\n', ...
    config.study, config.version, config.seed);
fprintf(fid, 'No historical paper-1 result is overwritten.\n');
fprintf(fid, 'No missing case or time sample is interpolated.\n');
end
