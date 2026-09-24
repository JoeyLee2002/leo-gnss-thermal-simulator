function options = telemetryOptions(input)
%TELEMETRYOPTIONS Explicit driver, gap, initialization, and scoring policy.
options.mode = 'orbit';
options.frame = ''; % Required confirmation for orbital telemetry.
options.maxGapS = 60;
options.maxStepS = 10;
options.useInitialTemperature = false;
options.excludeInitialS = 600;
options.rmseToleranceK = NaN;
if nargin > 0 && ~isempty(input)
    if ~isstruct(input) || ~isscalar(input)
        error('leotherm:TelemetryOptions', 'Telemetry options must be a scalar structure.');
    end
    names = fieldnames(input);
    for k = 1:numel(names)
        if ~isfield(options, names{k})
            error('leotherm:TelemetryOptions', 'Unknown telemetry option: %s', names{k});
        end
        options.(names{k}) = input.(names{k});
    end
end
if ~((ischar(options.mode) && isrow(options.mode)) || ...
        (isstring(options.mode) && isscalar(options.mode))) ...
        || ~ismember(string(options.mode), ["orbit","heat"])
    error('leotherm:TelemetryOptions', 'Mode must be orbit or heat.');
end
if ~((ischar(options.frame) && (isrow(options.frame) || isempty(options.frame))) ...
        || (isstring(options.frame) && isscalar(options.frame)))
    error('leotherm:TelemetryOptions', 'Frame declaration must be one string.');
end
for name = {'maxGapS','maxStepS','excludeInitialS','rmseToleranceK'}
    v = options.(name{1});
    if ~isnumeric(v) || ~isreal(v) || ~isscalar(v) ...
            || (~isfinite(v) && ~(strcmp(name{1}, 'rmseToleranceK') && isnan(v))) ...
            || v < 0 || (ismember(name{1}, {'maxGapS','maxStepS'}) && v == 0)
        error('leotherm:TelemetryOptions', 'Invalid numeric option: %s', name{1});
    end
end
if ~islogical(options.useInitialTemperature) || ~isscalar(options.useInitialTemperature)
    error('leotherm:TelemetryOptions', 'useInitialTemperature must be one logical value.');
end
end
