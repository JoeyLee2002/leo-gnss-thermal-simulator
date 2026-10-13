function study = runPaperStudy(outputDirectory, language, progress)
%RUNPAPERSTUDY Recompute the paper reference task and 36 controlled cases.
% Uses a fresh destination; archived CSVs are never used as solver results.
if nargin<2, language='both'; end
if nargin<3, progress=[]; end
if ~isempty(progress) && ~isa(progress,'function_handle')
    error('leotherm:InvalidProgress','Progress must be empty or a function handle.');
end
language=lower(char(string(language)));
if ~ismember(language,{'zh','en','both'})
    error('leotherm:InvalidLanguage','Language must be zh, en or both.');
end
validateattributes(outputDirectory,{'char','string'},{'nonempty'});
outputDirectory=char(java.io.File(char(outputDirectory)).getCanonicalPath());
if isfile(outputDirectory) || isfolder(outputDirectory)
    error('leotherm:PaperStudyOutput','Choose a new output directory: %s',outputDirectory);
end
scripts=fullfile(leotherm.installRoot,'studies','softwarex','sweep36');
if ~isfolder(scripts), error('leotherm:PaperStudyResources','Paper study scripts are missing.'); end
previousPath=path; cleanup=onCleanup(@() path(previousPath));
addpath(scripts,'-begin');
mkdir(outputDirectory);
status=struct('schema','leotherm.paper_study.v1','version',leotherm.version, ...
    'status','running','stage','reference','caseCount',0,'refinementCount',0, ...
    'solveJobsCompleted',0,'solveJobsTotal',40,'messageZh','参考任务', ...
    'messageEn','Reference task');
statusClock=tic;
saveStatus;
try
    task=leotherm.createThermalPipelineTask;
    task.language=language;
    if strcmp(language,'both'), task.language='en'; end
    task.scenario.name='reference_network_report_demo';
    task.scenario.durationS=7200; task.scenario.timeStepS=60;
    task.scenario.warmupOrbits=0; task.scenario.convergence.enabled=false;
    task.sweep.enabled=false;
    leotherm.notifyProgress(@observe,'reference',0,1,'参考任务：热求解与报告。','Reference task: thermal solution and report.');
    reference=leotherm.runThermalPipeline(task,fullfile(outputDirectory,'reference'),@observe);
    assert(strcmp(reference.status,'complete'));
    status.solveJobsCompleted=1;
    status.stage='sweep36'; saveStatus;
    summary=run_paper_sweep36_v129(fullfile(outputDirectory,'sweep36'),36,@observe);
    status.stage='audit';
    leotherm.notifyProgress(@observe,'audit',0,1,'检查全部工况并导出开放数据。','Auditing all cases and exporting open data.');
    data=load(fullfile(outputDirectory,'sweep36','sweep36_complete.mat'));
    audit_sweep36_v129(fullfile(outputDirectory,'sweep36'),fullfile(outputDirectory,'audit.csv'),@observe);
    export_sweep36_open_data(fullfile(outputDirectory,'sweep36'),fullfile(outputDirectory,'open_data'),@observe);
    status.caseCount=height(summary);
    canonical=summary;
    names=canonical.Properties.VariableNames;
    names{strcmp(names,'rf_span_k')}='rf_temperature_p95_p5_k';
    names{strcmp(names,'harmonic_delay_s')}='orbital_phase_delay_s';
    names{strcmp(names,'conductance_wk')}='effective_thermal_conductance_w_per_k';
    canonical.Properties.VariableNames=names;
    writetable(canonical,fullfile(outputDirectory,'paper_results.csv'));
    status.stage='report'; saveStatus;
    metadata=struct('paperStudy',struct('summary',table2struct(summary), ...
        'refinement',table2struct(data.refinement),'protocol',sweep36_readable_protocol(data.protocol)), ...
        'engineVersion',leotherm.version,'sourceFingerprint',data.sourceFingerprint);
    bundle=struct('scenario',reference.scenario,'metadata',metadata);
    leotherm.notifyProgress(@observe,'report',0,1,'生成综合图表和 PDF。','Generating combined figures and PDF reports.');
    report=leotherm.writeThermalReport(bundle,fullfile(outputDirectory,'report'),language,@observe);
    study=struct('version',leotherm.version,'reference',reference,'summary',summary, ...
        'refinement',data.refinement,'report',report,'outputDirectory',outputDirectory);
    save(fullfile(outputDirectory,'paper_study.mat'),'study','-v7.3');
    status.status='complete'; status.stage='complete'; saveStatus;
    fprintf('PAPER_STUDY_COMPLETE=%s\n',outputDirectory);
catch exception
    status.status='failed';
    if strcmp(exception.identifier,'leotherm:OperationCancelled'), status.status='cancelled'; end
    status.error=exception.message; saveStatus;
    rethrow(exception);
end

    function cancelled=observe(event)
        switch event.stage
            case {'reference','case_start','refinement_start','audit','report'}
                status.messageZh=event.messageZh; status.messageEn=event.messageEn;
            case 'case_complete'
                status.caseCount=event.completed;
                status.solveJobsCompleted=1+status.caseCount;
            case 'refinement_complete'
                status.refinementCount=event.completed;
                status.solveJobsCompleted=1+status.caseCount+status.refinementCount;
        end
        if startsWith(event.stage,'refinement'), status.stage='refinement'; end
        event.contextZh=status.messageZh; event.contextEn=status.messageEn;
        event.solveJobsCompleted=status.solveJobsCompleted;
        event.solveJobsTotal=status.solveJobsTotal;
        if toc(statusClock)>=0.5 || ismember(event.stage,{'case_complete','refinement_complete','reference','report','audit'})
            saveStatus; statusClock=tic;
        end
        cancelled=false;
        if ~isempty(progress), cancelled=progress(event); end
    end

    function saveStatus
        file=fullfile(outputDirectory,'paper_study_status.json');
        status.heartbeatUTC=char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));
        leotherm.writeJsonAtomic(file,status);
    end
end
