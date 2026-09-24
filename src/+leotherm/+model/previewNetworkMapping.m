function preview = previewNetworkMapping(model, network, mapping)
%PREVIEWNETWORKMAPPING Preview explicit thermal-model writes without mutation.
%   PREVIEW = leotherm.model.previewNetworkMapping(MODEL, NETWORK, MAPPING)
%   never changes NETWORK.  Every proposed write is listed with its old/new
%   value and source.  Conflicts are surfaced verbatim; no node is matched by
%   name unless the mapping explicitly declares networkNodeName.

validation = leotherm.model.validateNetworkMapping(model, network, mapping);
nodes = localExchangeNodes(model);
entries = validation.entries;
changed = struct('exchangeNodeId', {}, 'networkNodeIndex', {}, ...
    'networkNodeName', {}, 'field', {}, 'oldValue', {}, 'newValue', {}, ...
    'source', {});
requested = struct('exchangeNodeId', {}, 'networkNodeIndex', {}, ...
    'networkNodeName', {}, 'field', {}, 'value', {}, 'source', {});
for k = 1:numel(entries)
    id = localEntryId(entries(k));
    nodeAt = find(strcmp(localNodeIds(nodes), id), 1);
    index = localTargetIndex(entries(k), network);
    if isempty(nodeAt) || index == 0, continue; end
    fields = localEntryFields(entries(k), validation.allowedFields);
    for j = 1:numel(fields)
        field = fields{j};
        if ~isfield(nodes(nodeAt), field), continue; end
        value = double(nodes(nodeAt).(field));
        source = localSource(model, id, field);
        requested(end+1) = struct('exchangeNodeId', id, ...
            'networkNodeIndex', index, 'networkNodeName', network.nodeNames{index}, ...
            'field', field, 'value', value, 'source', source); %#ok<AGROW>
        oldValue = double(network.(field)(index));
        if oldValue ~= value
            changed(end+1) = struct('exchangeNodeId', id, ...
                'networkNodeIndex', index, 'networkNodeName', network.nodeNames{index}, ...
                'field', field, 'oldValue', oldValue, 'newValue', value, ...
                'source', source); %#ok<AGROW>
        end
    end
end

preview = struct;
preview.schema = 'leotherm.thermal_model_mapping_preview.v1';
preview.valid = validation.valid;
preview.hasChanges = ~isempty(changed);
preview.changedFields = changed;
preview.requestedFields = requested;
preview.unmappedExchangeNodeIds = validation.unmappedExchangeNodeIds;
preview.conflicts = validation.conflicts;
if preview.valid
    candidate = network;
    for k = 1:numel(changed)
        candidate.(changed(k).field)(changed(k).networkNodeIndex) = changed(k).newValue;
    end
    try
        leotherm.validateNetwork(candidate);
    catch err
        preview.valid = false;
        preview.conflicts(end+1) = struct('code', 'invalid_result_network', ...
            'message', err.message, 'entryIndex', 0, ...
            'exchangeNodeId', '', 'networkNodeIndex', 0);
    end
end
preview.sources = struct('exchangeModel', localModelSource(model), ...
    'modelFingerprint', validation.modelFingerprint, ...
    'mappingFingerprint', validation.mappingFingerprint);
preview.confirmationToken = validation.confirmationToken;
preview.fingerprint = localFingerprint(struct(...
    'schema', preview.schema, 'valid', preview.valid, ...
    'changedFields', preview.changedFields, ...
    'unmappedExchangeNodeIds', {preview.unmappedExchangeNodeIds}, ...
    'conflicts', preview.conflicts, 'sources', preview.sources));
end

function fields = localEntryFields(entry, top)
fields = top;
if isfield(entry, 'allowedFields') && ~isempty(entry.allowedFields)
    fields = localFieldList(entry.allowedFields);
elseif isfield(entry, 'fields') && ~isempty(entry.fields)
    fields = localFieldList(entry.fields);
end
end

function fields = localFieldList(value)
if ischar(value) || (isstring(value) && isscalar(value)), value = {char(value)}; end
if isstring(value), value = cellstr(value(:)); end
fields = cellfun(@localText, value(:), 'UniformOutput', false);
end

function id = localEntryId(entry)
names = {'exchangeNodeId','exchangeNodeID','nodeId'};
id = '';
for k = 1:numel(names)
    if isfield(entry, names{k}), id = localText(entry.(names{k})); return; end
end
end

function index = localTargetIndex(entry, network)
index = 0;
if isfield(entry, 'networkNodeIndex'), value = entry.networkNodeIndex;
elseif isfield(entry, 'networkIndex'), value = entry.networkIndex;
else, value = [];
end
if ~isempty(value), index = double(value); return; end
if isfield(entry, 'networkNodeName') && ~isempty(entry.networkNodeName), name = entry.networkNodeName;
elseif isfield(entry, 'networkName') && ~isempty(entry.networkName), name = entry.networkName;
else, return;
end
index = find(strcmp(network.nodeNames, localText(name)), 1);
if isempty(index), index = 0; end
end

function nodes = localExchangeNodes(model)
if isfield(model, 'metadata')
    nodes = model.nodes;
else
    n = numel(model.network.nodeNames);
    nodes = repmat(struct('id', ''), n, 1);
    fields = {'capacityJK','internalPowerW','projectedAreaM2','radiatingAreaM2', ...
        'solarAbsorptivity','irEmissivity','initialTemperatureK'};
    for k = 1:n
        nodes(k).id = model.network.nodeNames{k};
        for j = 1:numel(fields), nodes(k).(fields{j}) = model.network.(fields{j})(k); end
    end
end
end

function ids = localNodeIds(nodes)
ids = cell(numel(nodes),1);
for k = 1:numel(nodes), ids{k} = localText(nodes(k).id); end
end

function source = localModelSource(model)
source = 'exchange_model';
if isfield(model, 'provenance') && isstruct(model.provenance) && isfield(model.provenance, 'source')
    source = localText(model.provenance.source);
elseif isfield(model, 'metadata') && isfield(model.metadata, 'modelId')
    source = localText(model.metadata.modelId);
end
if isempty(source), source = 'exchange_model'; end
end

function source = localSource(model, id, field)
source = [localModelSource(model), '.nodes[', id, '].', field];
end

function value = localText(value)
if isstring(value), value = char(value); end
if ~ischar(value), value = ''; end
end

function digest = localFingerprint(value)
encoded = jsonencode(value);
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(int8(uint8(encoded)));
bytes = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(bytes, 2)', 1, []));
end
