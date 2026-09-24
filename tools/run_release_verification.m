function run_release_verification
%RUN_RELEASE_VERIFICATION Execute static, unit, and benchmark checks.

root = fileparts(fileparts(mfilename('fullpath')));
cd(root);
startup;

files = dir(fullfile(root, '**', '*.m'));
issueCount = 0;
for k = 1:numel(files)
    file = fullfile(files(k).folder, files(k).name);
    messages = checkcode(file, '-id');
    issueCount = issueCount + numel(messages);
    for j = 1:numel(messages)
        fprintf('MLINT %s:%d %s %s\n', file, messages(j).line, ...
            messages(j).id, messages(j).message);
    end
end
fprintf('MLINT_TOTAL=%d\n', issueCount);
assert(issueCount == 0, 'Static analysis issues found.');

results = run_tests;
fprintf('TEST_TOTAL=%d TEST_PASSED=%d\n', ...
    numel(results), sum([results.Passed]));

addpath(fullfile(root, 'examples'));
versionTag = strrep(leotherm.version, '.', '_');
benchmark = run_satmo_style_benchmark(fullfile(root,'results',['benchmark_v' versionTag]));
fprintf('BENCHMARK_ROWS=%d\n', height(benchmark));

versionTag = strrep(leotherm.version, '.', '_');
save(fullfile(root, 'results', ['verification_v' versionTag '.mat']), ...
    'results', 'benchmark');
statusPath = fullfile(root, 'results', ...
    ['verification_v' versionTag '_status.txt']);
file = fopen(statusPath, 'w');
assert(file >= 0, 'Cannot create release verification status file.');
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'outcome=complete\n');
fprintf(file, 'version=%s\n', leotherm.version);
fprintf(file, 'code_analyzer_findings=%d\n', issueCount);
fprintf(file, 'tests_passed=%d\n', sum([results.Passed]));
fprintf(file, 'tests_total=%d\n', numel(results));
fprintf(file, 'benchmark_rows=%d\n', height(benchmark));
fprintf('FINAL_VERIFICATION_OK\n');
end
