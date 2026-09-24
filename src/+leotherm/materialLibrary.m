function result = materialLibrary(action, varargin)
%MATERIALLIBRARY Extensible, provenance-aware thermal material library.
%   M = leotherm.materialLibrary() returns built-in reference materials.
%   M = leotherm.materialLibrary('list') returns material identifiers.
%   M = leotherm.materialLibrary('get', ID) returns one material.
%   M = leotherm.materialLibrary('register', SPEC) validates and returns SPEC.
%   V = leotherm.materialLibrary('evaluate', MATERIAL, T_K) evaluates
%   temperature-dependent properties at temperature(s) T_K.
%
% Built-in values are engineering reference values only; they are not
% measurements of any particular spacecraft or mission.

 persistent customMaterials
if isempty(customMaterials), customMaterials = {}; end
if nargin == 0 || isempty(action)
    if isempty(customMaterials)
        result = builtinMaterials();
    else
        % Return a cell when user records contain extension-specific fields.
        result = [{builtinMaterials()}, customMaterials];
    end
    return;
end
if isstruct(action)
    result = validateMaterial(action);
    return;
end
if ~(ischar(action) || (isstring(action) && isscalar(action)))
    error('leotherm:InvalidMaterialLibraryAction', 'Action must be text or a material structure.');
end
op = lower(char(action));
switch op
    case {'list','all'}
        base = builtinMaterials();
        result = [{base.id}, cellfun(@(x) x.id, customMaterials, 'UniformOutput', false)];
    case {'get','lookup'}
        if isempty(varargin), error('leotherm:MissingMaterialId', 'A material identifier is required.'); end
        id = char(string(varargin{1}));
        base = builtinMaterials();
        hit = strcmpi({base.id}, id) | strcmpi({base.name}, id);
        if any(hit), result = base(find(hit, 1)); return; end
        for j = 1:numel(customMaterials)
            if strcmpi(customMaterials{j}.id, id) || strcmpi(customMaterials{j}.name, id), result = customMaterials{j}; return; end
        end
        error('leotherm:UnknownMaterial', 'Unknown material: %s.', id);
    case {'register','create','validate'}
        if isempty(varargin) || ~isstruct(varargin{1}), error('leotherm:InvalidMaterial', 'A material structure is required.'); end
        result = validateMaterial(varargin{1});
        base = builtinMaterials();
        builtinIdHit = strcmpi({base.id}, result.id);
        builtinNameHit = strcmpi({base.name}, result.name);
        if any(builtinIdHit) || any(builtinNameHit)
            if isfield(result, 'isReferenceValue') && result.isReferenceValue && any(builtinIdHit)
                result = base(find(builtinIdHit, 1));
                return;
            end
            error('leotherm:MaterialNameConflict', ...
                'Custom material id or name conflicts with a built-in material.');
        end
        hit = false(1, numel(customMaterials));
        for j = 1:numel(customMaterials)
            sameId = strcmpi(customMaterials{j}.id, result.id);
            sameName = strcmpi(customMaterials{j}.name, result.name);
            if sameName && ~sameId
                error('leotherm:MaterialNameConflict', ...
                    'Custom material name conflicts with an existing material.');
            end
            hit(j) = sameId;
        end
        if any(hit), customMaterials{find(hit, 1)} = result; else, customMaterials{end+1} = result; end
    case {'evaluate','property'}
        if numel(varargin) < 2, error('leotherm:InvalidMaterialEvaluation', 'Material and temperature are required.'); end
        material = validateMaterial(varargin{1});
        temperatureK = varargin{2};
        if ~isnumeric(temperatureK) || ~isreal(temperatureK) || any(~isfinite(temperatureK(:))) || any(temperatureK(:) <= 0)
            error('leotherm:InvalidTemperature', 'Temperature must contain positive finite Kelvin values.');
        end
        result = evaluateMaterial(material, temperatureK);
    otherwise
        % A convenient shorthand: materialLibrary('aluminum')
        base = builtinMaterials();
        hit = strcmpi({base.id}, op) | strcmpi({base.name}, op);
        if any(hit), result = base(find(hit, 1)); return; end
        for j = 1:numel(customMaterials)
            if strcmpi(customMaterials{j}.id, op) || strcmpi(customMaterials{j}.name, op), result = customMaterials{j}; return; end
        end
        error('leotherm:UnknownMaterial', 'Unknown material action or identifier: %s.', op);
end
end

function materials = builtinMaterials()
materials = [referenceMaterial('aluminum_6061', 'Aluminum 6061', 167, 2700, 896, 0.15, 0.85), ...
    referenceMaterial('aluminum_7075', 'Aluminum 7075', 130, 2810, 960, 0.20, 0.82), ...
    referenceMaterial('stainless_steel_304', 'Stainless steel 304', 16.2, 8000, 500, 0.35, 0.70), ...
    referenceMaterial('peek', 'PEEK polymer', 0.25, 1320, 1100, 0.85, 0.90)];
end

function material = referenceMaterial(id, name, k, rho, cp, alpha, epsilon)
material = struct('id', id, 'name', name, 'kind', 'constant', ...
    'conductivityWmK', k, 'densityKgM3', rho, 'specificHeatJkgK', cp, ...
    'temperatureRangeK', [100, 500], ...
    'solarAbsorptivity', alpha, 'irEmissivity', epsilon, ...
    'source', 'Engineering reference value; verify against mission hardware.', ...
    'confidence', 'reference', 'uncertainty', struct('conductivityWmK', 0.20, ...
    'densityKgM3', 0.05, 'specificHeatJkgK', 0.15, 'solarAbsorptivity', 0.10, 'irEmissivity', 0.10), ...
    'isReferenceValue', true, 'provenance', 'reference_only');
end

function material = validateMaterial(material)
if ~isstruct(material) || ~isscalar(material), invalid('Material must be a scalar structure.'); end
required = {'id','name','kind','source','confidence','uncertainty'};
for i = 1:numel(required), if ~isfield(material, required{i}), invalid('Missing required material field: %s.', required{i}); end, end
for f = {'id','name','source'}
    value = material.(f{1});
    if ~(ischar(value) || (isstring(value) && isscalar(value))) || strlength(strtrim(string(value))) == 0
        invalid('material.%s must be non-empty text.', f{1});
    end
end
kind = lower(char(string(material.kind)));
if ~ismember(kind, {'constant','temperature_dependent'}), invalid('material.kind must be constant or temperature_dependent.'); end
material.kind = kind;
if ~isfield(material, 'temperatureRangeK'), material.temperatureRangeK = [1, 2000]; end
validateRange(material.temperatureRangeK, 'temperatureRangeK', true);
if strcmp(kind, 'constant')
    positive(material, 'conductivityWmK'); positive(material, 'densityKgM3'); positive(material, 'specificHeatJkgK');
else
    if isfield(material, 'temperatureK')
        validateTemperatureGrid(material.temperatureK, material.temperatureRangeK);
    end
    for f = {'conductivityWmK','densityKgM3','specificHeatJkgK'}
        if ~isfield(material, f{1}) && ~isfield(material, [f{1} 'Fcn'])
            invalid('Temperature-dependent material requires %s or %sFcn.', f{1}, f{1});
        end
        if isfield(material, f{1})
            validateCurve(material.(f{1}), material.temperatureRangeK, f{1});
        if isfield(material, 'temperatureK') && numel(material.(f{1})) ~= numel(material.temperatureK), invalid('%s must match temperatureK length.', f{1}); end
        if ~isfield(material, 'temperatureK') && numel(material.(f{1})) > 1 && ~isfield(material, [f{1} 'Fcn'])
            invalid('A tabulated %s curve requires temperatureK.', f{1});
        end
        end
        if isfield(material, [f{1} 'Fcn']) && ~isa(material.([f{1} 'Fcn']), 'function_handle'), invalid('%sFcn must be a function handle.', f{1}); end
    end
end
if isfield(material, 'surfaceOptical') && isstruct(material.surfaceOptical)
    if ~isfield(material, 'solarAbsorptivity') && isfield(material.surfaceOptical, 'solarAbsorptivity'), material.solarAbsorptivity = material.surfaceOptical.solarAbsorptivity; end
    if ~isfield(material, 'irEmissivity') && isfield(material.surfaceOptical, 'irEmissivity'), material.irEmissivity = material.surfaceOptical.irEmissivity; end
end
for f = {'solarAbsorptivity','irEmissivity'}
    if isfield(material, f{1})
        value = material.(f{1});
        if ~isnumeric(value) || any(~isfinite(value(:))) || any(value(:) < 0 | value(:) > 1), invalid('%s must lie in [0,1].', f{1}); end
    end
end
if isnumeric(material.uncertainty)
    if any(~isfinite(material.uncertainty(:))) || any(material.uncertainty(:) < 0), invalid('Uncertainty values must be finite and non-negative.'); end
elseif isstruct(material.uncertainty) && isscalar(material.uncertainty)
    uf = fieldnames(material.uncertainty);
    for i = 1:numel(uf)
        u = material.uncertainty.(uf{i});
        if ~isnumeric(u) || any(~isfinite(u(:))) || any(u(:) < 0)
            invalid('Uncertainty values must be finite and non-negative.');
        end
    end
else
    invalid('material.uncertainty must be numeric or a scalar structure.');
end
if isnumeric(material.confidence)
        if ~isscalar(material.confidence) || ~isfinite(material.confidence) || material.confidence < 0 || material.confidence > 1
            invalid('Numeric confidence must lie in [0,1].');
        end
elseif ~(ischar(material.confidence) || (isstring(material.confidence) && isscalar(material.confidence))) || strlength(strtrim(string(material.confidence))) == 0
    invalid('confidence must be text or a numeric value in [0,1].');
end
if ~isfield(material, 'isReferenceValue')
    material.isReferenceValue = false;
end
if ~islogical(material.isReferenceValue) || ~isscalar(material.isReferenceValue)
    invalid('isReferenceValue must be logical scalar.');
end
if ~isfield(material, 'provenance'), material.provenance = 'user_supplied'; end
if ~isfield(material, 'solarAbsorptivity'), material.solarAbsorptivity = 0; end
if ~isfield(material, 'irEmissivity'), material.irEmissivity = 0; end
end

function validateCurve(value, ~, name)
if ~isnumeric(value) || ~isvector(value) || isempty(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
    invalid('%s curve values must be positive and finite.', name);
end
end
function validateTemperatureGrid(grid, range)
if ~isnumeric(grid) || ~isvector(grid) || numel(grid) < 2 || any(~isfinite(grid(:))) || any(diff(grid(:)) <= 0) || grid(1) < range(1) || grid(end) > range(2)
    invalid('temperatureK must be an increasing grid inside temperatureRangeK.');
end
end
function positive(s, field)
if ~isfield(s, field) || ~isnumeric(s.(field)) || ~isscalar(s.(field)) || ~isfinite(s.(field)) || s.(field) <= 0
    invalid('material.%s must be positive finite scalar.', field);
end
end
function validateRange(value, name, positiveBounds)
if ~isnumeric(value) || ~isreal(value) || numel(value) ~= 2 || any(~isfinite(value(:))) || value(1) >= value(2) || (positiveBounds && value(1) <= 0)
    invalid('%s must be an increasing positive range.', name);
end
end
function result = evaluateMaterial(material, T)
result = struct('temperatureK', T, 'conductivityWmK', propertyAt(material, 'conductivityWmK', T), ...
    'densityKgM3', propertyAt(material, 'densityKgM3', T), 'specificHeatJkgK', propertyAt(material, 'specificHeatJkgK', T));
if isfield(material, 'solarAbsorptivity')
    result.solarAbsorptivity = material.solarAbsorptivity;
end
if isfield(material, 'irEmissivity')
    result.irEmissivity = material.irEmissivity;
end
end
function value = propertyAt(material, field, T)
fcn = [field 'Fcn'];
if isfield(material, fcn)
    value = material.(fcn)(T);
elseif isfield(material, field)
    raw = material.(field);
    if numel(raw) > 1 && isfield(material, 'temperatureK')
        if any(T(:) < material.temperatureRangeK(1) | T(:) > material.temperatureRangeK(2))
            error('leotherm:TemperatureOutOfRange', 'Temperature is outside material temperatureRangeK.');
        end
        value = interp1(material.temperatureK(:), raw(:), T, 'linear');
    else
        value = raw;
    end
else
    error('leotherm:MissingMaterialProperty', 'Missing %s.', field);
end
if ~isnumeric(value) || ~isequal(size(value), size(T)) && ~isscalar(value) || any(~isfinite(value(:))) || any(value(:) <= 0)
    error('leotherm:InvalidMaterialProperty', '%s evaluation must be positive finite.', field);
end
if isscalar(value)
    value = repmat(value, size(T));
end
end
function invalid(message, varargin), error('leotherm:InvalidMaterial', message, varargin{:}); end
