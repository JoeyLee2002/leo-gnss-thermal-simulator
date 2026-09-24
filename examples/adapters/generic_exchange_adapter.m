function [model, report] = generic_exchange_adapter(source, outputPath)
%GENERIC_EXCHANGE_ADAPTER Convert a neutral record to thermal-model v1.
%   [MODEL, REPORT] = GENERIC_EXCHANGE_ADAPTER(SOURCE, OUTPUTPATH) is a
%   deliberately small adapter example. SOURCE is either a MATLAB scalar
%   structure or a JSON/MAT file containing the same neutral fields. The
%   adapter copies declared values into leotherm.thermal_model.v1, validates
%   the exchange contract, and optionally writes OUTPUTPATH.
%
%   This function does not parse Thermal Desktop, ESATAN, SINDA, OpenFOAM,
%   or any other vendor format. A project-specific reader must translate a
%   vendor export into the neutral fields before calling this function.

if nargin < 1 || isempty(source)
    error('generic_adapter:Input', 'A neutral source structure or file is required.');
end
if nargin < 2
    outputPath = '';
end

[raw, inputKind] = readSource(source);
if ~isstruct(raw) || ~isscalar(raw)
    error('generic_adapter:Input', 'The neutral source must be a scalar structure.');
end

model = makeModel(raw);
leotherm.io.validateThermalModel(model);

report = struct('adapter', 'generic_exchange_adapter', ...
    'inputKind', inputKind, 'schema', model.schema, ...
    'exported', false, 'outputPath', '');
if ~isempty(outputPath)
    outputPath = char(outputPath);
    leotherm.io.exportThermalModel(model, outputPath, 'PrettyPrint', true);
    report.exported = true;
    report.outputPath = outputPath;
end
end

function [raw, inputKind] = readSource(source)
if isstruct(source)
    raw = source;
    inputKind = 'struct';
    return;
end
if ~(ischar(source) || (isstring(source) && isscalar(source)))
    error('generic_adapter:Input', 'SOURCE must be a structure or a JSON/MAT path.');
end
path = char(source);
if ~isfile(path)
    error('generic_adapter:File', 'Neutral source file does not exist: %s', path);
end
[~,~,ext] = fileparts(path);
switch lower(ext)
    case '.json'
        try
            raw = jsondecode(fileread(path));
        catch err
            error('generic_adapter:Json', 'Cannot decode neutral JSON: %s', err.message);
        end
        inputKind = 'json';
    case '.mat'
        loaded = load(path);
        names = fieldnames(loaded);
        if isfield(loaded, 'thermalModel')
            raw = loaded.thermalModel;
        elseif isfield(loaded, 'model')
            raw = loaded.model;
        elseif numel(names) == 1
            raw = loaded.(names{1});
        else
            error('generic_adapter:Mat', 'Neutral MAT must contain thermalModel, model, or one variable.');
        end
        inputKind = 'mat';
    otherwise
        error('generic_adapter:Format', 'Only neutral .json and .mat files are supported.');
end
end

function model = makeModel(raw)
% Keep this mapping intentionally mechanical: no names, geometry, or units
% are interpreted and no missing physical values are invented.
model = raw;
if ~isfield(model, 'schema') || isempty(model.schema)
    model.schema = 'leotherm.thermal_model.v1';
end
if ~isfield(model, 'metadata') || ~isstruct(model.metadata) || ~isscalar(model.metadata)
    error('generic_adapter:Metadata', 'Neutral source must declare scalar metadata.');
end
if ~isfield(model.metadata, 'units')
    error('generic_adapter:Units', 'Neutral source must declare canonical SI metadata.units.');
end
requiredArrays = {'nodes','materials','components','contacts','boundaries'};
for k = 1:numel(requiredArrays)
    if ~isfield(model, requiredArrays{k})
        model.(requiredArrays{k}) = struct([]);
    end
end
if ~isfield(model, 'provenance') || isempty(model.provenance)
    model.provenance = struct('source', 'generic adapter input', 'transformations', {{}});
end
if ~isfield(model, 'uncertainty') || isempty(model.uncertainty)
    model.uncertainty = struct('enabled', false, 'source', 'not_declared');
end
end
