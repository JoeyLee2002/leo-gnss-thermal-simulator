function tests=test_study_data_progress
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.originalPath=path;
addpath(fullfile(leotherm.installRoot,'studies','softwarex','sweep36'));
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testAuditStopsBeforeReadingCase(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
makeFixture(folder);
audit=fullfile(folder,'audit.csv');
verifyError(testCase,@()audit_sweep36_v129(folder,audit, ...
    @(e)strcmp(e.stage,'audit')),'leotherm:OperationCancelled');
verifyFalse(testCase,isfile(audit));
end

function testOpenDataStopsBeforeWritingHistory(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
makeFixture(folder);
output=fullfile(folder,'open_data');
verifyError(testCase,@()export_sweep36_open_data(folder,output, ...
    @(e)strcmp(e.stage,'export_data')),'leotherm:OperationCancelled');
verifyEmpty(testCase,dir(fullfile(output,'case_*.csv')));
end

function testSavedCaseRetainedOnStop(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
verifyError(testCase,@()run_paper_sweep36_v129(folder,2, ...
    @(e)strcmp(e.stage,'case_complete')),'leotherm:OperationCancelled');
t=readtable(fullfile(folder,'sweep36_summary.csv'));
verifyEqual(testCase,height(t),1);
verifyTrue(testCase,isfile(fullfile(folder,'case_01_h400_b00_g0.31.mat')));
verifyFalse(testCase,isfile(fullfile(folder,'sweep36_complete.mat')));
end

function testLegacyProjectBackupUsesEnglishName(testCase)
folder=tempname; mkdir(folder);
cleanup=onCleanup(@() removeFolder(folder));
app=leotherm.ThermalSimulatorApp('off','en');
appCleanup=onCleanup(@() delete(app));
state=app.getState;
originalName=[char([39033 30446]) '.mat'];
original=fullfile(folder,originalName);
leotherm.writeWorkspaceProject(original,state);
leotherm.writeWorkspaceProject(original,state,true);
backup=[leotherm.englishArtifactFilename(originalName,'leotherm_project.mat') '.previous'];
verifyTrue(testCase,isfile(original));
verifyTrue(testCase,isfile(fullfile(folder,backup)));
verifyTrue(testCase,all(double(backup)<=126));
saved=load(fullfile(folder,backup),'-mat','project');
verifyEqual(testCase,saved.project.state.scenario,state.scenario);
end

function makeFixture(folder)
mkdir(folder);
protocol=sweep36_protocol;
save(fullfile(folder,'protocol.mat'),'protocol');
[h,b,g]=ndgrid(protocol.altitudeKm,protocol.betaDeg,protocol.conductanceWK);
t=table((1:36)',h(:),b(:),g(:),'VariableNames', ...
    {'case_id','altitude_km','target_beta_deg','conductance_wk'});
writetable(t,fullfile(folder,'sweep36_summary.csv'));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
