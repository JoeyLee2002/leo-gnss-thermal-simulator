function tests = test_usability
tests=functiontests(localfunctions);
end

function testExactUtcClockAndFractions(testCase)
date=datetime(2024,1,2);
for time=["00:00:00","03:04:05.125","23:59:59.999"]
    epoch=leotherm.parseStartEpoch(date,time);
    verifyEqual(testCase,string(epoch,'HH:mm:ss.SSS'), ...
        string(datetime("2024-01-02T"+time,'InputFormat',timeFormat(time)),'HH:mm:ss.SSS'));
    verifyEqual(testCase,epoch.TimeZone,'UTC');
end
end

function format=timeFormat(time)
format='yyyy-MM-dd''T''HH:mm:ss';
if contains(time,'.'), format=[format '.SSS']; end
end

function testInvalidClockNeverDefaultsToNoon(testCase)
for value=["24:00:00","12:60:00","12:00:60","","noon","12:30"]
    verifyError(testCase,@()leotherm.parseStartEpoch(datetime(2024,1,1),value),'leotherm:InvalidStartTime');
end
end

function testScientificInputsIgnoreOnlyNames(testCase)
s=leotherm.defaultScenario; n=leotherm.defaultReceiverNetwork; renamed=s; renamed.name='renamed';
verifyTrue(testCase,leotherm.sameSimulationInputs(s,n,renamed,n));
renamed.startEpoch=s.startEpoch+seconds(1);
verifyFalse(testCase,leotherm.sameSimulationInputs(s,n,renamed,n));
other=n; other.capacityJK(1)=other.capacityJK(1)*1.01;
verifyFalse(testCase,leotherm.sameSimulationInputs(s,n,s,other));
end

function testLegacyEarthModeNormalizesButDoesNotEqualNewMode(testCase)
s=leotherm.defaultScenario; n=leotherm.defaultReceiverNetwork;
old=s; old.environment=rmfield(old.environment,'earthIRModel');
legacy=old; legacy.environment.earthIRModel='legacy_cosine';
verifyTrue(testCase,leotherm.sameSimulationInputs(old,n,legacy,n));
verifyFalse(testCase,leotherm.sameSimulationInputs(old,n,s,n));
end

function testPreflightDoesNotFillRejectedRecords(testCase)
n=leotherm.defaultReceiverNetwork;
[raw,~,options]=leotherm.telemetryDemo(n);
raw.quality(4:10)=0;
data=leotherm.readTelemetry(raw,[],n);
a=leotherm.telemetryPreflight(data,options);
verifyTrue(testCase,a.ready);
verifyEqual(testCase,a.validDriverRows,height(raw)-7);
verifyEqual(testCase,a.segmentCount,2);
verifyFalse(testCase,any(a.acceptedDriverMask(4:10)));
verifyTrue(testCase,ismember("rejected_driving_rows",a.codes));
end

function testPreflightDetectsMissingDriversAndExcludedCoverage(testCase)
n=leotherm.defaultReceiverNetwork;
[raw,~,options]=leotherm.telemetryDemo(n);
data=leotherm.readTelemetry(raw,[],n);
options.excludeInitialS=1e5;
a=leotherm.telemetryPreflight(data,options);
verifyTrue(testCase,ismember("exclusion_removes_segments",a.codes));
data.hasSun(1)=false;
a=leotherm.telemetryPreflight(data,options);
verifyFalse(testCase,a.ready);
verifyTrue(testCase,ismember("incomplete_or_mixed_orbit_mapping",a.codes));
end

function testPreflightTranslationsCoverAllCodes(testCase)
codes=["missing_external_power","incomplete_or_mixed_orbit_mapping","unconfirmed_frame", ...
    "incomplete_attitude","no_contiguous_drivers","exclusion_removes_segments", ...
    "no_measured_temperature","missing_initial_temperature","rejected_driving_rows","structural_checks_passed"];
verifyFalse(testCase,any(leotherm.preflightText(codes,'zh')==codes));
verifyFalse(testCase,any(leotherm.preflightText(codes,'en')==codes));
end

function testSweepCancellationRetainsCompletedAndUnrunCases(testCase)
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=20;
s.convergence.enabled=false; s.warmupOrbits=0; n=leotherm.defaultReceiverNetwork;
r=leotherm.runBetaAltitudeSweep(s,n,600,[0 20 40],1,@(done,~)done>=1);
verifyEqual(testCase,r.status,{'complete';'cancelled';'cancelled'});
verifyTrue(testCase,all(isnan(r.rf_temperature_span_k(2:3))));
end

function testPhysicalSweepCancellationIsNotFailure(testCase)
s=leotherm.defaultScenario; n=leotherm.defaultReceiverNetwork;
r=leotherm.runPhysicalSweep(s,n,s.startEpoch,600,97,[0 20],@(~,~)true);
verifyEqual(testCase,r.status,{'cancelled';'cancelled'});
end
