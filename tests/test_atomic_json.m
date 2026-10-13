function tests = test_atomic_json
tests = functiontests(localfunctions);
end

function setup(testCase)
folder = tempname;
mkdir(folder);
testCase.TestData.folder = folder;
testCase.addTeardown(@() rmdir(folder, 's'));
end

function testUtf8RoundtripAndSameDirectoryReplacement(testCase)
file = fullfile(testCase.TestData.folder, 'status.json');
value = struct('status', 'running', 'message', char([27979 35797]), 'count', 0);
leotherm.writeJsonAtomic(file, value);
verifyEqual(testCase, readJson(file), value);
value.status = 'complete'; value.count = 36;
leotherm.writeJsonAtomic(file, value);
verifyEqual(testCase, readJson(file), value);
verifyEmpty(testCase, dir(fullfile(testCase.TestData.folder, '*.tmp')));
end

function testRepeatedShortAndLongUpdatesRemainComplete(testCase)
file = fullfile(testCase.TestData.folder, 'status.json');
for k = 1:40
    value = struct('sequence', k, 'payload', repmat('x', 1, 1+mod(k,2)*10000));
    leotherm.writeJsonAtomic(file, value);
    verifyEqual(testCase, readJson(file), value);
end
end

function testEncodingFailurePreservesPreviousBytes(testCase)
file = fullfile(testCase.TestData.folder, 'status.json');
leotherm.writeJsonAtomic(file, struct('status', 'running'));
before = fileread(file);
verifyError(testCase, @() leotherm.writeJsonAtomic(file, struct('bad', @sin)), ...
    'leotherm:AtomicJsonEncode');
verifyEqual(testCase, fileread(file), before);
verifyEmpty(testCase, dir(fullfile(testCase.TestData.folder, '*.tmp')));
end

function testMissingParentAndDirectoryTargetAreRejected(testCase)
verifyError(testCase, @() leotherm.writeJsonAtomic( ...
    fullfile(testCase.TestData.folder, 'missing', 'status.json'), struct), ...
    'leotherm:AtomicJsonPath');
verifyError(testCase, @() leotherm.writeJsonAtomic(testCase.TestData.folder, struct), ...
    'leotherm:AtomicJsonPath');
end

function testLockedDestinationKeepsOldRecordAndCleansTemporary(testCase)
assumeTrue(testCase, ispc, 'Windows file-sharing regression.');
file = fullfile(testCase.TestData.folder, 'status.json');
old = struct('status', 'running', 'count', 1);
leotherm.writeJsonAtomic(file, old);
stream = System.IO.FileStream(file, System.IO.FileMode.Open, ...
    System.IO.FileAccess.Read, System.IO.FileShare.Read);
cleanup = onCleanup(@() stream.Close());
verifyError(testCase, @() leotherm.writeJsonAtomic(file, struct('status', 'complete')), ...
    'leotherm:AtomicJsonReplace');
clear cleanup
verifyEqual(testCase, readJson(file), old);
verifyEmpty(testCase, dir(fullfile(testCase.TestData.folder, '*.tmp')));
end

function value = readJson(file)
fid = fopen(file, 'rb');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
value = jsondecode(native2unicode(bytes', 'UTF-8'));
end
