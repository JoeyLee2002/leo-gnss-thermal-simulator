function tests = test_telemetry
tests = functiontests(localfunctions);
end

function testExplicitUnitsAndUtc(testCase)
[raw, network] = fixture;
raw.temperature_c_gnss_rf_frontend = 25 * ones(height(raw), 1);
raw.x_eci_m = ones(height(raw), 1) * 7000;
mapping = leotherm.telemetryMapping(raw, network);
mapping.unit(mapping.target == "position_x") = "km";
data = leotherm.readTelemetry(raw, mapping, network);
verifyEqual(testCase, data.temperatureK(:, 9), 298.15 * ones(6, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, data.positionM(:, 1), 7e6 * ones(6, 1));
verifyEqual(testCase, data.epoch.TimeZone, 'UTC');
end

function testDuplicateTimeRejected(testCase)
[raw, network] = fixture;
raw.epoch_utc(2) = raw.epoch_utc(1);
verifyError(testCase, @() leotherm.readTelemetry(raw, [], network), 'leotherm:TelemetryTime');
end

function testUnitMismatchRejected(testCase)
[raw, network] = fixture;
mapping = leotherm.telemetryMapping(raw, network);
mapping.unit(3) = "W/m2";
verifyError(testCase, @() leotherm.readTelemetry(raw, mapping, network), 'leotherm:TelemetryUnit');
end

function testDuplicateTargetRejected(testCase)
[raw, network] = fixture;
raw.extra = raw.quality;
mapping = leotherm.telemetryMapping(raw, network);
mapping.target(end) = "quality"; mapping.unit(end) = "1";
verifyError(testCase, @() leotherm.readTelemetry(raw, mapping, network), 'leotherm:TelemetryMapping');
end

function testHeatAndInternalPowerLeftHold(testCase)
[raw, network, scenario, options] = fixture;
raw.internal_power_w_gnss_rf_frontend = [0;10;0;0;0;0];
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
verifyEqual(testCase, result.temperatureK(:, 9), ...
    [300;300.02;300.14;300.16;300.18;300.20], 'AbsTol', 1e-10);
verifyFalse(testCase, result.provenance.interpolation);
verifyEqual(testCase, height(result.segments), 1);
end

function testBadDriverSplitsAndRestarts(testCase)
[raw, network, scenario, options] = fixture;
raw{3, 3} = NaN;
result = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, result.segmentId, [1;1;0;2;2;2]);
verifyTrue(testCase, all(isnan(result.temperatureK(3, :))));
verifyEqual(testCase, result.temperatureK(4, :), 300 * ones(1, 11));
verifyEqual(testCase, result.audit.reason(3), "invalid_external_power");
end

function testQualityRejectionNeverBridged(testCase)
[raw, network, scenario, options] = fixture;
raw.quality(3) = 0; options.maxGapS = 1000;
result = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, result.segmentId, [1;1;0;2;2;2]);
verifyEqual(testCase, result.audit.reason(3), "quality_rejected");
end

function testLongGapNeverIntegrated(testCase)
[raw, network, scenario, options] = fixture;
epoch = datetime(raw.epoch_utc, 'InputFormat', 'yyyy-MM-dd''T''HH:mm:ss''Z''', 'TimeZone','UTC');
epoch(4:end) = epoch(4:end) + seconds(100);
raw.epoch_utc = string(epoch, 'yyyy-MM-dd''T''HH:mm:ss''Z''');
result = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, result.segmentId, [1;1;1;2;2;2]);
verifyEqual(testCase, result.temperatureK(4, :), 300 * ones(1, 11));
end

function testExactAlignmentAndSignedBias(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = 302 + (0:5)' * 0.02;
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.metrics.used_samples, 5);
verifyEqual(testCase, report.metrics.bias_k, -2, 'AbsTol', 1e-10);
verifyEqual(testCase, report.metrics.rmse_k, 2, 'AbsTol', 1e-10);
verifyEqual(testCase, report.metrics.assessment, "comparison_only");
data.epoch = data.epoch + seconds(0.1);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.metrics.exact_matches, 0);
verifyTrue(testCase, isnan(report.metrics.rmse_k));
end

function testConditionedInitializationAndWarmupExcluded(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = 302 + (0:5)' * 0.02;
options.useInitialTemperature = true; options.excludeInitialS = 20;
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.metrics.used_samples, 4);
verifyEqual(testCase, report.metrics.rmse_k, 0, 'AbsTol', 1e-10);
verifyEqual(testCase, report.independence, 'conditioned_on_measured_initial_state');
verifyFalse(testCase, report.samples.used(1));
end

function testOrbitRequiresFrameConfirmation(testCase)
[raw, network, scenario] = fixture;
data = leotherm.readTelemetry(raw, [], network);
verifyError(testCase, @() leotherm.simulateTelemetry(data, scenario, network), 'leotherm:TelemetryFrame');
end

function testInvalidInitialStateRetainsFailureAudit(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = ones(6, 1) * 900;
options.useInitialTemperature = true;
result = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, result.segments.status, "failed");
verifyTrue(testCase, all(result.segmentId == 0));
verifyNotEmpty(testCase, result.segments.message);
end

function testInvalidObservationNotRepaired(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = [300;NaN;0;300.06;300.08;300.1];
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.metrics.used_samples, 3);
verifyEqual(testCase, report.samples.reason(2:3), repmat("invalid_temperature", 2, 1));
end

function testToleranceIsUserCriterionNotScientificProof(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = 300.5 + (0:5)' * 0.02;
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
options.rmseToleranceK = 1;
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.metrics.assessment, "within_user_rmse_limit");
verifyTrue(testCase, contains(report.conclusion, 'not proof'));
verifyFalse(testCase, report.fittedToValidation);
end

function testCsvRoundTripAndExport(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = 300 + (0:5)' * 0.02;
folder = tempname; mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's'));
file = fullfile(folder, 'telemetry.csv'); writetable(raw, file);
data = leotherm.readTelemetry(file, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
for language = {'zh','en'}
    output = fullfile(folder, language{1});
    leotherm.writeTelemetryResults(result, report, data, output, language{1});
    verifyTrue(testCase, isfile(fullfile(output, 'manifest.json')));
    verifyTrue(testCase, isfile(fullfile(output, 'paired_samples.csv')));
    summaryText = fileread(fullfile(output, ['validation_summary_' language{1} '.md']));
    verifyFalse(testCase, contains(summaryText, sprintf('|\n\n|')));
    verifyEqual(testCase, numel(dir(fullfile(output, '*.png'))), 1);
    verifyError(testCase, @() leotherm.writeTelemetryResults(result, report, data, output), ...
        'leotherm:TelemetryExport');
end
end

function testNumericInputPrecisionPreserved(testCase)
[raw, network] = fixture;
value = 7000000.12345678;
raw.x_eci_m = repmat(value, height(raw), 1);
data = leotherm.readTelemetry(raw, [], network);
verifyEqual(testCase, data.positionM(:,1), repmat(value, height(raw), 1));
end

function testInvalidTimeRetainedAndSplits(testCase)
[raw, network, scenario, options] = fixture;
raw.epoch_utc(3) = "2024-03-20 12:00:20";
data = leotherm.readTelemetry(raw, [], network);
verifyEqual(testCase, data.audit.reason(3), "invalid_utc_time");
result = leotherm.simulateTelemetry(data, scenario, network, options);
verifyEqual(testCase, result.segmentId, [1;1;0;2;2;2]);
end

function testOrbitRequiresSameFrameSunInput(testCase)
[raw, network, scenario, options] = orbitFixture;
raw.sun_z_eci_m = [];
data = leotherm.readTelemetry(raw, [], network);
verifyError(testCase, @() leotherm.simulateTelemetry(data, scenario, network, options), ...
    'leotherm:TelemetryMapping');
end

function testAttitudeInvalidRowSplits(testCase)
[raw, network, scenario, options] = orbitFixture;
for a = 1:3
    for b = 1:3
        raw.(sprintf('eci_to_body_%d%d',a,b)) = repmat(double(a==b), height(raw), 1);
    end
end
raw.eci_to_body_11(3) = 2;
result = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, result.segmentId, [1;1;0;2;2;2]);
verifyEqual(testCase, result.audit.reason(3), "invalid_attitude");
verifyEqual(testCase, result.provenance.attitudeSource, 'telemetry_attitude');
end

function testMeasuredTemperaturesDoNotDriveDefaultPrediction(testCase)
[raw, network, scenario, options] = orbitFixture;
raw.temperature_k_gnss_rf_frontend = ones(height(raw),1)*280;
first = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
raw.temperature_k_gnss_rf_frontend(:) = 330;
second = leotherm.simulateTelemetry(leotherm.readTelemetry(raw, [], network), scenario, network, options);
verifyEqual(testCase, first.temperatureK, second.temperatureK);
end

function testSyntheticDataCannotClaimIndependentValidation(testCase)
[raw, network, scenario, options] = fixture;
raw.temperature_k_gnss_rf_frontend = 300 + (0:5)'*0.02;
raw.dataset_type = repmat("synthetic_demo_not_flight_data", height(raw), 1);
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, report.independence, 'synthetic_not_independent_validation');
end

function testSimulationWithoutMeasuredChannels(testCase)
[raw, network, scenario, options] = fixture;
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEmpty(testCase, report.metrics);
verifyEmpty(testCase, report.samples);
verifyEqual(testCase, result.segments.status, "complete");
end

function testAllSegmentsFailWithoutSuccessScore(testCase)
[raw, network, scenario, options] = fixture;
network.initialTemperatureK(:) = scenario.integration.maximumTemperatureK + 1;
raw.temperature_k_gnss_rf_frontend = ones(height(raw),1)*300;
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
verifyEqual(testCase, result.segments.status, "failed");
verifyEqual(testCase, report.metrics.used_samples, 0);
verifyTrue(testCase, isnan(report.metrics.rmse_k));
verifyEqual(testCase, report.metrics.assessment, "insufficient_samples");
end

function [raw, network, scenario, options] = orbitFixture
[raw, network, scenario, options] = fixture;
raw = raw(:,1:2);
orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, (0:10:50)', scenario.orbit);
names = {'x_eci_m','y_eci_m','z_eci_m','vx_eci_mps','vy_eci_mps','vz_eci_mps', ...
    'sun_x_eci_m','sun_y_eci_m','sun_z_eci_m'};
values = [orbit.positionM,orbit.velocityMps,orbit.sunPositionM];
for k = 1:numel(names), raw.(names{k}) = values(:,k); end
options.mode = 'orbit'; options.frame = 'J2000_ECI';
end

function [raw, network, scenario, options] = fixture
network = leotherm.defaultReceiverNetwork;
network.capacityJK(:) = 1000; network.initialTemperatureK(:) = 300;
network.internalPowerW(:) = 0; network.conductanceWK(:) = 0;
network.irEmissivity(:) = 0;
scenario = leotherm.defaultScenario;
time = scenario.startEpoch + seconds((0:10:50)');
raw = table(string(time, 'yyyy-MM-dd''T''HH:mm:ss''Z'''), ones(6, 1), ...
    'VariableNames', {'epoch_utc','quality'});
for k = 1:numel(network.nodeNames)
    raw.(['external_power_w_' matlab.lang.makeValidName(network.nodeNames{k})]) = ones(6, 1) * 2;
end
options = leotherm.telemetryOptions(struct('mode', 'heat', 'maxGapS', 10, ...
    'maxStepS', 5, 'excludeInitialS', 0));
end
