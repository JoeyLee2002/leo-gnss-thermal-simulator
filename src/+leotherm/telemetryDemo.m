function [raw, scenario, options] = telemetryDemo(network, includeBoundary)
%TELEMETRYDEMO Synthetic known-model example, not an independent validation dataset.
if nargin < 1, network = leotherm.defaultReceiverNetwork; end
if nargin < 2, includeBoundary = false; end
validateattributes(includeBoundary, {'logical'}, {'scalar'});
scenario = leotherm.defaultScenario;
scenario.durationS = 3600; scenario.timeStepS = 20;
scenario.convergence.enabled = false; scenario.warmupOrbits = 0;
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, (0:20:3600)', scenario.orbit);
raw = table(string(orbit.epoch, 'yyyy-MM-dd''T''HH:mm:ss''Z'''), ...
    ones(numel(orbit.epoch), 1), 'VariableNames', {'epoch_utc','quality'});
names = {'x_eci_m','y_eci_m','z_eci_m','vx_eci_mps','vy_eci_mps','vz_eci_mps', ...
    'sun_x_eci_m','sun_y_eci_m','sun_z_eci_m'};
values = [orbit.positionM, orbit.velocityMps, orbit.sunPositionM];
for k = 1:numel(names), raw.(names{k}) = values(:, k); end
raw.dataset_type = repmat("synthetic_demo_not_flight_data", height(raw), 1);
if includeBoundary
    key = matlab.lang.makeValidName(network.nodeNames{network.roles.response});
    raw.(['boundary_temperature_k_' key]) = 295 + 8*sin(2*pi*orbit.elapsedS/1200);
    raw.(['boundary_conductance_wk_' key]) = 0.15*ones(height(raw),1);
end
options = leotherm.telemetryOptions(struct('frame', 'J2000_ECI', 'maxGapS', 20));
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
nodes = unique([network.roles.response, network.roles.antenna, network.roles.oscillator]);
if isempty(nodes), nodes = 1; end
for k = nodes(:)'
    name = ['temperature_k_' matlab.lang.makeValidName(network.nodeNames{k})];
    raw.(name) = result.temperatureK(:, k) + 0.2;
end
end
