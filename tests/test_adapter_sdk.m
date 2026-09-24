function tests = test_adapter_sdk
tests = functiontests(localfunctions);
end

function testGenericAdapterAndProfiles(testCase)
adapters = leotherm.adapter.list;
verifyTrue(testCase, any(strcmp({adapters.id}, 'generic_exchange')));
generic = leotherm.adapter.get('generic_exchange');
verifyEqual(testCase, generic.schema, 'leotherm.adapter.v1');
verifyTrue(testCase, generic.capabilities.readModel);
profiles = leotherm.adapter.profiles;
verifyEqual(testCase, numel(profiles), 4);
verifyTrue(testCase, all([profiles.requiresOfficialExporter]));
end

function testUserAdapterRegistrationAndIsolation(testCase)
leotherm.adapter.registry('clearcustom');
cleanup = onCleanup(@() leotherm.adapter.registry('clearcustom'));
adapter = struct('id','test_user_adapter','version','1.0.0', ...
    'displayName','Test user adapter','kind','file_exchange', ...
    'capabilities',struct('readModel',true), ...
    'handlers',struct('readModel',@(~) struct('ok',true)), ...
    'provenance',struct('source','unit test'));
registered = leotherm.adapter.register(adapter);
verifyEqual(testCase, registered.id, 'test_user_adapter');
verifyEqual(testCase, leotherm.adapter.get('test_user_adapter').version, '1.0.0');
verifyError(testCase, @() leotherm.adapter.register(adapter), 'leotherm:AdapterDuplicate');
clear cleanup
end

function testInvalidHandlerAndVersionRejected(testCase)
bad = struct('id','bad_adapter','version','1.0', ...
    'displayName','Bad','kind','file_exchange', ...
    'capabilities',struct('readModel',true), 'handlers',struct, ...
    'provenance',struct('source','test'));
verifyError(testCase, @() leotherm.adapter.validate(bad), 'leotherm:AdapterInvalid');
bad.version = '1.0.0';
verifyError(testCase, @() leotherm.adapter.validate(bad), 'leotherm:AdapterHandlerRequired');
end

function testExecuteAndUnregister(testCase)
leotherm.adapter.registry('clearcustom');
cleanup = onCleanup(@() leotherm.adapter.registry('clearcustom'));
generic = leotherm.adapter.get('generic_exchange');
source = struct('schema','leotherm.thermal_model.v1');
verifyError(testCase, @() leotherm.adapter.execute(generic, 'unknown', source), ...
    'leotherm:AdapterCapability');
% The capability gate is exercised without constructing a full thermal model.
noRun = generic;
noRun.capabilities.readModel = false;
verifyError(testCase, @() leotherm.adapter.execute(noRun, 'readModel', source), ...
    'leotherm:AdapterCapability');
adapter = struct('id','test_exec_adapter','version','1.0.0', ...
    'displayName','Execution fixture','kind','file_exchange', ...
    'capabilities',struct('readModel',true), ...
    'handlers',struct('readModel',@(~) struct('executed',true)), ...
    'provenance',struct('source','unit test'));
leotherm.adapter.register(adapter);
out = leotherm.adapter.execute('test_exec_adapter', 'readModel', 'fixture');
verifyTrue(testCase, out.executed);
removed = leotherm.adapter.registry('unregister', 'test_exec_adapter');
verifyEqual(testCase, removed.id, 'test_exec_adapter');
verifyError(testCase, @() leotherm.adapter.get('test_exec_adapter'), ...
    'leotherm:UnknownAdapter');
end

function testMetadataDescriptorImport(testCase)
leotherm.adapter.registry('clearcustom');
cleanup = onCleanup(@() leotherm.adapter.registry('clearcustom'));
root = tempname; mkdir(root); testCase.addTeardown(@() rmdir(root, 's'));
descriptor = struct('id','file_descriptor_adapter','version','1.0.0', ...
    'displayName','File descriptor fixture','kind','file_exchange', ...
    'capabilities',struct('readModel',true), 'handlers',struct, ...
    'provenance',struct('source','unit test descriptor'));
jsonPath = fullfile(root, 'adapter.json');
fid = fopen(jsonPath, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(descriptor)); fclose(fid);
handlers = struct('readModel',@(~) struct('fromFile',true));
[registered, report] = leotherm.adapter.registerFromFile(jsonPath, 'Handlers', handlers);
verifyEqual(testCase, registered.provenance.descriptorFormat, 'json');
verifyEqual(testCase, report.registeredId, 'file_descriptor_adapter');
result = leotherm.adapter.execute('file_descriptor_adapter', 'readModel', 'fixture');
verifyTrue(testCase, result.fromFile);
bad = descriptor;
bad.handlers = struct('readModel','myReadModel');
badPath = fullfile(root, 'bad.json');
fid = fopen(badPath, 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(bad)); fclose(fid);
verifyError(testCase, @() leotherm.adapter.registerFromFile(badPath), ...
    'leotherm:AdapterExecutableInFile');
end
