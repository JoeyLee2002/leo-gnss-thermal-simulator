function study = runPaperStudy(outputDirectory, language)
%RUNPAPERSTUDY Recompute the paper reference task and 36 controlled cases.
% Uses a fresh destination; archived CSVs are never used as solver results.
if nargin<2, language='both'; end
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
    'status','running','stage','reference','caseCount',0);
saveStatus;
try
    task=leotherm.createThermalPipelineTask;
    task.language=language;
    if strcmp(language,'both'), task.language='en'; end
    task.scenario.name='reference_network_report_demo';
    task.scenario.durationS=7200; task.scenario.timeStepS=60;
    task.scenario.warmupOrbits=0; task.scenario.convergence.enabled=false;
    task.sweep.enabled=false;
    reference=leotherm.runThermalPipeline(task,fullfile(outputDirectory,'reference'));
    assert(strcmp(reference.status,'complete'));
    status.stage='sweep36'; saveStatus;
    summary=run_paper_sweep36_v129(fullfile(outputDirectory,'sweep36'));
    data=load(fullfile(outputDirectory,'sweep36','sweep36_complete.mat'));
    audit_sweep36_v129(fullfile(outputDirectory,'sweep36'),fullfile(outputDirectory,'audit.csv'));
    export_sweep36_open_data(fullfile(outputDirectory,'sweep36'),fullfile(outputDirectory,'open_data'));
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
    report=leotherm.writeThermalReport(bundle,fullfile(outputDirectory,'report'),language);
    study=struct('version',leotherm.version,'reference',reference,'summary',summary, ...
        'refinement',data.refinement,'report',report,'outputDirectory',outputDirectory);
    save(fullfile(outputDirectory,'paper_study.mat'),'study','-v7.3');
    status.status='complete'; status.stage='complete'; saveStatus;
    fprintf('PAPER_STUDY_COMPLETE=%s\n',outputDirectory);
catch exception
    status.status='failed'; status.error=exception.message; saveStatus;
    rethrow(exception);
end

    function saveStatus
        file=fullfile(outputDirectory,'paper_study_status.json');
        fid=fopen(file,'w','n','UTF-8');
        if fid<0, error('leotherm:PaperStudyOutput','Cannot write study status.'); end
        fileCleanup=onCleanup(@() fclose(fid));
        fprintf(fid,'%s',jsonencode(status,'PrettyPrint',true));
    end
end
