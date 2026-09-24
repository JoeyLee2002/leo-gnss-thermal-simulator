function report = validateThermalResult(result)
%VALIDATETHERMALRESULT Validate leotherm.thermal_result.v1 exchange data.
%   Structural contract violations raise leotherm:InvalidThermalResult.
%   NaN samples are retained and reported as missing; Inf samples are
%   retained and reported as bad data. No sorting, interpolation, filling,
%   unit conversion, or time shifting is performed.

if ~isstruct(result) || ~isscalar(result)
    invalid('Thermal result must be a scalar structure.');
end
if ~isfield(result,'schema') || ~isText(result.schema) || ...
        ~strcmp(char(result.schema),'leotherm.thermal_result.v1')
    invalid('schema must equal leotherm.thermal_result.v1.');
end
required = {'epochs','nodeIds','units'};
for k = 1:numel(required)
    if ~isfield(result,required{k}), invalid('Missing required field "%s".',required{k}); end
end

epochs = result.epochs;
if ischar(epochs) || (isstring(epochs) && isscalar(epochs)), epochs = {char(epochs)}; end
if ~(iscell(epochs) || isstring(epochs)) || isempty(epochs)
    invalid('epochs must be a non-empty text vector.');
end
nEpoch = numel(epochs);
epochText = cell(nEpoch,1);
for k = 1:nEpoch
    if iscell(epochs), value = epochs{k}; else, value = epochs(k); end
    if ~isText(value), invalid('epochs must contain text UTC timestamps.'); end
    epochText{k} = char(value);
    if ~isUtc(epochText{k}), invalid('epochs{%d} is not a valid ISO-8601 UTC timestamp ending in Z.',k); end
end
epochDt = NaT(nEpoch,1,'TimeZone','UTC');
for k = 1:nEpoch
    try
        epochDt(k) = parseUtcEpoch(epochText{k});
    catch
        invalid('epochs could not be parsed as UTC timestamps.');
    end
end
delta = seconds(diff(epochDt));
if any(~isfinite(delta)) || any(delta <= 0)
    invalid('epochs must be strictly increasing; input order is preserved.');
end

nodeIds = result.nodeIds;
if ischar(nodeIds) || (isstring(nodeIds) && isscalar(nodeIds)), nodeIds = {char(nodeIds)}; end
if ~(iscell(nodeIds) || isstring(nodeIds) || ischar(nodeIds)) || isempty(nodeIds)
    invalid('nodeIds must be a non-empty text vector.');
end
nNode = numel(nodeIds); nodeText = cell(nNode,1);
for k = 1:nNode
    if iscell(nodeIds), value = nodeIds{k}; elseif isstring(nodeIds), value = nodeIds(k); else, value = nodeIds(k,:); end
    if ~isText(value) || isempty(char(value)), invalid('nodeIds must contain non-empty text.'); end
    nodeText{k} = char(value);
end
if numel(unique(nodeText)) ~= nNode, invalid('nodeIds must be unique.'); end

if ~isstruct(result.units) || ~isscalar(result.units), invalid('units must be a scalar structure.'); end
if ~isfield(result.units,'epoch') || ~isText(result.units.epoch) || ~strcmp(char(result.units.epoch),'UTC')
    invalid('units.epoch must be UTC.');
end
hasTemp = isfield(result,'temperatureK') && ~isempty(result.temperatureK);
hasPower = isfield(result,'heatPowerW') && ~isempty(result.heatPowerW);
if ~hasTemp && ~hasPower, invalid('At least one of temperatureK or heatPowerW is required.'); end
if hasTemp
    if ~isnumeric(result.temperatureK) || ~isequal(size(result.temperatureK),[nEpoch nNode])
        invalid('temperatureK must be a numeric epochs-by-nodeIds array.');
    end
    if ~isfield(result.units,'temperatureK') || ~isText(result.units.temperatureK) || ~strcmp(char(result.units.temperatureK),'K')
        invalid('units.temperatureK must be K when temperatureK is present.');
    end
end
if hasPower
    if ~isnumeric(result.heatPowerW) || ~isequal(size(result.heatPowerW),[nEpoch nNode])
        invalid('heatPowerW must be a numeric epochs-by-nodeIds array.');
    end
    if ~isfield(result.units,'heatPowerW') || ~isText(result.units.heatPowerW) || ~strcmp(char(result.units.heatPowerW),'W')
        invalid('units.heatPowerW must be W when heatPowerW is present.');
    end
end
if isfield(result,'modelFingerprint') && ~isempty(result.modelFingerprint) && ~isText(result.modelFingerprint)
    invalid('modelFingerprint must be text when provided.');
end

missing = struct('temperatureK',0,'heatPowerW',0,'total',0);
bad = struct('temperatureK',0,'heatPowerW',0,'total',0);
if hasTemp
    missing.temperatureK = sum(isnan(result.temperatureK(:)));
    bad.temperatureK = sum(isinf(result.temperatureK(:)) | ~isreal(result.temperatureK(:)));
end
if hasPower
    missing.heatPowerW = sum(isnan(result.heatPowerW(:)));
    bad.heatPowerW = sum(isinf(result.heatPowerW(:)) | ~isreal(result.heatPowerW(:)));
end
missing.total = missing.temperatureK + missing.heatPowerW;
bad.total = bad.temperatureK + bad.heatPowerW;
report = struct('schema',char(result.schema),'epochCount',nEpoch,'nodeCount',nNode,...
    'epochs', {epochText}, 'nodeIds', {nodeText}, 'intervalSeconds',delta(:)',...
    'coverageStartUTC',epochText{1},'coverageEndUTC',epochText{end},...
    'missing',missing,'badData',bad,'validationPassed',(missing.total==0 && bad.total==0));
if isempty(delta)
    report.intervalStats = struct('count',0,'minSeconds',NaN,'maxSeconds',NaN,'meanSeconds',NaN,'medianSeconds',NaN);
else
    report.intervalStats = struct('count',numel(delta),'minSeconds',min(delta),'maxSeconds',max(delta),...
        'meanSeconds',mean(delta),'medianSeconds',median(delta));
end
end

function invalid(message,varargin), error('leotherm:InvalidThermalResult',message,varargin{:}); end
function ok = isText(value), ok = ischar(value) || (isstring(value) && isscalar(value)); end
function ok = isUtc(value)
if ~isText(value), ok=false; return; end
s=char(value); ok=~isempty(regexp(s,'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$','once'));
if ok
    try
        parseUtcEpoch(s);
    catch
        ok=false;
    end
end
end
function d = parseUtcEpoch(s)
% Parse arbitrary ISO fractional precision without altering stored text.
tok = regexp(s,'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?Z$','tokens','once');
if isempty(tok), error('bad timestamp'); end
if isempty(tok{2})
    d = datetime([tok{1} 'Z'],'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX','TimeZone','UTC','Locale','en_US');
else
    frac = tok{2}(2:end); frac = [frac repmat('0',1,max(0,3-numel(frac)))]; frac = frac(1:min(3,numel(frac)));
    d = datetime([tok{1} '.' frac 'Z'],'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC','Locale','en_US');
end
end
