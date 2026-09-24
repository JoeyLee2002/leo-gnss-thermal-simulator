function orbit = propagateCircularOrbit(epoch, elapsedS, config)
%PROPAGATECIRCULARORBIT Circular ECI orbit with optional secular J2 rates.

c = leotherm.constants;
a = c.radiusEarth + config.altitudeM;
i = deg2rad(config.inclinationDeg);
raan0 = deg2rad(config.raanDeg);
u0 = deg2rad(config.argumentLatitudeDeg);
n = sqrt(c.muEarth / a^3);

if config.useJ2
    factor = c.j2Earth * n * (c.radiusEarth / a)^2;
    raanRate = -1.5 * factor * cos(i);
    perigeeRate = 0.75 * factor * (5 * cos(i)^2 - 1);
else
    raanRate = 0.0;
    perigeeRate = 0.0;
end
uRate = n + perigeeRate;

t = elapsedS(:);
raan = raan0 + raanRate .* t;
u = u0 + uRate .* t;
cu = cos(u); su = sin(u); co = cos(raan); so = sin(raan);

positionM = a .* [ ...
    co .* cu - so .* su .* cos(i), ...
    so .* cu + co .* su .* cos(i), ...
    su .* sin(i)];

relativeVelocity = a * uRate .* [ ...
    co .* (-su) - so .* cu .* cos(i), ...
    so .* (-su) + co .* cu .* cos(i), ...
    cu .* sin(i)];
frameVelocity = raanRate .* cross(repmat([0, 0, 1], numel(t), 1), positionM, 2);
velocityMps = relativeVelocity + frameVelocity;

epochColumn = epoch + seconds(t);
sunPositionM = leotherm.solarVectorECI(epochColumn);
normal = rowNormalize(cross(positionM, velocityMps, 2));
sunDirection = rowNormalize(sunPositionM - positionM);
betaDeg = rad2deg(asin(clamp(sum(normal .* sunDirection, 2), -1, 1)));

orbit.epoch = epochColumn;
orbit.elapsedS = t;
orbit.positionM = positionM;
orbit.velocityMps = velocityMps;
orbit.sunPositionM = sunPositionM;
orbit.betaDeg = betaDeg;
orbit.periodS = 2 * pi / n;
orbit.raanDeg = rad2deg(raan);
end

function out = rowNormalize(in)
out = in ./ vecnorm(in, 2, 2);
end

function out = clamp(in, low, high)
out = min(max(in, low), high);
end

