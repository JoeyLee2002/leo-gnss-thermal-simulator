function settings = deviceCalibrationOptions(input, nodeCount)
%DEVICECALIBRATIONOPTIONS Explicit prior, sensor, and acceptance policy.
if nargin < 1, input = struct; end
if nargin < 2, nodeCount = 1; end
settings = struct('telemetryOptions',leotherm.telemetryOptions, ...
    'temperatureSigmaK',1,'sensorEvidence','', ...
    'regularizationWeight',1,'rmseToleranceK',NaN, ...
    'independentHoldoutConfirmed',false,'forcingIndependenceConfirmed',false, ...
    'parameterEvidenceConfirmed',false,'solverSettings',struct, ...
    'maxFreeParameters',6,'minimumCoverageS',1800,'minimumContinuousS',600, ...
    'minimumTemperatureSpanK',0.5,'minimumScoredSamples',30);
if ~isstruct(input) || ~isscalar(input) || any(~ismember(fieldnames(input),fieldnames(settings)))
    error('leotherm:DeviceCalibrationOptions','Unknown or invalid device calibration settings.');
end
names = fieldnames(input);
for k = 1:numel(names), settings.(names{k}) = input.(names{k}); end
settings.telemetryOptions = leotherm.telemetryOptions(settings.telemetryOptions);
sigma = settings.temperatureSigmaK;
if ~isnumeric(sigma) || ~isreal(sigma) || ~isvector(sigma) ...
        || ~ismember(numel(sigma),[1 nodeCount]) || any(~isfinite(sigma) | sigma <= 0)
    error('leotherm:DeviceCalibrationOptions','Temperature uncertainties must be positive scalar or per-node values.');
end
settings.temperatureSigmaK = sigma(:)';
if isscalar(sigma), settings.temperatureSigmaK = repmat(sigma,1,nodeCount); end
if ~((ischar(settings.sensorEvidence) && (isrow(settings.sensorEvidence) || isempty(settings.sensorEvidence))) ...
        || (isstring(settings.sensorEvidence) && isscalar(settings.sensorEvidence))) ...
        || ismissing(string(settings.sensorEvidence))
    error('leotherm:DeviceCalibrationOptions','Sensor uncertainty evidence must be text.');
end
settings.sensorEvidence = char(strtrim(string(settings.sensorEvidence)));
validateattributes(settings.regularizationWeight,{'numeric'},{'scalar','real','finite','positive'});
validateattributes(settings.maxFreeParameters,{'numeric'},{'scalar','integer','finite','positive'});
for name = {'minimumCoverageS','minimumContinuousS','minimumTemperatureSpanK'}
    validateattributes(settings.(name{1}),{'numeric'},{'scalar','real','finite','nonnegative'});
end
validateattributes(settings.minimumScoredSamples,{'numeric'},{'scalar','integer','finite','>=',3});
v = settings.rmseToleranceK;
if ~isnumeric(v) || ~isreal(v) || ~isscalar(v) || (~isnan(v) && (~isfinite(v) || v <= 0))
    error('leotherm:DeviceCalibrationOptions','Specify a positive RMSE limit or NaN for comparison only.');
end
for name = {'independentHoldoutConfirmed','forcingIndependenceConfirmed','parameterEvidenceConfirmed'}
    if ~islogical(settings.(name{1})) || ~isscalar(settings.(name{1}))
        error('leotherm:DeviceCalibrationOptions','Confirmations must be explicit logical scalars.');
    end
end
if ~isstruct(settings.solverSettings) || ~isscalar(settings.solverSettings)
    error('leotherm:DeviceCalibrationOptions','solverSettings must be one structure.');
end
end
