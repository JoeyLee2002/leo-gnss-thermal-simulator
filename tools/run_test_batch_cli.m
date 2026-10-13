%RUN_TEST_BATCH_CLI Execute one release-test batch in an isolated MATLAB process.
specPath = getenv('LEOTHERM_BATCH_SPEC');
resultPath = getenv('LEOTHERM_BATCH_RESULT');
summary = struct('total',0,'passed',0,'failed',0,'incomplete',0, ...
    'durationS',0,'matlabRelease',version('-release'),'error','', ...
    'testFiles',{{}},'rows',table);
try
    if isempty(specPath) || isempty(resultPath)
        error('leotherm:IsolatedVerification', ...
            'LEOTHERM_BATCH_SPEC and LEOTHERM_BATCH_RESULT are required.');
    end
    spec = load(specPath);
    cd(spec.root);
    addpath(fullfile(spec.root, 'src'));
    timer = tic;
    if isfield(spec, 'currentTestNames') && ~isempty(spec.currentTestNames)
        assert(numel(spec.currentTestFiles) == 1, 'Method selection requires one test file.');
        suite = matlab.unittest.TestSuite.fromFile(spec.currentTestFiles{1});
        suite = suite(ismember({suite.Name}, spec.currentTestNames));
        assert(numel(suite) == numel(spec.currentTestNames), 'A selected test method is missing.');
        results = run(suite);
    else
        results = runtests(spec.currentTestFiles);
    end
    summary.durationS = toc(timer);
    summary.total = numel(results);
    summary.passed = nnz([results.Passed]);
    summary.failed = nnz([results.Failed]);
    summary.incomplete = nnz([results.Incomplete]);
    summary.testFiles = spec.currentTestFiles;
    summary.rows = table(string({results.Name})', [results.Passed]', ...
        [results.Failed]', [results.Incomplete]', [results.Duration]', ...
        'VariableNames', {'name','passed','failed','incomplete','duration_s'});
    save(resultPath, 'summary', '-v7.3');
    fprintf('BATCH_TOTAL=%d BATCH_PASSED=%d BATCH_FAILED=%d BATCH_INCOMPLETE=%d\n', ...
        summary.total, summary.passed, summary.failed, summary.incomplete);
    if summary.failed > 0
        error('leotherm:IsolatedBatchFailed', ...
            'The isolated batch contains %d failed test(s).', summary.failed);
    end
    clear results summary spec timer
    close all force
    drawnow;
    return;
catch exception
    summary.error = getReport(exception, 'extended');
    if ~isempty(resultPath)
        try
            save(resultPath, 'summary', '-v7.3');
        catch
        end
    end
    fprintf(2, '%s\n', summary.error);
    error('leotherm:IsolatedBatchFailed', 'The isolated batch failed.');
end
