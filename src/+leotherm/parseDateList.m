function dates = parseDateList(input, label)
%PARSEDATELIST Parse comma-separated ISO calendar dates as UTC datetimes.

if nargin < 2 || isempty(label)
    label = 'date list';
end
if isdatetime(input)
    dates = input(:)';
    if isempty(dates) || any(isnat(dates))
        invalid('%s must contain valid dates.', label);
    end
    if isempty(dates.TimeZone)
        dates.TimeZone = 'UTC';
    end
    return
end
if ~(ischar(input) || (isstring(input) && isscalar(input)))
    invalid('%s must be datetime values or a text scalar.', label);
end
text = strtrim(char(input));
text = strrep(text, '，', ',');
tokens = regexp(text, '[,;\s]+', 'split');
tokens = tokens(~cellfun('isempty', tokens));
if isempty(tokens)
    invalid('%s cannot be empty.', label);
end
try
    dates = datetime(tokens, 'InputFormat', 'yyyy-MM-dd', 'TimeZone', 'UTC');
catch
    invalid('%s must use yyyy-MM-dd dates separated by commas.', label);
end
if any(isnat(dates))
    invalid('%s contains an invalid calendar date.', label);
end
dates = dates(:)';
end

function invalid(message, varargin)
error('leotherm:InvalidDateList', message, varargin{:});
end
