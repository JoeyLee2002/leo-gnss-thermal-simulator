function report = run_release_verification_isolated(resumeDirectory, originalLog)
%RUN_RELEASE_VERIFICATION_ISOLATED Verify a release in fresh MATLAB batches.
% MATLAB R2021b can terminate after long mixed GUI/graphics/numerical suites
% with a native heap error. Each bounded batch therefore runs in a clean
% process. A crash, missing result, or failed test blocks the release.

root = fileparts(fileparts(mfilename('fullpath')));
cd(root);
addpath(fullfile(root, 'src'), fullfile(root, 'examples'), ...
    fullfile(root, 'tests'), fullfile(root, 'tools'));
issueCount = staticCheck(root);
fprintf('MLINT_TOTAL=%d\n', issueCount);
if issueCount ~= 0
    error('leotherm:IsolatedVerification', 'Static analysis issues found.');
end

files = dir(fullfile(root, 'tests', 'test_*.m'));
testFiles = fullfile({files.folder}, {files.name});
% MATLAB R2021b has shown native heap failures during teardown of mixed
% graphics/export suites even when every assertion passed. One test file per
% child process makes the failure reproducible and preserves all prior batch
% results for diagnosis. The extra startup cost is intentional release-gate
% overhead, not a change to the scientific test suite.
batches = partitionTests(testFiles, 1);
versionTag = strrep(leotherm.version, '.', '_');
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
batchRoot = fullfile(root, 'results', ...
    sprintf('verification_batches_v%s_%s', versionTag, stamp));
mkdir(batchRoot);
priorLog='';
if nargin>0 && ~isempty(resumeDirectory)
    candidate=char(java.io.File(resumeDirectory).getCanonicalPath());
    expected=char(java.io.File(fullfile(root,'results')).getCanonicalPath());
    assert(startsWith(candidate,[expected filesep]) && isfolder(candidate), ...
        'leotherm:IsolatedVerification','Resume directory must be inside this repository results.');
    assert(nargin==2,'Original parent verification logs are required.');
    originalLogs=cellstr(string(originalLog));
    assert(~isempty(originalLogs) && all(cellfun(@isfile,originalLogs)), ...
        'Original parent verification logs are required.');
    priorLog=strjoin(cellfun(@fileread,originalLogs,'UniformOutput',false),newline);
    batchRoot=candidate;
end
batchRows = table;
testRows = table;
for k = 1:numel(batches)
    specPath = fullfile(batchRoot, sprintf('batch_%02d_spec.mat', k));
    resultPath = fullfile(batchRoot, sprintf('batch_%02d_result.mat', k));
    currentTestFiles = batches{k};
    previousSucceeded=~isempty(regexp(priorLog,sprintf('BATCH_%02d_[^\n]*STATUS=0(?:\r?\n|$)',k),'once'));
    if previousSucceeded
        priorSpec=load(specPath,'root','currentTestFiles');
        priorResult=load(resultPath,'summary'); prior=priorResult.summary;
        assert(strcmp(priorSpec.root,root) && isequal(priorSpec.currentTestFiles,currentTestFiles) && ...
            prior.failed==0 && prior.incomplete==0 && isempty(prior.error), ...
            'leotherm:IsolatedVerification','Resume batch inputs or results differ.');
        batchRows=[batchRows;table(k,numel(testFiles),prior.total,prior.passed,prior.failed, ...
            prior.incomplete,NaN,0,string(fullfile(batchRoot,sprintf('batch_%02d.log',k))), ...
            'VariableNames',{'batch','test_file_count','test_count','passed','failed','incomplete','wall_time_s','exit_status','log'})]; %#ok<AGROW>
        testRows=[testRows;prior.rows]; %#ok<AGROW>
        fprintf('RESUMED_BATCH_%02d_PASSED=%d\n',k,prior.passed);
        continue
    end
    save(specPath, 'root', 'currentTestFiles');
    oldSpec = getenv('LEOTHERM_BATCH_SPEC');
    oldResult = getenv('LEOTHERM_BATCH_RESULT');
    restore = onCleanup(@() restoreEnvironment(oldSpec, oldResult));
    setenv('LEOTHERM_BATCH_SPEC', specPath);
    setenv('LEOTHERM_BATCH_RESULT', resultPath);
    matlabExe = fullfile(matlabroot, 'bin', ['matlab' executableExtension]);
    cliPath = fullfile(root, 'tools', 'run_test_batch_cli.m');
    command = sprintf('"%s" -batch "run(''%s'')"', matlabExe, escapeQuote(cliPath));
    timer = tic;
    [status, output] = system(command);
    elapsed = toc(timer);
    clear restore
    logPath = fullfile(batchRoot, sprintf('batch_%02d.log', k));
    if isfile(logPath)
        copyfile(logPath,[logPath '.previous_attempt_' stamp]);
    end
    writeText(logPath, output);
    if ~isfile(resultPath)
        error('leotherm:IsolatedVerification', ...
            'Batch %d exited with status %d and produced no result. See %s.', ...
            k, status, logPath);
    end
    loaded = load(resultPath, 'summary'); summary = loaded.summary;
    batchRows = [batchRows; table(k, numel(testFiles), summary.total, ...
        summary.passed, summary.failed, summary.incomplete, elapsed, status, ...
        string(logPath), 'VariableNames', {'batch','test_file_count', ...
        'test_count','passed','failed','incomplete','wall_time_s','exit_status','log'})]; %#ok<AGROW>
    if istable(summary.rows), testRows = [testRows; summary.rows]; end %#ok<AGROW>
    fprintf('BATCH_%02d_FILES=%d TESTS=%d PASSED=%d FAILED=%d INCOMPLETE=%d STATUS=%d\n', ...
        k, numel(testFiles), summary.total, summary.passed, summary.failed, ...
        summary.incomplete, status);
    if status ~= 0 || summary.failed > 0 || ~isempty(summary.error)
        error('leotherm:IsolatedVerification', ...
            'Release test batch %d failed. See %s.', k, logPath);
    end
end

benchmark = run_satmo_style_benchmark(fullfile(root, 'results', ...
    ['benchmark_v' versionTag]));
report = struct('softwareVersion',leotherm.version,'codeAnalyzerFindings',issueCount, ...
    'batches',batchRows,'tests',testRows,'benchmark',benchmark, ...
    'batchDirectory',batchRoot,'matlabRelease',version('-release'));
save(fullfile(root, 'results', ['verification_v' versionTag '.mat']), ...
    'report', 'benchmark', '-v7.3');
statusPath = fullfile(root, 'results', ['verification_v' versionTag '_status.txt']);
fid = fopen(statusPath, 'w');
if fid < 0, error('leotherm:IsolatedVerification', 'Cannot write release status.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'outcome=complete\nversion=%s\ncode_analyzer_findings=%d\n', ...
    leotherm.version, issueCount);
fprintf(fid, 'tests_passed=%d\ntests_total=%d\ntest_batches=%d\n', ...
    sum(batchRows.passed), sum(batchRows.test_count), height(batchRows));
fprintf(fid, 'benchmark_rows=%d\nmatlab_release=%s\n', height(benchmark), version('-release'));
fprintf('TEST_TOTAL=%d TEST_PASSED=%d BENCHMARK_ROWS=%d\n', ...
    sum(batchRows.test_count), sum(batchRows.passed), height(benchmark));
fprintf('FINAL_ISOLATED_VERIFICATION_OK\n');
% Release artifacts are already on disk. Explicitly release large table and
% benchmark objects before MATLAB R2021b performs process teardown; this
% avoids a native heap failure after a successful verification run.
clear batchRows testRows report benchmark
end

function count = staticCheck(root)
files = dir(fullfile(root, '**', '*.m')); count = 0;
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    messages = checkcode(path, '-id'); count = count + numel(messages);
    for j = 1:numel(messages)
        fprintf('MLINT %s:%d %s %s\n', path, messages(j).line, ...
            messages(j).id, messages(j).message);
    end
end
end

function batches = partitionTests(files, maximumFiles)
names = cellfun(@(x) lower(char(x)), files, 'UniformOutput', false);
isolated = contains(names, 'test_gui_') | contains(names, 'test_device_calibration_exports');
batches = cell(0,1);
regular = files(~isolated);
for first = 1:maximumFiles:numel(regular)
    batches{end+1,1} = regular(first:min(first+maximumFiles-1,numel(regular))); %#ok<AGROW>
end
special = files(isolated);
for k = 1:numel(special), batches{end+1,1} = special(k); end %#ok<AGROW>
end

function extension = executableExtension
if ispc, extension = '.exe'; else, extension = ''; end
end

function value = escapeQuote(value)
value = strrep(value, '''', '''''');
end

function restoreEnvironment(spec, result)
setenv('LEOTHERM_BATCH_SPEC', spec);
setenv('LEOTHERM_BATCH_RESULT', result);
end

function writeText(path, value)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:IsolatedVerification', 'Cannot write batch log.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', value);
end
