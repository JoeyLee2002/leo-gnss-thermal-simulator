function tests = test_device_calibration_guards
tests = functiontests(localfunctions);
end

function testStrongBoundaryStepHalvingActuallyRefines(testCase)
f = leotherm.deviceCalibrationDemo(3, true);
capacity = f.profile.parameters(f.profile.parameters.estimate, :);
f.network.initialTemperatureK = 280;
f.network.internalPowerW = 0;
f.network.irEmissivity = 0;
f.profile = leotherm.deviceCalibrationProfile(f.network);
f.profile.parameters(f.profile.parameters.field == "capacityJK", :) = capacity;
elapsed = f.elapsedS/10;
f.raw.epoch_utc = f.scenario.startEpoch + days(f.dayIndex-1) + seconds(elapsed);
f.raw.external_power_w_device(:) = 0;
f.raw.boundary_temperature_k_device(:) = 320;
f.raw.boundary_conductance_wk_device(:) = 100;
f.raw.temperature_k_device = 320 - 40*exp(-elapsed);
f.data = leotherm.readTelemetry(f.raw, [], f.network);
f.settings.telemetryOptions.excludeInitialS = 0;
f.settings.temperatureSigmaK = 1;

% Both requested steps hit the same stability cap; adaptive accuracy remains active.
options = f.settings.telemetryOptions;
coarse = leotherm.simulateTelemetry(f.data, f.scenario, f.network, options);
options.maxStepS = options.maxStepS/2;
unrefined = leotherm.simulateTelemetry(f.data, f.scenario, f.network, options);
verifyEqual(testCase, coarse.temperatureK, unrefined.temperatureK);
verifyEqual(testCase, coarse.temperatureK(2), 320-40*exp(-1), 'AbsTol', 1e-4);

r = calibrate(f);
verifyTrue(testCase, r.fit.converged);
options = r.protocol.effectiveTelemetryOptions;
verifyEqual(testCase, options.maxStepS, capacity.lower/100, 'AbsTol', 1e-12);
train = f.data;
train.accepted = train.accepted & f.dayIndex == 1;
train.temperatureK(f.dayIndex ~= 1, :) = NaN;
options.maxStepS = options.maxStepS/2;
fine = leotherm.simulateTelemetry(train, f.scenario, ...
    r.profileAfter.calibratedNetwork, options);
used = r.reports{1}.samples.used;
assertGreaterThanOrEqual(testCase, sum(used), 3);
delta = max(abs(fine.temperatureK(used)-r.prediction{1}.temperatureK(used)));
verifyGreaterThan(testCase, delta, 0);
verifyEqual(testCase, r.diagnostics.stepHalvingMaxDifferenceK, delta, 'AbsTol', 1e-12);
verifyLessThanOrEqual(testCase, delta, r.diagnostics.stepHalvingToleranceK);
exact = 320 - 40*exp(-100*elapsed(used)/r.fit.parameters);
verifyLessThan(testCase, max(abs(fine.temperatureK(used)-exact)), ...
    max(abs(r.prediction{1}.temperatureK(used)-exact)));
verifyFalse(testCase, r.prediction{1}.provenance.interpolation);
verifyEqual(testCase,r.checkNumerics.role,["validation";"test"]);
verifyGreaterThan(testCase,r.checkNumerics.step_halving_difference_k,0);
verifyLessThanOrEqual(testCase,r.checkNumerics.step_halving_difference_k,r.checkNumerics.tolerance_k);
verifyEqual(testCase, r.prediction{1}.boundaryConductanceWK, f.data.boundaryConductanceWK);
end

function testSampleIntervalCapsRequestedIntegrationStep(testCase)
f = leotherm.deviceCalibrationDemo;
f.settings.telemetryOptions.maxStepS = 100;
r = calibrate(f);
verifyEqual(testCase, r.settings.telemetryOptions.maxStepS, 100);
verifyEqual(testCase, r.protocol.effectiveTelemetryOptions.maxStepS, 10);
verifyGreaterThan(testCase, r.diagnostics.stepHalvingMaxDifferenceK, 0);
verifyLessThanOrEqual(testCase, r.diagnostics.stepHalvingMaxDifferenceK, ...
    r.diagnostics.stepHalvingToleranceK);
end

function testExcludedDayCannotChangeFitOrNumericalPolicy(testCase)
f = leotherm.deviceCalibrationDemo(6, true);
f.split.role = ["train"; "exclude"; "train"; "validation"; "test"; "test"];
first = calibrate(f);
excluded = f.dayIndex == 2;
raw = f.raw;
% A nonconstant target copy and large conductance exist only on the excluded day.
raw.temperature_k_device(excluded) = raw.boundary_temperature_k_device(excluded);
raw.boundary_conductance_wk_device(excluded) = 20;
raw.external_power_w_device(excluded) = 1e4;
f.data = leotherm.readTelemetry(raw, [], f.network);
assertTrue(testCase, all(f.data.accepted(excluded)));
assertGreaterThan(testCase, max(f.data.temperatureK(excluded))-min(f.data.temperatureK(excluded)), 0);
second = calibrate(f);
verifyEqual(testCase, second.fit.parameters, first.fit.parameters);
verifyEqual(testCase, second.fit.objective, first.fit.objective);
verifyEqual(testCase, second.fit.bounds, first.fit.bounds);
verifyEqual(testCase, second.trainingObjective, first.trainingObjective);
verifyEqual(testCase, second.diagnostics, first.diagnostics);
verifyEqual(testCase, second.protocol.effectiveTelemetryOptions, ...
    first.protocol.effectiveTelemetryOptions);
verifyEqual(testCase, second.dayMetrics, first.dayMetrics);
verifyEqual(testCase, second.stageMetrics, first.stageMetrics);
verifyEqual(testCase, second.samples, first.samples);
verifyEqual(testCase, height(second.dayMetrics), 5);
verifyEqual(testCase, sort(second.dayMetrics.day_utc), ...
    sort(f.split.day_utc(f.split.role ~= "exclude")));
verifyEqual(testCase, second.rowAudit.source_row, (1:height(raw))');
verifyEqual(testCase, second.rowAudit.calibration_role(excluded), ...
    repmat("exclude", sum(excluded), 1));
verifyEqual(testCase, second.rowAudit.calibration_disposition(excluded), ...
    repmat("excluded_day", sum(excluded), 1));
verifyFalse(testCase, any(second.rowAudit.calibration_scored(excluded)));
for k = 1:3
    verifyTrue(testCase, isequaln(second.prediction{k}.temperatureK, ...
        first.prediction{k}.temperatureK));
    verifyEqual(testCase, second.reports{k}.samples, first.reports{k}.samples);
    verifyTrue(testCase, all(isnan(second.prediction{k}.temperatureK(excluded))));
end
end

function testMatchingConstantBoundaryRequiresReviewNotCopyError(testCase)
f = leotherm.deviceCalibrationDemo(3, true);
capacity = f.profile.parameters(f.profile.parameters.estimate, :);
f.network.internalPowerW = 0;
f.network.irEmissivity = 0;
f.profile = leotherm.deviceCalibrationProfile(f.network);
f.profile.parameters(f.profile.parameters.field == "capacityJK", :) = capacity;
f.raw.external_power_w_device(:) = 0;
f.raw.boundary_temperature_k_device(:) = f.network.initialTemperatureK;
f.raw.temperature_k_device(:) = f.network.initialTemperatureK;
f.data = leotherm.readTelemetry(f.raw, [], f.network);
assertEqual(testCase, f.data.temperatureK, f.data.boundaryTemperatureK);
assertFalse(testCase, f.settings.forcingIndependenceConfirmed);
r = calibrate(f);
verifyTrue(testCase, r.fit.converged);
verifyTrue(testCase, r.withinDeclaredCriteria);
verifyEqual(testCase, r.status, 'review_required');
verifyFalse(testCase, r.passed);
verifyFalse(testCase, r.physicalValidityEstablished);
verifyTrue(testCase, r.diagnostics.rankDeficient);
verifyTrue(testCase, all(r.diagnostics.weakSensitivity));
verifyTrue(testCase, all(ismember(["forcing_independence_not_confirmed"; ...
    "conditional_boundary_driven_validation"; "weak_parameter_sensitivity"], r.warningCodes)));
for k = 1:3
    used = r.reports{k}.samples.used;
    verifyEqual(testCase, r.prediction{k}.temperatureK(used), ...
        repmat(f.network.initialTemperatureK, sum(used), 1));
    verifyEqual(testCase, r.prediction{k}.boundaryConductanceWK, f.data.boundaryConductanceWK);
end
end

function testConditionalInitializationMetadataAndNoLaterFeedback(testCase)
f = leotherm.deviceCalibrationDemo;
f.settings.telemetryOptions.useInitialTemperature = true;
first = calibrate(f);
roles = {'train', 'validation', 'test'};
verifyTrue(testCase, ismember("conditioned_on_measured_initial_state", first.warningCodes));
verifyEqual(testCase, first.reports{1}.independence, 'in_sample_calibration_not_validation');
for k = 1:3
    provenance = first.prediction{k}.provenance;
    verifyTrue(testCase, provenance.parametersFitted);
    verifyEqual(testCase, provenance.parameterFitRole, 'train');
    verifyEqual(testCase, provenance.evaluationRole, roles{k});
    verifyTrue(testCase, provenance.devicePriorsPreserved);
    verifyEqual(testCase, provenance.initialization, 'measured_initial_temperature_conditioned');
    verifyFalse(testCase, first.baseline{k}.provenance.parametersFitted);
    verifyEqual(testCase, first.reports{k}.fittedToValidation, k == 1);
    verifyEqual(testCase, first.reports{k}.calibrationRole, roles{k});
    verifyTrue(testCase, first.reports{k}.parametersFittedOnTrainingOnly);
    initial = find(f.dayIndex == k, 1);
    verifyEqual(testCase, first.prediction{k}.temperatureK(initial), f.data.temperatureK(initial));
    verifyFalse(testCase, first.reports{k}.samples.used(initial));
end

raw = f.raw;
laterHeldout = f.dayIndex > 1 & f.elapsedS > 0;
raw.temperature_k_device(laterHeldout) = raw.temperature_k_device(laterHeldout) ...
    + 5 + 0.2*cos((1:sum(laterHeldout))');
changed = f;
changed.data = leotherm.readTelemetry(raw, [], f.network);
initial = f.elapsedS == 0;
assertEqual(testCase, changed.data.temperatureK(initial), f.data.temperatureK(initial));
second = calibrate(changed);
verifyEqual(testCase, second.fit.parameters, first.fit.parameters);
verifyEqual(testCase, second.fit.objective, first.fit.objective);
verifyEqual(testCase, second.trainingObjective, first.trainingObjective);
verifyEqual(testCase, second.diagnostics, first.diagnostics);
verifyEqual(testCase, second.reports{1}.samples, first.reports{1}.samples);
for k = 1:3
    verifyTrue(testCase, isequaln(second.prediction{k}.temperatureK, ...
        first.prediction{k}.temperatureK));
    verifyEqual(testCase, second.reports{k}.samples.used, first.reports{k}.samples.used);
end
heldout = second.dayMetrics.role ~= "train";
verifyGreaterThan(testCase, second.dayMetrics.calibrated_rmse_k(heldout), ...
    first.dayMetrics.calibrated_rmse_k(heldout) + 3);

% Changing the test initializer affects that segment, but not training or validation.
raw = f.raw;
testInitial = find(f.dayIndex == 3, 1);
raw.temperature_k_device(testInitial) = raw.temperature_k_device(testInitial) + 2;
changed.data = leotherm.readTelemetry(raw, [], f.network);
third = calibrate(changed);
verifyEqual(testCase, third.fit.parameters, first.fit.parameters);
verifyEqual(testCase, third.trainingObjective, first.trainingObjective);
verifyEqual(testCase, third.diagnostics, first.diagnostics);
for k = 1:2
    verifyTrue(testCase, isequaln(third.prediction{k}.temperatureK, ...
        first.prediction{k}.temperatureK));
end
verifyEqual(testCase, third.prediction{3}.temperatureK(testInitial), ...
    first.prediction{3}.temperatureK(testInitial) + 2);
verifyGreaterThan(testCase, abs(third.prediction{3}.temperatureK(testInitial+1) ...
    - first.prediction{3}.temperatureK(testInitial+1)), 1);
verifyEqual(testCase, third.reports{3}.samples.used, first.reports{3}.samples.used);
end

function r = calibrate(f)
r = leotherm.calibrateTelemetry(f.data, f.scenario, f.network, ...
    f.profile, f.split, f.settings, '');
end
