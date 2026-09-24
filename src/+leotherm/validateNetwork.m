function validateNetwork(network)
%VALIDATENETWORK Validate thermal-network dimensions and physical constraints.

if ~isstruct(network) || ~isscalar(network)
    invalid('network must be a scalar structure.');
end
required = {'name', 'nodeNames', 'capacityJK', 'initialTemperatureK', ...
    'internalPowerW', 'projectedAreaM2', 'radiatingAreaM2', 'normalBody', ...
    'solarAbsorptivity', 'irEmissivity', 'conductanceWK', 'bias'};
for k = 1:numel(required)
    if ~isfield(network, required{k})
        invalid('network.%s is required.', required{k});
    end
end
if ~((ischar(network.name) && isrow(network.name)) ...
        || (isstring(network.name) && isscalar(network.name)))
    invalid('network.name must be a character vector or string scalar.');
end
if ~iscellstr(network.nodeNames) || isempty(network.nodeNames) ...
        || ~isvector(network.nodeNames)
    invalid('network.nodeNames must be a nonempty cell vector of names.');
end
if numel(unique(network.nodeNames)) ~= numel(network.nodeNames)
    invalid('network.nodeNames must be unique.');
end
n = numel(network.nodeNames);
vectors = {'capacityJK', 'initialTemperatureK', 'internalPowerW', ...
    'projectedAreaM2', 'radiatingAreaM2', 'solarAbsorptivity', 'irEmissivity'};
for k = 1:numel(vectors)
    value = network.(vectors{k});
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || numel(value) ~= n
        invalid('network.%s must contain one real value per node.', vectors{k});
    end
    if any(~isfinite(value))
        invalid('network.%s contains non-finite values.', vectors{k});
    end
end
if ~isnumeric(network.normalBody) || ~isreal(network.normalBody) ...
        || ~isequal(size(network.normalBody), [n, 3]) ...
        || any(~isfinite(network.normalBody), 'all')
    invalid('network.normalBody must be a finite number-of-nodes by 3 matrix.');
end
normalLength = vecnorm(network.normalBody, 2, 2);
isZero = normalLength <= 1e-12;
isUnit = abs(normalLength - 1) <= 1e-8;
if any(~isZero & ~isUnit)
    invalid('Each network.normalBody row must be zero or a unit vector.');
end
if any(network.projectedAreaM2(:) > 0 & ~isUnit)
    invalid('Nodes with positive projected area must have a unit normalBody row.');
end
conductance = network.conductanceWK;
if ~isnumeric(conductance) || ~isreal(conductance) ...
        || ~isequal(size(conductance), [n, n]) || any(~isfinite(conductance), 'all')
    invalid('network.conductanceWK must be a finite N-by-N real matrix.');
end
if max(abs(conductance - conductance'), [], 'all') >= 1e-12
    invalid('network.conductanceWK must be symmetric.');
end
if any(diag(conductance) ~= 0)
    invalid('network.conductanceWK diagonal must be zero.');
end
if any(conductance(:) < 0)
    invalid('Network conductances cannot be negative.');
end
if any(network.capacityJK <= 0)
    invalid('All network heat capacities must be positive.');
end
if any(network.initialTemperatureK <= 0)
    invalid('All network initial temperatures must be positive Kelvin values.');
end
if any(network.internalPowerW < 0)
    invalid('Network internal powers cannot be negative.');
end
if any(network.projectedAreaM2 < 0) || any(network.radiatingAreaM2 < 0)
    invalid('Network areas cannot be negative.');
end
if any(network.solarAbsorptivity < 0 | network.solarAbsorptivity > 1)
    invalid('Network solar absorptivity must lie in [0, 1].');
end
if any(network.irEmissivity < 0 | network.irEmissivity > 1)
    invalid('Network IR emissivity must lie in [0, 1].');
end

if ~isstruct(network.bias) || ~isscalar(network.bias)
    invalid('network.bias must be a scalar structure.');
end
biasFields = {'linearMPerK', 'quadraticNode', 'quadraticMPerK2'};
for k = 1:numel(biasFields)
    if ~isfield(network.bias, biasFields{k})
        invalid('network.bias.%s is required.', biasFields{k});
    end
end
linear = network.bias.linearMPerK;
if ~isnumeric(linear) || ~isreal(linear) || ~isvector(linear) ...
        || numel(linear) ~= n || any(~isfinite(linear))
    invalid('network.bias.linearMPerK must contain one finite value per node.');
end
quadraticNode = network.bias.quadraticNode;
if ~isnumeric(quadraticNode) || ~isscalar(quadraticNode) ...
        || ~isfinite(quadraticNode) || quadraticNode ~= floor(quadraticNode) ...
        || quadraticNode < 1 || quadraticNode > n
    invalid('network.bias.quadraticNode must be a valid node index.');
end
quadratic = network.bias.quadraticMPerK2;
if ~isnumeric(quadratic) || ~isscalar(quadratic) || ~isreal(quadratic) ...
        || ~isfinite(quadratic)
    invalid('network.bias.quadraticMPerK2 must be one finite real value.');
end
if isfield(network, 'roles')
    if ~isstruct(network.roles) || ~isscalar(network.roles)
        invalid('network.roles must be a scalar structure.');
    end
    roleNames = {'response', 'antenna', 'oscillator'};
    for k = 1:numel(roleNames)
        if ~isfield(network.roles, roleNames{k}) || isempty(network.roles.(roleNames{k}))
            continue
        end
        index = network.roles.(roleNames{k});
        if ~isnumeric(index) || ~isscalar(index) || ~isfinite(index) ...
                || index ~= floor(index) || index < 1 || index > n
            invalid('network.roles.%s must be empty or a valid node index.', ...
                roleNames{k});
        end
    end
end
end

function invalid(message, varargin)
error('leotherm:InvalidNetwork', message, varargin{:});
end
