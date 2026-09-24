function tests = test_validation_and_usability
tests = functiontests(localfunctions);
end

function testInvalidScenarioRejectedBeforeAllocation(testCase)
scenario = shortScenario;
scenario.timeStepS = 0;
verifyError(testCase, ...
    @() leotherm.simulateScenario(scenario, leotherm.defaultReceiverNetwork), ...
    'leotherm:InvalidScenario');
end

function testExternalEpochLengthRejected(testCase)
[trajectory, scenario, network] = externalInputs;
trajectory.epoch = trajectory.epoch(1);
verifyError(testCase, ...
    @() leotherm.simulateTrajectory(trajectory, scenario, network, []), ...
    'leotherm:InvalidTrajectory');
end

function testNonorthonormalFrameRejected(testCase)
[trajectory, scenario, network] = externalInputs;
trajectory.frameBodyAxesECI = zeros(numel(trajectory.elapsedS), 3, 3);
verifyError(testCase, ...
    @() leotherm.simulateTrajectory(trajectory, scenario, network, []), ...
    'leotherm:InvalidTrajectory');
end

function testNonfiniteNetworkNormalRejected(testCase)
network = leotherm.defaultReceiverNetwork;
network.normalBody(1, 1) = NaN;
verifyError(testCase, @() leotherm.validateNetwork(network), ...
    'leotherm:InvalidNetwork');
end

function testBiasDimensionRejected(testCase)
network = leotherm.defaultReceiverNetwork;
network.bias.linearMPerK(end) = [];
verifyError(testCase, @() leotherm.validateNetwork(network), ...
    'leotherm:InvalidNetwork');
end

function testGenericNetworkCanBePlotted(testCase)
previous = get(groot, 'DefaultFigureVisible');
cleanup = onCleanup(@() set(groot, 'DefaultFigureVisible', previous));
set(groot, 'DefaultFigureVisible', 'off');
scenario = shortScenario;
network = leotherm.satmoStyleNetwork;
result = leotherm.simulateScenario(scenario, network);
output = [tempname '.png'];
fileCleanup = onCleanup(@() deleteIfPresent(output));
leotherm.plotScenario(result, output);
verifyTrue(testCase, isfile(output));
verifyGreaterThan(testCase, dir(output).bytes, 1000);
end

function testScenarioPlotSupportsBothLanguagesAndLegends(testCase)
previous = get(groot, 'DefaultFigureVisible');
cleanup = onCleanup(@() set(groot, 'DefaultFigureVisible', previous));
set(groot, 'DefaultFigureVisible', 'off');
result = leotherm.simulateScenario(shortScenario, ...
    leotherm.defaultReceiverNetwork);
for language = {'zh', 'en'}
    output = [tempname '.png'];
    figureHandle = leotherm.plotScenario(result, output, language{1});
    figureCleanup = onCleanup(@() closeIfValid(figureHandle));
    fileCleanup = onCleanup(@() deleteIfPresent(output));
    verifyEqual(testCase, numel(findall(figureHandle, 'Type', 'legend')), 4);
    verifyTrue(testCase, isfile(output));
    verifyGreaterThan(testCase, dir(output).bytes, 1000);
    closeIfValid(figureHandle);
    deleteIfPresent(output);
    clear figureCleanup fileCleanup
end
clear cleanup
end

function testSweepPlotSupportsBothLanguagesAndLegends(testCase)
previous = get(groot, 'DefaultFigureVisible');
cleanup = onCleanup(@() set(groot, 'DefaultFigureVisible', previous));
set(groot, 'DefaultFigureVisible', 'off');
summary = sampleSweepSummary;
for language = {'zh', 'en'}
    output = [tempname '.png'];
    figureHandle = leotherm.plotSweep(summary, output, language{1});
    figureCleanup = onCleanup(@() closeIfValid(figureHandle));
    fileCleanup = onCleanup(@() deleteIfPresent(output));
    verifyEqual(testCase, numel(findall(figureHandle, 'Type', 'legend')), 4);
    verifyTrue(testCase, isfile(output));
    verifyGreaterThan(testCase, dir(output).bytes, 1000);
    closeIfValid(figureHandle);
    deleteIfPresent(output);
    clear figureCleanup fileCleanup
end
clear cleanup
end

function testLanguageAliasesAndNodeLabels(testCase)
verifyEqual(testCase, leotherm.normalizeLanguage('中文'), 'zh');
verifyEqual(testCase, leotherm.normalizeLanguage('English'), 'en');
verifyError(testCase, @() leotherm.normalizeLanguage('mixed'), ...
    'leotherm:InvalidLanguage');
names = {'gnss_rf_frontend', 'face_+Z_nadir'};
verifyEqual(testCase, leotherm.nodeDisplayNames(names, 'zh'), ...
    {'卫星导航射频前端', '对地表面'});
verifyEqual(testCase, leotherm.nodeDisplayNames(names, 'en'), ...
    {'GNSS RF front end', 'Nadir face'});
end

function testEmptySweepPlotRejected(testCase)
scenario = shortScenario;
summary = leotherm.runBetaAltitudeSweep( ...
    scenario, leotherm.defaultReceiverNetwork, 600, 89, 1);
verifyError(testCase, ...
    @() leotherm.plotSweep(summary, [tempname '.png']), ...
    'leotherm:NoCompleteCases');
end

function testPhysicalSweepRetainsFailedCase(testCase)
scenario = shortScenario;
network = leotherm.defaultReceiverNetwork;
network.internalPowerW(:) = 1e9;
summary = leotherm.runPhysicalSweep(scenario, network, ...
    scenario.startEpoch, 600, 97.6, 20);
verifyEqual(testCase, height(summary), 1);
verifyEqual(testCase, summary.status{1}, 'failed');
verifyNotEmpty(testCase, summary.message{1});
end

function testVersionMatchesReleaseFile(testCase)
packageDir = fileparts(which('leotherm.version'));
root = fileparts(fileparts(packageDir));
expected = strtrim(fileread(fullfile(root, 'VERSION')));
verifyEqual(testCase, leotherm.version, expected);
end

function scenario = shortScenario
scenario = leotherm.defaultScenario;
scenario.durationS = 600;
scenario.timeStepS = 60;
scenario.convergence.enabled = false;
scenario.warmupOrbits = 0;
end

function [trajectory, scenario, network] = externalInputs
scenario = shortScenario;
network = leotherm.defaultReceiverNetwork;
trajectory = leotherm.propagateCircularOrbit( ...
    scenario.startEpoch, (0:60:600)', scenario.orbit);
end

function summary = sampleSweepSummary
status = {'complete'; 'complete'; 'complete'; 'complete'};
accessible = true(4, 1);
altitude_km = [400; 400; 600; 600];
beta_deg = [-30; 30; -30; 30];
eclipse_fraction = [0.32; 0.31; 0.29; 0.28];
rf_temperature_span_k = [5.1; 5.0; 4.7; 4.6];
forcing_to_rf_lag_s = [420; 430; 460; 470];
code_bias_span_m = [0.40; 0.39; 0.36; 0.35];
summary = table(status, accessible, altitude_km, beta_deg, ...
    eclipse_fraction, rf_temperature_span_k, forcing_to_rf_lag_s, ...
    code_bias_span_m);
end

function deleteIfPresent(path)
if isfile(path)
    delete(path);
end
end

function closeIfValid(figureHandle)
if ~isempty(figureHandle) && isvalid(figureHandle)
    close(figureHandle);
end
end
