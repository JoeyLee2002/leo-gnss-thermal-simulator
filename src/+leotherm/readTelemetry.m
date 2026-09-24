function data = readTelemetry(source, mapping, network)
%READTELEMETRY Normalize explicit units; retain invalid rows for audit.
raw = leotherm.readTelemetryTable(source);
leotherm.validateNetwork(network);
if isempty(mapping)
    mapping = leotherm.telemetryMapping(raw, network);
end
required = {'source', 'target', 'node', 'unit'};
if ~istable(mapping) || ~all(ismember(required, mapping.Properties.VariableNames))
    error('leotherm:TelemetryMapping', 'Mapping needs source, target, node, and unit columns.');
end
for k = 1:numel(required)
    mapping.(required{k}) = string(mapping.(required{k}));
end
if any(ismissing(mapping{:, required}), 'all')
    error('leotherm:TelemetryMapping', 'Use empty strings, not missing mapping cells.');
end
active = mapping.target ~= "ignore";
if any(~ismember(mapping.source(active), raw.Properties.VariableNames)) ...
        || numel(unique(mapping.source(active))) ~= sum(active) ...
        || sum(mapping.target == "epoch") ~= 1
    error('leotherm:TelemetryMapping', 'Map exactly one time column and each active source once.');
end
keys = mapping.target(active) + ":" + mapping.node(active);
if numel(unique(keys)) ~= numel(keys)
    error('leotherm:TelemetryMapping', 'A target/node pair cannot have multiple source columns.');
end
n = height(raw); m = numel(network.nodeNames);
data.epoch = NaT(n, 1, 'TimeZone', 'UTC');
data.positionM = nan(n, 3); data.velocityMps = nan(n, 3); data.sunPositionM = nan(n, 3);
data.frameBodyAxesECI = nan(n, 3, 3);
data.temperatureK = nan(n, m); data.externalPowerW = nan(n, m);
data.internalPowerW = nan(n, m);
data.boundaryTemperatureK = nan(n, m); data.boundaryConductanceWK = nan(n, m);
data.hasBoundaryTemperature = false(1, m); data.hasBoundaryConductance = false(1, m);
data.hasTemperature = false(1, m); data.hasExternal = false(1, m);
data.hasInternal = false(1, m); data.hasPosition = false(1, 3);
data.hasVelocity = false(1, 3); data.hasAttitude = false(3, 3);
data.hasSun = false(1, 3);
quality = ones(n, 1);
for k = find(active)'
    t = char(mapping.target(k)); u = char(mapping.unit(k));
    rawValue = raw.(char(mapping.source(k)));
    if strcmp(t, 'epoch')
        requireUnit(u, {'UTC'});
        if strlength(mapping.node(k)) > 0
            error('leotherm:TelemetryMapping', 'The epoch mapping must not specify a thermal node.');
        end
        data.epoch = parseEpoch(rawValue);
        continue
    end
    if isnumeric(rawValue) || islogical(rawValue)
        value = double(rawValue);
    else
        value = str2double(string(rawValue));
    end
    if ~isreal(value) || ~iscolumn(value)
        error('leotherm:TelemetryMapping', 'Mapped numeric columns must be real scalar columns.');
    end
    switch t
        case 'quality'
            requireUnit(u, {'1'}); quality = value;
        case {'position_x','position_y','position_z','velocity_x','velocity_y','velocity_z','sun_x','sun_y','sun_z'}
            col = find('xyz' == t(end));
            if startsWith(t, 'sun')
                requireUnit(u, {'m','km'});
                if strcmp(u, 'km'), value = value * 1000; end
                data.sunPositionM(:, col) = value; data.hasSun(col) = true;
            elseif startsWith(t, 'position')
                requireUnit(u, {'m','km'});
                if strcmp(u, 'km'), value = value * 1000; end
                data.positionM(:, col) = value; data.hasPosition(col) = true;
            else
                requireUnit(u, {'m/s','km/s'});
                if strcmp(u, 'km/s'), value = value * 1000; end
                data.velocityMps(:, col) = value; data.hasVelocity(col) = true;
            end
        case {'temperature','external_power','internal_power','boundary_temperature','boundary_conductance'}
            col = find(strcmp(network.nodeNames, mapping.node(k)), 1);
            if isempty(col)
                error('leotherm:TelemetryMapping', 'Unknown thermal node: %s', mapping.node(k));
            end
            if strcmp(t, 'temperature')
                requireUnit(u, {'K','degC'});
                if strcmp(u, 'degC'), value = value + 273.15; end
                data.temperatureK(:, col) = value; data.hasTemperature(col) = true;
            elseif strcmp(t, 'external_power')
                requireUnit(u, {'W'});
                data.externalPowerW(:, col) = value; data.hasExternal(col) = true;
            elseif strcmp(t, 'internal_power')
                requireUnit(u, {'W'});
                data.internalPowerW(:, col) = value; data.hasInternal(col) = true;
            elseif strcmp(t, 'boundary_temperature')
                requireUnit(u, {'K','degC'});
                if strcmp(u, 'degC'), value = value + 273.15; end
                data.boundaryTemperatureK(:, col) = value; data.hasBoundaryTemperature(col) = true;
            else
                requireUnit(u, {'W/K'});
                data.boundaryConductanceWK(:, col) = value; data.hasBoundaryConductance(col) = true;
            end
        otherwise
            match = regexp(t, '^dcm_([123])([123])$', 'tokens', 'once');
            if isempty(match)
                error('leotherm:TelemetryMapping', 'Unknown mapping target: %s', t);
            end
            requireUnit(u, {'1'});
            a = str2double(match{1}); b = str2double(match{2});
            data.frameBodyAxesECI(:, a, b) = value; data.hasAttitude(a, b) = true;
    end
    if ~ismember(t, {'temperature','external_power','internal_power','boundary_temperature','boundary_conductance'}) ...
            && strlength(mapping.node(k)) > 0
        error('leotherm:TelemetryMapping', 'Non-node targets must have an empty node mapping.');
    end
end
if any(data.hasBoundaryTemperature ~= data.hasBoundaryConductance)
    error('leotherm:TelemetryBoundary', 'Map both boundary temperature and conductance for each connected node.');
end
validTime = ~isnat(data.epoch);
data.epoch.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSS''Z''';
if sum(validTime) < 2 || any(diff(data.epoch(validTime)) <= seconds(0))
    error('leotherm:TelemetryTime', ...
        'Need two valid, unique, increasing UTC epochs. Duplicate or unsorted times are not repaired.');
end
data.accepted = validTime & isfinite(quality) & quality == 1;
reason = repmat("accepted", n, 1);
reason(~isfinite(quality) | quality ~= 1) = "quality_rejected";
reason(~validTime) = "invalid_utc_time";
data.audit = table((1:n)', data.epoch, data.accepted, reason, ...
    'VariableNames', {'source_row','epoch_utc','accepted','reason'});
data.nodeNames = network.nodeNames;
data.mapping = mapping;
data.rawTable = raw;
data.datasetKind = 'user_supplied_unverified';
if ismember('dataset_type', raw.Properties.VariableNames) ...
        && any(contains(string(raw.dataset_type), 'synthetic'))
    data.datasetKind = 'synthetic_demo_not_flight_data';
end
data.source = '<MATLAB table>';
if ~istable(source), data.source = char(source); end
data.softwareVersion = leotherm.version;
data.importedUTC = datetime('now', 'TimeZone', 'UTC');
end

function requireUnit(unit, allowed)
if ~ismember(unit, allowed)
    error('leotherm:TelemetryUnit', 'Unit "%s" is invalid; expected %s.', unit, strjoin(allowed, ' or '));
end
end

function epoch = parseEpoch(value)
if isdatetime(value)
    if isempty(value.TimeZone)
        error('leotherm:TelemetryTime', 'Datetime input must have an explicit time zone.');
    end
    epoch = value; epoch.TimeZone = 'UTC'; return
end
value = string(value);
epoch = NaT(numel(value), 1, 'TimeZone', 'UTC');
for k = 1:numel(value)
    if ismissing(value(k)), continue; end
    text = char(value(k));
    if isempty(regexp(text, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$', 'once'))
        continue
    end
    format = 'yyyy-MM-dd''T''HH:mm:ss';
    dot = strfind(text, '.');
    if ~isempty(dot)
        format = [format '.' repmat('S', 1, length(text) - dot - 1)]; %#ok<AGROW>
    end
    try
        epoch(k) = datetime(text, 'InputFormat', [format '''Z'''], 'TimeZone', 'UTC');
    catch
        % An invalid calendar date remains rejected, never inferred.
    end
end
end
