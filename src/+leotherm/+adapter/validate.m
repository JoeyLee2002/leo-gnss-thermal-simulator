function adapter = validate(adapter)
%VALIDATE Validate and normalize a leotherm.adapter.v1 descriptor.
if ~isstruct(adapter) || ~isscalar(adapter)
    error('leotherm:AdapterInvalid', 'Adapter must be a scalar structure.');
end
required = {'id','version','displayName','kind','capabilities','handlers','provenance'};
for k = 1:numel(required)
    if ~isfield(adapter, required{k})
        error('leotherm:AdapterInvalid', 'Missing adapter field: %s.', required{k});
    end
end
for name = {'id','version','displayName','kind'}
    value = adapter.(name{1});
    if isstring(value) && isscalar(value), value = char(value); end
    if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
        error('leotherm:AdapterInvalid', 'adapter.%s must be non-empty text.', name{1});
    end
    adapter.(name{1}) = strtrim(value);
end
if isempty(regexp(adapter.id, '^[A-Za-z][A-Za-z0-9_.-]*$', 'once'))
    error('leotherm:AdapterInvalid', 'adapter.id contains unsupported characters.');
end
if isempty(regexp(adapter.version, '^[0-9]+\.[0-9]+\.[0-9]+$', 'once'))
    error('leotherm:AdapterInvalid', 'adapter.version must use MAJOR.MINOR.PATCH.');
end
if ~isstruct(adapter.capabilities) || ~isscalar(adapter.capabilities)
    error('leotherm:AdapterInvalid', 'capabilities must be a scalar structure.');
end
if ~isstruct(adapter.handlers) || ~isscalar(adapter.handlers)
    error('leotherm:AdapterInvalid', 'handlers must be a scalar structure.');
end
if ~isstruct(adapter.provenance) || ~isscalar(adapter.provenance)
    error('leotherm:AdapterInvalid', 'provenance must be a scalar structure.');
end
capabilityNames = {'readModel','writeModel','readResult','writeResult','runExternal'};
for k = 1:numel(capabilityNames)
    name = capabilityNames{k};
    if ~isfield(adapter.capabilities, name)
        adapter.capabilities.(name) = false;
    end
    value = adapter.capabilities.(name);
    if ~(islogical(value) || isnumeric(value)) || ~isscalar(value)
        error('leotherm:AdapterInvalid', 'capabilities.%s must be scalar logical.', name);
    end
    adapter.capabilities.(name) = logical(value);
    if adapter.capabilities.(name)
        if ~isfield(adapter.handlers, name) || ~isa(adapter.handlers.(name), 'function_handle')
            error('leotherm:AdapterHandlerRequired', ...
                'A function handle is required for capability %s.', name);
        end
    end
end
if isfield(adapter, 'exchangeFormats')
    if ~(iscellstr(adapter.exchangeFormats) || (isstring(adapter.exchangeFormats) && isvector(adapter.exchangeFormats)))
        error('leotherm:AdapterInvalid', 'exchangeFormats must be text values.');
    end
    adapter.exchangeFormats = cellstr(string(adapter.exchangeFormats(:)));
else
    adapter.exchangeFormats = {};
end
if ~isfield(adapter.provenance, 'source') || isempty(adapter.provenance.source)
    error('leotherm:AdapterInvalid', 'provenance.source is required.');
end
adapter.schema = 'leotherm.adapter.v1';
end
