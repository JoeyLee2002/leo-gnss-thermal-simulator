function tests = test_gracefo_import
tests = functiontests(localfunctions);
end

function testQualityAndMicroseconds(testCase)
[path, cleanup] = writeFixture([ ...
    "757339224 986915 G C 00000000 T 29 05"; ...
    "757339344 986914 G C 10000000 T 30 05"]); %#ok<ASGLU>
[records, metadata] = leotherm.readGracefoIhk(path);
verifyEqual(testCase, records.accepted,[true;false]);
verifyEqual(testCase, records.reason(2),"quality_rejected");
verifyEqual(testCase, records.epoch_utc(1), ...
    datetime(2024,1,1,0,0,6,'TimeZone','UTC')+seconds(.986915));
verifyEqual(testCase, records.temperature_k(1),302.15,'AbsTol',1e-12);
verifyEqual(testCase, metadata.gpsMinusUtcS,18);
end

function testDuplicateChannelRejected(testCase)
[path, cleanup] = writeFixture(repmat("757339224 986915 G C 00000000 T 29 05",2,1)); %#ok<ASGLU>
verifyError(testCase,@() leotherm.readGracefoIhk(path),'leotherm:GracefoTime');
end

function testDifferentSensorsAtSameTimeAllowed(testCase)
[path, cleanup] = writeFixture([ ...
    "757339224 986915 G C 00000000 T 29 05"; ...
    "757339224 986915 G C 00000000 T 30 06"]); %#ok<ASGLU>
records = leotherm.readGracefoIhk(path);
verifyEqual(testCase, records.accepted,[true;true]);
end

function testReceiverTimeNotReinterpretedAsGPS(testCase)
[path, cleanup] = writeFixture("757339224 986915 R C 00000000 T 29 05"); %#ok<ASGLU>
records = leotherm.readGracefoIhk(path);
verifyFalse(testCase, records.accepted);
verifyTrue(testCase, isnat(records.epoch_utc));
end

function testUnsupportedLeapSecondIntervalRejected(testCase)
[path, cleanup] = writeFixture("1 0 G C 00000000 T 29 05"); %#ok<ASGLU>
verifyError(testCase,@() leotherm.readGracefoIhk(path),'leotherm:GracefoTime');
end

function testMalformedRecordNotDropped(testCase)
[path, cleanup] = writeFixture("invalid record"); %#ok<ASGLU>
verifyError(testCase,@() leotherm.readGracefoIhk(path),'leotherm:GracefoFormat');
end

function testRealDownloadWhenAvailable(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
path = fullfile(root,'results','flight_telemetry','raw','IHK1B_2024-01-01_C_04.txt');
assumeTrue(testCase, isfile(path), 'Optional real-flight archive is not downloaded.');
[records, meta] = leotherm.readGracefoIhk(path);
verifyEqual(testCase, height(records),28080);
verifyEqual(testCase, records.epoch_utc(1), ...
    datetime(2024,1,1,0,0,6,'TimeZone','UTC') + seconds(0.986915));
verifyEqual(testCase, records.temperature_k(1),29.34653871110959 + 273.15,'AbsTol',1e-12);
verifyEqual(testCase, numel(unique(records.sensor_id(records.sensor_type=="T"))),17);
verifyFalse(testCase, meta.interpolation);
verifyFalse(testCase, meta.physicalValidationComplete);
verifyEqual(testCase, meta.sensorLocation,'unresolved_numeric_sensor_ids');
end

function [path, cleanup] = writeFixture(rows)
path = [tempname '.txt'];
cleanup = onCleanup(@() delete(path));
fid = fopen(path,'w'); assert(fid>=0);
closeFile = onCleanup(@() fclose(fid));
fprintf(fid,'header:\n  num_records: %d\n  title: IPU Housekeeping\n',numel(rows));
fprintf(fid,'  product_version: 04\n  units: microseconds\n# End of YAML header\n');
fprintf(fid,'%s\n',rows);
end
