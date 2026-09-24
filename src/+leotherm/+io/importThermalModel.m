function [model, report] = importThermalModel(filePath, varargin)
%IMPORTTHERMALMODEL Import a traceable leotherm.thermal_model.v1 exchange.
opts = parseOptions(varargin{:});
filePath = char(filePath);
if ~isfile(filePath)
    error('leotherm:ThermalModelIOFile', 'Thermal-model file does not exist: %s', filePath);
end
[~,~,ext] = fileparts(filePath);
rawBytes = readBytes(filePath);
switch lower(ext)
    case '.json'
        [model, jsonReport] = leotherm.io.readThermalModelJson(filePath, 'Validate', false);
    case '.mat'
        loaded = load(filePath);
        model = extractMatModel(loaded);
        jsonReport = struct();
    otherwise
        error('leotherm:ThermalModelIOFormat', 'Only .mat and .json are supported.');
end
leotherm.io.validateThermalModel(model);
fingerprint = sha256(rawBytes);
report = struct('path', filePath, 'format', lower(ext(2:end)), ...
    'inputFingerprint', fingerprint, 'schema', model.schema, ...
    'unknownFieldsRetained', true, 'sourceFingerprint', '');
if isfield(model, 'provenance') && isstruct(model.provenance) && ...
        isfield(model.provenance, 'inputFingerprint') && ~isempty(model.provenance.inputFingerprint)
    report.sourceFingerprint = char(model.provenance.inputFingerprint);
end
if isstruct(jsonReport) && ~isempty(fieldnames(jsonReport)), report.json = jsonReport; end
if opts.RequireFingerprint && ~(isfield(model,'provenance') && isfield(model.provenance,'inputFingerprint'))
    error('leotherm:ThermalModelIOFingerprint', 'A provenance.inputFingerprint is required by this import option.');
end
end

function model = extractMatModel(loaded)
if isfield(loaded, 'thermalModel'), model = loaded.thermalModel;
elseif isfield(loaded, 'model'), model = loaded.model;
else
    names = fieldnames(loaded);
    if numel(names) ~= 1, error('leotherm:ThermalModelIOMat', 'MAT input must contain thermalModel (or one unambiguous variable).'); end
    model = loaded.(names{1});
end
end
function bytes = readBytes(path)
fid = fopen(path, 'rb');
if fid < 0
    error('leotherm:ThermalModelIOFile', 'Cannot open %s.', path);
end
try
    bytes = fread(fid, Inf, '*uint8')';
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end
end
function digest = sha256(bytes)
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(int8(bytes));
h = typecast(md.digest(), 'uint8');
digest = lower(reshape(dec2hex(h,2)', 1, []));
end
function opts = parseOptions(varargin)
opts.RequireFingerprint = false;
if mod(numel(varargin),2) ~= 0, error('leotherm:ThermalModelIOOptions', 'Options must be name-value pairs.'); end
for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
        case 'requirefingerprint', opts.RequireFingerprint = logical(varargin{k+1});
        otherwise, error('leotherm:ThermalModelIOOptions', 'Unknown option: %s.', char(varargin{k}));
    end
end
end
