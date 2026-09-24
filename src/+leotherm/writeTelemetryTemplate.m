function raw = writeTelemetryTemplate(path, network, mode, includeBoundary)
%WRITETELEMETRYTEMPLATE Write an empty CSV with explicit units and node IDs.
leotherm.validateNetwork(network);
if nargin < 4, includeBoundary = false; end
validateattributes(includeBoundary, {'logical'}, {'scalar'});
names = {'epoch_utc', 'quality'};
switch mode
    case 'orbit'
        names = [names, {'x_eci_m','y_eci_m','z_eci_m', ...
            'vx_eci_mps','vy_eci_mps','vz_eci_mps','sun_x_eci_m','sun_y_eci_m','sun_z_eci_m'}];
    case 'heat'
        for k = 1:numel(network.nodeNames)
            names{end+1} = ['external_power_w_' matlab.lang.makeValidName(network.nodeNames{k})]; %#ok<AGROW>
        end
    case 'validation'
    otherwise
        error('leotherm:TelemetryOptions', 'Template mode must be orbit, heat, or validation.');
end
for k = 1:numel(network.nodeNames)
    names{end+1} = ['temperature_k_' matlab.lang.makeValidName(network.nodeNames{k})]; %#ok<AGROW>
    if includeBoundary && ~strcmp(mode, 'validation')
        key = matlab.lang.makeValidName(network.nodeNames{k});
        names(end+1:end+2) = {['boundary_temperature_k_' key], ['boundary_conductance_wk_' key]};
    end
end
if numel(unique(names)) ~= numel(names)
    error('leotherm:TelemetryMapping', 'Node names have colliding CSV-safe identifiers.');
end
raw = array2table(strings(0, numel(names)), 'VariableNames', names);
writetable(raw, path);
end
