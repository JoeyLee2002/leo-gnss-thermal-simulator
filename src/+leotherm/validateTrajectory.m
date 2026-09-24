function validateTrajectory(trajectory)
%VALIDATETRAJECTORY Validate an external ECI trajectory and optional attitude.

if ~isstruct(trajectory) || ~isscalar(trajectory)
    invalid('trajectory must be a scalar structure.');
end
required = {'epoch', 'elapsedS', 'positionM', 'velocityMps'};
for k = 1:numel(required)
    if ~isfield(trajectory, required{k})
        invalid('trajectory.%s is required.', required{k});
    end
end

elapsed = trajectory.elapsedS;
if ~isnumeric(elapsed) || ~iscolumn(elapsed) || numel(elapsed) < 2 ...
        || any(~isfinite(elapsed)) || any(diff(elapsed) <= 0)
    invalid(['trajectory.elapsedS must be a finite, strictly increasing ' ...
        'N-by-1 vector with at least two epochs.']);
end
nEpoch = numel(elapsed);
if ~isdatetime(trajectory.epoch) || ~iscolumn(trajectory.epoch) ...
        || numel(trajectory.epoch) ~= nEpoch || any(isnat(trajectory.epoch))
    invalid('trajectory.epoch must be a valid N-by-1 datetime vector.');
end
finiteMatrix(trajectory.positionM, nEpoch, 3, 'trajectory.positionM');
finiteMatrix(trajectory.velocityMps, nEpoch, 3, 'trajectory.velocityMps');
if any(vecnorm(trajectory.positionM, 2, 2) <= 0)
    invalid('trajectory.positionM contains a zero position vector.');
end
if any(vecnorm(trajectory.velocityMps, 2, 2) <= 0)
    invalid('trajectory.velocityMps contains a zero velocity vector.');
end
if any(vecnorm(cross(trajectory.positionM, trajectory.velocityMps, 2), 2, 2) <= 0)
    invalid('trajectory position and velocity cannot be parallel.');
end

if isfield(trajectory, 'sunPositionM') && ~isempty(trajectory.sunPositionM)
    finiteMatrix(trajectory.sunPositionM, nEpoch, 3, ...
        'trajectory.sunPositionM');
end
if isfield(trajectory, 'betaDeg') && ~isempty(trajectory.betaDeg)
    finiteColumn(trajectory.betaDeg, nEpoch, 'trajectory.betaDeg');
end
if isfield(trajectory, 'periodS') && ~isempty(trajectory.periodS)
    value = trajectory.periodS;
    if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
        invalid('trajectory.periodS must be one finite positive value.');
    end
end
if isfield(trajectory, 'raanDeg') && ~isempty(trajectory.raanDeg)
    value = trajectory.raanDeg;
    valid = isnumeric(value) && isreal(value) && all(isfinite(value), 'all') ...
        && (isscalar(value) || (iscolumn(value) && numel(value) == nEpoch));
    if ~valid
        invalid('trajectory.raanDeg must be scalar or a finite N-by-1 vector.');
    end
end
if isfield(trajectory, 'frameBodyAxesECI') ...
        && ~isempty(trajectory.frameBodyAxesECI)
    validateFrame(trajectory.frameBodyAxesECI, nEpoch);
end
end

function finiteMatrix(value, nRows, nColumns, label)
if ~isnumeric(value) || ~isreal(value) || ~isequal(size(value), [nRows, nColumns]) ...
        || any(~isfinite(value), 'all')
    invalid('%s must be a finite N-by-%d real matrix.', label, nColumns);
end
end

function finiteColumn(value, nRows, label)
if ~isnumeric(value) || ~isreal(value) || ~iscolumn(value) ...
        || numel(value) ~= nRows || any(~isfinite(value))
    invalid('%s must be a finite N-by-1 real vector.', label);
end
end

function validateFrame(frame, nEpoch)
if ~isnumeric(frame) || ~isreal(frame) || ~isequal(size(frame), [nEpoch, 3, 3]) ...
        || any(~isfinite(frame), 'all')
    invalid('trajectory.frameBodyAxesECI must be a finite N-by-3-by-3 array.');
end
tolerance = 1e-6;
for k = 1:nEpoch
    rotation = squeeze(frame(k, :, :));
    if max(abs(rotation * rotation' - eye(3)), [], 'all') > tolerance ...
            || abs(det(rotation) - 1) > tolerance
        invalid(['trajectory.frameBodyAxesECI(%d,:,:) must be a right-handed ' ...
            'orthonormal rotation matrix.'], k);
    end
end
end

function invalid(message, varargin)
error('leotherm:InvalidTrajectory', message, varargin{:});
end
