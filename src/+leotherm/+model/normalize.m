function model = normalize(source, geometry, volumeMesh, options)
%NORMALIZE Build the leotherm.thermal_model.v1 canonical model contract.
%   MODEL = leotherm.model.normalize(NETWORK)
%   MODEL = leotherm.model.normalize(NETWORK, GEOMETRY, VOLUMEMESH)
%   MODEL = leotherm.model.normalize(SOURCE) accepts a structure containing
%   network, geometry and/or volumeMesh fields.  All numerical quantities
%   remain SI; this function deliberately rejects implicit unit conversions.

if nargin < 2, geometry = []; end
if nargin < 3, volumeMesh = []; end
if nargin < 4 || isempty(options), options = struct; end
if ~isstruct(options) || ~isscalar(options)
    error('leotherm:modelInvalidOptions', 'options must be a scalar structure.');
end

% A carrier structure is convenient for project files, while the three
% positional arguments keep this helper compatible with existing APIs.
if isstruct(source) && isscalar(source) && isfield(source, 'network') ...
        && (nargin == 1 || isempty(geometry))
    carrier = source;
    source = carrier.network;
    if isfield(carrier, 'geometry'), geometry = carrier.geometry; end
    if isfield(carrier, 'volumeMesh'), volumeMesh = carrier.volumeMesh; end
    if isfield(carrier, 'units'), options.units = carrier.units; end
    if isfield(carrier, 'provenance'), options.provenance = carrier.provenance; end
    if isfield(carrier, 'material'), options.material = carrier.material; end
end

network = normalizeNetwork(source);
geometry = normalizeGeometry(geometry);
volumeMesh = normalizeVolumeMesh(volumeMesh);
units = canonicalUnits;
if isfield(options, 'units') && ~isempty(options.units)
    validateUnits(options.units, units);
end

model = struct;
model.schema = 'leotherm.thermal_model.v1';
model.schemaVersion = 1;
model.units = units;
model.network = network;
model.geometry = geometry;
model.volumeMesh = volumeMesh;
model.material = struct;
if isfield(options, 'material') && ~isempty(options.material)
    model.material = normalizeMaterial(options.material, volumeMesh);
end
model.connectivity = connectivitySummary(network, volumeMesh);
model.provenance = leotherm.model.parameterProvenance(network, geometry, volumeMesh, options);
model.uncertainty = defaultUncertainty;
if isfield(options, 'uncertainty') && ~isempty(options.uncertainty)
    model.uncertainty = normalizeUncertainty(options.uncertainty);
end
leotherm.model.validate(model);
end

function network = normalizeNetwork(network)
if ~isstruct(network) || ~isscalar(network)
    error('leotherm:modelInvalidNetwork', 'network must be a scalar structure.');
end
leotherm.validateNetwork(network);
network = network(:);
network.nodeNames = cellstr(network.nodeNames(:));
names = {'capacityJK','initialTemperatureK','internalPowerW','projectedAreaM2', ...
    'radiatingAreaM2','solarAbsorptivity','irEmissivity'};
for k = 1:numel(names), network.(names{k}) = network.(names{k})(:); end
network.normalBody = double(network.normalBody);
network.conductanceWK = double(network.conductanceWK);
network.unitSystem = 'SI';
end

function geometry = normalizeGeometry(geometry)
if isempty(geometry), geometry = struct; return; end
if isstruct(geometry) && isfield(geometry, 'surfaceMesh') && isscalar(geometry.surfaceMesh)
    geometry = geometry.surfaceMesh;
end
if ~isstruct(geometry) || ~isscalar(geometry)
    error('leotherm:modelInvalidGeometry', 'geometry must be a surface-mesh structure or empty.');
end
leotherm.validateSurfaceMesh(geometry);
if isfield(geometry, 'units'), validateLengthUnit(geometry.units, 'geometry.units'); end
geometry.unitSystem = 'SI';
end

function mesh = normalizeVolumeMesh(mesh)
if isempty(mesh), mesh = struct; return; end
if isstruct(mesh) && isfield(mesh, 'volumeMesh') && isscalar(mesh.volumeMesh)
    mesh = mesh.volumeMesh;
end
if ~isstruct(mesh) || ~isscalar(mesh)
    error('leotherm:modelInvalidVolumeMesh', 'volumeMesh must be a volume-mesh structure or empty.');
end
leotherm.validateVolumeMesh(mesh);
if isfield(mesh, 'units'), validateLengthUnit(mesh.units, 'volumeMesh.units'); end
mesh.unitSystem = 'SI';
end

function units = canonicalUnits
units = struct('length', 'm', 'area', 'm^2', 'volume', 'm^3', ...
    'temperature', 'K', 'time', 's', 'power', 'W', 'capacity', 'J/K', ...
    'conductance', 'W/K', 'conductivity', 'W/(m*K)', 'density', 'kg/m^3', ...
    'specificHeat', 'J/(kg*K)', 'normal', 'dimensionless');
end

function validateUnits(value, expected)
if ~isstruct(value) || ~isscalar(value)
    error('leotherm:modelInvalidUnits', 'units must be a scalar structure.');
end
fields = fieldnames(expected);
for k = 1:numel(fields)
    f = fields{k};
    if isfield(value, f) && ~strcmp(char(string(value.(f))), expected.(f))
        error('leotherm:modelInvalidUnits', 'units.%s must be %s.', f, expected.(f));
    end
end
end

function validateLengthUnit(value, label)
if ~(ischar(value) || (isstring(value) && isscalar(value))) || ~strcmp(char(value), 'm')
    error('leotherm:modelInvalidUnits', '%s must be metres (m).', label);
end
end

function summary = connectivitySummary(network, mesh)
summary = struct('networkNodeCount', numel(network.nodeNames), ...
    'networkConnected', isConnected(network.conductanceWK), ...
    'volumeNodeCount', 0, 'volumeElementCount', 0, 'volumeConnected', true);
if ~isempty(fieldnames(mesh))
    summary.volumeNodeCount = size(mesh.nodesM, 1);
    summary.volumeElementCount = size(mesh.tetrahedra, 1);
    summary.volumeConnected = elementConnectivity(mesh.tetrahedra);
end
end

function tf = isConnected(adjacency)
n = size(adjacency, 1);
if n <= 1, tf = true; return; end
seen = false(n, 1); seen(1) = true; queue = 1;
while ~isempty(queue)
    node = queue(1); queue(1) = [];
    next = find(adjacency(node, :) > 0 & ~seen');
    seen(next) = true; queue = [queue, next]; %#ok<AGROW>
end
tf = all(seen);
end

function tf = elementConnectivity(tetra)
n = size(tetra, 1);
if n <= 1, tf = true; return; end
seen = false(n, 1); seen(1) = true; queue = 1;
while ~isempty(queue)
    e = queue(1); queue(1) = [];
    neighbours = find(any(ismember(tetra, tetra(e, :)), 2));
    neighbours = neighbours(~seen(neighbours));
    seen(neighbours) = true; queue = [queue; neighbours]; %#ok<AGROW>
end
tf = all(seen);
end

function value = defaultUncertainty
value = struct('enabled', false, 'distribution', 'stratified_uniform', ...
    'seed', 0, 'sampleCount', 0, 'halfRanges', struct(...
    'capacity', 0, 'conductance', 0, 'power', 0, ...
    'absorptivity', 0, 'emissivity', 0), 'source', 'not_declared');
end

function material = normalizeMaterial(material, mesh)
if ~isstruct(material) || ~isscalar(material)
    error('leotherm:modelInvalidMaterial', 'material must be a scalar structure.');
end
names = {'conductivityWmK','densityKgM3','specificHeatJkgK'};
for k = 1:numel(names)
    if isfield(material, names{k})
        value = material.(names{k});
        if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
            error('leotherm:modelInvalidMaterial', '%s must contain positive finite values.', names{k});
        end
        if ~isempty(fieldnames(mesh)) && numel(value) ~= 1 && numel(value) ~= size(mesh.tetrahedra, 1)
            error('leotherm:modelInvalidMaterial', '%s must be scalar or one value per tetrahedron.', names{k});
        end
        material.(names{k}) = value(:);
    end
end
if isfield(material, 'regionProperties')
    regions = material.regionProperties;
    if ~isstruct(regions) || isempty(regions) || ~isvector(regions)
        error('leotherm:modelInvalidMaterial', 'regionProperties must be a nonempty structure array.');
    end
    required = {'physicalTag','conductivityWmK','densityKgM3','specificHeatJkgK'};
    for k = 1:numel(required)
        if ~all(isfield(regions, required{k}))
            error('leotherm:modelInvalidMaterial', 'Each regionProperties entry requires %s.', required{k});
        end
    end
    tags = [regions.physicalTag];
    if any(~isfinite(tags)) || any(tags ~= floor(tags)) || numel(unique(tags)) ~= numel(tags)
        error('leotherm:modelInvalidMaterial', 'physicalTag values must be unique finite integers.');
    end
    for k = 1:numel(regions)
        for j = 2:numel(required)
            value = regions(k).(required{j});
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                error('leotherm:modelInvalidMaterial', '%s must be positive and finite.', required{j});
            end
        end
    end
    if ~isempty(fieldnames(mesh))
        if ~isfield(mesh, 'tetraPhysicalTags')
            error('leotherm:modelInvalidMaterial', 'regionProperties requires tetraPhysicalTags on the volume mesh.');
        end
        tetraTags = mesh.tetraPhysicalTags(:);
        if isempty(tetraTags) || any(tetraTags == 0) || any(~ismember(tetraTags, tags))
            error('leotherm:modelInvalidMaterial', 'Every tetrahedron tag must match a regionProperties entry.');
        end
    end
end
end

function value = normalizeUncertainty(value)
required = {'enabled','distribution','seed','sampleCount','halfRanges'};
for k = 1:numel(required)
    if ~isfield(value, required{k}), error('leotherm:modelInvalidUncertainty', ...
            'uncertainty.%s is required.', required{k}); end
end
if ~(isscalar(value.enabled) && (islogical(value.enabled) || isnumeric(value.enabled)))
    error('leotherm:modelInvalidUncertainty', 'uncertainty.enabled must be scalar logical.');
end
if ~strcmp(char(string(value.distribution)), 'stratified_uniform')
    error('leotherm:modelInvalidUncertainty', 'Only stratified_uniform is supported in v1.');
end
if ~isnumeric(value.seed) || ~isscalar(value.seed) || ~isfinite(value.seed) || value.seed < 0 || value.seed ~= floor(value.seed)
    error('leotherm:modelInvalidUncertainty', 'uncertainty.seed must be a nonnegative integer.');
end
if ~isnumeric(value.sampleCount) || ~isscalar(value.sampleCount) || ~isfinite(value.sampleCount) || value.sampleCount < 0 || value.sampleCount ~= floor(value.sampleCount)
    error('leotherm:modelInvalidUncertainty', 'uncertainty.sampleCount must be a nonnegative integer.');
end
fields = {'capacity','conductance','power','absorptivity','emissivity'};
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(value.halfRanges, f) || ~isnumeric(value.halfRanges.(f)) || ~isscalar(value.halfRanges.(f)) || ~isfinite(value.halfRanges.(f)) || value.halfRanges.(f) < 0 || value.halfRanges.(f) >= 1
        error('leotherm:modelInvalidUncertainty', 'uncertainty.halfRanges.%s must lie in [0,1).', f);
    end
end
value.enabled = logical(value.enabled);
value.distribution = 'stratified_uniform';
end
