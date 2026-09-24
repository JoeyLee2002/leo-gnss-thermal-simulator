function report = exportThermalModel(model, filePath, varargin)
%EXPORTTHERMALMODEL Validate and export a leotherm.thermal_model.v1 model.
opts = parseOptions(varargin{:});
filePath = char(filePath);
leotherm.io.validateThermalModel(model);
[folder,~,ext] = fileparts(filePath);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
switch lower(ext)
    case '.json'
        leotherm.io.writeThermalModelJson(filePath, model, 'PrettyPrint', opts.PrettyPrint);
    case '.mat'
        thermalModel = model;
        save(filePath, 'thermalModel', '-v7.3');
        clear thermalModel
    otherwise
        error('leotherm:ThermalModelIOFormat', 'Only .mat and .json are supported.');
end
info = dir(filePath);
report = struct('path', filePath, 'format', lower(ext(2:end)), 'bytes', info.bytes, ...
    'schema', model.schema, 'outputFingerprint', fileFingerprint(filePath));
end

function digest = fileFingerprint(path)
fid = fopen(path, 'rb');
if fid < 0
    error('leotherm:ThermalModelIOFile', 'Cannot open output %s.', path);
end
try
    b = fread(fid, Inf, '*uint8')';
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end
md = java.security.MessageDigest.getInstance('SHA-256'); md.update(int8(b));
h = typecast(md.digest(), 'uint8'); digest = lower(reshape(dec2hex(h,2)',1,[]));
end

function opts = parseOptions(varargin)
opts.PrettyPrint = false;
if mod(numel(varargin),2) ~= 0, error('leotherm:ThermalModelIOOptions', 'Options must be name-value pairs.'); end
for k = 1:2:numel(varargin)
    switch lower(char(varargin{k}))
        case 'prettyprint', opts.PrettyPrint = logical(varargin{k+1});
        otherwise, error('leotherm:ThermalModelIOOptions', 'Unknown option: %s.', char(varargin{k}));
    end
end
end
