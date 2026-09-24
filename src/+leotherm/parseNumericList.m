function values = parseNumericList(input, label)
%PARSENUMERICLIST Parse numbers and MATLAB-style colon ranges without eval.

if nargin < 2 || isempty(label)
    label = 'value list';
end
if isnumeric(input)
    values = input(:)';
    validateOutput(values, label);
    return
end
if ~(ischar(input) || (isstring(input) && isscalar(input)))
    invalid('%s must be numeric or a text scalar.', label);
end
text = strtrim(char(input));
if isempty(text)
    invalid('%s cannot be empty.', label);
end
text = strrep(text, '，', ',');
tokens = regexp(text, '[,;\s]+', 'split');
values = [];
for k = 1:numel(tokens)
    token = strtrim(tokens{k});
    if isempty(token)
        continue
    end
    parts = regexp(token, ':', 'split');
    numbers = cellfun(@str2double, parts);
    if any(~isfinite(numbers)) || ~(numel(numbers) == 1 ...
            || numel(numbers) == 2 || numel(numbers) == 3)
        invalid('%s contains an invalid token: %s.', label, token);
    end
    if numel(numbers) == 1
        expanded = numbers;
    elseif numel(numbers) == 2
        expanded = numbers(1):numbers(2);
    else
        if numbers(2) == 0
            invalid('%s contains a zero range step: %s.', label, token);
        end
        expanded = numbers(1):numbers(2):numbers(3);
    end
    if isempty(expanded)
        invalid('%s contains an empty or inconsistent range: %s.', label, token);
    end
    values = [values, expanded]; %#ok<AGROW>
    if numel(values) > 10000
        invalid('%s expands to more than 10000 values.', label);
    end
end
validateOutput(values, label);
end

function validateOutput(values, label)
if isempty(values) || ~isvector(values) || ~isreal(values) ...
        || any(~isfinite(values))
    invalid('%s must contain finite real values.', label);
end
end

function invalid(message, varargin)
error('leotherm:InvalidList', message, varargin{:});
end
