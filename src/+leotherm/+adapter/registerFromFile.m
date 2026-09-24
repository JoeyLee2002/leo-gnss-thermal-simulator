function [adapter, report] = registerFromFile(filePath, varargin)
%REGISTERFROMFILE Register a metadata-only adapter descriptor from JSON/MAT.
%   ADAPTER = leotherm.adapter.registerFromFile(PATH)
%   ADAPTER = leotherm.adapter.registerFromFile(PATH, 'Handlers', HANDLERS)
%   JSON/MAT descriptors cannot provide executable function handles. Optional
%   MATLAB HANDLERS are attached explicitly and are validated against the
%   descriptor capabilities before registration.

if nargin < 1
    error('leotherm:AdapterDescriptorFile', 'A descriptor file is required.');
end
if isstring(filePath) && isscalar(filePath), filePath = char(filePath); end
if ~ischar(filePath) || ~isrow(filePath) || isempty(strtrim(filePath))
    error('leotherm:AdapterDescriptorFile', 'filePath must be non-empty text.');
end
filePath = char(filePath);
if ~isfile(filePath)
    error('leotherm:AdapterDescriptorFile', 'Descriptor file does not exist: %s.', filePath);
end
opts = parseOptions(varargin{:});
[~,~,ext] = fileparts(filePath);
switch lower(ext)
    case '.json'
        try
            raw = jsondecode(fileread(filePath));
        catch err
            error('leotherm:AdapterDescriptorFile', ...
                'Invalid JSON descriptor: %s.', err.message);
        end
    case '.mat'
        loaded = load(filePath);
        raw = extractDescriptor(loaded);
    otherwise
        error('leotherm:AdapterDescriptorFile', ...
            'Only .json and .mat descriptors are supported.');
end
if ~isstruct(raw) || ~isscalar(raw)
    error('leotherm:AdapterDescriptorFile', 'Descriptor must be a scalar structure.');
end
if isfield(raw, 'handlers') && (~isstruct(raw.handlers) || ~isscalar(raw.handlers))
    error('leotherm:AdapterExecutableInFile', ...
        'Descriptor handlers must be an empty scalar structure; attach handlers in MATLAB code.');
end
if isfield(raw, 'handlers') && ~isempty(fieldnames(raw.handlers))
    error('leotherm:AdapterExecutableInFile', ...
        'Descriptor files may not contain executable handlers. Attach MATLAB function handles explicitly.');
end
if hasFunctionHandle(raw)
    error('leotherm:AdapterExecutableInFile', ...
        'Descriptor files may not contain executable function handles.');
end
adapter = raw;
if ~isfield(adapter, 'handlers') || isempty(adapter.handlers), adapter.handlers = struct; end
if ~isstruct(adapter.handlers) || ~isscalar(adapter.handlers)
    error('leotherm:AdapterDescriptorFile', 'handlers must be a scalar structure.');
end
if ~isempty(fieldnames(opts.Handlers))
    names = fieldnames(opts.Handlers);
    for k = 1:numel(names)
        if ~isa(opts.Handlers.(names{k}), 'function_handle')
            error('leotherm:AdapterHandlerRequired', ...
                'Handlers.%s must be a MATLAB function handle.', names{k});
        end
        adapter.handlers.(names{k}) = opts.Handlers.(names{k});
    end
end
if ~isfield(adapter, 'provenance') || ~isstruct(adapter.provenance) || ~isscalar(adapter.provenance)
    adapter.provenance = struct;
end
adapter.provenance.descriptorPath = filePath;
adapter.provenance.descriptorFormat = lower(ext(2:end));
adapter = leotherm.adapter.validate(adapter);
adapter = leotherm.adapter.register(adapter);
report = struct('path', filePath, 'format', lower(ext(2:end)), ...
    'registeredId', adapter.id, 'schema', adapter.schema, ...
    'handlersAttachedInCode', fieldnames(opts.Handlers));
end

function opts = parseOptions(varargin)
opts.Handlers = struct;
if mod(numel(varargin), 2) ~= 0
    error('leotherm:AdapterDescriptorFile', 'Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(string(varargin{k})));
    switch name
        case 'handlers'
            value = varargin{k+1};
            if ~isstruct(value) || ~isscalar(value)
                error('leotherm:AdapterHandlerRequired', 'Handlers must be a scalar structure.');
            end
            opts.Handlers = value;
        otherwise
            error('leotherm:AdapterDescriptorFile', 'Unknown option: %s.', name);
    end
end
end

function descriptor = extractDescriptor(loaded)
if isfield(loaded, 'adapter'), descriptor = loaded.adapter; return; end
if isfield(loaded, 'descriptor'), descriptor = loaded.descriptor; return; end
names = fieldnames(loaded);
if numel(names) ~= 1
    error('leotherm:AdapterDescriptorFile', ...
        'MAT descriptor must contain adapter/descriptor or one unambiguous variable.');
end
descriptor = loaded.(names{1});
end

function tf = hasFunctionHandle(value)
tf = false;
if isa(value, 'function_handle')
    tf = true;
    return
end
if isstruct(value)
    fields = fieldnames(value);
    for k = 1:numel(fields)
        if hasFunctionHandle(value.(fields{k})), tf = true; return; end
    end
elseif iscell(value)
    for k = 1:numel(value)
        if hasFunctionHandle(value{k}), tf = true; return; end
    end
end
end
