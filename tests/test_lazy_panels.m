function tests = test_lazy_panels
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.fixture = leotherm.deviceCalibrationDemo;
end

function setup(testCase)
assumeTrue(testCase, usejava('jvm'), 'Panel tests require the JVM.');
end

function testStartupStateMatchesEagerAndStaysUnbuilt(testCase)
[fig, eager, lazy, calibration, lazyCalibration] = panels(testCase);
verifyTrue(testCase, eager.UIReady);
verifyTrue(testCase, calibration.UIReady);
verifyUnbuilt(testCase, lazy);
verifyUnbuilt(testCase, lazyCalibration);
initial = calibration.getState;
verifyEmpty(testCase, initial.profile);
verifyTrue(testCase, isequaln(initial, lazyCalibration.getState));
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
state = lazy.getState;
verifyEqual(testCase, state.selectedNode, '');
verifyEqual(testCase, state.options, leotherm.telemetryOptions);
calibration.loadCurrentDevice;
lazyCalibration.setEnabled(false);
lazyCalibration.loadCurrentDevice;
lazy.refreshContext;
lazyCalibration.refreshContext;
verifyTrue(testCase, isequaln(calibration.getState, lazyCalibration.getState));
loaded = lazyCalibration.getState;
verifyEqual(testCase, loaded.profile, ...
    leotherm.deviceCalibrationProfile(fig.UserData.model.network));
verifyFalse(testCase, any(loaded.profile.parameters.estimate));
verifyUnbuilt(testCase, lazy);
verifyUnbuilt(testCase, lazyCalibration);
verifyEnsurePreservesState(testCase, lazy);
verifyEnsurePreservesState(testCase, lazyCalibration);
verifyEqual(testCase, char(findobj(lazyCalibration.Tab, 'Tag', 'CalibrationSensorSigma').Enable), 'off');
end

function testTelemetryRestoresOptionsMappingNodesAndResults(testCase)
[~, eager, lazy] = panels(testCase);
f = testCase.TestData.fixture;
eager.importSource(f.raw);
eager.run(f.settings.telemetryOptions);
state = eager.getState;
state.options.frame = 'J2000_ECI';
state.options.useInitialTemperature = true;
state.options.rmseToleranceK = 0.25;
state.sourceLabel = 'saved.csv';
eager.restoreState(state);
lazy.restoreState(state);
verifyUnbuilt(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
lazy.setEnabled(false);
verifyEnsurePreservesState(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
verifyEqual(testCase, char(findobj(lazy.Tab, 'Tag', 'RunTelemetryButton').Enable), 'off');
verifyThat(testCase, labelText(lazy), ...
    matlab.unittest.constraints.ContainsSubstring('saved.csv'));
verifyTelemetryTablesEqual(testCase, eager, lazy);
end

function testImportedNodeDefaultSurvivesRestoreWithoutResult(testCase)
[~, eager, lazy] = panels(testCase);
f = testCase.TestData.fixture;
eager.importSource(f.raw);
state = eager.getState;
verifyEqual(testCase, state.selectedNode, f.network.nodeNames{1});
verifyEmpty(testCase, state.result);
lazy.restoreState(state);
verifyEnsurePreservesState(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
verifyTelemetryTablesEqual(testCase, eager, lazy);
end

function testCalibrationRestoresSettingsProfileDaysAndFrozenTables(testCase)
[fig, ~, ~, eager, lazy] = panels(testCase);
state = frozenCalibration(fig, eager, testCase.TestData.fixture);
state.toleranceEnabled = true;
state.toleranceDraft = '0.05';
state.settings.rmseToleranceK = 0.05;
state.resultInputs.settings = state.settings;
eager.restoreState(state);
lazy.setEnabled(false);
lazy.restoreState(state);
verifyUnbuilt(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
verifyEnsurePreservesState(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
tags = {'CalibrationProfileTable','CalibrationDayTable', ...
    'CalibrationParameterReport','CalibrationStageTable','CalibrationCoverageTable'};
for k = 1:numel(tags)
    verifyEqual(testCase, findobj(lazy.Tab, 'Tag', tags{k}).Data, ...
        findobj(eager.Tab, 'Tag', tags{k}).Data);
end
verifyEqual(testCase, findobj(lazy.Tab, 'Tag', 'CalibrationTolerance').Value, '0.05');
verifyEqual(testCase, char(findobj(lazy.Tab, 'Tag', 'CalibrationTolerance').Enable), 'off');
lazy.setEnabled(true);
verifyEqual(testCase, char(findobj(lazy.Tab, 'Tag', 'CalibrationTolerance').Enable), 'on');
verifyEqual(testCase, char(findobj(lazy.Tab, 'Tag', 'CalibrationProfileTable').Enable), 'on');
end

function testBlankEnabledToleranceDraftSurvivesConstruction(testCase)
[~, ~, ~, eager, lazy] = panels(testCase);
state = eager.getState;
state.toleranceEnabled = true;
state.toleranceDraft = '';
eager.restoreState(state);
lazy.restoreState(state);
verifyEnsurePreservesState(testCase, lazy);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
verifyEqual(testCase, findobj(lazy.Tab, 'Tag', 'CalibrationTolerance').Value, '');
end

function testTelemetryStaleDetectionBeforeAndAfterConstruction(testCase)
[fig, eager, lazy] = panels(testCase);
f = testCase.TestData.fixture;
eager.importSource(f.raw);
eager.run(f.settings.telemetryOptions);
baseline = eager.getState;
lazy.restoreState(baseline);
current = lazy.getState;
verifyFalse(testCase, current.resultStale);
original = fig.UserData;
fig.UserData.model.scenario.durationS = original.model.scenario.durationS + 1;
current = lazy.getState;
verifyTrue(testCase, current.resultStale);
verifyTrue(testCase, isequaln(eager.getState, lazy.getState));
verifyUnbuilt(testCase, lazy);
verifyEnsurePreservesState(testCase, lazy);
verifyThat(testCase, labelText(lazy), ...
    matlab.unittest.constraints.ContainsSubstring('Inputs changed'));
fig.UserData = original;
current = lazy.getState;
verifyFalse(testCase, current.resultStale);
for change = {'network','source','mapping','options','mode'}
    altered = baseline;
    switch change{1}
        case 'network'
            fig.UserData.model.network.capacityJK = f.network.capacityJK + 1;
        case 'source'
            altered.source.external_power_w_device(1) = altered.source.external_power_w_device(1) + 1;
        case 'mapping'
            altered.mapping.unit(1) = "";
        case 'options'
            altered.options.maxStepS = altered.options.maxStepS/2;
        case 'mode'
            altered.mode = 'validation';
    end
    deferred = leotherm.TelemetryPanel(lazy.Tab.Parent, 'en', ...
        @() fig.UserData.model, @(varargin) [], true);
    deferred.restoreState(altered);
    current = deferred.getState;
    verifyTrue(testCase, current.resultStale);
    verifyUnbuilt(testCase, deferred);
    fig.UserData = original;
end
end

function testCalibrationStaleDetectionDoesNotBuildOrReplaceInputs(testCase)
[fig, ~, ~, eager, lazy] = panels(testCase);
state = frozenCalibration(fig, eager, testCase.TestData.fixture);
lazy.restoreState(state);
current = lazy.getState;
verifyFalse(testCase, current.profileStale);
verifyFalse(testCase, current.splitStale);
verifyFalse(testCase, current.resultStale);
fig.UserData.model.network.capacityJK = fig.UserData.model.network.capacityJK + 1;
lazy.refreshContext;
changed = lazy.getState;
verifyTrue(testCase, changed.profileStale);
verifyTrue(testCase, changed.resultStale);
verifyFalse(testCase, changed.splitStale);
verifyEqual(testCase, changed.profile, state.profile);
verifyEqual(testCase, changed.settings, state.settings);
verifyEqual(testCase, changed.result, state.result);
fig.UserData.source.mapping.unit(1) = "";
lazy.refreshContext;
changed = lazy.getState;
verifyTrue(testCase, changed.splitStale);
verifyUnbuilt(testCase, lazy);
verifyEnsurePreservesState(testCase, lazy);
end

function testActionsCanBuildOnDemand(testCase)
[fig, ~, lazy, ~, calibration] = panels(testCase);
f = testCase.TestData.fixture;
lazy.setEnabled(false);
lazy.importSource(f.raw);
verifyTrue(testCase, lazy.UIReady);
verifyEqual(testCase, char(findobj(lazy.Tab, 'Tag', 'RunTelemetryButton').Enable), 'off');
lazy.setWorkflow('heat');
lazy.preflight;
current = lazy.getState;
verifyEqual(testCase, current.mode, 'heat');
fig.UserData.source = lazy.getState;
calibration.loadCurrentDevice;
calibration.loadTelemetryDays;
verifyUnbuilt(testCase, calibration);
verifyEnsurePreservesState(testCase, calibration);
end

function [fig, eager, lazy, calibration, lazyCalibration] = panels(testCase)
f = testCase.TestData.fixture;
fig = uifigure('Visible', 'off');
testCase.addTeardown(@() delete(fig));
group = uitabgroup(fig);
fig.UserData.model = struct('scenario', f.scenario, 'network', f.network, 'reference', []);
provider = @() fig.UserData.model;
busy = @(varargin) [];
eager = leotherm.TelemetryPanel(group, 'en', provider, busy);
lazy = leotherm.TelemetryPanel(group, 'en', provider, busy, true);
fig.UserData.source = eager.getState;
source = @() fig.UserData.source;
calibration = leotherm.CalibrationPanel(group, 'en', provider, source, busy);
lazyCalibration = leotherm.CalibrationPanel(group, 'en', provider, source, busy, true);
end

function state = frozenCalibration(fig, panel, f)
source = struct('source', f.raw, 'mapping', leotherm.telemetryMapping(f.raw, f.network), ...
    'options', f.settings.telemetryOptions, 'mode', 'heat');
fig.UserData.source = source;
state = panel.getState;
state.profile = f.profile;
state.split = f.split;
state.splitInput = struct('source', source.source, 'mapping', source.mapping, ...
    'fileStamp', [], 'nodeNames', {f.network.nodeNames});
state.result = struct('status', 'review_required', ...
    'parameterReport', f.profile.parameters, ...
    'stageMetrics', table("train", "device", 10, 1, 0.5, 'VariableNames', ...
    {'role','node','used_samples','baseline_rmse_k','calibrated_rmse_k'}), ...
    'coverage', table("train", "device", 10, 'VariableNames', {'role','node','scored_samples'}), ...
    'warningCodes', "synthetic_not_flight_validation");
state.outputDirectory = 'frozen_run';
inputSource = source;
inputSource.fileStamp = [];
state.resultInputs = struct('scenario', f.scenario, 'network', f.network, ...
    'source', inputSource, 'profile', state.profile, 'split', state.split, ...
    'settings', state.settings);
end

function verifyUnbuilt(testCase, panel)
verifyFalse(testCase, panel.UIReady);
verifyEmpty(testCase, panel.Tab.Children);
end

function verifyEnsurePreservesState(testCase, panel)
before = panel.getState;
tab = panel.Tab;
group = tab.Parent;
count = numel(group.Children);
panel.ensureUI;
verifyTrue(testCase, panel.UIReady);
verifyEqual(testCase, panel.Tab, tab);
verifyEqual(testCase, numel(group.Children), count);
verifyTrue(testCase, isequaln(before, panel.getState));
children = tab.Children;
panel.ensureUI;
verifyEqual(testCase, tab.Children, children);
verifyTrue(testCase, isequaln(before, panel.getState));
end

function verifyTelemetryTablesEqual(testCase, eager, lazy)
left = findobj(eager.Tab, 'Type', 'uitable');
right = findobj(lazy.Tab, 'Type', 'uitable');
verifyEqual(testCase, numel(left), numel(right));
for k = 1:numel(left)
    verifyEqual(testCase, right(k).Data, left(k).Data);
    verifyEqual(testCase, right(k).ColumnName, left(k).ColumnName);
end
end

function text = labelText(panel)
labels = findobj(panel.Tab, 'Type', 'uilabel');
text = strjoin(string({labels.Text}), newline);
end
