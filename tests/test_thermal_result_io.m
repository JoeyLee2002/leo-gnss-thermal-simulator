function tests = test_thermal_result_io
tests = functiontests(localfunctions);
end

function testJsonImportAndReport(testCase)
r = fixtureResult();
folder = tempname; mkdir(folder); testCase.addTeardown(@() rmdir(folder,'s'));
path = fullfile(folder,'result.json'); fid=fopen(path,'w'); fprintf(fid,'%s',jsonencode(r)); fclose(fid);
[actual, report] = leotherm.io.importThermalResult(path);
verifyEqual(testCase, actual.schema, 'leotherm.thermal_result.v1');
verifyEqual(testCase, report.format, 'json');
verifyEqual(testCase, report.epochCount, 3);
verifyEqual(testCase, report.intervalStats.count, 2);
verifyTrue(testCase, report.importValidationPassed);
verifyEqual(testCase, numel(report.inputFingerprint), 64);
end

function testMatImportAndNoReordering(testCase)
r = fixtureResult(); r.epochs = {'2026-01-01T00:00:00Z','2026-01-01T00:00:02Z'}; r.temperatureK = [300 301; 302 303]; r.heatPowerW = [];
folder = tempname; mkdir(folder); testCase.addTeardown(@() rmdir(folder,'s'));
path = fullfile(folder,'result.mat'); thermalResult = r; save(path,'thermalResult');
[actual, report] = leotherm.io.importThermalResult(path);
verifyEqual(testCase, actual.epochs, r.epochs);
verifyEqual(testCase, report.coverageEndUTC, '2026-01-01T00:00:02Z');
end

function testMissingAndBadDataReported(testCase)
r = fixtureResult(); r.temperatureK(2,1)=NaN; r.heatPowerW(3,2)=Inf;
report = leotherm.io.validateThermalResult(r);
verifyEqual(testCase, report.missing.temperatureK, 1);
verifyEqual(testCase, report.badData.heatPowerW, 1);
verifyFalse(testCase, report.validationPassed);
end

function testNonMonotonicRejectedWithoutSorting(testCase)
r = fixtureResult(); r.epochs = r.epochs([2 1 3]); r.temperatureK = r.temperatureK([2 1 3],:);
verifyError(testCase,@()leotherm.io.validateThermalResult(r),'leotherm:InvalidThermalResult');
end

function testUnitsAndDimensionsRejected(testCase)
r = fixtureResult(); r.units.temperatureK='C';
verifyError(testCase,@()leotherm.io.validateThermalResult(r),'leotherm:InvalidThermalResult');
r = fixtureResult(); r.temperatureK = [1 2 3];
verifyError(testCase,@()leotherm.io.validateThermalResult(r),'leotherm:InvalidThermalResult');
end

function r = fixtureResult()
r = struct('schema','leotherm.thermal_result.v1', ...
    'epochs',{{'2026-01-01T00:00:00Z','2026-01-01T00:00:01Z','2026-01-01T00:00:03Z'}}, ...
    'nodeIds',{{'n1','n2'}}, 'temperatureK',[300 301; 301 302; 302 303], ...
    'heatPowerW',[1 2; 2 3; 3 4], ...
    'units',struct('epoch','UTC','temperatureK','K','heatPowerW','W'), ...
    'modelFingerprint','model-abc', ...
    'provenance',struct('source','test','inputFingerprint',''), ...
    'qualityFlags',{{'nominal','nominal','nominal'}}, ...
    'extensions',struct('vendor','fixture'));
end
