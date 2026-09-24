function boundary = assembleThermalBoundaryConditions(nodeCount, conditions)
%ASSEMBLETHERMALBOUNDARYCONDITIONS Assemble flux/Robin boundary operators.
% Supports fixedTemperature metadata, prescribed heat flux, and linear
% convection (Robin) terms. Radiation is intentionally left nonlinear and
% is reported as an unsupported condition rather than silently linearized.
if ~isnumeric(nodeCount) || ~isscalar(nodeCount) || nodeCount ~= floor(nodeCount) || nodeCount < 1
    error('leotherm:InvalidThermalBoundary','nodeCount must be a positive integer.');
end
if nargin < 2 || isempty(conditions), conditions = struct([]); end
if ~isstruct(conditions), error('leotherm:InvalidThermalBoundary','conditions must be a structure array.'); end
K = sparse(nodeCount,nodeCount); loadW = zeros(nodeCount,1); fixed = struct('nodes',{},'temperatureK',{});
records = repmat(struct('type','','nodes',[]),numel(conditions),1);
for k=1:numel(conditions)
    c=conditions(k);
    if ~isfield(c,'type') || ~(ischar(c.type) || (isstring(c.type)&&isscalar(c.type)))
        error('leotherm:InvalidThermalBoundary','Condition %d requires type.',k);
    end
    type = lower(char(c.type)); nodes = validateNodes(c,nodeCount,k);
    records(k).type=type; records(k).nodes=nodes;
    switch type
        case 'fixedtemperature'
            if ~isfield(c,'temperatureK') || ~isnumeric(c.temperatureK) || ~isscalar(c.temperatureK) || ~isfinite(c.temperatureK) || c.temperatureK<=0
                error('leotherm:InvalidThermalBoundary','fixedTemperature requires positive temperatureK.');
            end
            fixed(end+1)=struct('nodes',nodes,'temperatureK',c.temperatureK); %#ok<AGROW>
        case 'heatflux'
            if ~isfield(c,'heatFluxW') || ~isnumeric(c.heatFluxW) || ~isvector(c.heatFluxW) || numel(c.heatFluxW)~=numel(nodes) || any(~isfinite(c.heatFluxW))
                error('leotherm:InvalidThermalBoundary','heatFluxW must align with nodes and be finite.');
            end
            loadW(nodes)=loadW(nodes)+c.heatFluxW(:);
        case {'convection','robin'}
            if ~isfield(c,'conductanceWK') || ~isfield(c,'ambientTemperatureK') || ~isnumeric(c.conductanceWK) || ~isnumeric(c.ambientTemperatureK)
                error('leotherm:InvalidThermalBoundary','convection requires conductanceWK and ambientTemperatureK.');
            end
            g = expandPositive(c.conductanceWK,numel(nodes),'conductanceWK');
            ta = expandPositive(c.ambientTemperatureK,numel(nodes),'ambientTemperatureK');
            K = K + sparse(nodes,nodes,g,nodeCount,nodeCount); loadW(nodes)=loadW(nodes)+g.*ta;
        case 'radiation'
            error('leotherm:UnsupportedThermalBoundary','Radiation boundary is nonlinear; provide an explicit Newton/Picard linearization.');
        otherwise
            error('leotherm:InvalidThermalBoundary','Unsupported boundary type: %s.',type);
    end
end
boundary=struct('stiffnessWK',K,'loadW',loadW,'fixedTemperature',fixed,'conditions',records, ...
    'formulation','flux_and_linear_robin_boundary_operator');
end
function nodes=validateNodes(c,n,k)
if ~isfield(c,'nodes') || ~isnumeric(c.nodes) || ~isvector(c.nodes) || isempty(c.nodes) || any(~isfinite(c.nodes)) || any(c.nodes~=floor(c.nodes)) || any(c.nodes<1) || any(c.nodes>n) || numel(unique(c.nodes))~=numel(c.nodes)
    error('leotherm:InvalidThermalBoundary','Condition %d nodes must be unique valid indices.',k);
end
nodes=c.nodes(:)';
end
function v=expandPositive(x,n,label)
if ~isnumeric(x)||~isvector(x)||(numel(x)~=1&&numel(x)~=n)||any(~isfinite(x(:)))||any(x(:)<=0), error('leotherm:InvalidThermalBoundary','%s must be positive finite scalar or node vector.',label); end
if isscalar(x), v=repmat(x,n,1); else, v=x(:); end
end
