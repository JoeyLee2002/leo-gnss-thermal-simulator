function tests = test_extensibility_audit
%TEST_EXTENSIBILITY_AUDIT Reproduction tests for v0.13.0 audit findings.
tests = functiontests(localfunctions);
end

function testComponentCreateActionAcceptsSpec(testCase)
spec = struct('id','audit_component','name','Audit component','nodeIndex',1, ...
    'capacityJK',1,'source','audit','uncertainty',struct);
component = leotherm.componentModel('create', spec);
verifyEqual(testCase, component.id, 'audit_component');
end

function testExchangeValidatorRejectsNonScalarUncertainty(testCase)
model = fixtureModel();
model.uncertainty = struct('assumption','a');
model.uncertainty(2).assumption = 'b';
verifyError(testCase, @() leotherm.io.validateThermalModel(model), ...
    'leotherm:InvalidThermalModel');
end

function testFingerprintSurvivesExportRoundTrip(testCase)
model = fixtureModel();
model.provenance.inputFingerprint = repmat('0',1,64);
folder = tempname; mkdir(folder); cleanup = onCleanup(@() rmdir(folder,'s'));
path = fullfile(folder,'fingerprinted.json');
leotherm.io.exportThermalModel(model, path);
 [actual, report] = leotherm.io.importThermalModel(path);
verifyEqual(testCase, actual.provenance.inputFingerprint, repmat('0',1,64));
verifyEqual(testCase, report.sourceFingerprint, repmat('0',1,64));
end

function testTemperatureCurveWithoutGridIsRejected(testCase)
material = struct('id','audit_curve','name','Audit curve', ...
    'kind','temperature_dependent','conductivityWmK',[1 2], ...
    'densityKgM3',[1000 1001],'specificHeatJkgK',[900 901], ...
    'temperatureRangeK',[200 400],'source','audit','confidence','low', ...
    'uncertainty',struct);
% Use the non-persistent structure validation form so this audit test does
% not contaminate the process-wide custom-material registry used by tests.
verifyError(testCase, @() leotherm.materialLibrary(material), ...
    'leotherm:InvalidMaterial');
end

function testCustomMaterialNameConflictIsRejected(testCase)
base = leotherm.materialLibrary('get', 'aluminum_6061');
custom = base;
custom.id = 'audit_aluminum';
custom.isReferenceValue = false;
custom.source = 'audit';
verifyError(testCase, @() leotherm.materialLibrary('register', custom), ...
    'leotherm:MaterialNameConflict');
end

function model = fixtureModel()
units = struct('length','m','mass','kg','time','s','temperature','K', ...
    'power','W','heatCapacity','J/K','conductance','W/K','area','m^2');
model = struct('schema','leotherm.thermal_model.v1', ...
    'metadata',struct('modelId','audit_fixture','createdUTC','2026-01-01T00:00:00Z','units',units), ...
    'nodes',struct('id',{'n1','n2'},'positionM',{[0 0 0],[1 0 0]}), ...
    'materials',struct('id','al','conductivityWmK',200), ...
    'components',struct('id','body','nodeIds',{{'n1','n2'}}), ...
    'contacts',struct('id','c1','nodeIds',{{'n1','n2'}},'conductanceWK',1), ...
    'boundaries',struct('id','b1','type','fixedTemperature','nodeIds',{{'n1'}},'temperatureK',300), ...
    'provenance',struct('source','audit','transformations',{{}}), ...
    'uncertainty',struct('assumption','none'));
end
