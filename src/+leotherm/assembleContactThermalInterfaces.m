function contact = assembleContactThermalInterfaces(nodeCount, interfaces)
%ASSEMBLECONTACTTHERMALINTERFACES Assemble conservative contact conductance.
%   contact = leotherm.assembleContactThermalInterfaces(N, I) builds the
%   Laplacian contribution for thermal contacts.  Each entry of I contains
%   leftNodes, rightNodes and a positive conductanceWK.  A scalar
%   conductance is distributed uniformly over the two node sets; a matrix
%   conductanceWK is interpreted pairwise (left-by-right, W/K).
%
%   The returned stiffnessWK is symmetric positive semidefinite with zero
%   row sums.  Thus every contact transfers Q=G*(T_left-T_right), while
%   internal heat is exactly cancelled in the global energy ledger.
if ~isnumeric(nodeCount) || ~isscalar(nodeCount) || ~isfinite(nodeCount) || ...
        nodeCount ~= floor(nodeCount) || nodeCount < 1
    error('leotherm:InvalidContactInterface','nodeCount must be a positive integer.');
end
if nargin < 2 || isempty(interfaces), interfaces = struct([]); end
if ~isstruct(interfaces)
    error('leotherm:InvalidContactInterface','interfaces must be a structure array.');
end
rows = zeros(0,1); cols = zeros(0,1); vals = zeros(0,1);
records = repmat(struct('name','','leftNodes',[],'rightNodes',[],'conductanceWK',[]), numel(interfaces), 1);
pairKeys = strings(0,1);
for k = 1:numel(interfaces)
    item = interfaces(k);
    required = {'leftNodes','rightNodes','conductanceWK'};
    for f = 1:numel(required)
        if ~isfield(item, required{f})
            error('leotherm:InvalidContactInterface','Interface %d requires %s.',k,required{f});
        end
    end
    left = validateNodes(item.leftNodes,nodeCount,'leftNodes',k);
    right = validateNodes(item.rightNodes,nodeCount,'rightNodes',k);
    if intersect(left,right)
        error('leotherm:InvalidContactInterface','Interface %d left/right node sets overlap.',k);
    end
    g = item.conductanceWK;
    if ~isnumeric(g) || ~isreal(g) || isempty(g) || any(~isfinite(g(:))) || any(g(:) <= 0)
        error('leotherm:InvalidContactInterface','Interface %d conductanceWK must be positive finite.',k);
    end
    if isscalar(g)
        g = repmat(g/numel(left)/numel(right),numel(left),numel(right));
    elseif ~isequal(size(g),[numel(left),numel(right)])
        error('leotherm:InvalidContactInterface','Interface %d conductance matrix must be nLeft-by-nRight.',k);
    end
    for a = 1:numel(left)
        for b = 1:numel(right)
            key = sprintf('%d:%d',left(a),right(b));
            if any(pairKeys == string(key)) || any(pairKeys == string(sprintf('%d:%d',right(b),left(a))))
                error('leotherm:DuplicateContactInterface','Contact node pair (%d,%d) is repeated.',left(a),right(b));
            end
            pairKeys(end+1,1) = string(key); %#ok<AGROW>
            gij = g(a,b); i = left(a); j = right(b);
            rows = [rows; i; j; i; j]; %#ok<AGROW>
            cols = [cols; i; j; j; i]; %#ok<AGROW>
            vals = [vals; gij; gij; -gij; -gij]; %#ok<AGROW>
        end
    end
    records(k).name = optionalName(item,k);
    records(k).leftNodes = left; records(k).rightNodes = right;
    records(k).conductanceWK = g;
end
K = sparse(rows,cols,vals,nodeCount,nodeCount);
contact = struct('nodeCount',nodeCount,'stiffnessWK',K, ...
    'conductanceWK',-K + spdiags(diag(K),0,nodeCount,nodeCount), ...
    'interfaces',records,'pairCount',numel(rows)/4, ...
    'formulation','pairwise_conservative_contact_laplacian', ...
    'energyLedger',struct('internalCancellationGuaranteed',true,'totalInternalPowerW',0));
end

function nodes = validateNodes(value,n,label,k)
if ~isnumeric(value) || ~isvector(value) || isempty(value) || any(~isfinite(value)) || ...
        any(value ~= floor(value)) || any(value < 1) || any(value > n) || numel(unique(value)) ~= numel(value)
    error('leotherm:InvalidContactInterface','Interface %d %s must be unique valid integer indices.',k,label);
end
nodes = value(:)';
end

function name = optionalName(item,k)
name = sprintf('contact_%d',k);
if isfield(item,'name') && (ischar(item.name) || (isstring(item.name) && isscalar(item.name)))
    name = char(item.name);
end
end
