function [records, metadata] = readGracefoIhk(path)
%READGRACEFOIHK Read RL04 ASCII IPU housekeeping without repairing samples.
% Sensor IDs are retained, not assigned to guessed thermal components.
lines = readlines(path);
marker = find(strtrim(lines) == "# End of YAML header", 1);
if isempty(marker)
    error('leotherm:GracefoFormat', 'Expected a GRACE-FO RL04 YAML-header ASCII product.');
end
header = strjoin(lines(1:marker), newline);
if ~contains(header, 'IPU Housekeeping') || ~contains(header, 'product_version: 04') ...
        || ~contains(header, 'units: microseconds')
    error('leotherm:GracefoFormat', 'Only the documented IHK1B RL04 schema is supported.');
end
count = regexp(char(header), 'num_records:\s*(\d+)', 'tokens', 'once');
body = lines(marker+1:end);
% A terminal newline is not a data record. Interior blank lines are errors.
if ~isempty(body) && strlength(body(end)) == 0, body(end) = []; end
if isempty(count) || numel(body) ~= str2double(count{1})
    error('leotherm:GracefoFormat', 'Record count differs from the source header.');
end
pattern = '^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+?)\s*$';
tokens = regexp(cellstr(body), pattern, 'tokens', 'once');
if any(cellfun(@isempty, tokens))
    error('leotherm:GracefoFormat', 'Malformed data row; no row was silently dropped.');
end
values = string(vertcat(tokens{:}));
integer = str2double(values(:,1)); fraction = str2double(values(:,2));
timeRef = values(:,3); spacecraft = values(:,4); flags = values(:,5);
type = values(:,6); observed = str2double(values(:,7)); sensor = values(:,8);
n = numel(integer);
validTime = isfinite(integer) & integer == fix(integer) & isfinite(fraction) ...
    & fraction == fix(fraction) & fraction >= 0 & fraction < 1e6 & timeRef == "G";
epoch = NaT(n,1,'TimeZone','UTC');
% IERS Bulletin C 72: GPS-UTC = 18 s throughout this supported mission interval.
% Keep integer seconds and microseconds separate to avoid loss in a 1e9-s sum.
base = datetime(2000,1,1,12,0,0,'TimeZone','UTC');
epoch(validTime) = base + seconds(integer(validTime)-18) + seconds(fraction(validTime)/1e6);
supported = epoch >= datetime(2018,1,1,'TimeZone','UTC') ...
    & epoch < datetime(2027,1,1,'TimeZone','UTC');
if any(validTime & ~supported)
    error('leotherm:GracefoTime', 'Adapter supports 2018-2026 only; outside this interval review leap seconds first.');
end
epoch.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSSSSS''Z''';
flagSyntax = ~cellfun(@isempty, regexp(cellstr(flags), '^[01]{8}$', 'once'));
good = validTime & flagSyntax & flags == "00000000" ...
    & ismember(spacecraft, ["C","D"]) & isfinite(observed);
reason = repmat("accepted", n, 1);
reason(~isfinite(observed)) = "nonfinite_value";
reason(~ismember(spacecraft,["C","D"])) = "invalid_spacecraft";
reason(~flagSyntax | flags ~= "00000000") = "quality_rejected";
reason(~validTime) = "invalid_gps_time";
temperatureK = nan(n,1);
temperatureK(type == "T") = observed(type == "T") + 273.15;
invalidTemperature = type == "T" & (~isfinite(temperatureK) | temperatureK <= 0);
good(invalidTemperature) = false; reason(invalidTemperature) = "invalid_temperature";
% Same epochs across channels are legitimate; duplicates within a channel are not.
channels = unique(spacecraft + ":" + type + ":" + sensor, 'stable');
for k = 1:numel(channels)
    at = spacecraft + ":" + type + ":" + sensor == channels(k) & validTime;
    if any(diff(epoch(at)) <= seconds(0))
        error('leotherm:GracefoTime', 'Non-increasing or duplicate epochs within a sensor channel.');
    end
end
records = table((1:n)',epoch,integer,fraction,timeRef,spacecraft,flags,type, ...
    sensor,observed,temperatureK,good,reason,'VariableNames', ...
    {'source_record','epoch_utc','gps_seconds','gps_microseconds','time_ref', ...
    'spacecraft','quality_bits','sensor_type','sensor_id','source_value', ...
    'temperature_k','accepted','reason'});
metadata = struct('source',char(path),'doi','10.5067/GFJPL-L1B04', ...
    'datasetKind','real_flight_telemetry','sourceTemperatureUnit','degC', ...
    'gpsMinusUtcS',18,'timeSupport','2018-01-01 through 2026-12-31', ...
    'timeAuthority','https://hpiers.obspm.fr/iers/bul/bulc/Leap_Second.dat', ...
    'sensorLocation','unresolved_numeric_sensor_ids', ...
    'interpolation',false,'physicalValidationComplete',false, ...
    'header',char(header));
end
