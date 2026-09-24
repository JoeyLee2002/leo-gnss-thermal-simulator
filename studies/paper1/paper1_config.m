function config = paper1_config(profile)
%PAPER1_CONFIG Reproducible design for the first thermal-lag paper.

if nargin < 1 || isempty(profile)
    profile = 'paper';
end
profile = lower(char(profile));
assert(ismember(profile, {'smoke', 'paper'}), ...
    'profile must be smoke or paper.');

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
config.study = 'paper1_orbital_geometry_thermal_lag';
config.profile = profile;
config.softwareVersion = strtrim(fileread(fullfile(root, 'VERSION')));
config.seed = 20260901;
config.outputDirectory = fullfile(root, 'results', ...
    ['paper1_v' strrep(config.softwareVersion, '.', '_') '_' profile]);
config.checkpointEvery = 10;

base = leotherm.defaultScenario;
base.name = 'paper1_reference';
base.startEpoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
base.durationS = 6 * 3600;
base.timeStepS = 30;
base.orbit.altitudeM = 600e3;
base.orbit.inclinationDeg = 90;
base.orbit.argumentLatitudeDeg = 0;
base.orbit.useJ2 = true;
base.attitude.mode = 'nadir';
base.attitude.eulerOffsetDeg = [0, 0, 0];
base.convergence.minimumCycles = 5;
base.convergence.maximumCycles = 60;
base.convergence.requiredStableCycles = 2;
base.convergence.toleranceK = 5e-3;
base.convergence.failOnNonConvergence = true;
config.baseScenario = base;

if strcmp(profile, 'smoke')
    config.experiment1.altitudeKm = [400, 800];
    config.experiment1.betaDeg = [0, 45, 75];
    config.experiment2.dates = datetime(2024, [3, 9], 20, 12, 0, 0, ...
        'TimeZone', 'UTC');
    config.experiment2.inclinationDeg = [50, 97.6];
    config.experiment2.raanDeg = [0, 120, 240];
    config.experiment3.absBetaDeg = [20, 60];
    config.experiment3.variants = variantTable(true);
    config.uncertainty.betaDeg = [0, 60];
    config.uncertainty.samplesPerRegime = 2;
else
    config.experiment1.altitudeKm = [400, 500, 600, 800, 1000];
    config.experiment1.betaDeg = 0:5:80;
    config.experiment2.dates = datetime(2024, 1:12, 20, 12, 0, 0, ...
        'TimeZone', 'UTC');
    config.experiment2.inclinationDeg = [30, 50, 70, 90, 97.6];
    config.experiment2.raanDeg = 0:30:330;
    config.experiment3.absBetaDeg = [10, 30, 50, 70];
    config.experiment3.variants = variantTable(false);
    config.uncertainty.betaDeg = [0, 40, 70];
    config.uncertainty.samplesPerRegime = 50;
end

config.experiment1.epoch = base.startEpoch;
config.experiment1.inclinationDeg = 90;
config.experiment1.branch = 1;
config.experiment2.altitudeKm = 600;
config.experiment3.altitudeKm = 600;
config.experiment3.epoch = base.startEpoch;
config.experiment3.inclinationDeg = 90;
config.experiment3.branch = 1;
config.uncertainty.altitudeKm = 600;
config.uncertainty.epoch = base.startEpoch;
config.uncertainty.inclinationDeg = 90;
config.uncertainty.samples = struct( ...
    'capacity', 0.20, 'conductance', 0.30, 'power', 0.20, ...
    'absorptivity', 0.12, 'emissivity', 0.08);
end

function variants = variantTable(smoke)
if smoke
    mechanism = {'symmetric'; 'surface_optical'; 'receiver_mount'; ...
        'attitude_pitch'; 'attitude_roll'};
    networkLevel = [0; 0.5; 1.0; 0; 0];
    attitudePitchDeg = [0; 0; 0; 10; 0];
    attitudeRollDeg = [0; 0; 0; 0; 10];
else
    mechanism = {'symmetric'; ...
        'surface_optical'; 'surface_optical'; 'surface_optical'; ...
        'structural_coupling'; 'structural_coupling'; 'structural_coupling'; ...
        'receiver_mount'; 'receiver_mount'; 'receiver_mount'; 'receiver_mount'; ...
        'combined'; 'combined'; 'combined'; ...
        'attitude_pitch'; 'attitude_pitch'; 'attitude_pitch'; ...
        'attitude_roll'; 'attitude_roll'; 'attitude_roll'};
    networkLevel = [0; 0.25; 0.50; 0.75; 0.25; 0.50; 0.75; ...
        0.25; 0.50; 0.75; 1.00; 0.25; 0.50; 0.75; 0; 0; 0; 0; 0; 0];
    attitudePitchDeg = [zeros(14, 1); 5; 10; 20; 0; 0; 0];
    attitudeRollDeg = [zeros(17, 1); 5; 10; 20];
end
variants = table(mechanism, networkLevel, attitudePitchDeg, attitudeRollDeg, ...
    'VariableNames', {'mechanism', 'network_level', 'attitude_pitch_deg', ...
    'attitude_roll_deg'});
end
