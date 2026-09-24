function summary = runUncertaintyEnsemble(scenario, baseNetwork, nSamples, seed, ranges)
%RUNUNCERTAINTYENSEMBLE Toolbox-free stratified thermal-parameter ensemble.
% ranges fields are fractional half-ranges for capacity, conductance, power,
% absorptivity, and emissivity. All samples are reproducible from seed.

if nargin < 5 || isempty(ranges)
    ranges.capacity = 0.20;
    ranges.conductance = 0.30;
    ranges.power = 0.20;
    ranges.absorptivity = 0.12;
    ranges.emissivity = 0.08;
end
if ~isnumeric(nSamples) || ~isscalar(nSamples) || ~isfinite(nSamples) ...
        || nSamples < 1 || nSamples ~= floor(nSamples)
    error('leotherm:InvalidEnsembleInput', ...
        'nSamples must be one positive integer.');
end
if ~isnumeric(seed) || ~isscalar(seed) || ~isfinite(seed) ...
        || seed < 0 || seed ~= floor(seed)
    error('leotherm:InvalidEnsembleInput', ...
        'seed must be one nonnegative integer.');
end
if ~isstruct(ranges) || ~isscalar(ranges)
    error('leotherm:InvalidEnsembleInput', ...
        'ranges must be a scalar structure.');
end
fields = {'capacity', 'conductance', 'power', 'absorptivity', 'emissivity'};
for k = 1:numel(fields)
    name = fields{k};
    if ~isfield(ranges, name)
        error('leotherm:InvalidEnsembleInput', 'ranges.%s is required.', name);
    end
    value = ranges.(name);
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) ...
            || value < 0 || value >= 1
        error('leotherm:InvalidEnsembleInput', ...
            'Each uncertainty half-range must be one value in [0, 1).');
    end
end

unit = stratifiedSamples(nSamples, numel(fields), seed);
rows = cell(nSamples, 1);
for sample = 1:nSamples
    factors = 1 + (2 * unit(sample, :) - 1) .* [ ...
        ranges.capacity, ranges.conductance, ranges.power, ...
        ranges.absorptivity, ranges.emissivity];
    network = perturbNetwork(baseNetwork, factors);
    row.sample = sample;
    row.seed = seed;
    row.capacity_factor = factors(1);
    row.conductance_factor = factors(2);
    row.power_factor = factors(3);
    row.absorptivity_factor = factors(4);
    row.emissivity_factor = factors(5);
    try
        result = leotherm.simulateScenario(scenario, network);
        m = result.metrics;
        row.status = {'complete'};
        row.beta_deg = m.meanBetaDeg;
        row.eclipse_fraction = m.eclipseFraction;
        row.rf_temperature_span_k = m.rfTemperatureSpanK;
        row.oscillator_temperature_span_k = m.oscillatorTemperatureSpanK;
        row.response_peak_lag_s = m.forcingPeakToResponsePeakLagS;
        row.response_trough_lag_s = m.forcingTroughToResponseTroughLagS;
        row.rf_lag_s = m.forcingToRfLagS;
        row.entry_cooling_lag_s = m.eclipseEntryCoolingLagS;
        row.exit_heating_lag_s = m.eclipseExitHeatingLagS;
        row.rf_hysteresis_area_wk = m.rfHysteresisAreaWK;
        row.rf_normalized_hysteresis_area = m.rfNormalizedHysteresisArea;
        row.periodic_error_k = result.convergence.periodicErrorK;
        row.convergence_cycles = result.convergence.cycles;
    catch exception
        row.status = {['failed: ' exception.identifier]};
        row.beta_deg = NaN;
        row.eclipse_fraction = NaN;
        row.rf_temperature_span_k = NaN;
        row.oscillator_temperature_span_k = NaN;
        row.response_peak_lag_s = NaN;
        row.response_trough_lag_s = NaN;
        row.rf_lag_s = NaN;
        row.entry_cooling_lag_s = NaN;
        row.exit_heating_lag_s = NaN;
        row.rf_hysteresis_area_wk = NaN;
        row.rf_normalized_hysteresis_area = NaN;
        row.periodic_error_k = NaN;
        row.convergence_cycles = NaN;
    end
    rows{sample} = row;
end
summary = struct2table(vertcat(rows{:}));
end

function samples = stratifiedSamples(nSamples, nParameters, seed)
previous = rng;
cleanup = onCleanup(@() rng(previous));
rng(seed, 'twister');
samples = zeros(nSamples, nParameters);
for parameter = 1:nParameters
    values = ((0:nSamples-1)' + rand(nSamples, 1)) / nSamples;
    samples(:, parameter) = values(randperm(nSamples));
end
end

function network = perturbNetwork(base, factors)
network = base;
network.capacityJK = base.capacityJK * factors(1);
network.conductanceWK = base.conductanceWK * factors(2);
network.internalPowerW = base.internalPowerW * factors(3);
network.solarAbsorptivity = min(max( ...
    base.solarAbsorptivity * factors(4), 0), 1);
network.irEmissivity = min(max(base.irEmissivity * factors(5), 0), 1);
network.name = sprintf('%s_uq', base.name);
leotherm.validateNetwork(network);
end
