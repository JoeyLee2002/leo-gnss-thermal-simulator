function [task, report] = importExternalTask(source, network)
%IMPORTEXTERNALTASK Import a traceable orbit/attitude/telemetry task bundle.
% Supported carriers are JSON (.json), MAT (.mat), or an equivalent scalar
% MATLAB structure.  The schema identifier must be
% 'leotherm.external_task.v1'. Time is explicit UTC ISO-8601 (trailing Z)
% and elapsed seconds are explicit SI seconds. No sorting, interpolation,
% gap filling, nearest-neighbour matching, or time shifting is performed.
if nargin < 2, network = []; end
raw = loadCarrier(source);
if ~isstruct(raw) || ~isscalar(raw)
    error('leotherm:ExternalTaskSchema','External task must decode to a scalar structure.');
end
if ~isfield(raw,'schema') || ~strcmp(string(raw.schema),'leotherm.external_task.v1')
    error('leotherm:ExternalTaskSchema','Unsupported or missing schema; expected leotherm.external_task.v1.');
end
if ~isfield(raw,'time') || ~isstruct(raw.time)
    error('leotherm:ExternalTaskTime','Task requires a time section with system, epoch_utc and elapsed_s.');
end
if ~isfield(raw.time,'system') || ~strcmpi(string(raw.time.system),'UTC')
    error('leotherm:ExternalTaskTime','Only UTC time.system is accepted.');
end
if ~isfield(raw.time,'elapsed_unit') || ~strcmpi(string(raw.time.elapsed_unit),'s')
    error('leotherm:ExternalTaskTime','time.elapsed_unit must be explicit SI seconds (s).');
end
epoch = parseEpoch(raw.time.epoch_utc);
elapsed = column(raw.time.elapsed_s,'elapsed_s');
if numel(epoch) ~= numel(elapsed) || numel(epoch) < 2
    error('leotherm:ExternalTaskTime','epoch_utc and elapsed_s must have equal length (at least two rows).');
end
if any(diff(elapsed)<=0) || any(diff(epoch)<=seconds(0))
    error('leotherm:ExternalTaskTime','Epochs must be strictly increasing; input is never reordered or repaired.');
end
if ~isfield(raw,'orbit') || ~isstruct(raw.orbit)
    error('leotherm:ExternalTaskSchema','Task requires an orbit section.');
end
orbit.positionM = matrix(raw.orbit,'position_m',numel(elapsed),3);
orbit.velocityMps = matrix(raw.orbit,'velocity_mps',numel(elapsed),3);
orbit.epoch = epoch; orbit.elapsedS = elapsed;
if isfield(raw.orbit,'sun_position_m') && ~isempty(raw.orbit.sun_position_m)
    orbit.sunPositionM = matrix(raw.orbit,'sun_position_m',numel(elapsed),3);
end
if isfield(raw,'attitude') && ~isempty(raw.attitude)
    if ~isstruct(raw.attitude) || ~isfield(raw.attitude,'representation')
        error('leotherm:ExternalTaskAttitude','Attitude requires representation and values.');
    end
    representation = lower(string(raw.attitude.representation));
    values = raw.attitude.values;
    if representation == "quaternion"
        if ~isfield(raw.attitude,'convention')
            error('leotherm:ExternalTaskAttitude','Quaternion convention must be explicit.');
        end
        q = matrix(raw.attitude,'values',numel(elapsed),4);
        orbit.frameBodyAxesECI = leotherm.quaternionToBodyAxes(q, char(raw.attitude.convention));
    elseif representation == "dcm"
        orbit.frameBodyAxesECI = dcmFromValues(values,numel(elapsed));
    else
        error('leotherm:ExternalTaskAttitude','Unsupported attitude representation: %s.',representation);
    end
end
leotherm.validateTrajectory(orbit);
task = struct('schema',char(raw.schema),'trajectory',orbit,'telemetry',[],'raw',raw);
if isfield(raw,'telemetry') && ~isempty(raw.telemetry)
    task.telemetry = raw.telemetry;
end
report = makeReport(raw, orbit, task.telemetry, source);
if ~isempty(network), report.networkNodeCount = numel(network.nodeNames); end
end

function raw = loadCarrier(source)
if isstruct(source), raw = source; return; end
if ~(ischar(source) || (isstring(source)&&isscalar(source))) || ~isfile(source)
    error('leotherm:ExternalTaskFile','Provide an existing JSON/MAT task file or a structure.');
end
[~,~,ext] = fileparts(source);
switch lower(ext)
    case '.json'
        raw = jsondecode(fileread(source));
    case '.mat'
        loaded = load(source);
        names = fieldnames(loaded);
        hit = names(ismember(names,{'task','externalTask','bundle'}));
        if isempty(hit), hit = names(cellfun(@(n)isstruct(loaded.(n)) && isscalar(loaded.(n)),names)); end
        if isempty(hit), error('leotherm:ExternalTaskFile','MAT file contains no scalar task structure.'); end
        raw = loaded.(hit{1});
    otherwise
        error('leotherm:ExternalTaskFile','Task carrier must be .json or .mat.');
end
end

function out = column(value,label)
if ~isnumeric(value) || ~isreal(value) || any(~isfinite(value),'all')
    error('leotherm:ExternalTaskTime','time.%s must be finite numeric seconds.',label);
end
out = double(value(:));
end
function out = matrix(s,name,n,m)
if ~isfield(s,name), error('leotherm:ExternalTaskSchema','Missing %s.',name); end
out = s.(name);
if ~isnumeric(out) || ~isreal(out) || ~isequal(size(out),[n m]) || any(~isfinite(out),'all')
    error('leotherm:ExternalTaskSchema','%s must be finite %d-by-%d.',name,n,m);
end
out = double(out);
end
function epoch = parseEpoch(value)
if isdatetime(value)
    if isempty(value.TimeZone), error('leotherm:ExternalTaskTime','Datetime epochs require an explicit time zone.'); end
    epoch=value(:); epoch.TimeZone='UTC';
else
    text=string(value); epoch=NaT(numel(text),1,'TimeZone','UTC');
    for k=1:numel(text)
        token=char(text(k));
        if ~ismissing(text(k)) && ~isempty(regexp(token,'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$','once'))
            baseFormat='yyyy-MM-dd''T''HH:mm:ss'; dot=strfind(token,'.');
            inputFormat = [baseFormat '''Z'''];
            if ~isempty(dot)
                fractionFormat = repmat('S',1,length(token)-dot-1);
                inputFormat = [baseFormat '.' fractionFormat '''Z'''];
            end
            try
                epoch(k)=datetime(token,'TimeZone','UTC','InputFormat',inputFormat);
            catch
            end
        end
    end
end
if any(isnat(epoch)), error('leotherm:ExternalTaskTime','All epoch_utc values must be valid ISO-8601 UTC strings.'); end
end
function frame = dcmFromValues(values,n)
if isnumeric(values) && isequal(size(values),[n 3 3]), frame=double(values); return; end
if isnumeric(values) && isequal(size(values),[n 9])
    frame=zeros(n,3,3); values=double(values);
    for k=1:n, frame(k,:,:)=reshape(values(k,:),3,3)'; end
    return;
end
error('leotherm:ExternalTaskAttitude','DCM values must be N-by-3-by-3 or N-by-9.');
end
function report = makeReport(raw,orbit,telemetry,source)
report = struct('schema',char(raw.schema),'source',sourceLabel(source), ...
    'timeSystem','UTC','elapsedUnit','s','rows',numel(orbit.elapsedS), ...
    'strictMonotonicTime',true,'interpolation',false,'reordered',false, ...
    'missingRows',0,'attitudeProvided',isfield(orbit,'frameBodyAxesECI'), ...
    'telemetryPresent',~isempty(telemetry),'synchronization','not_checked');
if isempty(telemetry), return; end
if isstruct(telemetry) && isfield(telemetry,'epoch_utc')
    try
        te=parseEpoch(telemetry.epoch_utc);
        report.telemetryRows=numel(te);
        report.exactEpochMatch=(numel(te)==numel(orbit.epoch) && all(te==orbit.epoch));
        report.synchronization=ternary(report.exactEpochMatch,'exact_epoch_match','mismatch_rejected_no_interpolation');
    catch
        report.synchronization='invalid_telemetry_time';
    end
else
    report.synchronization='telemetry_epoch_not_declared';
end
end
function label=sourceLabel(source)
if isstruct(source), label='<MATLAB structure>'; else, label=char(source); end
end
function out=ternary(cond,a,b)
if cond, out=a; else, out=b; end
end
