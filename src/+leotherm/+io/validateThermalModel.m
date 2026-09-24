function validateThermalModel(model)
%VALIDATETHERMALMODEL Validate v1 without normalising or dropping fields.
if ~isstruct(model) || ~isscalar(model), invalid('Model must be a scalar structure.'); end
required = {'schema','metadata','nodes','materials','components','contacts','boundaries','provenance','uncertainty'};
for k = 1:numel(required)
    if ~isfield(model, required{k}), invalid('Missing required field "%s".', required{k}); end
end
if ~(ischar(model.schema) || (isstring(model.schema) && isscalar(model.schema))) || ...
        ~strcmp(char(model.schema), 'leotherm.thermal_model.v1')
    invalid('schema must equal leotherm.thermal_model.v1.');
end
if ~isstruct(model.metadata) || ~isscalar(model.metadata), invalid('metadata must be a scalar structure.'); end
for k = {'modelId','createdUTC','units'}
    if ~isfield(model.metadata,k{1}), invalid('metadata.%s is required.',k{1}); end
end
if ~isText(model.metadata.modelId) || isempty(char(model.metadata.modelId)), invalid('metadata.modelId must be text.'); end
if ~isUtc(model.metadata.createdUTC), invalid('metadata.createdUTC must be an ISO-8601 UTC timestamp ending in Z.'); end
validateUnits(model.metadata.units);
for k = {'nodes','materials','components','contacts','boundaries'}
    v = model.(k{1});
    if ~(isstruct(v) || iscell(v) || isnumeric(v) || isempty(v))
        invalid('%s must be a structure array, cell array, numeric array, or empty.', k{1});
    end
end
if ~isstruct(model.provenance) || ~isscalar(model.provenance), invalid('provenance must be a scalar structure.'); end
if isfield(model.provenance,'inputFingerprint') && ~isempty(model.provenance.inputFingerprint)
    fp = model.provenance.inputFingerprint;
    if ~isText(fp) || isempty(regexp(char(fp),'^[0-9a-fA-F]{64}$','once'))
        invalid('provenance.inputFingerprint must be a 64-character SHA-256 hex string.');
    end
end
if isfield(model.provenance,'createdUTC') && ~isUtc(model.provenance.createdUTC), invalid('provenance.createdUTC must be UTC.'); end
if ~(isempty(model.uncertainty) || (isstruct(model.uncertainty) && isscalar(model.uncertainty)))
    invalid('uncertainty must be a scalar structure or empty.');
end
walk(model);
end

function validateUnits(units)
if ~isstruct(units) || ~isscalar(units), invalid('metadata.units must be a scalar structure.'); end
names = {'length','mass','time','temperature','power','heatCapacity','conductance','area'};
expected = {'m','kg','s','K','W','J/K','W/K','m^2'};
for k = 1:numel(names)
    if ~isfield(units,names{k}) || ~isText(units.(names{k})) || ~strcmp(char(units.(names{k})),expected{k})
        invalid('metadata.units.%s must be canonical SI unit %s.', names{k}, expected{k});
    end
end
end

function walk(value)
if isnumeric(value)
    if ~isreal(value) || any(~isfinite(value(:))), invalid('Numeric values must be real and finite.'); end
elseif iscell(value)
    for k = 1:numel(value), walk(value{k}); end
elseif isstruct(value)
    names = fieldnames(value);
    for k = 1:numel(value), for j = 1:numel(names), walk(value(k).(names{j})); end, end
end
end

function ok = isUtc(value)
if ~isText(value), ok = false; return; end
s = char(value);
ok = ~isempty(regexp(s, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$', 'once'));
if ok
    try
        if contains(s, '.')
            datetime(s,'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSXXX','TimeZone','UTC');
        else
            datetime(s,'InputFormat','yyyy-MM-dd''T''HH:mm:ssXXX','TimeZone','UTC');
        end
    catch
        ok = false;
    end
end
end
function ok = isText(value), ok = ischar(value) || (isstring(value) && isscalar(value)); end
function invalid(message,varargin), error('leotherm:InvalidThermalModel',message,varargin{:}); end
