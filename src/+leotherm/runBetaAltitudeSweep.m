function summary = runBetaAltitudeSweep(baseScenario, network, altitudeKm, targetBetaDeg, branch, progress)
%RUNBETAALTITUDESWEEP Controlled altitude-beta parameter study.

if nargin < 5
    branch = 1;
end
if nargin<6, progress=[]; end
if ~isempty(progress) && ~isa(progress,'function_handle'), error('leotherm:InvalidSweepInput','Progress must be a callback.'); end
cancelled=false;
leotherm.validateScenario(baseScenario);
leotherm.validateNetwork(network);
if ~isnumeric(altitudeKm) || isempty(altitudeKm) ...
        || any(~isfinite(altitudeKm)) || any(altitudeKm <= 0)
    error('leotherm:InvalidSweepInput', ...
        'altitudeKm must contain finite positive values.');
end
if ~isnumeric(targetBetaDeg) || isempty(targetBetaDeg) ...
        || any(~isfinite(targetBetaDeg)) ...
        || any(targetBetaDeg < -90 | targetBetaDeg > 90)
    error('leotherm:InvalidSweepInput', ...
        'targetBetaDeg must contain finite values in [-90, 90].');
end
if ~isscalar(branch) || ~(branch == 1 || branch == 2)
    error('leotherm:InvalidSweepInput', 'branch must be 1 or 2.');
end
rows = cell(numel(altitudeKm) * numel(targetBetaDeg), 1);
index = 0;
for a = 1:numel(altitudeKm)
    for b = 1:numel(targetBetaDeg)
        index = index + 1;
        altitude = altitudeKm(a);
        target = targetBetaDeg(b);
        if ~cancelled && ~isempty(progress), cancelled=logical(progress(index-1,numel(rows))); end
        if cancelled
            rows{index}=makeRow(altitude,target,NaN,false,[],'cancelled','Cancelled before this case started.');
            continue
        end
        [raan, accessible] = leotherm.solveRaanForBeta( ...
            baseScenario.startEpoch, baseScenario.orbit.inclinationDeg, target, branch);
        if ~accessible
            rows{index} = makeRow(altitude, target, NaN, false, [], ...
                'inaccessible', 'Target beta is inaccessible at this epoch and inclination.');
            continue
        end
        scenario = baseScenario;
        scenario.name = sprintf('h%04gkm_beta%+05.1f', altitude, target);
        scenario.orbit.altitudeM = altitude * 1000;
        scenario.orbit.raanDeg = raan;
        try
            result = leotherm.simulateScenario(scenario, network);
            rows{index} = makeRow(altitude, target, raan, true, result, ...
                'complete', '');
        catch exception
            rows{index} = makeRow(altitude, target, raan, true, [], 'failed', ...
                exceptionSummary(exception));
        end
    end
end
summary = struct2table(vertcat(rows{:}));
if ~cancelled && ~isempty(progress), progress(numel(rows),numel(rows)); end
end

function row = makeRow(altitude, target, raan, accessible, result, status, message)
row.altitude_km = altitude;
row.target_beta_deg = target;
row.raan_deg = raan;
row.accessible = accessible;
row.status = {status};
row.message = {message};
names = {'actual_beta_deg', 'eclipse_fraction', 'umbra_fraction', ...
    'response_temperature_span_k', ...
    'antenna_temperature_span_k', 'rf_temperature_span_k', ...
    'oscillator_temperature_span_k', 'code_bias_span_m', 'code_bias_rms_m', ...
    'forcing_to_rf_lag_s', 'forcing_to_code_bias_lag_s', ...
    'eclipse_entry_cooling_lag_s', 'eclipse_exit_heating_lag_s', ...
    'eclipse_transition_count', 'rf_hysteresis_area_wk', ...
    'response_hysteresis_area_wk', 'response_normalized_hysteresis_area', ...
    'rf_normalized_hysteresis_area', 'oscillator_hysteresis_area_wk', ...
    'oscillator_normalized_hysteresis_area', 'periodic_error_k', ...
    'convergence_cycles'};
for k = 1:numel(names)
    row.(names{k}) = NaN;
end
if isempty(result)
    return
end
metrics = result.metrics;
row.actual_beta_deg = metrics.meanBetaDeg;
row.eclipse_fraction = metrics.eclipseFraction;
row.umbra_fraction = metrics.umbraFraction;
row.response_temperature_span_k = metrics.responseTemperatureSpanK;
row.antenna_temperature_span_k = metrics.antennaTemperatureSpanK;
row.rf_temperature_span_k = metrics.rfTemperatureSpanK;
row.oscillator_temperature_span_k = metrics.oscillatorTemperatureSpanK;
row.code_bias_span_m = metrics.codeBiasSpanM;
row.code_bias_rms_m = metrics.codeBiasRmsM;
row.forcing_to_rf_lag_s = metrics.forcingToRfLagS;
row.forcing_to_code_bias_lag_s = metrics.forcingToCodeBiasLagS;
row.eclipse_entry_cooling_lag_s = metrics.eclipseEntryCoolingLagS;
row.eclipse_exit_heating_lag_s = metrics.eclipseExitHeatingLagS;
row.eclipse_transition_count = metrics.eclipseTransitionCount;
row.rf_hysteresis_area_wk = metrics.rfHysteresisAreaWK;
row.response_hysteresis_area_wk = metrics.responseHysteresisAreaWK;
row.response_normalized_hysteresis_area = metrics.responseNormalizedHysteresisArea;
row.rf_normalized_hysteresis_area = metrics.rfNormalizedHysteresisArea;
row.oscillator_hysteresis_area_wk = metrics.oscillatorHysteresisAreaWK;
row.oscillator_normalized_hysteresis_area = metrics.oscillatorNormalizedHysteresisArea;
row.periodic_error_k = result.convergence.periodicErrorK;
row.convergence_cycles = result.convergence.cycles;
end

function value = exceptionSummary(exception)
if isempty(exception.identifier)
    value = exception.message;
else
    value = sprintf('%s: %s', exception.identifier, exception.message);
end
end
