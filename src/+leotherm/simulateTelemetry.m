function result = simulateTelemetry(data, scenario, network, options)
%SIMULATETELEMETRY Integrate valid contiguous telemetry segments without gap filling.
if nargin < 4, options = struct; end
options = leotherm.telemetryOptions(options);
leotherm.validateScenario(scenario); leotherm.validateNetwork(network);
if ~isequal(data.nodeNames, network.nodeNames)
    error('leotherm:TelemetryMapping', 'Remap telemetry after changing the network nodes.');
end
n = numel(data.epoch); m = numel(network.nodeNames);
good = data.accepted;
audit = data.audit;
externalW = nan(n, m);
internalW = repmat(network.internalPowerW(:)', n, 1);
internalW(:, data.hasInternal) = data.internalPowerW(:, data.hasInternal);
goodPower = all(isfinite(internalW) & internalW >= 0, 2);
audit.reason(good & ~goodPower) = "invalid_internal_power";
good = good & goodPower;
boundaryK = repmat(network.initialTemperatureK(:)', n, 1);
boundaryG = zeros(n, m); boundaryNodes = false(1, m);
if isfield(data, 'hasBoundaryTemperature')
    if any(data.hasBoundaryTemperature ~= data.hasBoundaryConductance)
        error('leotherm:TelemetryBoundary', 'Boundary temperature and conductance mappings must match.');
    end
    boundaryNodes = data.hasBoundaryTemperature;
    boundaryK(:, boundaryNodes) = data.boundaryTemperatureK(:, boundaryNodes);
    boundaryG(:, boundaryNodes) = data.boundaryConductanceWK(:, boundaryNodes);
    valid = all(isfinite(boundaryK) & boundaryK > 0 & isfinite(boundaryG) & boundaryG >= 0, 2);
    audit.reason(good & ~valid) = "invalid_thermal_boundary";
    good = good & valid;
end
if strcmp(options.mode, 'heat')
    if ~all(data.hasExternal)
        error('leotherm:TelemetryMapping', ...
            'Heat mode requires absorbed external power in W for every node, including explicit zeros.');
    end
    externalW = data.externalPowerW;
    valid = all(isfinite(externalW) & externalW >= 0, 2);
    audit.reason(good & ~valid) = "invalid_external_power";
    good = good & valid;
    attitudeSource = 'not_used';
else
    if ~strcmp(options.frame, 'J2000_ECI')
        error('leotherm:TelemetryFrame', ...
            'Explicitly confirm geocentric J2000 ECI coordinates; ECEF/TEME/GPS time are not converted.');
    end
    if ~all(data.hasPosition) || ~all(data.hasVelocity) || ~all(data.hasSun) || any(data.hasExternal)
        error('leotherm:TelemetryMapping', ...
            ['Orbit mode needs complete position, velocity, and geocentric Sun position in the same frame; ' ...
            'do not also map external power.']);
    end
    c = leotherm.constants;
    radius = vecnorm(data.positionM, 2, 2);
    speed = vecnorm(data.velocityMps, 2, 2);
    angular = vecnorm(cross(data.positionM, data.velocityMps, 2), 2, 2);
    valid = all(isfinite(data.positionM), 2) & all(isfinite(data.velocityMps), 2) ...
        & radius > c.radiusEarth & radius < c.radiusEarth + 50000e3 ...
        & speed > 0 & speed < 20e3 & angular > 0;
    audit.reason(good & ~valid) = "invalid_orbit"; good = good & valid;
    sunRadius = vecnorm(data.sunPositionM, 2, 2);
    valid = all(isfinite(data.sunPositionM), 2) ...
        & sunRadius > 0.8*c.astronomicalUnit & sunRadius < 1.2*c.astronomicalUnit;
    audit.reason(good & ~valid) = "invalid_sun_position"; good = good & valid;
    attitudeSource = 'scenario_attitude';
    if any(data.hasAttitude, 'all')
        if ~all(data.hasAttitude, 'all')
            error('leotherm:TelemetryMapping', 'Map all nine ECI-to-body rotation entries or none.');
        end
        attitudeSource = 'telemetry_attitude';
        for k = find(good)'
            r = squeeze(data.frameBodyAxesECI(k, :, :));
            if any(~isfinite(r), 'all') || max(abs(r*r'-eye(3)), [], 'all') > 1e-6 ...
                    || abs(det(r)-1) > 1e-6
                good(k) = false; audit.reason(k) = "invalid_attitude";
            end
        end
    end
    rows = find(good);
    if ~isempty(rows)
        orbit.epoch = data.epoch(rows);
        orbit.elapsedS = seconds(orbit.epoch - orbit.epoch(1));
        orbit.positionM = data.positionM(rows, :); orbit.velocityMps = data.velocityMps(rows, :);
        orbit.sunPositionM = data.sunPositionM(rows, :);
        if strcmp(attitudeSource, 'telemetry_attitude')
            frame = data.frameBodyAxesECI(rows, :, :);
        else
            frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
                orbit.sunPositionM, scenario.attitude);
        end
        loads = leotherm.environmentHeatLoads(orbit, frame, network, scenario.environment);
        externalW(rows, :) = loads.totalExternalW;
    end
end
temperature = nan(n, m); segmentId = zeros(n, 1);
segmentRows = {}; segmentStatus = strings(0, 1); segmentMessages = strings(0, 1);
segmentNumerics = {};
rows = find(good);
if ~isempty(rows)
    breaks = [true; diff(rows) ~= 1 | seconds(diff(data.epoch(rows))) > options.maxGapS];
    ids = cumsum(breaks);
    for id = 1:max(ids)
        selected = rows(ids == id);
        segmentRows{end + 1, 1} = selected; %#ok<AGROW>
        segmentStatus(end + 1, 1) = "complete"; %#ok<AGROW>
        segmentMessages(end + 1, 1) = ""; %#ok<AGROW>
        segmentNumerics{end+1,1} = []; %#ok<AGROW>
        if numel(selected) < 2
            audit.reason(selected) = "isolated_sample";
            segmentStatus(end) = "isolated_sample";
            continue
        end
        segmentNetwork = network;
        try
            if options.useInitialTemperature
                if ~any(data.hasTemperature)
                    error('leotherm:TelemetryInitialization', 'No initial temperatures are mapped.');
                end
                initial = data.temperatureK(selected(1), data.hasTemperature);
                if any(~isfinite(initial)) || any(initial <= 0)
                    error('leotherm:TelemetryInitialization', 'Initial measured temperatures are invalid.');
                end
                segmentNetwork.initialTemperatureK(data.hasTemperature) = initial;
            end
            forcing.internalPowerW = internalW(selected, :);
            forcing.holdPrevious = true;
            forcing.maxStepS = options.maxStepS;
            if any(boundaryNodes)
                forcing.boundaryTemperatureK = boundaryK(selected, :);
                forcing.boundaryConductanceWK = boundaryG(selected, :);
            end
            [temperature(selected, :), segmentNumerics{end}] = leotherm.solveThermalNetwork( ...
                seconds(data.epoch(selected)-data.epoch(selected(1))), ...
                externalW(selected, :), segmentNetwork, scenario.environment, ...
                scenario.integration, forcing);
            segmentId(selected) = id;
            audit.reason(selected) = "simulated";
        catch exception
            segmentStatus(end) = "failed";
            segmentMessages(end) = string(exception.identifier) + ": " + string(exception.message);
            audit.reason(selected) = "segment_failed";
        end
    end
end
audit.accepted = segmentId > 0;
audit.segment_id = segmentId;
result.epoch = data.epoch;
result.temperatureK = temperature;
result.network = network; result.scenario = scenario;
result.segmentId = segmentId;
result.externalPowerW = externalW; result.internalPowerW = internalW;
result.boundaryTemperatureK = boundaryK; result.boundaryConductanceWK = boundaryG;
result.boundaryHeatW = boundaryG .* (boundaryK-temperature);
result.boundaryHeatW(segmentId == 0, :) = NaN;
result.boundaryMapped = boundaryNodes;
result.audit = audit;
result.segments = table(segmentRows, segmentStatus, segmentMessages, ...
    'VariableNames', {'source_rows','status','message'});
result.segmentNumerics = segmentNumerics;
result.options = options;
result.provenance.source = data.source;
result.provenance.softwareVersion = leotherm.version;
result.provenance.forcingPolicy = 'left_hold_on_valid_intervals_no_gap_filling';
result.provenance.attitudeSource = attitudeSource;
result.provenance.sunSource = 'not_used';
if strcmp(options.mode, 'orbit'), result.provenance.sunSource = 'provided_in_same_j2000_frame'; end
result.provenance.initialization = 'network_initial_temperature_each_segment';
if options.useInitialTemperature
    result.provenance.initialization = 'measured_initial_temperature_conditioned';
end
result.provenance.periodicWarmupApplied = false;
result.provenance.parametersFitted = false;
result.provenance.interpolation = false;
result.provenance.boundaryConditioning = any(boundaryNodes);
result.provenance.boundaryPolicy = 'prescribed_reservoir_temperature_left_hold_no_two_way_reservoir_dynamics';
result.provenance.boundaryHeatSampling = 'instantaneous_right_sample_not_integrated_energy';
result.provenance.sourceRows = height(data.rawTable);
end
