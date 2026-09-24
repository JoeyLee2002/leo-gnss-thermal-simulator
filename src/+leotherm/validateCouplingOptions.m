function validateCouplingOptions(options, volumeMesh)
%VALIDATECOUPLINGOPTIONS Validate explicit contacts and fixed temperatures.
if nargin < 2, volumeMesh = []; end
if ~isstruct(options) || ~isscalar(options)
    error('leotherm:InvalidCouplingOptions', 'Coupling options must be a scalar structure.');
end
if ~isfield(options, 'contacts') || isempty(options.contacts)
    contacts = struct([]);
else
    contacts = options.contacts;
end
if ~isstruct(contacts)
    error('leotherm:InvalidCouplingOptions', 'contacts must be a structure array.');
end
nNode = 0;
if isstruct(volumeMesh) && isfield(volumeMesh, 'nodeCount'), nNode = volumeMesh.nodeCount; end
for k = 1:numel(contacts)
    required = {'leftNodes','rightNodes','conductanceWK'};
    if ~all(isfield(contacts, required))
        error('leotherm:InvalidCouplingOptions', 'Each contact needs leftNodes, rightNodes, and conductanceWK.');
    end
    left = validateIndices(contacts(k).leftNodes, 'leftNodes', nNode);
    right = validateIndices(contacts(k).rightNodes, 'rightNodes', nNode);
    if isempty(left) || isempty(right) || any(ismember(left, right))
        error('leotherm:InvalidCouplingOptions', 'Contact node sets must be nonempty and disjoint.');
    end
    g = contacts(k).conductanceWK;
    if ~isnumeric(g) || ~isscalar(g) || ~isfinite(g) || g <= 0
        error('leotherm:InvalidCouplingOptions', 'Contact conductance must be positive and finite.');
    end
end
if ~isfield(options, 'volumeThermal') || ~isstruct(options.volumeThermal) || ~isscalar(options.volumeThermal)
    error('leotherm:InvalidCouplingOptions', 'volumeThermal must be a scalar structure.');
end
thermal = options.volumeThermal;
if ~isfield(thermal, 'fixedNodeIndices') || isempty(thermal.fixedNodeIndices)
    fixed = zeros(0, 1);
else
    fixed = validateIndices(thermal.fixedNodeIndices, 'fixedNodeIndices', nNode);
end
if ~isempty(fixed)
    if ~isfield(thermal, 'fixedTemperatureK') || ~isnumeric(thermal.fixedTemperatureK) ...
            || ~isscalar(thermal.fixedTemperatureK) || ~isfinite(thermal.fixedTemperatureK) ...
            || thermal.fixedTemperatureK <= 0
        error('leotherm:InvalidCouplingOptions', 'fixedTemperatureK must be positive and finite.');
    end
end
end

function values = validateIndices(values, name, nNode)
if ~isnumeric(values) || ~isvector(values) || any(~isfinite(values)) ...
        || any(values ~= floor(values)) || any(values < 1) || numel(unique(values)) ~= numel(values)
    error('leotherm:InvalidCouplingOptions', '%s must contain unique positive integer indices.', name);
end
values = values(:);
if nNode > 0 && any(values > nNode)
    error('leotherm:InvalidCouplingOptions', '%s contains a node outside the loaded volume mesh.', name);
end
end
