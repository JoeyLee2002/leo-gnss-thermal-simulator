function p = validateDeviceCalibrationProfile(p, network)
%VALIDATEDEVICECALIBRATIONPROFILE Validate a profile against its exact network.
% Preserve row order: free values are ordered by parameters.estimate. Numeric
% columns are normalized to double and columns to the template order. Locked
% rows may retain valid ranges and uncertainty for later reactivation.

template = leotherm.deviceCalibrationProfile(network);
required = {'schemaVersion', 'name', 'nodeNames', 'referenceNetwork', 'parameters'};
if ~isstruct(p) || ~isscalar(p) || ~all(isfield(p, required))
    invalid('Profile must be a scalar structure containing all schema fields.');
end
if ~isnumeric(p.schemaVersion) || ~isreal(p.schemaVersion) ...
        || ~isscalar(p.schemaVersion) || p.schemaVersion ~= 1
    invalid('Profile schemaVersion must be 1.');
end
if ~((ischar(p.name) && isrow(p.name)) ...
        || (isstring(p.name) && isscalar(p.name)))
    invalid('Profile name must be a character vector or string scalar.');
end
if ismissing(string(p.name)) || strlength(strtrim(string(p.name))) == 0
    invalid('Profile name must not be missing or blank.');
end
if ~isequaln(p.nodeNames, network.nodeNames)
    invalid('Profile nodeNames must match the network, including node order.');
end
if ~isequaln(p.referenceNetwork, network)
    invalid('Profile referenceNetwork differs from the supplied network; rebuild the profile.');
end

expected = template.parameters;
columns = expected.Properties.VariableNames;
if ~istable(p.parameters) || width(p.parameters) ~= numel(columns) ...
        || ~all(ismember(columns, p.parameters.Properties.VariableNames)) ...
        || height(p.parameters) ~= height(expected)
    invalid('Profile parameters must contain exactly the template columns and rows.');
end
t = p.parameters(:, columns);
textColumns = {'field', 'node', 'peer', 'unit', 'evidence', 'kind'};
for k = 1:numel(textColumns)
    value = t.(textColumns{k});
    if ~isstring(value) || ~isequal(size(value), [height(t), 1]) ...
            || any(ismissing(value))
        invalid('Parameter %s must be a nonmissing string column.', textColumns{k});
    end
end
numericColumns = {'nominal', 'lower', 'upper', 'priorSigma'};
for k = 1:numel(numericColumns)
    value = t.(numericColumns{k});
    if ~isnumeric(value) || ~isreal(value) ...
            || ~isequal(size(value), [height(t), 1]) || any(~isfinite(value))
        invalid('Parameter %s must be a finite real numeric column.', numericColumns{k});
    end
    t.(numericColumns{k}) = double(value);
end
if ~islogical(t.estimate) || ~isequal(size(t.estimate), [height(t), 1])
    invalid('Parameter estimate must be a logical column, not numeric or text.');
end

% Compare structured keys, without evaluating paths or joining node names.
keys = {'field', 'node', 'peer'};
[known, indices] = ismember(t(:, keys), expected(:, keys));
if ~all(known) || numel(unique(indices)) ~= height(expected)
    invalid('Parameter keys must cover the template exactly, without duplicate or reversed edges.');
end
if any(t.unit ~= expected.unit(indices))
    invalid('Parameter units must match the template.');
end
if any(t.nominal ~= expected.nominal(indices))
    invalid('Parameter nominal values must equal the supplied network values.');
end
if any(t.lower > t.nominal | t.upper < t.nominal)
    invalid('Every parameter range must contain its nominal value.');
end
if any(t.priorSigma < 0)
    invalid('Parameter priorSigma cannot be negative.');
end
if any(~ismember(t.kind, ["unverified", "physical", "effective"]))
    invalid('Parameter kind must be unverified, physical, or effective.');
end

capacity = t.field == "capacityJK";
optics = t.field == "solarAbsorptivity" | t.field == "irEmissivity";
nonnegative = ~capacity & ~optics;
if any(t.lower(capacity) <= 0 | t.upper(capacity) <= 0)
    invalid('Heat-capacity bounds must be positive.');
end
if any(t.lower(nonnegative) < 0 | t.upper(nonnegative) < 0)
    invalid('Power, area, and conductance bounds must be nonnegative.');
end
if any(t.lower(optics) < 0 | t.upper(optics) > 1)
    invalid('Optical-property bounds must lie in [0, 1].');
end
active = t.estimate;
if any(t.lower(active) >= t.upper(active))
    invalid('Estimated parameters require lower < upper.');
end
if any(t.priorSigma(active) <= 0)
    invalid('Estimated parameters require positive priorSigma.');
end
if any(strlength(strtrim(t.evidence(active))) == 0)
    invalid('Estimated parameters require nonblank evidence or an explicit assumption.');
end
if any(t.kind(active) == "unverified")
    invalid('Estimated parameters require physical or effective kind.');
end
p.schemaVersion = 1;
p.parameters = t;
end

function invalid(message, varargin)
error('leotherm:DeviceCalibrationProfile', message, varargin{:});
end
