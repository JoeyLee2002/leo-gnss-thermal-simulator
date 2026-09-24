function provenance = parameterProvenance(network, geometry, volumeMesh, options)
%PARAMETERPROVENANCE Create deterministic parameter-source metadata.
% The helper records declared source text without asserting calibration or
% engineering certification.  It is intentionally free of timestamps so
% model fingerprints remain reproducible.
if nargin < 4 || isempty(options), options = struct; end
source = 'user_supplied';
status = 'declared';
if isfield(options, 'provenance') && isstruct(options.provenance)
    supplied = options.provenance;
    if isfield(supplied, 'source') && ~isempty(supplied.source), source = char(string(supplied.source)); end
    if isfield(supplied, 'status') && ~isempty(supplied.status), status = char(string(supplied.status)); end
elseif isfield(options, 'source') && ~isempty(options.source)
    source = char(string(options.source));
end
if isempty(strtrim(source)), error('leotherm:modelInvalidProvenance', 'Provenance source cannot be empty.'); end
if isempty(strtrim(status)), error('leotherm:modelInvalidProvenance', 'Provenance status cannot be empty.'); end

provenance = struct('schema', 'leotherm.thermal_model_provenance.v1', ...
    'source', source, 'status', status, 'fields', struct);
provenance.fields.network = fieldRecord(network, 'network');
provenance.fields.geometry = fieldRecord(geometry, 'geometry');
provenance.fields.volumeMesh = fieldRecord(volumeMesh, 'volumeMesh');
if isfield(options, 'provenance') && isstruct(options.provenance)
    names = fieldnames(options.provenance);
    for k = 1:numel(names)
        name = names{k};
        if ~ismember(name, {'schema','source','status','fields'})
            provenance.(name) = options.provenance.(name);
        end
    end
    if isfield(options.provenance, 'fields') && isstruct(options.provenance.fields)
        provenance.fields = mergeFields(provenance.fields, options.provenance.fields);
    end
end
end

function record = fieldRecord(value, label)
record = struct('source', 'inferred_from_input', 'status', 'inferred', 'label', label);
if isempty(value), record.source = 'not_provided'; record.status = 'absent'; return; end
if isfield(value, 'thermalParameterProvenance')
    record.source = char(string(value.thermalParameterProvenance));
    record.status = 'declared';
elseif isfield(value, 'sourcePath') && ~isempty(value.sourcePath)
    record.source = char(string(value.sourcePath));
end
end

function out = mergeFields(base, extra)
out = base;
names = fieldnames(extra);
for k = 1:numel(names), out.(names{k}) = extra.(names{k}); end
end
