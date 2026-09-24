function f = deviceCalibrationDemo(dayCount, withBoundary)
%DEVICECALIBRATIONDEMO Deterministic synthetic heat transients, never flight data.
if nargin < 1, dayCount = 3; end
if nargin < 2, withBoundary = false; end
validateattributes(dayCount, {'numeric'}, {'scalar', 'integer'});
assert(ismember(dayCount, [3, 6]), 'Use three or six separate UTC days.');
validateattributes(withBoundary, {'logical'}, {'scalar'});

network.name = 'synthetic_single_node_calibration';
network.nodeNames = {'device'};
network.capacityJK = 100;
network.initialTemperatureK = 300;
network.internalPowerW = 0.4;
network.projectedAreaM2 = 0.01;
network.radiatingAreaM2 = 0.01;
network.normalBody = [1, 0, 0];
network.solarAbsorptivity = 0.5;
network.irEmissivity = 0.6;
network.conductanceWK = 0;
network.bias = struct('linearMPerK', 0, 'quadraticNode', 1, ...
    'quadraticMPerK2', 0);
leotherm.validateNetwork(network);
trueNetwork = network;
trueNetwork.capacityJK = 110;

scenario = leotherm.defaultScenario;
scenario.name = 'synthetic_calibration_test_only';
scenario.startEpoch = datetime(2024, 1, 1, 23, 0, 0, 'TimeZone', 'UTC');
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
samplesPerDay = 50;
dayIndex = repelem((1:dayCount)', samplesPerDay);
elapsedS = repmat((0:samplesPerDay-1)' * 10, dayCount, 1);
epoch = scenario.startEpoch + days(dayIndex-1) + seconds(elapsedS);
powerW = 2 + 0.2*(dayIndex-1) + 5*(elapsedS >= 100 & elapsedS < 350);
raw = table(epoch, ones(size(epoch)), ...
    repmat("synthetic", size(epoch)), powerW, ...
    'VariableNames', {'epoch_utc', 'quality', 'dataset_type', ...
    'external_power_w_device'});
if withBoundary
    raw.boundary_temperature_k_device = 295 + 0.3*(dayIndex-1) ...
        + 0.5*(elapsedS >= 200);
    raw.boundary_conductance_wk_device = 0.03 * ones(size(epoch));
end

settings = leotherm.deviceCalibrationOptions(struct( ...
    'telemetryOptions', struct('mode', 'heat', 'maxGapS', 10, ...
        'maxStepS', 10, 'excludeInitialS', 20, 'useInitialTemperature', false), ...
    'temperatureSigmaK', 0.02, ...
    'sensorEvidence', 'Synthetic known noise assumption; not a flight sensor calibration.', ...
    'regularizationWeight', 1, 'rmseToleranceK', 0.05, ...
    'solverSettings', struct('starts', 2, 'solver', 'fminsearch', ...
        'maximumIterations', 300)), 1);

% Each day starts from the exact same nominal state; targets never initialize it.
drivers = leotherm.readTelemetry(raw, [], network);
truth = leotherm.simulateTelemetry(drivers, scenario, trueNetwork, ...
    settings.telemetryOptions);
assert(all(truth.segments.status == "complete"));
noiseK = 0.003 * sin((1:height(raw))' * sqrt(2));
raw.temperature_k_device = truth.temperatureK + noiseK;
data = leotherm.readTelemetry(raw, [], network);

profile = leotherm.deviceCalibrationProfile(network);
active = profile.parameters.field == "capacityJK";
profile.parameters.estimate(active) = true;
profile.parameters.lower(active) = 0.8 * network.capacityJK;
profile.parameters.upper(active) = 1.2 * network.capacityJK;
profile.parameters.priorSigma(active) = 10;
profile.parameters.evidence(active) = "Synthetic known physical heat capacity assumption.";
profile.parameters.kind(active) = "physical";
profile = leotherm.validateDeviceCalibrationProfile(profile, network);
split = leotherm.calibrationDaySplit(data);
split.role = repelem(["train"; "validation"; "test"], dayCount/3);

f = struct('network', network, 'trueNetwork', trueNetwork, ...
    'scenario', scenario, 'settings', settings, 'profile', profile, ...
    'raw', raw, 'data', data, 'split', split, 'truth', truth, ...
    'noiseK', noiseK, 'dayIndex', dayIndex, 'elapsedS', elapsedS, ...
    'samplesPerDay', samplesPerDay, 'dayCount', dayCount);
end
