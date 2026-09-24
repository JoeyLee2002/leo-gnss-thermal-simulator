function metrics = hysteresisLoopMetrics(timeS, forcing, response, periodS)
%HYSTERESISLOOPMETRICS Per-orbit forcing-response loop areas.
% Physical area has units forcing-units times response-units. Normalized area
% scales each complete orbit by its 5-95% span before applying the shoelace rule.

timeS = timeS(:); forcing = forcing(:); response = response(:);
assert(numel(timeS) == numel(forcing) && numel(timeS) == numel(response), ...
    'timeS, forcing, and response must have equal lengths.');
cycleIndex = floor((timeS - timeS(1)) / periodS);
cycles = unique(cycleIndex);
physical = [];
normalized = [];
signedPhysical = [];
for k = 1:numel(cycles)
    select = cycleIndex == cycles(k);
    localTime = timeS(select);
    if numel(localTime) < 8 || localTime(end) - localTime(1) < 0.90 * periodS
        continue
    end
    x = forcing(select);
    y = response(select);
    xSpan = percentile(x, 95) - percentile(x, 5);
    ySpan = percentile(y, 95) - percentile(y, 5);
    signedArea = polygonArea(x, y);
    signedPhysical(end + 1, 1) = signedArea; %#ok<AGROW>
    physical(end + 1, 1) = abs(signedArea); %#ok<AGROW>
    if xSpan > eps(max(abs(x))) && ySpan > eps(max(abs(y)))
        xn = (x - median(x)) / xSpan;
        yn = (y - median(y)) / ySpan;
        normalized(end + 1, 1) = abs(polygonArea(xn, yn)); %#ok<AGROW>
    end
end

metrics.completeCycles = numel(physical);
metrics.areaPhysicalMedian = medianOrNaN(physical);
metrics.areaPhysicalP05 = percentileOrNaN(physical, 5);
metrics.areaPhysicalP95 = percentileOrNaN(physical, 95);
metrics.areaNormalizedMedian = medianOrNaN(normalized);
metrics.areaNormalizedP05 = percentileOrNaN(normalized, 5);
metrics.areaNormalizedP95 = percentileOrNaN(normalized, 95);
metrics.signedAreaPhysicalMedian = medianOrNaN(signedPhysical);
end

function area = polygonArea(x, y)
x = x(:); y = y(:);
xNext = [x(2:end); x(1)];
yNext = [y(2:end); y(1)];
area = 0.5 * sum(x .* yNext - xNext .* y);
end

function value = medianOrNaN(values)
if isempty(values)
    value = NaN;
else
    value = median(values);
end
end

function value = percentileOrNaN(values, percentage)
if isempty(values)
    value = NaN;
else
    value = percentile(values, percentage);
end
end

function value = percentile(values, percentage)
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

