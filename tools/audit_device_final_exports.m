function summary = audit_device_final_exports(outputDirectory)
%AUDIT_DEVICE_FINAL_EXPORTS Verify final labels and regenerate complete examples.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root); startup; addpath(fullfile(root,'examples'));
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'Use a new audit directory.');
mkdir(outputDirectory);
count = 0;
for folder = {'src','tests','tools','examples','studies'}
    files = dir(fullfile(root,folder{1},'**','*.m'));
    for k = 1:numel(files)
        path = fullfile(files(k).folder,files(k).name);
        messages = checkcode(path,'-id');
        count = count + numel(messages);
        for j = 1:numel(messages)
            fprintf('MLINT %s:%d %s\n',path,messages(j).line,messages(j).message);
        end
    end
end
assert(count == 0,'Static findings remain.');
tests = runtests(fullfile(root,'tests','test_device_calibration_exports.m'));
assert(all([tests.Passed]),'Final export/date-label regression failed.');
examples = run_device_calibration_demo(fullfile(outputDirectory,'examples'));
summary = struct('softwareVersion',leotherm.version,'codeAnalyzerFindings',count, ...
    'exportTestsPassed',sum([tests.Passed]),'insideCapacityJK',examples.inside.fit.parameters, ...
    'outsideCapacityJK',examples.outside.fit.parameters,'scope','synthetic_software_verification_not_flight_validation');
save(fullfile(outputDirectory,'export_audit.mat'),'summary','tests');
disp(summary);
fprintf('FINAL_EXPORT_AUDIT_COMPLETE\n');
end
