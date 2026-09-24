function sunPositionM = solarVectorECI(epoch)
%SOLARVECTORECI Approximate geocentric Sun position in mean equatorial axes.
% Accuracy is appropriate for orbit-thermal trade studies, not navigation.

if isempty(epoch.TimeZone)
    epoch.TimeZone = 'UTC';
end
jd = juliandate(epoch);
d = jd - 2451545.0;
meanLongitude = deg2rad(mod(280.460 + 0.9856474 .* d, 360));
meanAnomaly = deg2rad(mod(357.528 + 0.9856003 .* d, 360));
eclipticLongitude = meanLongitude + deg2rad(1.915) .* sin(meanAnomaly) ...
    + deg2rad(0.020) .* sin(2 .* meanAnomaly);
obliquity = deg2rad(23.439291 - 0.0000004 .* d);

c = leotherm.constants;
distanceAU = 1.00014 - 0.01671 .* cos(meanAnomaly) ...
    - 0.00014 .* cos(2 .* meanAnomaly);
sunPositionM = c.astronomicalUnit .* distanceAU(:) .* [ ...
    cos(eclipticLongitude(:)), ...
    cos(obliquity(:)) .* sin(eclipticLongitude(:)), ...
    sin(obliquity(:)) .* sin(eclipticLongitude(:))];
end

