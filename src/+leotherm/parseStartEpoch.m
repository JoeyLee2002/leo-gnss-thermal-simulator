function epoch = parseStartEpoch(dateValue,timeText)
%PARSESTARTEPOCH Preserve explicit UTC time, including fractional seconds.
if ~isdatetime(dateValue) || ~isscalar(dateValue) || isnat(dateValue)
    error('leotherm:InvalidStartTime','Choose a valid UTC date.');
end
if ~((ischar(timeText) && isrow(timeText)) || (isstring(timeText) && isscalar(timeText)))
    error('leotherm:InvalidStartTime','UTC time must be HH:mm:ss, optionally with fractional seconds.');
end
text = char(timeText);
if isempty(regexp(text,'^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,9})?$','once'))
    error('leotherm:InvalidStartTime','Use UTC HH:mm:ss, for example 00:00:00 or 12:30:05.125.');
end
part = sscanf(text,'%f:%f:%f');
epoch = datetime(year(dateValue),month(dateValue),day(dateValue),0,0,0,'TimeZone','UTC') ...
    + seconds(part(1)*3600+part(2)*60+part(3));
end
