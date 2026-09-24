function component = validateComponentModel(component, network)
%VALIDATECOMPONENTMODEL Validate equivalent component parameters and node map.
if ~isstruct(component) || ~isscalar(component), invalid('Component must be a scalar structure.'); end
for f = {'id','name','source'}
    if ~isfield(component, f{1}) || ~(ischar(component.(f{1})) || (isstring(component.(f{1})) && isscalar(component.(f{1})))) || strlength(strtrim(string(component.(f{1})))) == 0
        invalid('component.%s is required and must be non-empty text.', f{1});
    end
end
for f = {'capacityJK','internalPowerW','contactConductanceWK','projectedAreaM2','radiatingAreaM2'}
    if ~isfield(component, f{1}) || ~isnumeric(component.(f{1})) || ~isscalar(component.(f{1})) || ~isfinite(component.(f{1})) || component.(f{1}) < 0
        invalid('component.%s must be a finite non-negative scalar.', f{1});
    end
end
if component.capacityJK <= 0, invalid('component.capacityJK must be strictly positive.'); end
for f = {'solarAbsorptivity','irEmissivity'}
    if ~isfield(component, f{1}) || ~isnumeric(component.(f{1})) || ~isscalar(component.(f{1})) || ~isfinite(component.(f{1})) || component.(f{1}) < 0 || component.(f{1}) > 1
        invalid('component.%s must be a scalar in [0,1].', f{1});
    end
end
if component.radiatingAreaM2 > 0 && component.projectedAreaM2 == 0
    invalid('radiatingAreaM2 cannot be positive when projectedAreaM2 is zero.');
end
if isnumeric(component.uncertainty)
    if any(~isfinite(component.uncertainty(:))) || any(component.uncertainty(:) < 0), invalid('Uncertainty values must be finite and non-negative.'); end
elseif isstruct(component.uncertainty) && isscalar(component.uncertainty)
    uf = fieldnames(component.uncertainty);
    for i = 1:numel(uf)
        u = component.uncertainty.(uf{i});
        if ~isnumeric(u) || any(~isfinite(u(:))) || any(u(:) < 0), invalid('Uncertainty values must be finite and non-negative.'); end
    end
else
    invalid('component.uncertainty must be numeric or a scalar structure.');
end
if isnumeric(component.confidence)
    if ~isscalar(component.confidence) || ~isfinite(component.confidence) || component.confidence < 0 || component.confidence > 1, invalid('Numeric confidence must lie in [0,1].'); end
elseif ~(ischar(component.confidence) || (isstring(component.confidence) && isscalar(component.confidence))) || strlength(strtrim(string(component.confidence))) == 0
    invalid('confidence must be text or a numeric value in [0,1].');
end
if isfield(component, 'material')
    component.material = leotherm.materialLibrary(component.material);
end
if nargin >= 2 && ~isempty(network)
    if ~isstruct(network) || ~isfield(network, 'nodeNames'), invalid('network must provide nodeNames.'); end
    names = network.nodeNames;
    if ~iscellstr(names) && ~(isstring(names) && isvector(names)), invalid('network.nodeNames must be text names.'); end
    n = numel(names);
    if isfield(component, 'nodeIndex')
        idx = component.nodeIndex;
        if ~isnumeric(idx) || ~isscalar(idx) || ~isfinite(idx) || idx ~= floor(idx) || idx < 1 || idx > n, invalid('nodeIndex must identify an existing network node.'); end
    elseif isfield(component, 'nodeName')
        idx = find(strcmp(string(names), string(component.nodeName)), 1);
        if isempty(idx), invalid('nodeName does not exist in network.nodeNames.'); end
        component.nodeIndex = idx;
    else
        invalid('Component must provide nodeIndex or nodeName for network mapping.');
    end
    component.nodeName = char(string(names{component.nodeIndex}));
    component.networkPatch = struct('nodeIndex', component.nodeIndex, ...
        'capacityJK', component.capacityJK, 'internalPowerW', component.internalPowerW, ...
        'projectedAreaM2', component.projectedAreaM2, 'radiatingAreaM2', component.radiatingAreaM2, ...
        'solarAbsorptivity', component.solarAbsorptivity, 'irEmissivity', component.irEmissivity);
else
    if ~isfield(component, 'nodeIndex') && ~isfield(component, 'nodeName'), invalid('Component must provide nodeIndex or nodeName.'); end
end
component.validated = true;
end
function invalid(message, varargin), error('leotherm:InvalidComponent', message, varargin{:}); end
