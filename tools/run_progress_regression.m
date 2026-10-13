function report=run_progress_regression
%RUN_PROGRESS_REGRESSION Isolate the suites affected by progress and naming.
root=fileparts(fileparts(mfilename('fullpath')));
folder=fullfile(root,'results','progress_regression_v1_3');
if isfolder(folder), error('leotherm:VerificationOutput','Use a fresh verification folder.'); end
mkdir(folder);
names={'test_operation_progress','test_artifact_filenames','test_thermal_network', ...
    'test_thermal_pipeline','test_gui_support','test_report_metadata', ...
    'test_report_pdf_merge','test_report_figure_style','test_paper_study_report'};
matlabExe=fullfile(matlabroot,'bin','matlab.exe');
script=fullfile(root,'tools','run_test_batch_cli.m');
oldSpec=getenv('LEOTHERM_BATCH_SPEC'); oldResult=getenv('LEOTHERM_BATCH_RESULT');
cleanup=onCleanup(@() restoreEnvironment(oldSpec,oldResult));
rows=table;
for k=1:numel(names)
    currentTestFiles={fullfile(root,'tests',[names{k} '.m'])};
    specPath=fullfile(folder,[names{k} '_spec.mat']);
    resultPath=fullfile(folder,[names{k} '_result.mat']);
    save(specPath,'root','currentTestFiles');
    setenv('LEOTHERM_BATCH_SPEC',specPath); setenv('LEOTHERM_BATCH_RESULT',resultPath);
    command=sprintf('"%s" -batch "run(''%s'')"',matlabExe,strrep(script,'''',''''''));
    [exitCode,output]=system(command);
    fid=fopen(fullfile(folder,[names{k} '.log']),'w','n','UTF-8');
    assert(fid>=0,'Cannot write regression log.');
    logCleanup=onCleanup(@() fclose(fid)); fprintf(fid,'%s',output); clear logCleanup
    assert(isfile(resultPath),'Missing regression result: %s',names{k});
    data=load(resultPath,'summary');
    fprintf('SCOPED_%s PASSED=%d TOTAL=%d EXIT=%d\n',names{k},data.summary.passed,data.summary.total,exitCode);
    assert(exitCode==0 && data.summary.failed==0 && data.summary.incomplete==0 && isempty(data.summary.error), ...
        'Regression failed: %s',names{k});
    rows=[rows;data.summary.rows]; %#ok<AGROW>
end
report=struct('version','1.3','files',{names},'tests',rows,'passed',nnz(rows.passed), ...
    'total',height(rows),'outcome','passed');
save(fullfile(folder,'summary.mat'),'report','-v7.3');
writetable(rows,fullfile(folder,'tests.csv'));
fprintf('SCOPED_REGRESSION_OK PASSED=%d TOTAL=%d\n',report.passed,report.total);
clear rows data report
end

function restoreEnvironment(spec,result)
setenv('LEOTHERM_BATCH_SPEC',spec); setenv('LEOTHERM_BATCH_RESULT',result);
end
