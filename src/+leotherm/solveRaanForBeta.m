function [raanDeg, accessible] = solveRaanForBeta(epoch, inclinationDeg, targetBetaDeg, branch)
%SOLVERAANFORBETA Solve RAAN that reaches a signed beta at one epoch.

if nargin < 4
    branch = 1;
end
assert(branch == 1 || branch == 2, 'branch must be 1 or 2.');

sun = leotherm.solarVectorECI(epoch);
sun = sun ./ norm(sun);
i = deg2rad(inclinationDeg);
a = sin(i) * sun(1);
b = -sin(i) * sun(2);
c = cos(i) * sun(3);
radius = hypot(a, b);
rhs = (sind(targetBetaDeg) - c) / radius;
accessible = isfinite(rhs) && abs(rhs) <= 1 + 1e-12;
if ~accessible
    raanDeg = NaN;
    return
end
rhs = min(max(rhs, -1), 1);
phase = atan2(b, a);
if branch == 1
    omega = asin(rhs) - phase;
else
    omega = pi - asin(rhs) - phase;
end
raanDeg = mod(rad2deg(omega), 360);
end

