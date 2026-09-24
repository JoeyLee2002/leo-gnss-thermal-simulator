function varargout = registry(action, varargin)
%REGISTRY Manage user and built-in leotherm.adapter.v1 descriptors.
%   leotherm.adapter.registry('register', ADAPTER)
%   leotherm.adapter.registry('list')
%   leotherm.adapter.registry('get', ID)
%   leotherm.adapter.registry('unregister', ID)

persistent customAdapters
if isempty(customAdapters)
    customAdapters = emptyAdapters;
end
if nargin == 0 || isempty(action)
    action = 'list';
end
op = lower(char(string(action)));
builtins = leotherm.adapter.builtins;
switch op
    case 'list'
        allAdapters = [builtins, orderfields(customAdapters, fieldnames(builtins))];
        if nargout > 0
            varargout{1} = allAdapters;
        end
    case 'get'
        if isempty(varargin)
            error('leotherm:AdapterIdRequired', 'An adapter id is required.');
        end
        id = textScalar(varargin{1}, 'id');
        hit = find(strcmpi({builtins.id}, id), 1);
        if ~isempty(hit)
            varargout{1} = builtins(hit);
            return
        end
        hit = find(strcmpi({customAdapters.id}, id), 1);
        if isempty(hit)
            error('leotherm:UnknownAdapter', 'Unknown adapter id: %s.', id);
        end
        varargout{1} = customAdapters(hit);
    case 'register'
        if isempty(varargin)
            error('leotherm:AdapterInvalid', 'An adapter descriptor is required.');
        end
        adapter = leotherm.adapter.validate(varargin{1});
        if any(strcmpi({builtins.id}, adapter.id)) || ...
                any(strcmpi({customAdapters.id}, adapter.id))
            error('leotherm:AdapterDuplicate', ...
                'Adapter id already exists: %s.', adapter.id);
        end
        customAdapters(end + 1) = orderfields(adapter, fieldnames(customAdapters));
        varargout{1} = adapter;
    case 'unregister'
        if isempty(varargin)
            error('leotherm:AdapterIdRequired', 'An adapter id is required.');
        end
        id = textScalar(varargin{1}, 'id');
        hit = find(strcmpi({customAdapters.id}, id), 1);
        if isempty(hit)
            error('leotherm:UnknownAdapter', ...
                'Only user adapters can be unregistered: %s.', id);
        end
        removed = customAdapters(hit);
        customAdapters(hit) = [];
        if nargout > 0
            varargout{1} = removed;
        end
    case 'clearcustom'
        customAdapters = emptyAdapters;
    otherwise
        error('leotherm:AdapterAction', 'Unknown adapter registry action: %s.', op);
end

function adapters = emptyAdapters
adapters = struct('id', {}, 'version', {}, 'displayName', {}, 'kind', {}, ...
    'capabilities', {}, 'handlers', {}, 'exchangeFormats', {}, ...
    'provenance', {}, 'schema', {});
end
end

function value = textScalar(value, name)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error('leotherm:AdapterInvalid', '%s must be non-empty text.', name);
end
value = strtrim(value);
end
