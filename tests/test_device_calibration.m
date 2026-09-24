function tests = test_device_calibration
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.fixture = deviceCalibrationFixture;
end

function testFixtureIsDeterministicAndExplicitlySynthetic(testCase)
f = testCase.TestData.fixture;
again = deviceCalibrationFixture;
verifyEqual(testCase, again.raw, f.raw);
verifyEqual(testCase, again.truth.temperatureK, f.truth.temperatureK);
verifyEqual(testCase, f.data.datasetKind, 'synthetic_demo_not_flight_data');
verifyEqual(testCase, f.raw.dataset_type, repmat("synthetic", 150, 1));
verifyEqual(testCase, f.data.temperatureK, f.truth.temperatureK + f.noiseK);
verifyGreaterThan(testCase, max(abs(f.noiseK)), 0);
verifyLessThan(testCase, max(abs(f.noiseK)), f.settings.temperatureSigmaK);
verifyEqual(testCase, f.trueNetwork.initialTemperatureK, f.network.initialTemperatureK);
verifyEqual(testCase, f.truth.temperatureK(1:50:end), repmat(300, 3, 1));
verifyEqual(testCase, seconds(diff(f.data.epoch(1:50:end))), [86400; 86400]);
verifyEqual(testCase, diff(f.raw.external_power_w_device(10:11)), 5);
verifyEqual(testCase, sum(f.profile.parameters.estimate), 1);
verifyEqual(testCase, f.settings.solverSettings.solver, 'fminsearch');
verifyFalse(testCase, f.settings.telemetryOptions.useInitialTemperature);
verifyFalse(testCase, f.truth.provenance.interpolation);
end

function testHardBoundsAndLockedNominalValues(testCase)
f = testCase.TestData.fixture;
p = f.profile;
active = p.parameters.estimate;
locked = ~active;
defaults = leotherm.deviceCalibrationProfile(f.network);
verifyFalse(testCase, any(defaults.parameters.estimate));
verifyEqual(testCase, p.parameters(locked, :), defaults.parameters(locked, :));
for value = [p.parameters.lower(active), p.parameters.upper(active)]
    actual = leotherm.applyDeviceCalibrationProfile(f.network, p, value);
    expected = f.network;
    expected.capacityJK = value;
    verifyEqual(testCase, actual, expected);
end
for value = [p.parameters.lower(active)-eps(p.parameters.lower(active)), ...
        p.parameters.upper(active)+eps(p.parameters.upper(active))]
    verifyError(testCase, @() leotherm.applyDeviceCalibrationProfile( ...
        f.network, p, value), 'leotherm:DeviceCalibrationParameters');
end
verifyEqual(testCase, p.referenceNetwork, f.network);
verifyEqual(testCase, f.profile, testCase.TestData.fixture.profile);
end

function testRecoveryObjectiveAndSyntheticClaimLimits(testCase)
f = deviceCalibrationFixture(6);
% Unequal valid day lengths distinguish day-balanced from pooled scoring.
f.raw.quality(f.dayIndex == 1 & f.elapsedS >= 400) = 0;
f.data = leotherm.readTelemetry(f.raw, [], f.network);
before = f;
r = calibrate(f);
verifyTrue(testCase, r.fit.converged);
verifyEqual(testCase, r.fit.parameters, f.trueNetwork.capacityJK, 'AbsTol', 0.5);
verifyTrue(testCase, all(r.parameterReport.within_bounds));
verifyEqual(testCase, r.profileBefore, f.profile);
verifyEqual(testCase, r.profileAfter.parameters, f.profile.parameters);
verifyEqual(testCase, r.profileAfter.referenceNetwork, f.network);
expected = f.network;
expected.capacityJK = r.fit.parameters;
verifyEqual(testCase, r.profileAfter.calibratedNetwork, expected);
locked = ~f.profile.parameters.estimate;
verifyEqual(testCase, r.parameterReport.calibrated(locked), ...
    f.profile.parameters.nominal(locked));
verifyEqual(testCase, f, before);

% Reconstruct equal-day/node weighting, not a sum over correlated samples.
s = r.samples(r.samples.role == "train", :);
keys = s.day_utc + ":" + s.node;
groups = unique(keys);
terms = zeros(numel(groups), 1);
for k = 1:numel(groups)
    terms(k) = mean((s.residual_k(keys == groups(k)) ...
        / f.settings.temperatureSigmaK).^2);
end
p = f.profile.parameters(f.profile.parameters.estimate, :);
priorTerm = f.settings.regularizationWeight * ...
    sum(((r.fit.parameters(:)-p.nominal)./p.priorSigma).^2);
verifyEqual(testCase, r.trainingObjective.dataTerm, mean(terms), 'AbsTol', 1e-9);
verifyEqual(testCase, r.trainingObjective.priorTerm, priorTerm, 'AbsTol', 1e-12);
verifyGreaterThan(testCase, priorTerm, 0);
verifyEqual(testCase, r.fit.objective, mean(terms)+priorTerm, 'AbsTol', 1e-9);
verifyCoverage(testCase, r, f);
verifyLessThan(testCase, r.stageMetrics.calibrated_rmse_k, ...
    r.stageMetrics.baseline_rmse_k);
verifyTrue(testCase, r.withinDeclaredCriteria);
verifyFalse(testCase, r.passed);
verifyFalse(testCase, r.physicalValidityEstablished);
verifyFalse(testCase, r.fit.identifiabilityEstablished);
verifyFalse(testCase, r.diagnostics.identifiabilityEstablished);
verifyTrue(testCase, all(ismember(["synthetic_not_flight_validation"; ...
    "holdout_history_not_confirmed"; "forcing_independence_not_confirmed"; ...
    "parameter_evidence_not_confirmed"], r.warningCodes)));
verifyEmpty(testCase, r.outputDirectory);
end

function testOutOfBoundsTruthRespectsBoundsAndPriorWeight(testCase)
f = testCase.TestData.fixture;
originalProfile = f.profile;
active = originalProfile.parameters.estimate;
p = originalProfile.parameters(active, :);
assertEqual(testCase, p.nominal, 100);
assertEqual(testCase, [p.lower, p.upper], [80, 120]);

% Generate truth outside the calibration box through the production solver.
f.trueNetwork.capacityJK = 150;
truth = leotherm.simulateTelemetry(f.data, f.scenario, f.trueNetwork, ...
    f.settings.telemetryOptions);
assertTrue(testCase, all(truth.segments.status == "complete"));
assertEqual(testCase, f.trueNetwork.initialTemperatureK, f.network.initialTemperatureK);
raw = f.raw;
raw.temperature_k_device = truth.temperatureK + f.noiseK;
f.data = leotherm.readTelemetry(raw, [], f.network);
assertEqual(testCase, f.data.datasetKind, 'synthetic_demo_not_flight_data');

weights = [1, 1e4];
results = cell(1, numel(weights));
for k = 1:numel(weights)
    f.settings.regularizationWeight = weights(k);
    r = calibrate(f);
    results{k} = r;
    verifyTrue(testCase, r.fit.converged);
    verifyGreaterThanOrEqual(testCase, r.fit.parameters, p.lower);
    verifyLessThanOrEqual(testCase, r.fit.parameters, p.upper);
    verifyTrue(testCase, all(r.parameterReport.within_bounds));
    verifyEqual(testCase, r.fit.bounds, ...
        struct('lower', p.lower, 'upper', p.upper, 'initial', p.nominal));
    verifyEqual(testCase, r.profileBefore, originalProfile);
    verifyEqual(testCase, r.profileAfter.parameters, originalProfile.parameters);
    verifyEqual(testCase, r.profileAfter.referenceNetwork, f.network);
    verifyEqual(testCase, r.parameterReport.calibrated(~active), ...
        originalProfile.parameters.nominal(~active));
    expectedPrior = weights(k)*sum(((r.fit.parameters(:)-p.nominal)./p.priorSigma).^2);
    verifyEqual(testCase, r.trainingObjective.priorTerm, expectedPrior, 'AbsTol', 1e-9);
    verifyEqual(testCase, r.status, 'criteria_not_met');
    verifyFalse(testCase, r.withinDeclaredCriteria);
    verifyFalse(testCase, r.passed);
    heldout = r.dayMetrics.role ~= "train";
    verifyGreaterThan(testCase, r.dayMetrics.calibrated_rmse_k(heldout), ...
        f.settings.rmseToleranceK);
    verifyCoverage(testCase, r, f);
    verifyEmpty(testCase, r.outputDirectory);
end

weak = results{1};
strong = results{2};
verifyEqual(testCase, weak.fit.parameters, p.upper, 'AbsTol', 1e-3);
verifyTrue(testCase, weak.fit.nearBound);
verifyGreaterThan(testCase, strong.fit.parameters, p.nominal);
verifyLessThan(testCase, abs(strong.fit.parameters-p.nominal), ...
    abs(weak.fit.parameters-p.nominal));
verifyGreaterThan(testCase, abs(strong.fit.parameters-f.trueNetwork.capacityJK), ...
    abs(weak.fit.parameters-f.trueNetwork.capacityJK));
verifyGreaterThan(testCase, strong.trainingObjective.dataTerm, weak.trainingObjective.dataTerm);
verifyEqual(testCase, strong.fit.bounds, weak.fit.bounds);
verifyEqual(testCase, f.profile, originalProfile);
verifyEqual(testCase, f.network.capacityJK, 100);
end

function testDefaultConfirmationsRequireExplicitEvidence(testCase)
settings = leotherm.deviceCalibrationOptions;
verifyFalse(testCase, settings.independentHoldoutConfirmed);
verifyFalse(testCase, settings.forcingIndependenceConfirmed);
verifyFalse(testCase, settings.parameterEvidenceConfirmed);
verifyEmpty(testCase, settings.sensorEvidence);
verifyTrue(testCase, isnan(settings.rmseToleranceK));
f = testCase.TestData.fixture;
f.settings.sensorEvidence = '';
verifyError(testCase, @() calibrate(f), 'leotherm:DeviceCalibrationEvidence');
end

function testFiniteHeldoutMutationsCannotChangeTrainingFit(testCase)
f = testCase.TestData.fixture;
first = calibrate(f);
heldout = f.dayIndex > 1;
raw = f.raw;
raw.temperature_k_device(heldout) = raw.temperature_k_device(heldout) ...
    + 3 + 0.2*cos((1:sum(heldout))');
f.data = leotherm.readTelemetry(raw, [], f.network);
assertTrue(testCase, all(isfinite(f.data.temperatureK) & f.data.temperatureK > 0));
second = calibrate(f);
verifyEqual(testCase, second.fit.parameters, first.fit.parameters);
verifyEqual(testCase, second.fit.objective, first.fit.objective);
verifyEqual(testCase, second.fit.bounds, first.fit.bounds);
verifyEqual(testCase, second.trainingObjective, first.trainingObjective);
verifyEqual(testCase, second.diagnostics, first.diagnostics);
verifyEqual(testCase, second.reports{1}.samples, first.reports{1}.samples);
for k = 1:3
    verifyTrue(testCase, isequaln(second.prediction{k}.temperatureK, ...
        first.prediction{k}.temperatureK));
end
verifyGreaterThan(testCase, second.dayMetrics.calibrated_rmse_k(2:3), ...
    first.dayMetrics.calibrated_rmse_k(2:3) + 2);
verifyFalse(testCase, second.withinDeclaredCriteria);
verifyFalse(testCase, second.passed);
end

function testInvalidTargetsKeepValidDriversAndSourceRows(testCase)
f = testCase.TestData.fixture;
badRows = [20; 32];
f.settings.telemetryOptions.maxGapS = 600;
drivers = f.data;
truth = leotherm.simulateTelemetry(drivers, f.scenario, f.trueNetwork, ...
    f.settings.telemetryOptions);
raw = f.raw;
raw.temperature_k_device = truth.temperatureK + f.noiseK;
raw.temperature_k_device(badRows) = [NaN; 0];
f.data = leotherm.readTelemetry(raw, [], f.network);
assertTrue(testCase, all(f.data.accepted));
r = calibrate(f);
n = height(raw);
verifyEqual(testCase, r.rowAudit.source_row, (1:n)');
verifyEqual(testCase, r.rowAudit.accepted, f.data.accepted);
verifyFalse(testCase, any(r.rowAudit.calibration_temperature_valid(badRows)));
prediction = r.prediction{1};
verifyEqual(testCase, prediction.epoch, f.data.epoch);
verifyEqual(testCase, size(prediction.temperatureK), [n, 1]);
verifyEqual(testCase, prediction.segments.source_rows, ...
    {(1:50)'});
verifyEqual(testCase, prediction.segmentId(badRows), [1; 1]);
verifyTrue(testCase, all(isfinite(prediction.temperatureK(badRows))));
verifyEqual(testCase, prediction.temperatureK(1), 300);
verifyEqual(testCase, prediction.audit.reason(badRows), ...
    repmat("simulated", 2, 1));
verifyFalse(testCase, prediction.provenance.interpolation);
verifyEqual(testCase, prediction.provenance.sourceRows, n);
verifyFalse(testCase, any(ismember(r.samples.source_row, badRows)));
verifyFalse(testCase, any(ismember(r.samples.source_row, [1; 2])));
verifyTrue(testCase, all(ismember([21;22;33;34],r.samples.source_row)));
verifyEqual(testCase, r.samples.epoch_utc, f.data.epoch(r.samples.source_row));
for k = 1:3
    verifyEqual(testCase, r.reports{k}.samples.source_row, (1:n)');
    verifyEqual(testCase, r.reports{k}.samples.used, r.baselineReports{k}.samples.used);
    outside = f.dayIndex ~= k;
    verifyTrue(testCase, all(isnan(r.prediction{k}.temperatureK(outside))));
end
verifyCoverage(testCase, r, f);
end

function testUtcDaySplitIsExplicitAndTimezoneInvariant(testCase)
f = testCase.TestData.fixture;
split = leotherm.calibrationDaySplit(f.data);
verifyEqual(testCase, split.day_utc, ["2024-01-01"; "2024-01-02"; "2024-01-03"]);
verifyEqual(testCase, split.role, repmat("exclude", 3, 1));
data = f.data;
data.epoch.TimeZone = 'Asia/Shanghai';
verifyEqual(testCase, leotherm.calibrationDaySplit(data), split);
data.epoch.TimeZone = '';
verifyError(testCase, @() leotherm.calibrationDaySplit(data), ...
    'leotherm:DeviceCalibrationSplit');
end

function testChronologicalAndSameDayReuseRejected(testCase)
f = testCase.TestData.fixture;
bad = f;
bad.split.role = ["validation"; "train"; "test"];
verifyError(testCase, @() calibrate(bad), 'leotherm:DeviceCalibrationSplit');
bad.split = f.split([1; 1; 3], :);
bad.split.role = ["train"; "validation"; "test"];
verifyError(testCase, @() calibrate(bad), 'leotherm:DeviceCalibrationSplit');
bad.split = leotherm.calibrationDaySplit(f.data);
verifyError(testCase, @() calibrate(bad), 'leotherm:DeviceCalibrationSplit');

raw = f.raw;
raw.epoch_utc = f.scenario.startEpoch + seconds((0:height(raw)-1)'*10);
bad.data = leotherm.readTelemetry(raw, [], f.network);
onlyDay = leotherm.calibrationDaySplit(bad.data);
assertEqual(testCase, height(onlyDay), 1);
bad.split = onlyDay([1; 1; 1], :);
bad.split.role = ["train"; "validation"; "test"];
verifyError(testCase, @() calibrate(bad), 'leotherm:DeviceCalibrationSplit');
end

function testEveryExpectedDayNeedsCoverageEvenWithAnotherGoodDay(testCase)
f = deviceCalibrationFixture(6);
for missingDay = [2, 4, 6]
    bad = f;
    raw = f.raw;
    raw.temperature_k_device(f.dayIndex == missingDay) = NaN;
    bad.data = leotherm.readTelemetry(raw, [], f.network);
    verifyError(testCase, @() calibrate(bad), 'leotherm:DeviceCalibrationCoverage');
end
end

function testMeasuredPowerOverrideAndBypassedOpticsRejected(testCase)
f = testCase.TestData.fixture;
raw = f.raw;
raw.internal_power_w_device = repmat(f.network.internalPowerW, height(raw), 1);
f.data = leotherm.readTelemetry(raw, [], f.network);
f.profile = activeFields(f.network, "internalPowerW");
verifyError(testCase, @() calibrate(f), 'leotherm:DeviceCalibrationDriver');
for field = ["projectedAreaM2", "solarAbsorptivity"]
    f.profile = activeFields(f.network, field);
    verifyError(testCase, @() calibrate(f), 'leotherm:DeviceCalibrationDriver');
end
end

function testFailedBoundedCandidateCannotImproveByDroppingRows(testCase)
f = testCase.TestData.fixture;
% Keep held-out runs in the same envelope, so only the optimizer candidate fails.
f.raw.external_power_w_device = repmat(f.raw.external_power_w_device(1:50), 3, 1);
f.data = leotherm.readTelemetry(f.raw, [], f.network);
truth = leotherm.simulateTelemetry(f.data, f.scenario, f.trueNetwork, f.settings.telemetryOptions);
f.raw.temperature_k_device = truth.temperatureK + f.noiseK;
f.data = leotherm.readTelemetry(f.raw, [], f.network);
train = f.data;
train.accepted = f.dayIndex == 1;
low = f.profile.parameters.lower(f.profile.parameters.estimate);
badNetwork = leotherm.applyDeviceCalibrationProfile(f.network, f.profile, low);
nominal = leotherm.simulateTelemetry(train, f.scenario, f.network, f.settings.telemetryOptions);
candidate = leotherm.simulateTelemetry(train, f.scenario, badNetwork, f.settings.telemetryOptions);
rows = f.dayIndex == 1;
nominalMax = max(nominal.temperatureK(rows));
candidateMax = max(candidate.temperatureK(rows));
assertGreaterThan(testCase, candidateMax, nominalMax);
f.scenario.integration.maximumTemperatureK = (nominalMax + candidateMax)/2;
nominal = leotherm.simulateTelemetry(train, f.scenario, f.network, f.settings.telemetryOptions);
candidate = leotherm.simulateTelemetry(train, f.scenario, badNetwork, f.settings.telemetryOptions);
baselineScore = leotherm.validateTelemetry(nominal, train, f.settings.telemetryOptions);
failedScore = leotherm.validateTelemetry(candidate, train, f.settings.telemetryOptions);
assertEqual(testCase, nominal.segments.status, "complete");
assertGreaterThanOrEqual(testCase, baselineScore.metrics.used_samples, 3);
assertEqual(testCase, candidate.segments.status, "failed");
assertEqual(testCase, failedScore.metrics.used_samples, 0);
assertTrue(testCase, contains(candidate.segments.message, 'ThermalStateOutOfBounds'));
allDays = leotherm.simulateTelemetry(f.data, f.scenario, f.network, f.settings.telemetryOptions);
assertTrue(testCase, all(allDays.segments.status == "complete"));
% The nominal baseline is valid; the first bounded optimizer start must fail.
f.settings.solverSettings.initialPoints = [low; f.network.capacityJK];
verifyError(testCase, @() calibrate(f), 'leotherm:DeviceCalibrationSimulation');
end

function testPrescribedBoundaryRemainsConditionalAndSynthetic(testCase)
f = deviceCalibrationFixture(3, true);
f.settings.independentHoldoutConfirmed = true;
f.settings.forcingIndependenceConfirmed = true;
f.settings.parameterEvidenceConfirmed = true;
r = calibrate(f);
verifyTrue(testCase, r.withinDeclaredCriteria);
verifyFalse(testCase, r.passed);
verifyFalse(testCase, r.physicalValidityEstablished);
verifyTrue(testCase, all(ismember(["conditional_boundary_driven_validation"; ...
    "synthetic_not_flight_validation"], r.warningCodes)));
for k = 1:3
    verifyTrue(testCase, r.prediction{k}.provenance.boundaryConditioning);
    verifyEqual(testCase, r.prediction{k}.boundaryTemperatureK, f.data.boundaryTemperatureK);
    verifyEqual(testCase, r.prediction{k}.boundaryConductanceWK, f.data.boundaryConductanceWK);
end
verifyCoverage(testCase, r, f);
end

function testRadiatingAreaEmissivityProductHasRankOne(testCase)
f = testCase.TestData.fixture;
f.trueNetwork = f.network;
f.trueNetwork.irEmissivity = 1.1*f.network.irEmissivity;
truth = leotherm.simulateTelemetry(f.data, f.scenario, f.trueNetwork, f.settings.telemetryOptions);
raw = f.raw;
raw.temperature_k_device = truth.temperatureK + f.noiseK;
f.data = leotherm.readTelemetry(raw, [], f.network);
f.profile = activeFields(f.network, ["radiatingAreaM2", "irEmissivity"]);

equivalent = f.trueNetwork;
equivalent.radiatingAreaM2 = 1.1*f.trueNetwork.radiatingAreaM2;
equivalent.irEmissivity = f.trueNetwork.irEmissivity/1.1;
sameProduct = leotherm.simulateTelemetry(f.data, f.scenario, equivalent, f.settings.telemetryOptions);
verifyEqual(testCase, sameProduct.temperatureK, truth.temperatureK, 'AbsTol', 1e-9);
r = calibrate(f);
verifyTrue(testCase, r.fit.converged);
verifyEqual(testCase, r.diagnostics.parameterCount, 2);
verifyEqual(testCase, r.diagnostics.rank, 1);
verifyTrue(testCase, r.diagnostics.rankDeficient);
verifyEqual(testCase, r.diagnostics.sensitivityCosine(1, 2), 1, 'AbsTol', 1e-6);
verifyTrue(testCase, ismember("training_sensitivity_rank_deficient", r.warningCodes));
verifyFalse(testCase, r.diagnostics.identifiabilityEstablished);
verifyFalse(testCase, r.passed);
verifyCoverage(testCase, r, f);
end

function testNonconvergenceCannotWriteFrozenFile(testCase)
f = testCase.TestData.fixture;
f.settings.solverSettings.maximumIterations = 1;
f.settings.solverSettings.maximumEvaluations = 3;
root = freshTemporaryRoot(testCase);
output = fullfile(root, 'incomplete_fit');
verifyError(testCase, @() calibrate(f, output), 'leotherm:CalibrationNotConverged');
verifyTrue(testCase, isfile(fullfile(output, 'protocol_before_fit.mat')));
verifyTrue(testCase, isfile(fullfile(output, 'input_snapshot.mat')));
verifyFalse(testCase, isfile(fullfile(output, 'frozen_before_checks.mat')));
verifyFalse(testCase, isfile(fullfile(output, 'calibration_result.mat')));
checkpoint = fullfile(output, 'fit_start1.mat');
assertTrue(testCase, isfile(checkpoint));
saved = load(checkpoint, 'item');
verifyFalse(testCase, saved.item.converged);
end

function testExistingOutputDirectoryCannotBeOverwritten(testCase)
f = testCase.TestData.fixture;
root = freshTemporaryRoot(testCase);
output = fullfile(root, 'already_exists');
mkdir(output);
verifyError(testCase, @() calibrate(f, output), 'leotherm:DeviceCalibrationExport');
sentinel = uint8([0, 17, 255, 42]);
sentinelFile = fullfile(output, 'protocol_before_fit.mat');
save(sentinelFile, 'sentinel');
originalBytes = fileBytes(sentinelFile);
verifyError(testCase, @() calibrate(f, output), 'leotherm:DeviceCalibrationExport');
verifyEqual(testCase, fileBytes(sentinelFile), originalBytes);
files = dir(output);
files = files(~[files.isdir]);
verifyEqual(testCase, {files.name}, {'protocol_before_fit.mat'});
verifyFalse(testCase, isfile(fullfile(output, 'frozen_before_checks.mat')));
end

function r = calibrate(f, output)
if nargin < 2, output = ''; end
r = leotherm.calibrateTelemetry(f.data, f.scenario, f.network, ...
    f.profile, f.split, f.settings, output);
end

function verifyCoverage(testCase, r, f)
verifyEqual(testCase, height(r.dayMetrics), f.dayCount);
verifyGreaterThanOrEqual(testCase, r.dayMetrics.used_samples, ...
    3*ones(height(r.dayMetrics), 1));
verifyGreaterThanOrEqual(testCase, r.stageMetrics.used_samples, ...
    3*ones(height(r.stageMetrics), 1));
verifyEqual(testCase, sort(r.dayMetrics.day_utc), sort(f.split.day_utc));
[found, index] = ismember(r.dayMetrics.day_utc, f.split.day_utc);
verifyTrue(testCase, all(found));
verifyEqual(testCase, r.dayMetrics.role, f.split.role(index));
end

function p = activeFields(network, fields)
p = leotherm.deviceCalibrationProfile(network);
active = ismember(p.parameters.field, fields);
p.parameters.estimate(active) = true;
p.parameters.lower(active) = 0.8*p.parameters.nominal(active);
p.parameters.upper(active) = 1.2*p.parameters.nominal(active);
p.parameters.priorSigma(active) = 0.1*p.parameters.nominal(active);
p.parameters.evidence(active) = "Synthetic physical parameter assumption, not flight evidence.";
p.parameters.kind(active) = "physical";
p = leotherm.validateDeviceCalibrationProfile(p, network);
end

function root = freshTemporaryRoot(testCase)
root = tempname;
mkdir(root);
testCase.addTeardown(@() removeTemporaryRoot(root));
end

function removeTemporaryRoot(root)
% Delete only the absolute, direct child of tempdir created by this test.
if ~isfolder(root), return; end
[rootExists, rootInfo] = fileattrib(root);
[tempExists, tempInfo] = fileattrib(tempdir);
assert(rootExists && tempExists && strcmpi(fileparts(rootInfo.Name), tempInfo.Name), ...
    'Refusing to remove a directory outside the temporary root.');
rmdir(rootInfo.Name, 's');
end

function bytes = fileBytes(file)
fid = fopen(file, 'rb');
assert(fid ~= -1, 'Cannot read the export sentinel.');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
end
