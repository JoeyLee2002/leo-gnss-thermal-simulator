function outputs = run_paper1_experiments(profile)
%RUN_PAPER1_EXPERIMENTS Run or resume all experiments for paper 1.

if nargin < 1
    profile = 'paper';
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root, 'src'));
addpath(fileparts(mfilename('fullpath')));
config = paper1_config(profile);
outDir = config.outputDirectory;
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
save(fullfile(outDir, 'paper1_config.mat'), 'config');
writeManifest(fullfile(outDir, 'run_manifest.txt'), config);

network = leotherm.symmetricReceiverNetwork;
exp1Cases = buildExperiment1(config);
outputs.experiment1 = executeCases(exp1Cases, config, network, outDir, 'experiment1');

exp2Cases = buildExperiment2(config);
outputs.experiment2 = executeCases(exp2Cases, config, network, outDir, 'experiment2');

exp3Cases = buildExperiment3(config);
outputs.experiment3 = executeCases(exp3Cases, config, network, outDir, 'experiment3');
outputs.experiment3Pairs = makeSignedBetaPairs(outputs.experiment3);
writetable(outputs.experiment3Pairs, ...
    fullfile(outDir, 'experiment3_signed_beta_pairs.csv'));

outputs.uncertainty = runUncertainty(config, network, outDir);
save(fullfile(outDir, 'paper1_results.mat'), 'outputs', 'config', '-v7.3');
safeProgress('Paper-1 results written to %s\n', outDir);
end

function cases = buildExperiment1(config)
settings = config.experiment1;
n = numel(settings.altitudeKm) * numel(settings.betaDeg);
cases = repmat(emptyCase, n, 1);
index = 0;
for altitude = settings.altitudeKm
    for beta = settings.betaDeg
        index = index + 1;
        cases(index) = emptyCase;
        cases(index).caseId = sprintf('E1_h%04g_b%+05.1f', altitude, beta);
        cases(index).experiment = 'altitude_absolute_beta';
        cases(index).epoch = settings.epoch;
        cases(index).altitudeKm = altitude;
        cases(index).inclinationDeg = settings.inclinationDeg;
        cases(index).targetBetaDeg = beta;
        cases(index).branch = settings.branch;
        cases(index).mechanism = 'symmetric';
    end
end
end

function cases = buildExperiment2(config)
settings = config.experiment2;
n = numel(settings.dates) * numel(settings.inclinationDeg) * numel(settings.raanDeg);
cases = repmat(emptyCase, n, 1);
index = 0;
for dateIndex = 1:numel(settings.dates)
    for inclination = settings.inclinationDeg
        for raan = settings.raanDeg
            index = index + 1;
            cases(index) = emptyCase;
            cases(index).caseId = sprintf('E2_m%02d_i%04.1f_r%03g', ...
                month(settings.dates(dateIndex)), inclination, raan);
            cases(index).experiment = 'physical_accessibility';
            cases(index).epoch = settings.dates(dateIndex);
            cases(index).altitudeKm = settings.altitudeKm;
            cases(index).inclinationDeg = inclination;
            cases(index).raanDeg = raan;
            cases(index).mechanism = 'symmetric';
        end
    end
end
end

function cases = buildExperiment3(config)
settings = config.experiment3;
variants = settings.variants;
n = 2 * numel(settings.absBetaDeg) * height(variants);
cases = repmat(emptyCase, n, 1);
index = 0;
for absoluteBeta = settings.absBetaDeg
    for signValue = [-1, 1]
        for variant = 1:height(variants)
            index = index + 1;
            cases(index) = emptyCase;
            mechanism = variants.mechanism{variant};
            level = variants.network_level(variant);
            pitch = variants.attitude_pitch_deg(variant);
            roll = variants.attitude_roll_deg(variant);
            cases(index).caseId = sprintf('E3_b%+05.1f_%s_l%03d_p%02d_r%02d', ...
                signValue * absoluteBeta, mechanism, round(100 * level), ...
                round(pitch), round(roll));
            cases(index).experiment = 'signed_beta_symmetry_breaking';
            cases(index).epoch = settings.epoch;
            cases(index).altitudeKm = settings.altitudeKm;
            cases(index).inclinationDeg = settings.inclinationDeg;
            cases(index).targetBetaDeg = signValue * absoluteBeta;
            cases(index).branch = settings.branch;
            cases(index).mechanism = mechanism;
            cases(index).networkLevel = level;
            cases(index).attitudePitchDeg = pitch;
            cases(index).attitudeRollDeg = roll;
        end
    end
end
end

function cases = emptyCase
cases.caseId = '';
cases.experiment = '';
cases.epoch = NaT(1, 1, 'TimeZone', 'UTC');
cases.altitudeKm = NaN;
cases.inclinationDeg = NaN;
cases.raanDeg = NaN;
cases.targetBetaDeg = NaN;
cases.branch = 1;
cases.mechanism = 'symmetric';
cases.networkLevel = 0;
cases.attitudePitchDeg = 0;
cases.attitudeRollDeg = 0;
end

function tableOut = executeCases(cases, config, baseNetwork, outDir, label)
checkpointPath = fullfile(outDir, ['checkpoint_' label '.mat']);
rows = repmat(emptyRow, numel(cases), 1);
done = false(numel(cases), 1);
caseIds = {cases.caseId}';
if exist(checkpointPath, 'file')
    saved = load(checkpointPath, 'rows', 'caseIds', 'softwareVersion', 'profile');
    compatible = isequal(saved.caseIds, caseIds) ...
        && strcmp(saved.softwareVersion, config.softwareVersion) ...
        && strcmp(saved.profile, config.profile);
    assert(compatible, 'Existing %s is incompatible with this configuration.', checkpointPath);
    rows = saved.rows;
    done = strcmp({rows.status}', 'complete') | strcmp({rows.status}', 'inaccessible');
end

for index = 1:numel(cases)
    if done(index)
        continue
    end
    safeProgress('[%s] %d/%d %s\n', ...
        label, index, numel(cases), cases(index).caseId);
    rows(index) = runOneCase(cases(index), config.baseScenario, baseNetwork);
    done(index) = true;
    if mod(index, config.checkpointEvery) == 0 || index == numel(cases)
        softwareVersion = config.softwareVersion;
        profile = config.profile;
        save(checkpointPath, 'rows', 'caseIds', 'softwareVersion', 'profile');
    end
end
tableOut = struct2table(rows);
writetable(tableOut, fullfile(outDir, [label '.csv']));
end

function row = runOneCase(caseConfig, baseScenario, baseNetwork)
row = emptyRow;
row.case_id = caseConfig.caseId;
row.experiment = caseConfig.experiment;
row.epoch_utc = [datestr(caseConfig.epoch, 'yyyy-mm-ddTHH:MM:SS') 'Z'];
row.altitude_km = caseConfig.altitudeKm;
row.inclination_deg = caseConfig.inclinationDeg;
row.target_beta_deg = caseConfig.targetBetaDeg;
row.mechanism = caseConfig.mechanism;
row.network_level = caseConfig.networkLevel;
row.attitude_pitch_deg = caseConfig.attitudePitchDeg;
row.attitude_roll_deg = caseConfig.attitudeRollDeg;

scenario = baseScenario;
scenario.startEpoch = caseConfig.epoch;
scenario.orbit.altitudeM = caseConfig.altitudeKm * 1000;
scenario.orbit.inclinationDeg = caseConfig.inclinationDeg;
scenario.attitude.eulerOffsetDeg = [caseConfig.attitudeRollDeg, ...
    caseConfig.attitudePitchDeg, 0];
if ismember(caseConfig.experiment, ...
        {'altitude_absolute_beta', 'signed_beta_symmetry_breaking'})
    scenario.orbit.useJ2 = false;
    scenario.environment.freezeSunAtEpoch = true;
end
if isfinite(caseConfig.targetBetaDeg)
    [raan, accessible] = leotherm.solveRaanForBeta(caseConfig.epoch, ...
        caseConfig.inclinationDeg, caseConfig.targetBetaDeg, caseConfig.branch);
    if ~accessible
        row.status = 'inaccessible';
        row.message = 'Target signed beta is inaccessible for this epoch and inclination.';
        return
    end
    scenario.orbit.raanDeg = raan;
else
    scenario.orbit.raanDeg = caseConfig.raanDeg;
end
row.raan_deg = scenario.orbit.raanDeg;
scenario.name = caseConfig.caseId;

network = baseNetwork;
if ~ismember(caseConfig.mechanism, ...
        {'symmetric', 'attitude_pitch', 'attitude_roll'})
    network = leotherm.applyThermalAsymmetry( ...
        baseNetwork, caseConfig.mechanism, caseConfig.networkLevel);
end
try
    result = leotherm.simulateScenario(scenario, network);
    m = result.metrics;
    response = network.roles.response;
    row.status = 'complete';
    row.actual_beta_deg = m.meanBetaDeg;
    row.minimum_beta_deg = m.minimumBetaDeg;
    row.maximum_beta_deg = m.maximumBetaDeg;
    row.eclipse_fraction = m.eclipseFraction;
    row.umbra_fraction = m.umbraFraction;
    row.eclipse_transitions = m.eclipseTransitionCount;
    row.absorbed_heat_span_w = m.totalAbsorbedHeatSpanW;
    row.response_temperature_mean_k = mean(result.temperatureK(:, response));
    row.response_temperature_span_k = m.responseTemperatureSpanK;
    row.response_temperature_minimum_k = min(result.temperatureK(:, response));
    row.response_temperature_maximum_k = max(result.temperatureK(:, response));
    row.forcing_peak_to_response_peak_lag_s = ...
        m.forcingPeakToResponsePeakLagS;
    row.forcing_trough_to_response_trough_lag_s = ...
        m.forcingTroughToResponseTroughLagS;
    row.eclipse_entry_to_temperature_minimum_s = ...
        m.eclipseEntryToTemperatureMinimumS;
    row.eclipse_exit_to_temperature_maximum_s = ...
        m.eclipseExitToTemperatureMaximumS;
    row.response_hysteresis_area_wk = m.responseHysteresisAreaWK;
    row.response_normalized_hysteresis_area = m.responseNormalizedHysteresisArea;
    row.complete_hysteresis_cycles = m.hysteresisCompleteCycles;
    row.periodic_error_k = result.convergence.periodicErrorK;
    row.convergence_cycles = result.convergence.cycles;
catch exception
    row.status = 'failed';
    row.message = sprintf('%s: %s', exception.identifier, exception.message);
end
end

function row = emptyRow
row.case_id = '';
row.experiment = '';
row.status = 'pending';
row.message = '';
row.epoch_utc = '';
row.mechanism = '';
numeric = {'altitude_km', 'inclination_deg', 'raan_deg', 'target_beta_deg', ...
    'actual_beta_deg', 'minimum_beta_deg', 'maximum_beta_deg', ...
    'network_level', 'attitude_pitch_deg', 'attitude_roll_deg', ...
    'eclipse_fraction', ...
    'umbra_fraction', 'eclipse_transitions', 'absorbed_heat_span_w', ...
    'response_temperature_mean_k', 'response_temperature_span_k', ...
    'response_temperature_minimum_k', 'response_temperature_maximum_k', ...
    'forcing_peak_to_response_peak_lag_s', ...
    'forcing_trough_to_response_trough_lag_s', ...
    'eclipse_entry_to_temperature_minimum_s', ...
    'eclipse_exit_to_temperature_maximum_s', ...
    'response_hysteresis_area_wk', ...
    'response_normalized_hysteresis_area', 'complete_hysteresis_cycles', ...
    'periodic_error_k', 'convergence_cycles'};
for k = 1:numel(numeric)
    row.(numeric{k}) = NaN;
end
end

function pairs = makeSignedBetaPairs(rows)
complete = rows(strcmp(rows.status, 'complete'), :);
positive = complete(complete.target_beta_deg > 0, :);
pairRows = cell(height(positive), 1);
count = 0;
for index = 1:height(positive)
    match = complete.target_beta_deg == -positive.target_beta_deg(index) ...
        & strcmp(complete.mechanism, positive.mechanism(index)) ...
        & complete.network_level == positive.network_level(index) ...
        & complete.attitude_pitch_deg == positive.attitude_pitch_deg(index) ...
        & complete.attitude_roll_deg == positive.attitude_roll_deg(index);
    negative = complete(match, :);
    if height(negative) ~= 1
        continue
    end
    count = count + 1;
    row.abs_beta_deg = positive.target_beta_deg(index);
    row.mechanism = positive.mechanism(index);
    row.network_level = positive.network_level(index);
    row.attitude_pitch_deg = positive.attitude_pitch_deg(index);
    row.attitude_roll_deg = positive.attitude_roll_deg(index);
    fields = {'eclipse_fraction', 'response_temperature_span_k', ...
        'forcing_peak_to_response_peak_lag_s', ...
        'response_hysteresis_area_wk', ...
        'response_normalized_hysteresis_area'};
    for fieldIndex = 1:numel(fields)
        name = fields{fieldIndex};
        plus = positive.(name)(index);
        minus = negative.(name)(1);
        row.([name '_positive']) = plus;
        row.([name '_negative']) = minus;
        row.([name '_difference']) = plus - minus;
        denominator = 0.5 * (abs(plus) + abs(minus));
        if denominator > 0
            row.([name '_asymmetry']) = (plus - minus) / denominator;
        else
            row.([name '_asymmetry']) = 0;
        end
    end
    pairRows{count} = row;
end
if count == 0
    pairs = table;
else
    pairs = struct2table(vertcat(pairRows{1:count}));
end
end

function summary = runUncertainty(config, network, outDir)
settings = config.uncertainty;
tables = cell(numel(settings.betaDeg), 1);
for index = 1:numel(settings.betaDeg)
    target = settings.betaDeg(index);
    file = fullfile(outDir, sprintf('uncertainty_beta_%02d.csv', round(target)));
    if exist(file, 'file')
        tables{index} = readtable(file);
        continue
    end
    scenario = config.baseScenario;
    scenario.name = sprintf('UQ_beta_%g', target);
    scenario.startEpoch = settings.epoch;
    scenario.orbit.altitudeM = settings.altitudeKm * 1000;
    scenario.orbit.inclinationDeg = settings.inclinationDeg;
    scenario.orbit.useJ2 = false;
    scenario.environment.freezeSunAtEpoch = true;
    [raan, accessible] = leotherm.solveRaanForBeta( ...
        settings.epoch, settings.inclinationDeg, target, 1);
    assert(accessible, 'Configured uncertainty beta angle is inaccessible.');
    scenario.orbit.raanDeg = raan;
    % Reuse identical parameter samples across beta regimes for paired tests.
    seed = config.seed;
    tableNow = leotherm.runUncertaintyEnsemble(scenario, network, ...
        settings.samplesPerRegime, seed, settings.samples);
    tableNow.target_beta_deg = repmat(target, height(tableNow), 1);
    writetable(tableNow, file);
    tables{index} = tableNow;
end
summary = vertcat(tables{:});
writetable(summary, fullfile(outDir, 'uncertainty_all.csv'));
end

function writeManifest(path, config)
file = fopen(path, 'w');
assert(file >= 0, 'Cannot create run manifest: %s', path);
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'Study: %s\n', config.study);
fprintf(file, 'Software version: %s\n', config.softwareVersion);
fprintf(file, 'Profile: %s\n', config.profile);
fprintf(file, 'Random seed: %d\n', config.seed);
fprintf(file, 'Generated UTC: %s\n', datestr(datetime('now', 'TimeZone', 'UTC'), 31));
fprintf(file, 'No interpolation is performed. Failed and inaccessible cases retain status.\n');
end

function safeProgress(format, varargin)
try
    fprintf(format, varargin{:});
catch
    % Progress output must never terminate a long-running scientific batch.
end
end
