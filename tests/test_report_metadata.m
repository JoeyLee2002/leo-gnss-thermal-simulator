function tests = test_report_metadata
tests = functiontests(localfunctions);
end

function testBuiltInFrameHasDefinition(testCase)
s = leotherm.defaultScenario;
orbit = leotherm.propagateCircularOrbit(s.startEpoch, (0:60:180)', s.orbit);
verifyEqual(testCase, orbit.frame.name, 'approximate_geocentric_equatorial');
verifyEqual(testCase, orbit.frame.origin, 'Earth centre');
verifyNotEmpty(testCase, orbit.frame.definition);
end

function testFrameSurvivesWarmupTrimming(testCase)
s = leotherm.defaultScenario;
s.durationS = 120; s.timeStepS = 60; s.warmupOrbits = 0.03;
s.convergence.enabled = false;
r = leotherm.simulateScenario(s, leotherm.defaultReceiverNetwork);
verifyEqual(testCase, r.orbit.frame.name, 'approximate_geocentric_equatorial');
verifySize(testCase, r.orbit.positionM, [3 3]);
verifyGreaterThanOrEqual(testCase, min(r.timeS), 0);
end

function testExternalFramePreservedWithoutChangingNumerics(testCase)
s = leotherm.defaultScenario;
s.durationS = 120; s.timeStepS = 60; s.warmupOrbits = 0;
s.convergence.enabled = false;
orbit = leotherm.propagateCircularOrbit(s.startEpoch, (0:60:120)', s.orbit);
orbit.frame.name = 'user_declared_test_axes';
n = leotherm.defaultReceiverNetwork;
withMetadata = leotherm.simulateTrajectory(orbit, s, n);
withoutMetadata = leotherm.simulateTrajectory(rmfield(orbit, 'frame'), s, n);
verifyEqual(testCase, withMetadata.orbit.frame, orbit.frame);
verifyEqual(testCase, withMetadata.temperatureK, withoutMetadata.temperatureK);
verifyEqual(testCase, withMetadata.orbit.positionM, withoutMetadata.orbit.positionM);
verifyFalse(testCase, isfield(withoutMetadata.orbit, 'frame'));
end

function testBilingualFrameLabels(testCase)
[name, value] = leotherm.reportMetadataText('trajectory_frame', ...
    'approximate_geocentric_equatorial', 'zh');
verifyEqual(testCase, name, '轨道坐标系');
verifyEqual(testCase, value, '地心赤道坐标系（内置近似轨道模型）');
[~, value] = leotherm.reportMetadataText('trajectory_frame', ...
    'approximate_geocentric_equatorial', 'en');
verifyTrue(testCase, contains(value, 'approximate orbit model'));
[~, value] = leotherm.reportMetadataText('trajectory_frame', 'user_axes', 'en');
verifyEqual(testCase, value, 'user_axes');
end

function testTelemetryStatesAreExplicit(testCase)
codes = {'not_run_no_data','not_run','comparison_available'};
for k = 1:numel(codes)
    [name, value] = leotherm.reportMetadataText('telemetry_status', codes{k}, 'zh');
    verifyEqual(testCase, name, '遥测比较');
    verifyNotEqual(testCase, value, codes{k});
    [name, value] = leotherm.reportMetadataText('telemetry_status', codes{k}, 'en');
    verifyEqual(testCase, name, 'Telemetry comparison');
    verifyNotEqual(testCase, value, codes{k});
    verifyFalse(testCase, contains(value, 'passed'));
end
end

function testUnlabelledAxesNeedAnActionNotAGuess(testCase)
for lang = {'zh','en'}
    [~, value] = leotherm.reportMetadataText('trajectory_frame', ...
        'source_frame_not_recorded', lang{1});
    verifyFalse(testCase, contains(value, 'J2000'));
    verifyTrue(testCase, contains(value, '重新运行') || contains(value, 'rerun'));
end
end
