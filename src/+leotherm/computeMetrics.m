function metrics = computeMetrics(timeS, orbit, loads, temperatureK, codeBiasM, network)
%COMPUTEMETRICS Summarize geometry, thermal response, lag, and code bias.

response = resolveNode(network, 'response', 'gnss_rf_frontend');
osc = resolveNode(network, 'oscillator', 'gnss_oscillator');
antenna = resolveNode(network, 'antenna', 'gnss_antenna');
forcing = sum(loads.totalExternalW, 2);
responseLoop = leotherm.hysteresisLoopMetrics( ...
    timeS, forcing, temperatureK(:, response), orbit.periodS);
responsePeakLag = leotherm.orbitalPeakLagMetrics( ...
    timeS, forcing, temperatureK(:, response), orbit.periodS);
oscillatorLoop = emptyLoopMetrics;
if ~isempty(osc)
    oscillatorLoop = leotherm.hysteresisLoopMetrics( ...
        timeS, forcing, temperatureK(:, osc), orbit.periodS);
end

metrics = struct;
metrics.meanBetaDeg = mean(orbit.betaDeg);
metrics.minimumBetaDeg = min(orbit.betaDeg);
metrics.maximumBetaDeg = max(orbit.betaDeg);
metrics.eclipseFraction = mean(loads.visibleFraction < 0.999);
metrics.umbraFraction = mean(loads.visibleFraction <= 0.001);
metrics.penumbraEpochs = sum(loads.visibleFraction > 0.001 & loads.visibleFraction < 0.999);
metrics.antennaTemperatureSpanK = nodeSpan(temperatureK, antenna);
metrics.responseTemperatureSpanK = nodeSpan(temperatureK, response);
metrics.rfTemperatureSpanK = metrics.responseTemperatureSpanK;
metrics.oscillatorTemperatureSpanK = nodeSpan(temperatureK, osc);
metrics.codeBiasSpanM = percentileSpan(codeBiasM);
metrics.codeBiasRmsM = sqrt(mean((codeBiasM - mean(codeBiasM)).^2));
metrics.totalAbsorbedHeatSpanW = percentileSpan(forcing);
metrics.forcingPeakToResponsePeakLagS = responsePeakLag.peakToPeakLagMedianS;
metrics.peakPhaseIdentifiable = responsePeakLag.identifiable;
metrics.peakPhaseIdentifiableCycles = responsePeakLag.identifiablePeakCycles;
metrics.signedPeakPhaseMedianS = responsePeakLag.signedPeakPhaseMedianS;
metrics.peakPhaseSamplingResolutionS = responsePeakLag.samplingResolutionS;
metrics.forcingTroughToResponseTroughLagS = responsePeakLag.troughToTroughLagMedianS;
metrics.forcingToResponseLagS = metrics.forcingPeakToResponsePeakLagS;
metrics.forcingToRfLagS = metrics.forcingToResponseLagS;
codeBiasPeakLag = leotherm.orbitalPeakLagMetrics( ...
    timeS, forcing, codeBiasM, orbit.periodS);
metrics.forcingToCodeBiasLagS = codeBiasPeakLag.peakToPeakLagMedianS;
[metrics.eclipseEntryToTemperatureMinimumS, ...
    metrics.eclipseExitToTemperatureMaximumS, ...
    metrics.eclipseTransitionCount] = transitionLags(timeS, loads.visibleFraction, ...
    temperatureK(:, response), orbit.periodS);
metrics.eclipseEntryCoolingLagS = metrics.eclipseEntryToTemperatureMinimumS;
metrics.eclipseExitHeatingLagS = metrics.eclipseExitToTemperatureMaximumS;
metrics.responseHysteresisAreaWK = responseLoop.areaPhysicalMedian;
metrics.responseNormalizedHysteresisArea = responseLoop.areaNormalizedMedian;
metrics.rfHysteresisAreaWK = metrics.responseHysteresisAreaWK;
metrics.rfNormalizedHysteresisArea = metrics.responseNormalizedHysteresisArea;
metrics.oscillatorHysteresisAreaWK = oscillatorLoop.areaPhysicalMedian;
metrics.oscillatorNormalizedHysteresisArea = oscillatorLoop.areaNormalizedMedian;
metrics.hysteresisCompleteCycles = responseLoop.completeCycles;
end

function index = resolveNode(network, role, legacyName)
index = [];
if isfield(network, 'roles') && isfield(network.roles, role)
    index = network.roles.(role);
end
if isempty(index)
    index = find(strcmp(network.nodeNames, legacyName), 1);
end
if strcmp(role, 'response') && isempty(index)
    error('leotherm:MissingResponseNode', ...
        'The network must define roles.response or a gnss_rf_frontend node.');
end
end

function value = nodeSpan(temperatureK, index)
if isempty(index)
    value = NaN;
else
    value = percentileSpan(temperatureK(:, index));
end
end

function metrics = emptyLoopMetrics
metrics.areaPhysicalMedian = NaN;
metrics.areaNormalizedMedian = NaN;
end

function value = percentileSpan(x)
value = percentile(x, 95) - percentile(x, 5);
end

function value = percentile(x, percentage)
x = sort(x(:));
position = 1 + (numel(x) - 1) * percentage / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = x(lowerIndex);
else
    fraction = position - lowerIndex;
    value = x(lowerIndex) * (1 - fraction) + x(upperIndex) * fraction;
end
end

function [entryLagS, exitLagS, count] = transitionLags(timeS, visible, temperatureK, periodS)
sunlit = visible >= 0.5;
entry = find(diff(sunlit) == -1) + 1;
exit = find(diff(sunlit) == 1) + 1;
windowS = 0.95 * periodS;
entryValues = eventExtremaLag(timeS, temperatureK, entry, windowS, 'minimum');
exitValues = eventExtremaLag(timeS, temperatureK, exit, windowS, 'maximum');
entryLagS = medianOrNaN(entryValues);
exitLagS = medianOrNaN(exitValues);
count = min(numel(entry), numel(exit));
end

function values = eventExtremaLag(timeS, rate, indices, windowS, mode)
values = [];
for k = 1:numel(indices)
    first = indices(k);
    last = find(timeS <= timeS(first) + windowS, 1, 'last');
    if isempty(last) || last <= first
        continue
    end
    if timeS(end) < timeS(first)+windowS || ...
            max(rate(first:last))-min(rate(first:last)) <= max(1e-8,1e-6*max(abs(rate(first:last))))
        continue
    end
    if strcmp(mode, 'minimum')
        [~, local] = min(rate(first:last));
    else
        [~, local] = max(rate(first:last));
    end
    event = first + local - 1;
    if event == first || event == last, continue; end
    values(end + 1, 1) = timeS(event) - timeS(first); %#ok<AGROW>
end
end

function value = medianOrNaN(values)
if isempty(values)
    value = NaN;
else
    value = median(values);
end
end
