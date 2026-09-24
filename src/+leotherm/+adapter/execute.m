function varargout = execute(adapterOrId, capability, varargin)
%EXECUTE Execute one explicitly registered adapter capability.
%   [OUT...] = leotherm.adapter.execute(ID, CAPABILITY, ARGS...)
%   [OUT...] = leotherm.adapter.execute(DESCRIPTOR, CAPABILITY, ARGS...)
%   The descriptor is validated before its function handle is called. This
%   function deliberately does not infer formats, units, or handler inputs.

if nargin < 2
    error('leotherm:AdapterExecution', ...
        'An adapter and capability are required.');
end
if ischar(adapterOrId) || (isstring(adapterOrId) && isscalar(adapterOrId))
    adapter = leotherm.adapter.get(adapterOrId);
elseif isstruct(adapterOrId) && isscalar(adapterOrId)
    adapter = leotherm.adapter.validate(adapterOrId);
else
    error('leotherm:AdapterExecution', ...
        'The adapter must be an id or scalar descriptor.');
end
capability = textScalar(capability, 'capability');
known = {'readModel','writeModel','readResult','writeResult','runExternal'};
hit = find(strcmpi(known, capability), 1);
if isempty(hit)
    error('leotherm:AdapterCapability', 'Unknown adapter capability: %s.', capability);
end
capability = known{hit};
if ~adapter.capabilities.(capability)
    error('leotherm:AdapterCapability', ...
        'Adapter %s does not provide capability %s.', adapter.id, capability);
end
handler = adapter.handlers.(capability);
if ~isa(handler, 'function_handle')
    error('leotherm:AdapterHandlerRequired', ...
        'Adapter %s has no executable handler for %s.', adapter.id, capability);
end
[varargout{1:nargout}] = handler(varargin{:});
end

function value = textScalar(value, name)
if isstring(value) && isscalar(value), value = char(value); end
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error('leotherm:AdapterExecution', '%s must be non-empty text.', name);
end
value = strtrim(value);
end
