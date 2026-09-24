function report = writeThermalModelJson(filePath, model, varargin)
%WRITETHERMALMODELJSON Write a validated model as UTF-8 JSON.
opts.PrettyPrint = false;
if mod(numel(varargin),2) ~= 0
    error('leotherm:ThermalModelIOOptions','Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    if strcmpi(char(varargin{k}), 'prettyprint')
        opts.PrettyPrint = logical(varargin{k+1});
    else
        error('leotherm:ThermalModelIOOptions','Unknown option: %s.',char(varargin{k}));
    end
end
leotherm.io.validateThermalModel(model);
if opts.PrettyPrint
    try
        text = jsonencode(model, 'PrettyPrint', true);
    catch
        text = jsonencode(model);
    end
else
    text = jsonencode(model);
end
fid = fopen(char(filePath), 'w', 'n', 'UTF-8');
if fid < 0
    error('leotherm:ThermalModelIOFile', 'Cannot open %s for writing.', char(filePath));
end
encoded = unicode2native(text, 'UTF-8');
count = fwrite(fid, encoded, 'uint8');
if count ~= numel(encoded)
    error('leotherm:ThermalModelIOFile', 'Short write while writing %s.', char(filePath));
end
fclose(fid);
report = struct('path', char(filePath), 'jsonCharacters', numel(text), 'schema', model.schema);
end
