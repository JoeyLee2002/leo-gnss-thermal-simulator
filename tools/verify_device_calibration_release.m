function summary = verify_device_calibration_release(outputDirectory)
%VERIFY_DEVICE_CALIBRATION_RELEASE Static, regression, export and GUI checks.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1
    outputDirectory = fullfile(root,'results',['device_release_' datestr(now,'yyyymmdd_HHMMSS')]);
end
assert(~isfolder(outputDirectory) && ~isfile(outputDirectory),'Use a new verification directory.');
mkdir(outputDirectory);
addpath(root); startup;
addpath(fullfile(root,'examples')); addpath(fullfile(root,'tools'));
issueCount = 0;
for directory = {'src','tests','tools','examples','studies'}
    files = dir(fullfile(root,directory{1},'**','*.m'));
    for k = 1:numel(files)
        path = fullfile(files(k).folder,files(k).name);
        messages = checkcode(path,'-id');
        issueCount = issueCount + numel(messages);
        for j = 1:numel(messages)
            fprintf('MLINT %s:%d %s %s\n',path,messages(j).line,messages(j).id,messages(j).message);
        end
    end
end
fprintf('MLINT_TOTAL=%d\n',issueCount);
assert(issueCount == 0,'Resolve code analyzer findings before release verification.');
tests = run_tests;
fprintf('TEST_TOTAL=%d TEST_PASSED=%d\n',numel(tests),sum([tests.Passed]));
save(fullfile(outputDirectory,'test_results.mat'),'tests');
benchmark = run_satmo_style_benchmark(fullfile(outputDirectory,'benchmark'));
demo = run_device_calibration_demo(fullfile(outputDirectory,'synthetic_demo'));
gui = run_device_calibration_gui_check(fullfile(outputDirectory,'gui_fit'));
summary = struct('version',leotherm.version,'codeAnalyzerFindings',issueCount, ...
    'testsTotal',numel(tests),'testsPassed',sum([tests.Passed]), ...
    'benchmarkRows',height(benchmark),'insideCapacityJK',demo.inside.fit.parameters, ...
    'outsideCapacityJK',demo.outside.fit.parameters,'gui',gui);
save(fullfile(outputDirectory,'release_summary.mat'),'summary','benchmark');
disp(summary);
fprintf('DEVICE_CALIBRATION_RELEASE_VERIFIED\n');
end
