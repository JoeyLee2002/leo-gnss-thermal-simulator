function summary = runPhysicalSweep(baseScenario, network, dates, altitudeKm, inclinationDeg, raanDeg, progress)
%RUNPHYSICALSWEEP Sweep physical date/inclination/RAAN combinations.
if nargin<7, progress=[]; end
if ~isempty(progress) && ~isa(progress,'function_handle'), error('leotherm:InvalidSweepInput','Progress must be a callback.'); end
cancelled=false;

leotherm.validateScenario(baseScenario);
leotherm.validateNetwork(network);
if ~isdatetime(dates) || isempty(dates) || any(isnat(dates))
    error('leotherm:InvalidSweepInput', ...
        'dates must contain one or more valid datetime values.');
end
finiteVector(altitudeKm, 'altitudeKm');
if any(altitudeKm <= 0)
    error('leotherm:InvalidSweepInput', 'altitudeKm values must be positive.');
end
finiteVector(inclinationDeg, 'inclinationDeg');
if any(inclinationDeg < 0 | inclinationDeg > 180)
    error('leotherm:InvalidSweepInput', ...
        'inclinationDeg values must lie in [0, 180].');
end
finiteVector(raanDeg, 'raanDeg');

nRows = numel(dates) * numel(altitudeKm) * numel(inclinationDeg) * numel(raanDeg);
rows = cell(nRows, 1);
index = 0;
for d = 1:numel(dates)
    for a = 1:numel(altitudeKm)
        for i = 1:numel(inclinationDeg)
            for r = 1:numel(raanDeg)
                index = index + 1;
                scenario = baseScenario;
                scenario.startEpoch = dates(d);
                scenario.orbit.altitudeM = altitudeKm(a) * 1000;
                scenario.orbit.inclinationDeg = inclinationDeg(i);
                scenario.orbit.raanDeg = raanDeg(r);
                row = struct( ...
                    'epoch', dates(d), ...
                    'altitude_km', altitudeKm(a), ...
                    'inclination_deg', inclinationDeg(i), ...
                    'raan_deg', raanDeg(r), ...
                    'status', {{'pending'}}, ...
                    'message', {{''}}, ...
                    'beta_deg', NaN, ...
                    'eclipse_fraction', NaN, ...
                    'rf_temperature_span_k', NaN, ...
                    'code_bias_span_m', NaN, ...
                    'forcing_to_rf_lag_s', NaN);
                if ~cancelled && ~isempty(progress), cancelled=logical(progress(index-1,nRows)); end
                if cancelled
                    row.status={'cancelled'}; row.message={'Cancelled before this case started.'};
                    rows{index}=row;
                    continue
                end
                try
                    result = leotherm.simulateScenario(scenario, network);
                    m = result.metrics;
                    row.status = {'complete'};
                    row.beta_deg = m.meanBetaDeg;
                    row.eclipse_fraction = m.eclipseFraction;
                    row.rf_temperature_span_k = m.rfTemperatureSpanK;
                    row.code_bias_span_m = m.codeBiasSpanM;
                    row.forcing_to_rf_lag_s = m.forcingToRfLagS;
                catch exception
                    row.status = {'failed'};
                    if isempty(exception.identifier)
                        row.message = {exception.message};
                    else
                        row.message = {sprintf('%s: %s', ...
                            exception.identifier, exception.message)};
                    end
                end
                rows{index} = row;
            end
        end
    end
end
summary = struct2table(vertcat(rows{:}));
if ~cancelled && ~isempty(progress), progress(nRows,nRows); end
end

function finiteVector(value, label)
if ~isnumeric(value) || isempty(value) || ~isvector(value) ...
        || any(~isfinite(value)) || ~isreal(value)
    error('leotherm:InvalidSweepInput', ...
        '%s must contain one or more finite real values.', label);
end
end
