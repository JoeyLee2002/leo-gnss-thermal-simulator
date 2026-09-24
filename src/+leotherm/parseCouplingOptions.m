function options = parseCouplingOptions(answer, previousThermal)
%PARSECOUPLINGOPTIONS Parse the explicit GUI coupling-boundary dialog.
if nargin < 2 || isempty(previousThermal)
    previousThermal = leotherm.defaultCouplingOptions.volumeThermal;
end
if ~iscell(answer) || numel(answer) ~= 5
    error('leotherm:InvalidCouplingOptions', 'The coupling dialog returned five text fields.');
end
left = parseIndexList(answer{1}, 'leftNodes');
right = parseIndexList(answer{2}, 'rightNodes');
conductance = parsePositiveScalar(answer{3}, 'conductanceWK', []);
fixed = parseIndexList(answer{4}, 'fixedNodeIndices');
temperature = parsePositiveScalar(answer{5}, 'fixedTemperatureK', 293.15);
if isempty(left) && isempty(right) && isempty(conductance)
    contacts = struct([]);
elseif isempty(left) || isempty(right) || isempty(conductance)
    error('leotherm:InvalidCouplingOptions', ...
        'Contact nodes and conductance must all be provided, or all be blank.');
else
    contacts = struct('leftNodes', left, 'rightNodes', right, ...
        'conductanceWK', conductance);
end
volumeThermal = previousThermal;
volumeThermal.fixedNodeIndices = fixed;
volumeThermal.fixedTemperatureK = temperature;
options = struct('contacts', contacts, 'volumeThermal', volumeThermal);
end

function values = parseIndexList(value, name)
value = strtrim(char(value));
if isempty(value), values = zeros(0, 1); return; end
value = strrep(value, ';', ',');
parts = strsplit(value, ',');
values = str2double(strtrim(parts));
if isempty(values) || any(~isfinite(values)) || any(values ~= floor(values)) || any(values < 1)
    error('leotherm:InvalidCouplingOptions', '%s must contain positive integer indices.', name);
end
values = values(:);
if numel(unique(values)) ~= numel(values)
    error('leotherm:InvalidCouplingOptions', '%s must not contain duplicates.', name);
end
end

function value = parsePositiveScalar(text, name, blankValue)
text = strtrim(char(text));
if isempty(text)
    if nargin >= 3, value = blankValue; return; end
    error('leotherm:InvalidCouplingOptions', '%s is required.', name);
end
value = sscanf(text, '%f', 1);
if isempty(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('leotherm:InvalidCouplingOptions', '%s must be one positive finite scalar.', name);
end
end
