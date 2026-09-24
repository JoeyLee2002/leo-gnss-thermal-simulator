function summary = validate_satmo_reference
%VALIDATE_SATMO_REFERENCE Recompute and compare the matched SATMO case.
% The archived trace contains SATMO v1.5.0 numerical output only. No SATMO
% source code is redistributed. See docs/satmo_external_validation.md.

studyDir = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(studyDir));
addpath(fullfile(root, 'src'));

referenceDir = fullfile(studyDir, 'reference');
referencePath = fullfile(referenceDir, 'satmo_same_input_trace.csv');
assert(isfile(referencePath), 'Reference trace is missing: %s', referencePath);
reference = readtable(referencePath);

nodeNames = {'Zenith','Nadir','Forward','Aft','North','South','Internal'};
ours = runMatchedCase(reference.time_s(end), reference.time_s(2) - reference.time_s(1));
assert(isequal(ours.timeS, reference.time_s), 'Time grids differ; no interpolation is allowed.');

satmoK = nan(height(reference), numel(nodeNames));
for k = 1:numel(nodeNames)
    satmoK(:, k) = reference.(['satmo_' lower(nodeNames{k}) '_k']);
end
differenceK = ours.temperatureK - satmoK;
rmseK = sqrt(mean(differenceK.^2, 1));
maxAbsK = max(abs(differenceK), [], 1);

summary = table(string(nodeNames(:)), rmseK(:), maxAbsK(:), ...
    satmoK(end, :)', ours.temperatureK(end, :)', ...
    'VariableNames', {'node','rmse_k','max_abs_k','satmo_final_k','ours_final_k'});

outputDir = fullfile(root, 'results', 'softwarex_external_validation');
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
writetable(summary, fullfile(outputDir, 'satmo_same_input_summary.csv'));
save(fullfile(outputDir, 'satmo_same_input_results.mat'), ...
    'summary', 'differenceK', 'ours', 'satmoK');
disp(summary)
end

function output = runMatchedCase(durationS, timeStepS)
nodeNames = {'Zenith','Nadir','Forward','Aft','North','South','Internal'};
network.name = 'satmo_same_input_six_face_box';
network.nodeNames = nodeNames;
network.capacityJK = 0.25 * 896 * ones(7,1);
network.initialTemperatureK = 293.15 * ones(7,1);
network.internalPowerW = [0.5 * ones(6,1); 0];
network.projectedAreaM2 = [0.01 * ones(6,1); 0];
network.radiatingAreaM2 = network.projectedAreaM2;
network.normalBody = [0 0 -1; 0 0 1; 1 0 0; -1 0 0; ...
    0 -1 0; 0 1 0; 0 0 0];
network.solarAbsorptivity = [ones(6,1); 0];
network.irEmissivity = [ones(6,1); 0];
network.conductanceWK = zeros(7);
opposites = [1 2; 3 4; 5 6];
for i = 1:6
    for j = i+1:6
        if ~any(all(sort([i j]) == opposites, 2))
            network.conductanceWK(i,j) = 0.12;
            network.conductanceWK(j,i) = 0.12;
        end
    end
end
network.bias.linearMPerK = zeros(7,1);
network.bias.quadraticNode = 7;
network.bias.quadraticMPerK2 = 0;
network.roles.response = 7;
network.roles.antenna = [];
network.roles.oscillator = [];

scenario = leotherm.defaultScenario;
scenario.name = 'satmo_same_input_validation';
scenario.durationS = durationS;
scenario.timeStepS = timeStepS;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
scenario.orbit.altitudeM = 400e3;
sunPosition = leotherm.solarVectorECI(scenario.startEpoch);
sun = sunPosition ./ norm(sunPosition);
scenario.orbit.inclinationDeg = acosd(sun(3));
[scenario.orbit.raanDeg, accessible] = leotherm.solveRaanForBeta( ...
    scenario.startEpoch, scenario.orbit.inclinationDeg, 90, 1);
assert(accessible, 'The beta=90 deg geometry is inaccessible.');
scenario.orbit.useJ2 = false;
scenario.environment.freezeSunAtEpoch = true;
c = leotherm.constants;
sunDistanceAU = norm(sunPosition) / c.astronomicalUnit;
scenario.environment.solarConstantWm2 = 1361 * sunDistanceAU^2;
scenario.environment.albedo = 0;
scenario.environment.earthIRWm2 = 0;
scenario.environment.includeAlbedo = false;
scenario.environment.includeEarthIR = false;
scenario.environment.deepSpaceK = 2.73;

result = leotherm.simulateScenario(scenario, network);
output.timeS = result.timeS;
output.temperatureK = result.temperatureK;
output.actualBetaDeg = result.orbit.betaDeg;
end
