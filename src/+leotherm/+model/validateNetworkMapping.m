function report = validateNetworkMapping(model, network, mapping)
%VALIDATENETWORKMAPPING Validate an explicit exchange-node/network mapping.
%   REPORT = leotherm.model.validateNetworkMapping(MODEL, NETWORK, MAPPING)
%   validates the v1 exchange model, the existing lumped network, and an
%   explicit one-to-one mapping.  Mapping conflicts are returned (rather
%   than guessed or repaired) in REPORT.conflicts.  Malformed models and
%   networks raise an error using the existing validators.

if nargin ~= 3
    error('leotherm:NetworkMappingArguments', ...
        'model, network and mapping are required.');
end
validateExchangeModel(model);
leotherm.validateNetwork(network);
if ~isstruct(mapping) || ~isscalar(mapping)
    error('leotherm:NetworkMappingInvalid', ...
        'mapping must be a scalar structure.');
end
if isfield(mapping, 'schema') && ~strcmp(textValue(mapping.schema), ...
        'leotherm.thermal_model_mapping.v1')
    error('leotherm:NetworkMappingInvalid', ...
        'mapping.schema must equal leotherm.thermal_model_mapping.v1.');
end

nodes = exchangeNodes(model);
entries = mappingEntries(mapping);
allowedTop = declaredFields(mapping, 'allowedFields');
if isempty(allowedTop) && isfield(mapping, 'writeFields')
    allowedTop = declaredFields(mapping, 'writeFields');
end
if isempty(allowedTop) && isfield(mapping, 'fields') && ~isstruct(mapping.fields)
    allowedTop = declaredFields(mapping, 'fields');
end

report = struct;
report.valid = true;
report.conflicts = struct('code', {}, 'message', {}, 'entryIndex', {}, ...
    'exchangeNodeId', {}, 'networkNodeIndex', {});
report.unmappedExchangeNodeIds = nodeIds(nodes);
report.entries = entries;
report.allowedFields = allowedTop;
report.exchangeNodeIds = nodeIds(nodes);
report.modelFingerprint = valueFingerprint(model);
report.mappingFingerprint = valueFingerprint(mapping);
report.confirmationToken = valueFingerprint(struct(...
    'model', report.modelFingerprint, 'mapping', report.mappingFingerprint));

if isempty(entries)
    addConflict('empty_mapping', 'mapping.entries must contain at least one entry.', 0, '', 0);
else
    seenExchange = {};
    seenNetwork = [];
    for k = 1:numel(entries)
        entry = entries(k);
        exchangeId = entryExchangeId(entry, k);
        if any(strcmp(seenExchange, exchangeId))
            addConflict('duplicate_exchange_node', ...
                'An exchange node id appears more than once.', k, exchangeId, 0);
        end
        seenExchange{end+1} = exchangeId; %#ok<AGROW>
        nodeIndex = resolveNetworkNode(entry, network, k);
        if nodeIndex == 0
            addConflict('unknown_network_node', ...
                'mapping references a network node that is not present.', ...
                k, exchangeId, 0);
        end
        if nodeIndex > 0
            if any(seenNetwork == nodeIndex)
                addConflict('duplicate_network_node', ...
                    'A network node is targeted by more than one exchange node.', ...
                    k, exchangeId, nodeIndex);
            end
            seenNetwork(end+1) = nodeIndex; %#ok<AGROW>
        end
        nodeAt = find(strcmp(nodeIds(nodes), exchangeId), 1);
        if isempty(nodeAt)
            addConflict('unknown_exchange_node', ...
                'mapping references an exchange node id that is not present.', ...
                k, exchangeId, nodeIndex);
        else
            report.unmappedExchangeNodeIds(strcmp(report.unmappedExchangeNodeIds, exchangeId)) = [];
            fields = entryFields(entry, allowedTop);
            for j = 1:numel(fields)
                field = fields{j};
                if ~ismember(field, supportedFields())
                    addConflict('unsupported_field', ...
                        'The requested write field is not supported.', k, exchangeId, nodeIndex);
                elseif ~isfield(nodes(nodeAt), field)
                    addConflict('missing_exchange_field', ...
                        'The exchange node does not declare the requested field.', ...
                        k, exchangeId, nodeIndex);
                else
                    checkFieldValue(nodes(nodeAt).(field), field, k, exchangeId, nodeIndex);
                end
            end
        end
    end
end
report.valid = isempty(report.conflicts);

    function addConflict(code, message, entryIndex, exchangeNodeId, networkNodeIndex)
        c = struct('code', code, 'message', message, 'entryIndex', entryIndex, ...
            'exchangeNodeId', exchangeNodeId, 'networkNodeIndex', networkNodeIndex);
        conflicts = report.conflicts;
        conflicts(end+1) = c;
        report.conflicts = conflicts;
    end
end

function fields = supportedFields()
fields = {'capacityJK','internalPowerW','projectedAreaM2','radiatingAreaM2', ...
    'solarAbsorptivity','irEmissivity','initialTemperatureK'};
end

function validateExchangeModel(model)
if ~isstruct(model) || ~isscalar(model)
    error('leotherm:NetworkMappingInvalidModel', 'model must be a scalar structure.');
end
if isfield(model, 'metadata') && isfield(model, 'nodes')
    % Raw exchange representation.  This checks schema, canonical units,
    % finite values and container shape without normalising any field.
    leotherm.io.validateThermalModel(model);
elseif isfield(model, 'schemaVersion') && isfield(model, 'network')
    leotherm.model.validate(model);
else
    error('leotherm:NetworkMappingInvalidModel', ...
        'model must be a leotherm.thermal_model.v1 exchange model.');
end
end

function nodes = exchangeNodes(model)
if isfield(model, 'metadata')
    nodes = model.nodes;
    if isempty(nodes), nodes = struct('id', {}, 'name', {}); end
    if ~isstruct(nodes) || ~isvector(nodes)
        error('leotherm:NetworkMappingInvalidModel', 'model.nodes must be a structure vector.');
    end
else
    n = numel(model.network.nodeNames);
    nodes = repmat(struct('id', '', 'name', ''), n, 1);
    for k = 1:n
        nodes(k).id = model.network.nodeNames{k};
        nodes(k).name = model.network.nodeNames{k};
        for f = supportedFields()
            name = f{1};
            nodes(k).(name) = model.network.(name)(k);
        end
    end
end
for k = 1:numel(nodes)
    if ~isfield(nodes(k), 'id') || ~isText(nodes(k).id) || isempty(textValue(nodes(k).id))
        error('leotherm:NetworkMappingInvalidModel', ...
            'Every exchange node must have a nonempty text id.');
    end
end
ids = nodeIds(nodes);
if numel(unique(ids)) ~= numel(ids)
    error('leotherm:NetworkMappingInvalidModel', 'Exchange node ids must be unique.');
end
end

function entries = mappingEntries(mapping)
if ~isfield(mapping, 'entries')
    entries = struct('exchangeNodeId', {}, 'networkNodeIndex', {});
    return;
end
entries = mapping.entries;
if ~isstruct(entries) || (~isempty(entries) && ~isvector(entries))
    error('leotherm:NetworkMappingInvalid', 'mapping.entries must be a structure vector.');
end
end

function fields = declaredFields(mapping, name)
fields = {};
if ~isfield(mapping, name) || isempty(mapping.(name)), return; end
value = mapping.(name);
if ischar(value) || (isstring(value) && isscalar(value)), value = {char(value)}; end
if isstring(value), value = cellstr(value(:)); end
if ~iscell(value) || ~all(cellfun(@isText, value))
    error('leotherm:NetworkMappingInvalid', '%s must be text or a cell vector of text.', name);
end
fields = cellfun(@textValue, value(:), 'UniformOutput', false);
if numel(unique(fields)) ~= numel(fields)
    error('leotherm:NetworkMappingInvalid', '%s must not contain duplicates.', name);
end
unknown = setdiff(fields, supportedFields());
if ~isempty(unknown)
    error('leotherm:NetworkMappingInvalid', 'Unsupported write field: %s.', unknown{1});
end
end

function fields = entryFields(entry, top)
fields = top;
if isfield(entry, 'allowedFields') && ~isempty(entry.allowedFields)
    fields = declaredFields(entry, 'allowedFields');
elseif isfield(entry, 'fields') && ~isempty(entry.fields)
    if isstruct(entry.fields)
        error('leotherm:NetworkMappingInvalid', 'entry.fields must be a field list.');
    end
    fields = declaredFields(entry, 'fields');
end
end

function id = entryExchangeId(entry, k)
names = {'exchangeNodeId','exchangeNodeID','nodeId'};
id = '';
for j = 1:numel(names)
    if isfield(entry, names{j}), id = textValue(entry.(names{j})); break; end
end
if isempty(id)
    error('leotherm:NetworkMappingInvalid', ...
        'Mapping entry %d must declare exchangeNodeId.', k);
end
end

function index = resolveNetworkNode(entry, network, k)
hasIndex = (isfield(entry, 'networkNodeIndex') && ~isempty(entry.networkNodeIndex)) ...
    || (isfield(entry, 'networkIndex') && ~isempty(entry.networkIndex));
hasName = (isfield(entry, 'networkNodeName') && ~isempty(entry.networkNodeName)) ...
    || (isfield(entry, 'networkName') && ~isempty(entry.networkName));
if hasIndex && hasName
    error('leotherm:NetworkMappingInvalid', ...
        'Entry %d must use either networkNodeIndex or networkNodeName, not both.', k);
end
index = 0;
if hasIndex
    f = 'networkNodeIndex'; if ~isfield(entry,f) || isempty(entry.(f)), f = 'networkIndex'; end
    value = entry.(f);
    if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || value ~= floor(value)
        error('leotherm:NetworkMappingInvalid', ...
            'Entry %d network node index must be a finite integer.', k);
    end
    if value >= 1 && value <= numel(network.nodeNames)
        index = double(value);
    end
elseif hasName
    f = 'networkNodeName'; if ~isfield(entry,f) || isempty(entry.(f)), f = 'networkName'; end
    if ~isText(entry.(f)), error('leotherm:NetworkMappingInvalid', ...
            'Entry %d network node name must be text.', k); end
    index = find(strcmp(network.nodeNames, textValue(entry.(f))), 1);
    if isempty(index), index = 0; end
else
    error('leotherm:NetworkMappingInvalid', ...
        'Entry %d must declare an explicit network node target.', k);
end
end

function checkFieldValue(value, field, ~, exchangeId, ~)
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
    error('leotherm:NetworkMappingInvalidValue', ...
        'Exchange field %s for node %s must be one finite numeric scalar.', field, exchangeId);
end
v = double(value);
switch field
    case {'capacityJK','initialTemperatureK'}
        ok = v > 0;
    case {'internalPowerW','projectedAreaM2','radiatingAreaM2'}
        ok = v >= 0;
    case {'solarAbsorptivity','irEmissivity'}
        ok = v >= 0 && v <= 1;
    otherwise
        ok = false;
end
if ~ok
    error('leotherm:NetworkMappingInvalidValue', ...
        'Exchange field %s for node %s is outside its physical range.', field, exchangeId);
end
end

function ids = nodeIds(nodes)
ids = cell(numel(nodes), 1);
for k = 1:numel(nodes), ids{k} = textValue(nodes(k).id); end
end

function value = textValue(value)
if isstring(value), value = char(value); end
if ~ischar(value), value = ''; end
end

function tf = isText(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end

function digest = valueFingerprint(value)
try
    encoded = jsonencode(value);
catch
    encoded = evalc('disp(value)');
end
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(int8(uint8(encoded)));
bytes = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(bytes, 2)', 1, []));
end
