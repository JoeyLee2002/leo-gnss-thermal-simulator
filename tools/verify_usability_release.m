function diagnostics = verify_usability_release(directory)
%VERIFY_USABILITY_RELEASE Exercise real GUI state, portable saves and stale exports.
assert(~isfolder(directory) && ~isfile(directory),'Use a new verification directory.');
mkdir(directory); directory=char(java.io.File(directory).getCanonicalPath());
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
app=leotherm.ThermalSimulatorApp('off','zh'); cleanup=onCleanup(@()delete(app));
assert(~app.hasUnsavedChanges,'A new project is unexpectedly dirty.');
mainResult=findall(app.Figure,'Type','uitab','Title','结果与导出');
assert(numel(mainResult)==1 && numel(mainResult.Parent.Children)==3, ...
    'The GUI must expose Quick start, Simulation, and Results as the three main areas.');
assert(numel(findall(app.Figure,'Tag','TaskRunButton'))==1 && ...
    numel(findall(app.Figure,'Tag','TaskSummaryLabel'))==1, ...
    'The simulation task workspace is missing its primary controls.');
s=leotherm.defaultScenario; n=leotherm.defaultReceiverNetwork;
s.startEpoch=datetime(2024,1,1,3,4,5.125,'TimeZone','UTC');
s.durationS=120; s.timeStepS=20; s.convergence.enabled=false; s.warmupOrbits=0;
original=app.runScenario(s,n);
for language={'en','zh'}
    app.setLanguage(language{1}); current=app.getState;
    assert(current.scenario.startEpoch==s.startEpoch,'Language switch changed UTC epoch.');
    assert(~current.resultStale,'Language switch invalidated the scientific result.');
end
editCapacity(app,1.1);
current=app.getState;
assert(current.resultStale && isequaln(current.result,original),'Edits did not preserve and flag old results.');
assert(app.hasUnsavedChanges,'Changes were not detected before closing.');
app.exportResults(fullfile(directory,'stale_result_export'));
exported=load(fullfile(directory,'stale_result_export','scenario_configuration.mat'));
assert(isequaln(exported.network,n),'An old result was exported with the new network.');
metadata=load(fullfile(directory,'stale_result_export','export_metadata.mat'));
assert(metadata.metadata.scenarioStale,'The old exported result was not labeled stale.');
[raw,~,options]=leotherm.telemetryDemo(n);
csv=fullfile(directory,'source.csv'); writetable(raw,csv);
app.TelemetryWorkspace.importSource(csv);
app.TelemetryWorkspace.setWorkflow('validation');
expectError(@()app.TelemetryWorkspace.run(options),'leotherm:StaleResult');
app.runScenario(s,n);
app.TelemetryWorkspace.setWorkflow('orbit');
app.TelemetryWorkspace.run(options);
audit=app.TelemetryWorkspace.preflight;
assert(audit.ready && audit.measuredNodes>0,'Valid data failed preflight.');
app.CalibrationWorkspace.loadCurrentDevice;
app.CalibrationWorkspace.loadTelemetryDays;
cal=app.CalibrationWorkspace.getState;
cal.settings.minimumCoverageS=900; cal.split.role(:)="train";
cal.profile.parameters.evidence(1)="Project roundtrip test only";
app.CalibrationWorkspace.restoreState(cal);
app.runSweep('beta_altitude',s,n,600,[0 20],1);
saved=app.getState;
assert(saved.task.schemaVersion==1 && ~isempty(saved.lastTaskSnapshot) && ...
    numel(saved.lastTaskSnapshot.inputFingerprint)==64, ...
    'The workspace did not retain a frozen task snapshot.');
projectPath=fullfile(directory,'workspace.mat');
app.saveProject(projectPath);
assert(~app.hasUnsavedChanges,'Saving did not clear the unsaved state.');
expectError(@()app.saveProject(projectPath),'leotherm:ProjectExists');
changed=saved;
changed.telemetry.data.rawTable(1,:)=[];
changedPath=fullfile(directory,'changed_source.mat');
leotherm.writeWorkspaceProject(changedPath,changed,false);
changedState=leotherm.readWorkspaceProject(changedPath);
assert(changedState.telemetry.resultStale && ~istable(changedState.telemetry.resultInputs.source), ...
    'A mismatching source was incorrectly assigned the old result fingerprint.');
movefile(csv,[csv '.moved']);
restored=leotherm.ThermalSimulatorApp('off','en'); otherCleanup=onCleanup(@()delete(restored));
restored.loadProject(projectPath);
state=restored.getState;
assert(istable(state.telemetry.source),'Telemetry was not embedded in the project.');
assert(isequaln(state.telemetry.result,saved.telemetry.result),'Telemetry result changed across project save/load.');
assert(isequaln(state.result,saved.result) && isequaln(state.sweep,saved.sweep),'Results were not fully restored.');
assert(isequaln(state.lastTaskSnapshot.inputFingerprint,saved.lastTaskSnapshot.inputFingerprint), ...
    'The frozen task fingerprint changed across project save/load.');
assert(isequaln(state.scanSettings,saved.scanSettings),'Scan settings were not restored.');
assert(state.calibration.settings.minimumCoverageS==900 && all(state.calibration.split.role=="train"),'Calibration settings were lost.');
assert(~state.calibration.splitStale && ~state.telemetry.resultStale,'Embedding unchanged data made it stale.');
assert(~restored.hasUnsavedChanges,'A restored project was marked dirty.');
restored.saveProject(projectPath,true);
assert(isfile([projectPath '.previous']),'The previous project was not preserved.');
before=restored.getState;
project=struct('schemaVersion',999); bad=fullfile(directory,'unsupported.mat'); save(bad,'project');
expectError(@()restored.loadProject(bad),'leotherm:ProjectFormat');
assert(isequaln(before,restored.getState),'A rejected project changed the workspace.');
for language={'zh','en'}
    restored.setLanguage(language{1});
    restored.Figure.Visible='on'; restored.Figure.Position=[80 60 1120 780];
    tabs=restored.TelemetryWorkspace.Tab.Parent.Children;
    index=find(strcmp({tabs.Title},pick(language{1},'单场景','Single scenario')),1);
    tabs(index).Parent.SelectedTab=tabs(index); drawnow;
    button=findall(restored.Figure,'Text',pick(language{1},'运行单场景','Run scenario'));
    assert(numel(button)==1 && strcmp(button.Parent.Scrollable,'off'), ...
        'The Run action is inside a scrolling region.');
    buttonBounds=getpixelposition(button,true);
    assert(buttonBounds(2)>30 && buttonBounds(2)+buttonBounds(4)<restored.Figure.Position(4), ...
        'The Run action is outside the visible window.');
    exportapp(restored.Figure,fullfile(directory,['scenario_' language{1} '.png']));
    restored.CalibrationWorkspace.Tab.Parent.SelectedTab=restored.CalibrationWorkspace.Tab;
    coverage=findall(restored.Figure,'Tag','MinimumCoverage'); tab=coverage.Parent.Parent;
    tab.Parent.SelectedTab=tab; drawnow;
    exportapp(restored.Figure,fullfile(directory,['project_' language{1} '.png']));
end
editCapacity(restored,1.01);
state=restored.getState;
assert(state.resultStale && state.sweepStale && state.telemetry.resultStale,'Cross-workflow invalidation failed.');
diagnostics=struct('version',leotherm.version,'passed',true,'exactUtcPreserved',true, ...
    'staleResultProtected',true,'exportBoundToOriginalInputs',true,'sourceMovedProjectRestored',true, ...
    'previousSavePreserved',true,'invalidProjectNoMutation',true,'crossWorkflowInvalidation',true);
save(fullfile(directory,'verification.mat'),'diagnostics','saved','state');
disp(diagnostics);
clear otherCleanup cleanup
end

function editCapacity(app,factor)
tables=findall(app.Figure,'Type','uitable');
for k=1:numel(tables)
    d=tables(k).Data;
    if istable(d) && ismember('capacity',d.Properties.VariableNames)
        d.capacity(1)=d.capacity(1)*factor; tables(k).Data=d;
        tables(k).CellEditCallback(tables(k),[]); return
    end
end
error('Node table was not found.');
end

function expectError(action,id)
try
    action();
catch exception
    assert(strcmp(exception.identifier,id),'Unexpected error: %s',exception.identifier); return
end
error('Expected error was not raised: %s',id);
end

function text=pick(language,zh,en)
text=en; if strcmp(language,'zh'), text=zh; end
end
