function lagS = positivePhaseLag(timeS, forcing, response, periodS)
%POSITIVEPHASELAG Positive forcing-response lag within half a period.
% Restricting the search to [0, period/2] prevents a one-cycle alias from
% being reported as thermal lag for approximately periodic orbital forcing.

timeS = timeS(:);
forcing = forcing(:);
response = response(:);
assert(numel(timeS) == numel(forcing) && numel(timeS) == numel(response), ...
    'timeS, forcing, and response must have equal lengths.');
assert(all(diff(timeS) > 0), 'timeS must be strictly increasing.');
assert(isscalar(periodS) && isfinite(periodS) && periodS > 0, ...
    'periodS must be a positive finite scalar.');

dt = median(diff(timeS));
x = forcing - mean(forcing);
y = response - mean(response);
maxLag = min(numel(x) - 2, floor(0.5 * periodS / dt));
if maxLag < 0 || norm(x) == 0 || norm(y) == 0
    lagS = NaN;
    return
end
score = -inf(maxLag + 1, 1);
for lag = 0:maxLag
    if lag == 0
        left = x;
        right = y;
    else
        left = x(1:end-lag);
        right = y(1+lag:end);
    end
    denominator = norm(left) * norm(right);
    if denominator > 0
        score(lag + 1) = dot(left, right) / denominator;
    end
end
[~, index] = max(score);
lagS = (index - 1) * dt;
end
