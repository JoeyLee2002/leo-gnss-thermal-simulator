function verify_sweep36_release(outputDirectory)
%VERIFY_SWEEP36_RELEASE Recompute the publication from a new source directory.
[root,~,defaultOutput]=sweep36_paths;
if nargin<1 || isempty(outputDirectory), outputDirectory=fullfile(defaultOutput,'release_verification'); end
outputDirectory=sweep36_safe_output(outputDirectory);
assert(~isfolder(outputDirectory),'sweep36:ExistingVerification','Choose a new verification directory.');
files=dir(fullfile(root,'*.m'));
findingCount=0;
for k=1:numel(files)
    findings=checkcode(fullfile(root,files(k).name),'-id');
    findingCount=findingCount+numel(findings);
    if ~isempty(findings), disp(files(k).name); disp(findings); end
end
verify_sweep36_archive;
run=paper_example_revision4(outputDirectory);
assert(strcmp(run.status,'complete'));
folder=fullfile(outputDirectory,'sweep36');
actual=readtable(fullfile(folder,'sweep36_summary.csv'));
expected=readtable(fullfile(root,'archive','sweep36','sweep36_summary.csv'));
names=setdiff(actual.Properties.VariableNames,{'elapsed_wall_s'},'stable');
maximumMetricDifference=0;
for k=1:numel(names)
    difference=max(abs(double(actual.(names{k}))-double(expected.(names{k}))));
    assert(isfinite(difference) && difference<1e-7,'sweep36:ReproductionMismatch', ...
        'Recomputed %s differs from the archive.',names{k});
    maximumMetricDifference=max(maximumMetricDifference,difference);
end
refined=readtable(fullfile(folder,'time_refinement.csv'));
expectedRefined=readtable(fullfile(root,'archive','sweep36','time_refinement.csv'));
assert(max(abs(refined{:,:}-expectedRefined{:,:}),[],'all')<1e-7);
resumed=run_paper_sweep36_v129(folder);
assert(max(abs(double(actual{:,:})-double(resumed{:,:})),[],'all')<1e-7);
% A changed case, changed protocol, and archive output must be rejected.
first=fullfile(folder,'case_01_h400_b00_g0.31.mat');
savedCase=load(first);
bad=savedCase;
bad.result.network.conductanceWK(7,9)=0.50;
save(first,'-struct','bad','-v7.3');
expectError(@() run_paper_sweep36_v129(folder,1),'sweep36:CacheMismatch');
save(first,'-struct','savedCase','-v7.3');
protocolFile=fullfile(folder,'protocol.mat');
savedProtocol=load(protocolFile);
bad=savedProtocol;
bad.protocol.analysisOrbits=5;
save(protocolFile,'-struct','bad');
expectError(@() run_paper_sweep36_v129(folder,1),'sweep36:ProtocolMismatch');
save(protocolFile,'-struct','savedProtocol');
expectError(@() run_paper_sweep36_v129(fullfile(root,'archive')),'sweep36:ArchiveReadOnly');
export_sweep36_open_data(folder,fullfile(outputDirectory,'open_data'));
audit_sweep36_v129(folder,fullfile(outputDirectory,'final_audit.csv'));
record=struct('schema','leotherm.sweep36.verification.v1', ...
    'caseCount',36,'refinementCases',3,'cacheResumePassed',true, ...
    'changedCaseRejected',true,'changedProtocolRejected',true, ...
    'archiveWriteRejected',true,'maximumMetricDifference',maximumMetricDifference, ...
    'codeAnalyzerFindings',findingCount,'matlabRelease',version('-release'), ...
    'architecture',computer,'engineVersion',leotherm.version, ...
    'sourceFingerprint',sweep36_source_fingerprint);
sweep36_write_json(fullfile(outputDirectory,'verification.json'),record);
assert(findingCount==0,'sweep36:CodeAnalyzer','Resolve Code Analyzer findings before release.');
fprintf('SWEEP36_PUBLIC_REPRODUCTION_VERIFIED\n');
end

function expectError(action,identifier)
try
    action();
catch exception
    assert(strcmp(exception.identifier,identifier), ...
        'sweep36:UnexpectedError','Expected %s, received %s.',identifier,exception.identifier);
    return
end
error('sweep36:MissingError','Expected rejection %s.',identifier);
end
