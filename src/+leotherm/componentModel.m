function component = componentModel(spec, varargin)
%COMPONENTMODEL Create an equivalent thermal component and map it to a node.
%   C = leotherm.componentModel(SPEC) validates/normalizes a component.
%   C = leotherm.componentModel(SPEC, NETWORK) also resolves nodeIndex and
%   nodeName against NETWORK.  SPEC may contain node, nodeIndex or nodeName.
%   C = leotherm.componentModel('map', C, NETWORK) maps an existing C.

network = [];
action = '';
if (ischar(spec) || (isstring(spec) && isscalar(spec))) && ~isempty(varargin)
    action = lower(char(spec));
    if strcmp(action, 'map')
        if numel(varargin) < 2, error('leotherm:InvalidComponent', 'map requires a component and network.'); end
        component = leotherm.validateComponentModel(varargin{1}, varargin{2});
        return;
    elseif strcmp(action, 'create')
        spec = varargin{1};
        if numel(varargin) >= 2
            network = varargin{2};
        end
    end
end
if ~isstruct(spec) || ~isscalar(spec), error('leotherm:InvalidComponent', 'Component specification must be a scalar structure.'); end
component = normalize(spec);
if ~isempty(network)
    component = leotherm.validateComponentModel(component, network);
elseif isempty(action) && ~isempty(varargin)
    component = leotherm.validateComponentModel(component, varargin{1});
else
    component = leotherm.validateComponentModel(component);
end
end

function c = normalize(s)
c = s;
if ~isfield(c, 'id') && isfield(c, 'name'), c.id = c.name; end
if ~isfield(c, 'name') && isfield(c, 'id'), c.name = c.id; end
if ~isfield(c, 'source'), error('leotherm:InvalidComponent', 'Component source is required.'); end
if ~isfield(c, 'uncertainty'), c.uncertainty = struct; end
if ~isfield(c, 'confidence'), c.confidence = 'unspecified'; end
if ~isfield(c, 'internalPowerW'), c.internalPowerW = 0; end
if ~isfield(c, 'contactConductanceWK'), c.contactConductanceWK = 0; end
if ~isfield(c, 'projectedAreaM2'), c.projectedAreaM2 = 0; end
if ~isfield(c, 'radiatingAreaM2'), c.radiatingAreaM2 = c.projectedAreaM2; end
if isfield(c, 'node')
    if isnumeric(c.node), c.nodeIndex = c.node; else, c.nodeName = c.node; end
end
if isfield(c, 'material') && (ischar(c.material) || (isstring(c.material) && isscalar(c.material)))
    c.material = leotherm.materialLibrary('get', c.material);
end
if ~isfield(c, 'capacityJK')
    if ~isfield(c, 'massKg') || ~isfield(c, 'material'), error('leotherm:MissingComponentThermalParameter', 'Provide capacityJK or massKg and material.'); end
    m = c.massKg; mat = leotherm.materialLibrary(c.material);
    if strcmp(mat.kind, 'constant'), c.capacityJK = m * mat.specificHeatJkgK; else, c.capacityJK = m * leotherm.materialLibrary('evaluate', mat, 293.15).specificHeatJkgK; end
end
if isfield(c, 'material')
    mat = leotherm.materialLibrary(c.material);
    if ~isfield(c, 'solarAbsorptivity') && isfield(mat, 'solarAbsorptivity'), c.solarAbsorptivity = mat.solarAbsorptivity; end
    if ~isfield(c, 'irEmissivity') && isfield(mat, 'irEmissivity'), c.irEmissivity = mat.irEmissivity; end
end
if ~isfield(c, 'solarAbsorptivity'), c.solarAbsorptivity = 0; end
if ~isfield(c, 'irEmissivity'), c.irEmissivity = 0; end
end
