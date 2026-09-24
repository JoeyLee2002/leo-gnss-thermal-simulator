function [networkOut, result] = applyNetworkMapping(model, network, mapping, varargin)
%APPLYNETWORKMAPPING Apply a reviewed explicit mapping to a copied network.
%   [NEWNETWORK, RESULT] = leotherm.model.applyNetworkMapping(...,
%   'ConfirmationToken', PREVIEW.confirmationToken) applies only when the
%   token matches a fresh preview.  'AllowApply', true is the programmatic
%   alternative.  The input NETWORK is never modified in place.

opts = parseOptions(varargin{:});
preview = leotherm.model.previewNetworkMapping(model, network, mapping);
if ~preview.valid || ~isempty(preview.conflicts)
    error('leotherm:NetworkMappingConflict', ...
        'Mapping cannot be applied because the preview contains %d conflict(s).', ...
        numel(preview.conflicts));
end
confirmed = opts.AllowApply;
if ~confirmed && ~isempty(opts.ConfirmationToken)
    confirmed = strcmpi(opts.ConfirmationToken, preview.confirmationToken);
end
if ~confirmed
    error('leotherm:NetworkMappingConfirmationRequired', ...
        ['Apply requires a matching preview.confirmationToken or ', ...
         '''AllowApply'', true.']);
end

networkOut = network;
for k = 1:numel(preview.changedFields)
    change = preview.changedFields(k);
    networkOut.(change.field)(change.networkNodeIndex) = change.newValue;
end
leotherm.validateNetwork(networkOut);

provenance = struct;
provenance.schema = 'leotherm.thermal_model_network_mapping_provenance.v1';
provenance.source = preview.sources.exchangeModel;
provenance.sourceModelFingerprint = preview.sources.modelFingerprint;
provenance.mappingFingerprint = preview.sources.mappingFingerprint;
provenance.previewFingerprint = preview.fingerprint;
provenance.changedFields = preview.changedFields;
provenance.unmappedExchangeNodeIds = preview.unmappedExchangeNodeIds;
provenance.confirmationMethod = ternary(opts.AllowApply, 'allowApply', 'confirmationToken');
networkOut.thermalModelMappingProvenance = provenance;
if ~isfield(networkOut, 'provenance') || isempty(networkOut.provenance)
    networkOut.provenance = struct;
end
if isstruct(networkOut.provenance) && isscalar(networkOut.provenance)
    networkOut.provenance.thermalModelMapping = provenance;
end

result = struct('schema', 'leotherm.thermal_model_mapping_apply.v1', ...
    'applied', true, 'changedFieldCount', numel(preview.changedFields), ...
    'preview', preview, 'provenance', provenance);
end

function opts = parseOptions(varargin)
opts = struct('AllowApply', false, 'ConfirmationToken', '');
if numel(varargin) == 1 && isstruct(varargin{1}) && isscalar(varargin{1})
    supplied = varargin{1};
    if isfield(supplied, 'allowApply'), opts.AllowApply = logicalScalar(supplied.allowApply, 'allowApply'); end
    if isfield(supplied, 'AllowApply'), opts.AllowApply = logicalScalar(supplied.AllowApply, 'AllowApply'); end
    if isfield(supplied, 'confirmationToken'), opts.ConfirmationToken = textScalar(supplied.confirmationToken, 'confirmationToken'); end
    if isfield(supplied, 'ConfirmationToken'), opts.ConfirmationToken = textScalar(supplied.ConfirmationToken, 'ConfirmationToken'); end
    known = {'allowApply','AllowApply','confirmationToken','ConfirmationToken'};
    unknown = setdiff(fieldnames(supplied), known);
    if ~isempty(unknown), error('leotherm:NetworkMappingOptions', 'Unknown option: %s.', unknown{1}); end
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('leotherm:NetworkMappingOptions', 'Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    switch name
        case 'allowapply'
            opts.AllowApply = logicalScalar(varargin{k+1}, 'AllowApply');
        case 'confirmationtoken'
            opts.ConfirmationToken = textScalar(varargin{k+1}, 'ConfirmationToken');
        otherwise
            error('leotherm:NetworkMappingOptions', 'Unknown option: %s.', char(varargin{k}));
    end
end
end

function value = logicalScalar(value, name)
if ~(islogical(value) || isnumeric(value)) || ~isscalar(value) || ~isfinite(double(value))
    error('leotherm:NetworkMappingOptions', '%s must be a scalar logical value.', name);
end
value = logical(value);
end

function value = textScalar(value, name)
if isstring(value) && isscalar(value), value = char(value); end
if ~ischar(value) || ~isrow(value)
    error('leotherm:NetworkMappingOptions', '%s must be text.', name);
end
end

function out = ternary(condition, yesValue, noValue)
if condition, out = yesValue; else, out = noValue; end
end
