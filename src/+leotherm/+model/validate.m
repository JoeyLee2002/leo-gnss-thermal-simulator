function validate(model)
%VALIDATE Validate a leotherm.thermal_model.v1 canonical model.
if ~isstruct(model) || ~isscalar(model)
    invalid('model must be a scalar structure.');
end
required = {'schema','schemaVersion','units','network','geometry','volumeMesh', ...
    'connectivity','provenance','uncertainty'};
for k = 1:numel(required)
    if ~isfield(model, required{k}), invalid('model.%s is required.', required{k}); end
end
if ~strcmp(char(string(model.schema)), 'leotherm.thermal_model.v1') || model.schemaVersion ~= 1
    invalid('Only schema leotherm.thermal_model.v1 is supported.');
end
checkUnits(model.units);
leotherm.validateNetwork(model.network);
if ~isempty(fieldnames(model.geometry)), leotherm.validateSurfaceMesh(model.geometry); end
if ~isempty(fieldnames(model.volumeMesh)), leotherm.validateVolumeMesh(model.volumeMesh); end
if ~isstruct(model.connectivity) || ~isscalar(model.connectivity)
    invalid('model.connectivity must be a scalar structure.');
end
if ~isfield(model.connectivity, 'networkConnected') || ~model.connectivity.networkConnected
    invalid('All thermal-network nodes must be connected by positive conductance paths.');
end
if isfield(model.connectivity, 'volumeConnected') && ~model.connectivity.volumeConnected
    invalid('All volume-mesh tetrahedra must belong to one connected component.');
end
if isfield(model, 'material') && ~isempty(fieldnames(model.material))
    checkMaterial(model.material, model.volumeMesh);
end
checkProvenance(model.provenance);
checkUncertainty(model.uncertainty);
end

function checkMaterial(material, mesh)
if ~isstruct(material) || ~isscalar(material), invalid('model.material must be a scalar structure.'); end
names = {'conductivityWmK','densityKgM3','specificHeatJkgK'};
for k = 1:numel(names)
    if ~isfield(material, names{k}), continue; end
    value = material.(names{k});
    if ~isnumeric(value) || ~isreal(value) || ~isvector(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
        invalid('model.material.%s must contain positive finite values.', names{k});
    end
    if ~isempty(fieldnames(mesh)) && numel(value) ~= 1 && numel(value) ~= size(mesh.tetrahedra, 1)
        invalid('model.material.%s must be scalar or per tetrahedron.', names{k});
    end
end
if isfield(material, 'regionProperties')
    regions = material.regionProperties;
    if ~isstruct(regions) || isempty(regions) || ~isvector(regions), invalid('model.material.regionProperties must be nonempty.'); end
    required = {'physicalTag','conductivityWmK','densityKgM3','specificHeatJkgK'};
    for k = 1:numel(required)
        if ~all(isfield(regions, required{k})), invalid('Each material region requires %s.', required{k}); end
    end
    tags = [regions.physicalTag];
    if any(~isfinite(tags)) || any(tags ~= floor(tags)) || numel(unique(tags)) ~= numel(tags)
        invalid('Material physicalTag values must be unique finite integers.');
    end
    for k = 1:numel(regions)
        for j = 2:numel(required)
            value = regions(k).(required{j});
            if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                invalid('Material region values must be positive finite scalars.');
            end
        end
    end
    if ~isempty(fieldnames(mesh))
        if ~isfield(mesh, 'tetraPhysicalTags'), invalid('regionProperties requires volume tetraPhysicalTags.'); end
        tagsInMesh = mesh.tetraPhysicalTags(:);
        if isempty(tagsInMesh) || any(tagsInMesh == 0) || any(~ismember(tagsInMesh, tags))
            invalid('Every tetrahedron must have a matching material region.');
        end
    end
end
end

function checkUnits(units)
if ~isstruct(units) || ~isscalar(units), invalid('model.units must be a scalar structure.'); end
expected = struct('length','m','area','m^2','volume','m^3','temperature','K', ...
    'time','s','power','W','capacity','J/K','conductance','W/K', ...
    'conductivity','W/(m*K)','density','kg/m^3','specificHeat','J/(kg*K)', ...
    'normal','dimensionless');
fields = fieldnames(expected);
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(units, f) || ~strcmp(char(string(units.(f))), expected.(f))
        invalid('model.units.%s must be %s.', f, expected.(f));
    end
end
end

function checkProvenance(value)
if ~isstruct(value) || ~isscalar(value), invalid('model.provenance must be a scalar structure.'); end
required = {'schema','source','status','fields'};
for k = 1:numel(required)
    if ~isfield(value, required{k}), invalid('model.provenance.%s is required.', required{k}); end
end
if ~strcmp(char(string(value.schema)), 'leotherm.thermal_model_provenance.v1')
    invalid('Unsupported model provenance schema.');
end
if ~(ischar(value.source) || (isstring(value.source) && isscalar(value.source))) || strlength(string(value.source)) == 0
    invalid('model.provenance.source must be nonempty text.');
end
if ~(ischar(value.status) || (isstring(value.status) && isscalar(value.status))) || strlength(string(value.status)) == 0
    invalid('model.provenance.status must be nonempty text.');
end
if ~isstruct(value.fields), invalid('model.provenance.fields must be a structure.'); end
end

function checkUncertainty(value)
if ~isstruct(value) || ~isscalar(value), invalid('model.uncertainty must be a scalar structure.'); end
required = {'enabled','distribution','seed','sampleCount','halfRanges'};
for k = 1:numel(required)
    if ~isfield(value, required{k}), invalid('model.uncertainty.%s is required.', required{k}); end
end
if ~isscalar(value.enabled) || ~(islogical(value.enabled) || isnumeric(value.enabled))
    invalid('model.uncertainty.enabled must be scalar logical.');
end
if ~strcmp(char(string(value.distribution)), 'stratified_uniform')
    invalid('Unsupported uncertainty distribution.');
end
if ~isnumeric(value.seed) || ~isscalar(value.seed) || ~isfinite(value.seed) || value.seed < 0 || value.seed ~= floor(value.seed)
    invalid('model.uncertainty.seed must be a nonnegative integer.');
end
if ~isnumeric(value.sampleCount) || ~isscalar(value.sampleCount) || ~isfinite(value.sampleCount) || value.sampleCount < 0 || value.sampleCount ~= floor(value.sampleCount)
    invalid('model.uncertainty.sampleCount must be a nonnegative integer.');
end
fields = {'capacity','conductance','power','absorptivity','emissivity'};
if ~isstruct(value.halfRanges), invalid('model.uncertainty.halfRanges must be a structure.'); end
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(value.halfRanges, f) || ~isnumeric(value.halfRanges.(f)) || ~isscalar(value.halfRanges.(f)) || ~isfinite(value.halfRanges.(f)) || value.halfRanges.(f) < 0 || value.halfRanges.(f) >= 1
        invalid('model.uncertainty.halfRanges.%s must lie in [0,1).', f);
    end
end
end

function invalid(message, varargin)
error('leotherm:modelInvalid', message, varargin{:});
end
