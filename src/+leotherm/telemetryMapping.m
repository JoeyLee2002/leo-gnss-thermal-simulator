function mapping = telemetryMapping(raw, network)
%TELEMETRYMAPPING Suggest mappings only for explicitly unit-tagged columns.
leotherm.validateNetwork(network);
source = string(raw.Properties.VariableNames(:));
target = repmat("ignore", numel(source), 1);
node = repmat("", numel(source), 1);
unit = repmat("", numel(source), 1);
simple = {'epoch_utc','epoch','UTC'; 'quality','quality','1'; ...
    'x_eci_m','position_x','m'; 'y_eci_m','position_y','m'; ...
    'z_eci_m','position_z','m'; 'vx_eci_mps','velocity_x','m/s'; ...
    'vy_eci_mps','velocity_y','m/s'; 'vz_eci_mps','velocity_z','m/s'; ...
    'sun_x_eci_m','sun_x','m'; 'sun_y_eci_m','sun_y','m'; 'sun_z_eci_m','sun_z','m'};
keys = matlab.lang.makeValidName(network.nodeNames);
if numel(unique(keys)) ~= numel(keys)
    error('leotherm:TelemetryMapping', 'Node names have colliding CSV-safe identifiers.');
end
for k = 1:numel(source)
    match = find(strcmp(simple(:, 1), source(k)), 1);
    if ~isempty(match)
        target(k) = simple{match, 2}; unit(k) = simple{match, 3};
    end
    for a = 1:3
        for b = 1:3
            if source(k) == sprintf('eci_to_body_%d%d', a, b)
                target(k) = sprintf('dcm_%d%d', a, b); unit(k) = "1";
            end
        end
    end
    prefixes = {'temperature_k_', 'temperature_c_', ...
        'external_power_w_', 'internal_power_w_', 'boundary_temperature_k_', ...
        'boundary_temperature_c_', 'boundary_conductance_wk_'};
    kinds = {'temperature', 'temperature', 'external_power', 'internal_power', ...
        'boundary_temperature', 'boundary_temperature', 'boundary_conductance'};
    units = {'K', 'degC', 'W', 'W', 'K', 'degC', 'W/K'};
    for n = 1:numel(keys)
        for p = 1:numel(prefixes)
            if source(k) == string([prefixes{p} keys{n}])
                target(k) = kinds{p}; node(k) = network.nodeNames{n};
                unit(k) = units{p};
            end
        end
    end
end
mapping = table(source, target, node, unit);
end
