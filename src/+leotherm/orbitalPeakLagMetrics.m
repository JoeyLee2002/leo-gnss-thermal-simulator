function metrics = orbitalPeakLagMetrics(timeS, forcing, response, periodS)
%ORBITALPEAKLAGMETRICS Per-orbit peak-to-next-peak and trough lags.
% A modulo-period difference makes the event definition explicit and avoids
% phase aliases from unrestricted cross-correlation of multi-harmonic signals.

timeS = timeS(:);
forcing = forcing(:);
response = response(:);
assert(numel(timeS) == numel(forcing) && numel(timeS) == numel(response), ...
    'timeS, forcing, and response must have equal lengths.');
validateattributes(timeS,{'numeric'},{'real','finite','increasing','nonempty'});
validateattributes(periodS,{'numeric'},{'real','finite','scalar','positive'});
cycleIndex = floor((timeS - timeS(1)) / periodS);
cycles = unique(cycleIndex);
peakLagS = [];
troughLagS = [];
signedLagS = []; rejected = 0; complete = 0;
for k = 1:numel(cycles)
    select = cycleIndex == cycles(k);
    localTime = timeS(select);
    if numel(localTime) < 8 || localTime(end) - localTime(1) < 0.90 * periodS
        continue
    end
    complete = complete + 1;
    localForcing = forcing(select);
    localResponse = response(select);
    if any(~isfinite(localForcing)) || any(~isfinite(localResponse)) ...
            || max(diff(localTime)) > 2.5*median(diff(localTime)) ...
            || ~varying(localForcing) || ~varying(localResponse)
        rejected = rejected + 1;
        continue
    end
    [~, forcingPeak] = max(localForcing);
    [~, responsePeak] = max(localResponse);
    [~, forcingTrough] = min(localForcing);
    [~, responseTrough] = min(localResponse);
    signed = mod(localTime(responsePeak)-localTime(forcingPeak)+periodS/2,periodS)-periodS/2;
    signedLagS(end+1,1) = signed; %#ok<AGROW>
    peak = signed;
    trough = mod(localTime(responseTrough)-localTime(forcingTrough)+periodS/2,periodS)-periodS/2;
    if peak < 0 || ~uniqueExtremum(localForcing,'max') || ~uniqueExtremum(localResponse,'max')
        peak = NaN;
    end
    if trough < 0 || ~uniqueExtremum(localForcing,'min') || ~uniqueExtremum(localResponse,'min')
        trough = NaN;
    end
    if isnan(peak), rejected = rejected + 1; end
    peakLagS(end+1,1) = peak; %#ok<AGROW>
    troughLagS(end+1,1) = trough; %#ok<AGROW>
end
metrics.completeCycles = complete;
metrics.identifiablePeakCycles = sum(isfinite(peakLagS));
metrics.rejectedPeakCycles = rejected;
metrics.signedPeakPhaseMedianS = medianOrNaN(signedLagS);
metrics.identifiable = metrics.identifiablePeakCycles > 0;
metrics.definition = 'sampled_nonnegative_peak_phase_not_a_thermal_time_constant';
metrics.status = 'identified_phase_only';
if ~metrics.identifiable, metrics.status = 'not_identifiable_or_phase_ambiguous'; end
metrics.samplingResolutionS = NaN;
if numel(timeS)>1, metrics.samplingResolutionS = median(diff(timeS)); end
metrics.peakToPeakLagMedianS = medianOrNaN(peakLagS);
metrics.peakToPeakLagP05S = percentileOrNaN(peakLagS, 5);
metrics.peakToPeakLagP95S = percentileOrNaN(peakLagS, 95);
metrics.troughToTroughLagMedianS = medianOrNaN(troughLagS);
metrics.troughToTroughLagP05S = percentileOrNaN(troughLagS, 5);
metrics.troughToTroughLagP95S = percentileOrNaN(troughLagS, 95);
end

function value = medianOrNaN(values)
values = values(isfinite(values));
if isempty(values)
    value = NaN;
else
    value = median(values);
end
end

function value = percentileOrNaN(values, percentage)
values = values(isfinite(values));
if isempty(values)
    value = NaN;
    return
end

values = sort(values(:));
position = 1 + (numel(values) - 1) * percentage / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = values(lowerIndex);
else
    fraction = position - lowerIndex;
    value = values(lowerIndex) * (1 - fraction) + values(upperIndex) * fraction;
end
end

function yes = varying(values)
yes = max(values)-min(values) > max(1e-8,1e-6*max(abs(values)));
end

function yes = uniqueExtremum(values,mode)
if strcmp(mode,'max'), extreme = max(values); else, extreme = min(values); end
at = find(abs(values-extreme) <= max(1e-12,1e-9*(max(values)-min(values))));
% Permit two adjacent samples around one extremum, not plateaus or repeated peaks.
yes = numel(at) == 1 || (numel(at) == 2 && diff(at) == 1);
end
