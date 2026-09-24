function frame = bodyFrame(positionM, velocityMps, sunPositionM, attitude)
%BODYFRAME Return body axes expressed in ECI for each epoch.
% frame is N-by-3-by-3; frame(:,axis,:) contains one body-axis unit vector.

nEpoch = size(positionM, 1);
mode = lower(attitude.mode);
switch mode
    case 'nadir'
        zAxis = -rowNormalize(positionM);
        velocityHorizontal = velocityMps - sum(velocityMps .* zAxis, 2) .* zAxis;
        xAxis = rowNormalize(velocityHorizontal);
        yAxis = rowNormalize(cross(zAxis, xAxis, 2));
        xAxis = rowNormalize(cross(yAxis, zAxis, 2));
    case 'sun_pointing'
        xAxis = rowNormalize(sunPositionM - positionM);
        nadir = -rowNormalize(positionM);
        zTrial = nadir - sum(nadir .* xAxis, 2) .* xAxis;
        zAxis = rowNormalize(zTrial);
        yAxis = rowNormalize(cross(zAxis, xAxis, 2));
        zAxis = rowNormalize(cross(xAxis, yAxis, 2));
    case 'inertial'
        xAxis = repmat([1, 0, 0], nEpoch, 1);
        yAxis = repmat([0, 1, 0], nEpoch, 1);
        zAxis = repmat([0, 0, 1], nEpoch, 1);
    otherwise
        error('Unsupported attitude mode: %s', attitude.mode);
end

offset = rotation321(deg2rad(attitude.eulerOffsetDeg));
frame = zeros(nEpoch, 3, 3);
for k = 1:nEpoch
    nominal = [xAxis(k, :); yAxis(k, :); zAxis(k, :)];
    frame(k, :, :) = reshape(offset * nominal, [1, 3, 3]);
end
end

function rotation = rotation321(eulerRad)
roll = eulerRad(1); pitch = eulerRad(2); yaw = eulerRad(3);
cr = cos(roll); sr = sin(roll);
cp = cos(pitch); sp = sin(pitch);
cy = cos(yaw); sy = sin(yaw);
rotation = [ ...
    cy*cp, cy*sp*sr-sy*cr, cy*sp*cr+sy*sr; ...
    sy*cp, sy*sp*sr+cy*cr, sy*sp*cr-cy*sr; ...
    -sp, cp*sr, cp*cr];
end

function out = rowNormalize(in)
lengths = vecnorm(in, 2, 2);
assert(all(lengths > 0), 'Cannot normalize a zero vector.');
out = in ./ lengths;
end
