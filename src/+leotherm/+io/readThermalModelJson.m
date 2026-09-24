function [model, report] = readThermalModelJson(filePath, varargin)
%READTHERMALMODELJSON Read JSON without changing field order or values.
opts.Validate = true;
if mod(numel(varargin),2) ~= 0
    error('leotherm:ThermalModelIOOptions','Options must be name-value pairs.');
end
for k = 1:2:numel(varargin)
    if strcmpi(char(varargin{k}), 'validate')
        opts.Validate = logical(varargin{k+1});
    else
        error('leotherm:ThermalModelIOOptions','Unknown option: %s.',char(varargin{k}));
    end
end
text = fileread(char(filePath));
try
    model = jsondecode(text);
catch err
    error('leotherm:ThermalModelIOJson', 'Invalid JSON: %s', err.message);
end
if opts.Validate, leotherm.io.validateThermalModel(model); end
report = struct('jsonCharacters', numel(text), 'schema', fieldOr(model,'schema',''));
end
function value = fieldOr(s, field, fallback)
if isstruct(s) && isfield(s,field), value = s.(field); else, value = fallback; end
end
