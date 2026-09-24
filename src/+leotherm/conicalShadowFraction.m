function visible = conicalShadowFraction(positionM, sunPositionM)
%CONICALSHADOWFRACTION Visible solar-disk fraction in [0, 1].

c = leotherm.constants;
toSun = sunPositionM - positionM;
toEarth = -positionM;
sunDistance = vecnorm(toSun, 2, 2);
earthDistance = vecnorm(toEarth, 2, 2);
sunRadius = asin(min(c.radiusSun ./ sunDistance, 1));
earthRadius = asin(min(c.radiusEarth ./ earthDistance, 1));
cosSeparation = sum(toSun .* toEarth, 2) ./ (sunDistance .* earthDistance);
separation = acos(min(max(cosSeparation, -1), 1));

visible = ones(size(separation));
full = separation <= max(earthRadius - sunRadius, 0);
visible(full) = 0;
partial = ~full & separation < (earthRadius + sunRadius);

if any(partial)
    d = separation(partial);
    rs = sunRadius(partial);
    re = earthRadius(partial);
    xs = min(max((d.^2 + rs.^2 - re.^2) ./ (2 .* d .* rs), -1), 1);
    xe = min(max((d.^2 + re.^2 - rs.^2) ./ (2 .* d .* re), -1), 1);
    radicand = max((-d + rs + re) .* (d + rs - re) .* ...
        (d - rs + re) .* (d + rs + re), 0);
    overlap = rs.^2 .* acos(xs) + re.^2 .* acos(xe) ...
        - 0.5 .* sqrt(radicand);
    visible(partial) = 1 - overlap ./ (pi .* rs.^2);
end
visible = min(max(visible, 0), 1);
end
