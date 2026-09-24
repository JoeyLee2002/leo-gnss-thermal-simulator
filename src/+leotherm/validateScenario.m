function validateScenario(scenario)
%VALIDATESCENARIO Validate scenario fields before allocating or propagating.

required = {'name', 'startEpoch', 'durationS', 'timeStepS', 'warmupOrbits', ...
    'orbit', 'attitude', 'environment', 'integration'};
requireFields(scenario, required, 'scenario');

if ~((ischar(scenario.name) && isrow(scenario.name)) ...
        || (isstring(scenario.name) && isscalar(scenario.name)))
    invalid('scenario.name must be a character vector or string scalar.');
end
if ~isdatetime(scenario.startEpoch) || ~isscalar(scenario.startEpoch) ...
        || isnat(scenario.startEpoch)
    invalid('scenario.startEpoch must be one valid datetime scalar.');
end
positiveScalar(scenario.durationS, 'scenario.durationS');
positiveScalar(scenario.timeStepS, 'scenario.timeStepS');
nonnegativeScalar(scenario.warmupOrbits, 'scenario.warmupOrbits');

requireFields(scenario.orbit, {'altitudeM', 'inclinationDeg', 'raanDeg', ...
    'argumentLatitudeDeg', 'useJ2'}, 'scenario.orbit');
positiveScalar(scenario.orbit.altitudeM, 'scenario.orbit.altitudeM');
boundedScalar(scenario.orbit.inclinationDeg, 0, 180, ...
    'scenario.orbit.inclinationDeg');
finiteScalar(scenario.orbit.raanDeg, 'scenario.orbit.raanDeg');
finiteScalar(scenario.orbit.argumentLatitudeDeg, ...
    'scenario.orbit.argumentLatitudeDeg');
logicalScalar(scenario.orbit.useJ2, 'scenario.orbit.useJ2');

requireFields(scenario.attitude, {'mode', 'eulerOffsetDeg'}, ...
    'scenario.attitude');
validModes = {'nadir', 'sun_pointing', 'inertial'};
modeValue = scenario.attitude.mode;
if ~((ischar(modeValue) && isrow(modeValue)) ...
        || (isstring(modeValue) && isscalar(modeValue)))
    invalid('scenario.attitude.mode must be nadir, sun_pointing, or inertial.');
end
mode = lower(char(modeValue));
if ~ismember(mode, validModes)
    invalid('scenario.attitude.mode must be nadir, sun_pointing, or inertial.');
end
offset = scenario.attitude.eulerOffsetDeg;
if ~isnumeric(offset) || numel(offset) ~= 3 || any(~isfinite(offset))
    invalid('scenario.attitude.eulerOffsetDeg must contain three finite values.');
end

environmentFields = {'solarConstantWm2', 'earthIRWm2', 'albedo', ...
    'deepSpaceK', 'includeDirectSolar', 'includeAlbedo', 'includeEarthIR', ...
    'freezeSunAtEpoch'};
requireFields(scenario.environment, environmentFields, 'scenario.environment');
positiveScalar(scenario.environment.solarConstantWm2, ...
    'scenario.environment.solarConstantWm2');
nonnegativeScalar(scenario.environment.earthIRWm2, ...
    'scenario.environment.earthIRWm2');
boundedScalar(scenario.environment.albedo, 0, 1, ...
    'scenario.environment.albedo');
nonnegativeScalar(scenario.environment.deepSpaceK, ...
    'scenario.environment.deepSpaceK');
if isfield(scenario.environment,'earthIRModel')
    value = string(scenario.environment.earthIRModel);
    if ~isscalar(value) || ~ismember(value,["legacy_cosine","finite_disk"])
        invalid('Earth infrared model must be legacy_cosine or finite_disk.');
    end
end
logicalFields = {'includeDirectSolar', 'includeAlbedo', 'includeEarthIR', ...
    'freezeSunAtEpoch'};
for k = 1:numel(logicalFields)
    name = logicalFields{k};
    logicalScalar(scenario.environment.(name), ['scenario.environment.' name]);
end

requireFields(scenario.integration, {'minimumTemperatureK', ...
    'maximumTemperatureK'}, 'scenario.integration');
positiveScalar(scenario.integration.minimumTemperatureK, ...
    'scenario.integration.minimumTemperatureK');
positiveScalar(scenario.integration.maximumTemperatureK, ...
    'scenario.integration.maximumTemperatureK');
if scenario.integration.minimumTemperatureK >= scenario.integration.maximumTemperatureK
    invalid(['scenario.integration.minimumTemperatureK must be lower than ' ...
        'maximumTemperatureK.']);
end

if isfield(scenario, 'convergence')
    fields = {'enabled', 'minimumCycles', 'maximumCycles', ...
        'requiredStableCycles', 'toleranceK', 'failOnNonConvergence'};
    requireFields(scenario.convergence, fields, 'scenario.convergence');
    logicalScalar(scenario.convergence.enabled, 'scenario.convergence.enabled');
    positiveInteger(scenario.convergence.minimumCycles, ...
        'scenario.convergence.minimumCycles');
    positiveInteger(scenario.convergence.maximumCycles, ...
        'scenario.convergence.maximumCycles');
    positiveInteger(scenario.convergence.requiredStableCycles, ...
        'scenario.convergence.requiredStableCycles');
    positiveScalar(scenario.convergence.toleranceK, ...
        'scenario.convergence.toleranceK');
    logicalScalar(scenario.convergence.failOnNonConvergence, ...
        'scenario.convergence.failOnNonConvergence');
    if scenario.convergence.minimumCycles > scenario.convergence.maximumCycles
        invalid('scenario.convergence.minimumCycles cannot exceed maximumCycles.');
    end
    if scenario.convergence.requiredStableCycles > scenario.convergence.maximumCycles
        invalid(['scenario.convergence.requiredStableCycles cannot exceed ' ...
            'maximumCycles.']);
    end
end
end

function requireFields(value, fields, label)
if ~isstruct(value) || ~isscalar(value)
    invalid('%s must be a scalar structure.', label);
end
for k = 1:numel(fields)
    if ~isfield(value, fields{k})
        invalid('%s.%s is required.', label, fields{k});
    end
end
end

function finiteScalar(value, label)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ~isreal(value)
    invalid('%s must be one finite real number.', label);
end
end

function positiveScalar(value, label)
finiteScalar(value, label);
if value <= 0
    invalid('%s must be greater than zero.', label);
end
end

function nonnegativeScalar(value, label)
finiteScalar(value, label);
if value < 0
    invalid('%s cannot be negative.', label);
end
end

function boundedScalar(value, low, high, label)
finiteScalar(value, label);
if value < low || value > high
    invalid('%s must lie in [%g, %g].', label, low, high);
end
end

function positiveInteger(value, label)
positiveScalar(value, label);
if value ~= floor(value)
    invalid('%s must be an integer.', label);
end
end

function logicalScalar(value, label)
if ~(isscalar(value) && (islogical(value) || ...
        (isnumeric(value) && isfinite(value) && (value == 0 || value == 1))))
    invalid('%s must be a logical scalar.', label);
end
end

function invalid(message, varargin)
error('leotherm:InvalidScenario', message, varargin{:});
end
