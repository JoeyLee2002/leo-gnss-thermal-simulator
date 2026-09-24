function outputs = run_paper1_core_experiments(profile)
%RUN_PAPER1_CORE_EXPERIMENTS Generate the focused experiment set for paper 1.
% The study is organized around a single causal chain:
% orbital geometry -> node-resolved forcing -> thermal storage/pathways.
% All mechanism comparisons reuse the same sampled forcing for a case.
% Historical paper-1 CSV files are never overwritten.

if nargin < 1 || isempty(profile), profile = 'paper'; end
assert(ismember(lower(char(profile)), {'paper', 'smoke'}), ...
    'profile must be paper or smoke.');
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'src'));
config = core_config(root, profile);
outDir = config.outputDirectory;
if ~exist(outDir, 'dir'), mkdir(outDir); end
write_manifest(outDir, config);

network = leotherm.symmetricReceiverNetwork;
outputs = struct;
outputs.environmentEnvelope = run_environment_envelope(config, network, outDir);
[forcingCases, forcingData] = prepare_forcing_cases(config, network, outDir);
outputs.forcingCases = forcingCases;
outputs.storage = run_storage_experiment(config, network, forcingData, outDir);
outputs.modelComparison = run_model_comparison(config, network, forcingData, outDir);
outputs.pathAblation = run_path_ablation(config, network, forcingData, outDir);
outputs.numericalStability = run_numerical_stability(config, network, forcingData, outDir);
outputs.uncertaintyGeneralization = run_uncertainty_generalization(config, network, forcingData, outDir);
save(fullfile(outDir, 'paper1_core_experiments.mat'), 'outputs', 'config', '-v7.3');
fprintf('Focused paper-1 experiments written to %s\n', outDir);
end

function config = core_config(root, profile)
config.softwareVersion = strtrim(fileread(fullfile(root, 'VERSION')));
config.profile = lower(char(profile));
config.study = 'paper1_focused_causal_chain';
config.seed = 20260915;
config.outputDirectory = fullfile(root, 'results', ...
    ['paper1_core_v' strrep(config.softwareVersion, '.', '_') '_' config.profile]);
config.epoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
config.environmentDates = datetime(2024, [3, 6, 9, 12], 20, 12, 0, 0, 'TimeZone', 'UTC');
config.environmentInclinationsDeg = [30, 50, 70, 90, 97.6];
config.environmentRaanDeg = 0:30:330;
config.environmentAltitudesKm = [400, 500, 600, 800, 1000];
config.environmentBetasDeg = [0, 20, 40, 60, 70];
[altitudeGrid, betaGrid] = ndgrid(config.environmentAltitudesKm, config.environmentBetasDeg);
config.forcingCases = [altitudeGrid(:), betaGrid(:)];
config.storageFactors = [0.05, 0.25, 1, 4, 16];
config.pathFactors = [0.25, 0.5, 1, 2, 4];
config.numericalCaseIndex = [2, 7, 13, 18, 22, 25];
config.numericalStepsS = [30, 15, 7.5];
config.windowCycles = [1, 2, 3];
config.uncertaintySamples = 20;
config.uncertaintyLogStd = struct('capacity', 0.20, 'conductance', 0.30, ...
    'power', 0.20, 'absorptivity', 0.12, 'emissivity', 0.08);

base = leotherm.defaultScenario;
base.name = 'paper1_focused_reference';
base.startEpoch = config.epoch;
base.durationS = 6 * 3600;
base.timeStepS = config.numericalStepsS(1);
base.orbit.altitudeM = 600e3;
base.orbit.inclinationDeg = 90;
base.orbit.argumentLatitudeDeg = 0;
base.orbit.useJ2 = false;
base.attitude.mode = 'nadir';
base.attitude.eulerOffsetDeg = [0, 0, 0];
base.environment.freezeSunAtEpoch = true;
base.convergence.minimumCycles = 5;
base.convergence.maximumCycles = 400;
base.convergence.requiredStableCycles = 2;
base.convergence.toleranceK = 5e-3;
base.convergence.failOnNonConvergence = true;
config.baseScenario = base;
if strcmpi(config.profile, 'smoke')
    config.environmentDates = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
    config.environmentInclinationsDeg = 90;
    config.environmentRaanDeg = [0, 120];
    config.environmentAltitudesKm = 600;
    config.environmentBetasDeg = [0, 30];
    config.forcingCases = [600, 0; 600, 30];
    config.storageFactors = [0.25, 1];
    config.pathFactors = [0.5, 1.5];
    config.numericalCaseIndex = [1, 2];
    config.numericalStepsS = [30, 15];
    config.windowCycles = [1, 2];
    config.uncertaintySamples = 2;
    config.baseScenario.convergence.maximumCycles = 80;
end
end

function summary = run_environment_envelope(config, network, outDir)
rows = repmat(emptyEnvelopeRow, numel(config.environmentAltitudesKm) * ...
    numel(config.environmentDates) * numel(config.environmentInclinationsDeg) * ...
    numel(config.environmentRaanDeg), 1);
count = 0;
for altitude = config.environmentAltitudesKm
    for epoch = config.environmentDates
        for inclination = config.environmentInclinationsDeg
            for raan = config.environmentRaanDeg
        count = count + 1;
        scenario = config.baseScenario;
        scenario.name = sprintf('paper1_env_%s_i%g_o%g', datestr(epoch, 'yyyymmdd'), inclination, raan);
        scenario.startEpoch = epoch;
        scenario.orbit.inclinationDeg = inclination;
        scenario.orbit.raanDeg = raan;
        scenario.orbit.altitudeM = altitude * 1000;
        scenario.orbit.useJ2 = true;
        scenario.environment.freezeSunAtEpoch = false;
        scenario.timeStepS = config.numericalStepsS(1);
        result = leotherm.simulateScenario(scenario, network);
        row = emptyEnvelopeRow;
        row.case_id = sprintf('ENV_h%04d_%s_i%05.1f_o%03d', altitude, datestr(epoch, 'yyyymmdd'), inclination, raan);
        row.epoch_utc = datestr(epoch, 'yyyy-mm-ddTHH:MM:SS');
        row.inclination_deg = inclination;
        row.raan_deg = raan;
        row.altitude_km = altitude;
        row.target_beta_deg = NaN;
        row.actual_beta_deg = result.metrics.meanBetaDeg;
        row.eclipse_fraction = result.metrics.eclipseFraction;
        row.temperature_span_k = result.metrics.responseTemperatureSpanK;
        row.hysteresis_area_wk = result.metrics.responseHysteresisAreaWK;
        row.peak_lag_s = result.metrics.forcingPeakToResponsePeakLagS;
        row.peak_identifiable = result.metrics.peakPhaseIdentifiable;
        row.periodic_error_k = result.convergence.periodicErrorK;
        row.status = 'complete';
        rows(count) = row;
            end
        end
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment2_forcing_envelope.csv'));
end

function [summary, cases] = prepare_forcing_cases(config, network, outDir)
nCase = size(config.forcingCases, 1);
summary = repmat(emptyCaseRow, nCase, 1);
cases = repmat(struct('id', '', 'altitudeKm', NaN, 'betaDeg', NaN, ...
    'scenario', struct, 'timeS', [], 'forcingW', [], 'orbit', struct, ...
    'environment', struct, 'baseline', struct), nCase, 1);
for k = 1:nCase
    altitude = config.forcingCases(k, 1);
    beta = config.forcingCases(k, 2);
    scenario = makeScenario(config, altitude, beta, config.numericalStepsS(1));
    baseline = leotherm.simulateScenario(scenario, network);
    id = sprintf('FORCE_h%04d_b%+03d', altitude, beta);
    cases(k).id = id;
    cases(k).altitudeKm = altitude;
    cases(k).betaDeg = beta;
    cases(k).scenario = scenario;
    cases(k).timeS = baseline.timeS;
    cases(k).forcingW = baseline.loads.totalExternalW;
    cases(k).orbit = baseline.orbit;
    cases(k).environment = scenario.environment;
    cases(k).baseline = baseline;
    forcingTable = array2table([baseline.timeS, baseline.loads.totalExternalW], ...
        'VariableNames', [{'time_s'}, arrayfun(@(j) sprintf('node_%02d_w', j), ...
        1:size(baseline.loads.totalExternalW, 2), 'UniformOutput', false)]);
    writetable(forcingTable, fullfile(outDir, [id '_forcing.csv']));

    row = emptyCaseRow;
    row.case_id = id;
    row.altitude_km = altitude;
    row.beta_deg = beta;
    row.actual_beta_deg = baseline.metrics.meanBetaDeg;
    row.eclipse_fraction = baseline.metrics.eclipseFraction;
    row.temperature_span_k = baseline.metrics.responseTemperatureSpanK;
    row.periodic_error_k = baseline.convergence.periodicErrorK;
    summary(k) = row;
end
writetable(struct2table(summary), fullfile(outDir, 'forcing_case_manifest.csv'));
end

function summary = run_storage_experiment(config, baseNetwork, cases, outDir)
rows = repmat(emptyStorageRow, numel(cases) * (numel(config.storageFactors) + 1), 1);
count = 0;
for c = 1:numel(cases)
    forcing = cases(c);
    quasi = quasiStaticTemperature(forcing.forcingW, baseNetwork, forcing.environment, ...
        forcing.scenario.integration);
    for factor = [NaN, config.storageFactors]
        count = count + 1;
        row = emptyStorageRow;
        row.case_id = forcing.id;
        row.capacity_factor = factor;
        row.case_type = 'dynamic';
        response = baseNetwork.roles.response;
        if isnan(factor)
            row.case_type = 'quasi_static_reference';
            row.temperature_span_k = percentileSpan(quasi(:, response));
            row.dynamic_quasi_static_rms_k = NaN;
            row.periodic_error_k = NaN;
            row.convergence_cycles = NaN;
        else
            network = baseNetwork;
            network.capacityJK = baseNetwork.capacityJK * factor;
            [result, state] = solveFixedForcing(forcing, network, config);
            row.temperature_span_k = percentileSpan(result.temperatureK(:, response));
            row.dynamic_quasi_static_rms_k = sqrt(mean((result.temperatureK(:, response) - ...
                quasi(:, response)).^2));
            row.quasi_static_difference_span_k = percentileSpan(result.temperatureK(:, response) - ...
                quasi(:, response));
            row.peak_lag_s = result.peakLagS;
            row.peak_identifiable = result.peakIdentifiable;
            row.periodic_error_k = state.periodicErrorK;
            row.convergence_cycles = state.cycles;
        end
        rows(count) = row;
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment1_storage_mechanism.csv'));
end

function summary = run_model_comparison(config, baseNetwork, cases, outDir)
rows = repmat(emptyModelRow, numel(cases) * 3, 1);
count = 0;
for c = 1:numel(cases)
    forcing = cases(c);
    [reference, ~] = solveFixedForcing(forcing, baseNetwork, config);
    models = {'one_node', 'two_node', 'eleven_node'};
    for m = 1:numel(models)
        count = count + 1;
        model = models{m};
        if strcmp(model, 'eleven_node')
            result = reference;
            modelResponse = baseNetwork.roles.response;
        else
            [modelNetwork, modelForcing] = aggregateNetwork(baseNetwork, forcing.forcingW, model);
            [result, state] = solveFixedForcing(forcing, modelNetwork, config, modelForcing);
            modelResponse = size(result.temperatureK, 2);
        end
        row = emptyModelRow;
        row.case_id = forcing.id;
        row.model = model;
        row.temperature_span_k = percentileSpan(result.temperatureK(:, modelResponse));
        row.rmse_vs_eleven_node_k = sqrt(mean((result.temperatureK(:, modelResponse) - ...
            reference.temperatureK(:, baseNetwork.roles.response)).^2));
        row.peak_lag_s = result.peakLagS;
        row.peak_identifiable = result.peakIdentifiable;
        if strcmp(model, 'eleven_node')
            row.convergence_cycles = NaN;
        else
            row.convergence_cycles = state.cycles;
        end
        rows(count) = row;
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment3_model_complexity.csv'));
end

function summary = run_path_ablation(config, baseNetwork, cases, outDir)
modes = {'rf_capacity', 'structure_rf_conductance', 'rf_oscillator_conductance'};
rows = repmat(emptyAblationRow, numel(cases) * numel(modes) * ...
    numel(config.pathFactors), 1);
count = 0;
for c = 1:numel(cases)
    forcing = cases(c);
    [reference, ~] = solveFixedForcing(forcing, baseNetwork, config);
    refSpan = percentileSpan(reference.temperatureK(:, baseNetwork.roles.response));
    for modeIndex = 1:numel(modes)
        for factor = config.pathFactors
            count = count + 1;
            network = baseNetwork;
            switch modes{modeIndex}
                case 'rf_capacity'
                    network.capacityJK(9) = baseNetwork.capacityJK(9) * factor;
                case 'structure_rf_conductance'
                    network.conductanceWK(7, 9) = baseNetwork.conductanceWK(7, 9) * factor;
                    network.conductanceWK(9, 7) = network.conductanceWK(7, 9);
                case 'rf_oscillator_conductance'
                    network.conductanceWK(9, 10) = baseNetwork.conductanceWK(9, 10) * factor;
                    network.conductanceWK(10, 9) = network.conductanceWK(9, 10);
            end
            [result, state] = solveFixedForcing(forcing, network, config);
            row = emptyAblationRow;
            row.case_id = forcing.id;
            row.mode = modes{modeIndex};
            row.factor = factor;
            row.temperature_span_k = percentileSpan(result.temperatureK(:, 9));
            row.span_change_k = row.temperature_span_k - refSpan;
            row.rmse_vs_baseline_k = sqrt(mean((result.temperatureK(:, 9) - ...
                reference.temperatureK(:, 9)).^2));
            row.peak_lag_s = result.peakLagS;
            row.peak_identifiable = result.peakIdentifiable;
            row.periodic_error_k = state.periodicErrorK;
            rows(count) = row;
        end
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment4_path_ablation.csv'));
end

function summary = run_numerical_stability(config, baseNetwork, cases, outDir)
rows = repmat(emptyNumericalRow, numel(config.numericalCaseIndex) * ...
    numel(config.numericalStepsS) * numel(config.windowCycles), 1);
count = 0;
for index = config.numericalCaseIndex
    forcing = cases(index);
    for step = config.numericalStepsS
        scenario = forcing.scenario;
        scenario.timeStepS = step;
        [raan, accessible] = leotherm.solveRaanForBeta(scenario.startEpoch, ...
            scenario.orbit.inclinationDeg, forcing.betaDeg, 1);
        assert(accessible, 'Numerical case is inaccessible.');
        scenario.orbit.raanDeg = raan;
        baseline = leotherm.simulateScenario(scenario, baseNetwork);
        for nCycles = config.windowCycles
            count = count + 1;
            row = emptyNumericalRow;
            row.case_id = forcing.id;
            row.time_step_s = step;
            row.window_cycles = nCycles;
            row.temperature_span_k = baseline.metrics.responseTemperatureSpanK;
            row.hysteresis_area_wk = baseline.metrics.responseHysteresisAreaWK;
            row.peak_lag_s = baseline.metrics.forcingPeakToResponsePeakLagS;
            row.peak_identifiable = baseline.metrics.peakPhaseIdentifiable;
            row.periodic_error_k = baseline.convergence.periodicErrorK;
            tEnd = min(nCycles * baseline.orbit.periodS, baseline.timeS(end));
            keep = baseline.timeS <= tEnd + 1e-9;
            if sum(keep) >= 8
                lag = leotherm.orbitalPeakLagMetrics(baseline.timeS(keep), ...
                    sum(baseline.loads.totalExternalW(keep, :), 2), ...
                    baseline.temperatureK(keep, baseNetwork.roles.response), ...
                    baseline.orbit.periodS);
                loop = leotherm.hysteresisLoopMetrics(baseline.timeS(keep), ...
                    sum(baseline.loads.totalExternalW(keep, :), 2), ...
                    baseline.temperatureK(keep, baseNetwork.roles.response), ...
                    baseline.orbit.periodS);
                row.window_peak_lag_s = lag.peakToPeakLagMedianS;
                row.window_peak_identifiable = lag.identifiable;
                row.window_hysteresis_area_wk = loop.areaPhysicalMedian;
            end
            rows(count) = row;
        end
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment5_numerical_stability.csv'));
end

function summary = run_uncertainty_generalization(config, baseNetwork, cases, outDir)
% Paired network perturbations are reused across all fixed-forcing cases.
% They test conclusion stability, not a confidence interval over satellites.
rng(config.seed, 'twister');
nSample = config.uncertaintySamples;
z = randn(nSample, 5);
rows = repmat(emptyUncertaintyRow, numel(cases) * nSample, 1);
count = 0;
for c = 1:numel(cases)
    forcing = cases(c);
    [reference, ~] = solveFixedForcing(forcing, baseNetwork, config);
    refSpan = percentileSpan(reference.temperatureK(:, baseNetwork.roles.response));
    for s = 1:nSample
        network = baseNetwork;
        factors = exp(z(s,:) .* [config.uncertaintyLogStd.capacity, ...
            config.uncertaintyLogStd.conductance, config.uncertaintyLogStd.power, ...
            config.uncertaintyLogStd.absorptivity, config.uncertaintyLogStd.emissivity]);
        network.capacityJK = baseNetwork.capacityJK * factors(1);
        network.conductanceWK = baseNetwork.conductanceWK * factors(2);
        network.internalPowerW = baseNetwork.internalPowerW * factors(3);
        network.solarAbsorptivity = min(0.98, baseNetwork.solarAbsorptivity * factors(4));
        network.irEmissivity = min(0.98, max(0.05, baseNetwork.irEmissivity * factors(5)));
        [result, state] = solveFixedForcing(forcing, network, config);
        count = count + 1;
        row = emptyUncertaintyRow;
        row.case_id = forcing.id;
        row.sample_id = s;
        row.capacity_factor = factors(1);
        row.conductance_factor = factors(2);
        row.power_factor = factors(3);
        row.absorptivity_factor = factors(4);
        row.emissivity_factor = factors(5);
        row.temperature_span_k = percentileSpan(result.temperatureK(:, 9));
        row.span_change_k = row.temperature_span_k - refSpan;
        row.rmse_vs_baseline_k = sqrt(mean((result.temperatureK(:, 9) - reference.temperatureK(:, 9)).^2));
        row.periodic_error_k = state.periodicErrorK;
        row.status = 'complete';
        rows(count) = row;
    end
end
summary = struct2table(rows);
writetable(summary, fullfile(outDir, 'experiment6_uncertainty_generalization.csv'));
end

function scenario = makeScenario(config, altitudeKm, betaDeg, step)
scenario = config.baseScenario;
scenario.name = sprintf('paper1_h%04d_b%+03d_step_%g', altitudeKm, betaDeg, step);
scenario.timeStepS = step;
scenario.orbit.altitudeM = altitudeKm * 1000;
[raan, accessible] = leotherm.solveRaanForBeta(config.epoch, ...
    scenario.orbit.inclinationDeg, betaDeg, 1);
assert(accessible, 'Requested beta is inaccessible.');
scenario.orbit.raanDeg = raan;
end

function [result, state] = solveFixedForcing(caseData, network, config, suppliedForcing)
if nargin < 4 || isempty(suppliedForcing), suppliedForcing = caseData.forcingW; end
timeS = caseData.timeS;
if size(suppliedForcing, 1) ~= numel(timeS)
    error('paper1:ForcingLength', 'Supplied forcing does not match the case time grid.');
end
periodS = caseData.baseline.orbit.periodS;
cycleEnd = find(timeS <= periodS + 1e-9, 1, 'last');
if isempty(cycleEnd) || timeS(cycleEnd) - timeS(1) < 0.90 * periodS
    error('paper1:IncompleteForcing', 'Case does not contain one accepted forcing cycle.');
end
cycleTime = timeS(1:cycleEnd);
cycleForcing = suppliedForcing(1:cycleEnd, :);
cycleForcing(end, :) = cycleForcing(1, :);
stateVector = network.initialTemperatureK(:);
stable = 0; errorK = Inf;
for cycles = 1:config.baseScenario.convergence.maximumCycles
    work = network;
    work.initialTemperatureK = stateVector;
    cycleTemperature = leotherm.solveThermalNetwork(cycleTime, cycleForcing, ...
        work, caseData.environment, caseData.scenario.integration);
    nextState = cycleTemperature(end, :)';
    errorK = max(abs(nextState - stateVector));
    stateVector = nextState;
    if cycles >= config.baseScenario.convergence.minimumCycles && ...
            errorK <= config.baseScenario.convergence.toleranceK
        stable = stable + 1;
    else
        stable = 0;
    end
    if stable >= config.baseScenario.convergence.requiredStableCycles, break; end
end
if stable < config.baseScenario.convergence.requiredStableCycles
    error('paper1:FixedForcingNotConverged', ...
        'Fixed-forcing periodic initialization failed for %s.', caseData.id);
end
work = network;
work.initialTemperatureK = stateVector;
temperature = leotherm.solveThermalNetwork(timeS, suppliedForcing, work, ...
    caseData.environment, caseData.scenario.integration);
response = temperature(:, end);
forcing = sum(suppliedForcing, 2);
lag = leotherm.orbitalPeakLagMetrics(timeS, forcing, response, periodS);
result.temperatureK = temperature;
result.peakLagS = lag.peakToPeakLagMedianS;
result.peakIdentifiable = lag.identifiable;
state.periodicErrorK = errorK;
state.cycles = cycles;
end

function [network, forcing] = aggregateNetwork(baseNetwork, externalW, model)
if strcmp(model, 'one_node')
    groups = {1:11};
else
    groups = {1:8, 9:11};
end
n = numel(groups);
network = baseNetwork;
network.name = ['aggregate_' model];
network.nodeNames = arrayfun(@(i) sprintf('%s_node_%d', model, i), 1:n, 'UniformOutput', false)';
network.capacityJK = zeros(n,1); network.initialTemperatureK = zeros(n,1);
network.internalPowerW = zeros(n,1); network.projectedAreaM2 = zeros(n,1);
network.radiatingAreaM2 = zeros(n,1); network.normalBody = zeros(n,3);
network.solarAbsorptivity = zeros(n,1); network.irEmissivity = zeros(n,1);
network.conductanceWK = zeros(n); network.bias.linearMPerK = zeros(n,1);
network.bias.quadraticNode = 1; network.bias.quadraticMPerK2 = 0;
network.roles.response = n; network.roles.antenna = []; network.roles.oscillator = [];
forcing = zeros(size(externalW,1), n);
for i = 1:n
    g = groups{i};
    network.capacityJK(i) = sum(baseNetwork.capacityJK(g));
    network.initialTemperatureK(i) = mean(baseNetwork.initialTemperatureK(g));
    network.internalPowerW(i) = sum(baseNetwork.internalPowerW(g));
    network.projectedAreaM2(i) = sum(baseNetwork.projectedAreaM2(g));
    network.radiatingAreaM2(i) = sum(baseNetwork.radiatingAreaM2(g));
    network.normalBody(i,:) = [1,0,0];
    area = baseNetwork.radiatingAreaM2(g);
    if sum(area) > 0
        network.irEmissivity(i) = sum(area .* baseNetwork.irEmissivity(g)) / sum(area);
    else
        network.irEmissivity(i) = 0.8;
    end
    area = baseNetwork.projectedAreaM2(g);
    if sum(area) > 0
        network.solarAbsorptivity(i) = sum(area .* baseNetwork.solarAbsorptivity(g)) / sum(area);
    else
        network.solarAbsorptivity(i) = 0.5;
    end
    forcing(:,i) = sum(externalW(:,g),2);
end
for i = 1:n
    for j = (i+1):n
        edge = baseNetwork.conductanceWK(groups{i}, groups{j});
        value = sum(edge(:));
        network.conductanceWK(i,j) = value;
        network.conductanceWK(j,i) = value;
    end
end
leotherm.validateNetwork(network);
end

function temperatureK = quasiStaticTemperature(externalW, network, environment, limits)
c = leotherm.constants;
nEpoch = size(externalW, 1); nNode = size(externalW, 2);
laplacian = diag(sum(network.conductanceWK, 2)) - network.conductanceWK;
emission = network.irEmissivity(:) .* c.sigma .* network.radiatingAreaM2(:);
spaceFourth = environment.deepSpaceK^4;
temperatureK = zeros(nEpoch, nNode);
state = network.initialTemperatureK(:);
for k = 1:nEpoch
    state = max(limits.minimumTemperatureK, min(limits.maximumTemperatureK, state));
    for iteration = 1:80
        residual = externalW(k,:)' + network.internalPowerW(:) - laplacian*state - ...
            emission .* (state.^4 - spaceFourth);
        jacobian = laplacian + diag(4*emission.*state.^3);
        stepK = jacobian \ residual;
        if norm(stepK, inf) < 1e-10*max(1,norm(state,inf)), break; end
        scale = 1;
        while scale > 1/1024
            candidate = max(limits.minimumTemperatureK, min(limits.maximumTemperatureK, state + scale*stepK));
            nextResidual = externalW(k,:)' + network.internalPowerW(:) - laplacian*candidate - ...
                emission .* (candidate.^4 - spaceFourth);
            if norm(nextResidual, inf) <= norm(residual, inf), break; end
            scale = scale / 2;
        end
        state = candidate;
    end
    if iteration == 80 && norm(residual, inf) > 1e-7
        error('paper1:QuasiStaticFailed', 'Quasi-static equilibrium failed at epoch %d.', k);
    end
    temperatureK(k,:) = state';
end
end

function write_manifest(outDir, config)
fid = fopen(fullfile(outDir, 'run_manifest.txt'), 'w');
assert(fid >= 0, 'Cannot write manifest.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'Study: %s\nVersion: %s\nSeed: %d\n', config.study, config.softwareVersion, config.seed);
fprintf(fid, 'Environment envelope: %d altitude-date-inclination-RAAN cases.\n', ...
    numel(config.environmentAltitudesKm) * numel(config.environmentDates) * ...
    numel(config.environmentInclinationsDeg) * numel(config.environmentRaanDeg));
fprintf(fid, 'Fixed-forcing cases: %d.\n', size(config.forcingCases,1));
fprintf(fid, 'No historical paper-1 result is overwritten.\n');
clear cleanup
fprintf(fid, 'No missing case or time sample is interpolated.\n');
end

function value = percentileSpan(x)
x = sort(x(:)); value = percentile(x,95) - percentile(x,5);
end
function value = percentile(x,p)
position = 1 + (numel(x)-1)*p/100; lo=floor(position); hi=ceil(position);
if lo == hi, value=x(lo); else, value=x(lo)*(hi-position)+x(hi)*(position-lo); end
end

function row = emptyEnvelopeRow
row = struct('case_id','','epoch_utc','','inclination_deg',NaN,'raan_deg',NaN, ...
    'altitude_km',NaN,'target_beta_deg',NaN,'actual_beta_deg',NaN, ...
    'eclipse_fraction',NaN,'temperature_span_k',NaN,'hysteresis_area_wk',NaN, ...
    'peak_lag_s',NaN,'peak_identifiable',false,'periodic_error_k',NaN,'status','');
end
function row = emptyUncertaintyRow
row = struct('case_id','','sample_id',NaN,'capacity_factor',NaN,'conductance_factor',NaN, ...
    'power_factor',NaN,'absorptivity_factor',NaN,'emissivity_factor',NaN, ...
    'temperature_span_k',NaN,'span_change_k',NaN,'rmse_vs_baseline_k',NaN, ...
    'periodic_error_k',NaN,'status','');
end
function row = emptyCaseRow
row = struct('case_id','','altitude_km',NaN,'beta_deg',NaN,'actual_beta_deg',NaN, ...
    'eclipse_fraction',NaN,'temperature_span_k',NaN,'periodic_error_k',NaN);
end
function row = emptyStorageRow
row = struct('case_id','','capacity_factor',NaN,'case_type','','temperature_span_k',NaN, ...
    'dynamic_quasi_static_rms_k',NaN,'quasi_static_difference_span_k',NaN,'peak_lag_s',NaN, ...
    'peak_identifiable',false,'periodic_error_k',NaN,'convergence_cycles',NaN);
end
function row = emptyModelRow
row = struct('case_id','','model','','temperature_span_k',NaN,'rmse_vs_eleven_node_k',NaN, ...
    'peak_lag_s',NaN,'peak_identifiable',false,'convergence_cycles',NaN);
end
function row = emptyAblationRow
row = struct('case_id','','mode','','factor',NaN,'temperature_span_k',NaN,'span_change_k',NaN, ...
    'rmse_vs_baseline_k',NaN,'peak_lag_s',NaN,'peak_identifiable',false,'periodic_error_k',NaN);
end
function row = emptyNumericalRow
row = struct('case_id','','time_step_s',NaN,'window_cycles',NaN,'temperature_span_k',NaN, ...
    'hysteresis_area_wk',NaN,'peak_lag_s',NaN,'peak_identifiable',false,'periodic_error_k',NaN, ...
    'window_peak_lag_s',NaN,'window_peak_identifiable',false,'window_hysteresis_area_wk',NaN);
end
