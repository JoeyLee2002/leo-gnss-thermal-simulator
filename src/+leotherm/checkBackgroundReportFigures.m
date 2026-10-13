function result=checkBackgroundReportFigures(outputDirectory)
%CHECKBACKGROUNDREPORTFIGURES Verify export figures never appear onscreen.
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('leotherm:FigureCheck','Use a new output directory.');
end
mkdir(outputDirectory);
owner=uifigure('Visible','on','WindowState','maximized','Tag','LEOThermMainWindow');
ownerCleanup=onCleanup(@() delete(owner));
drawnow; owner.WindowState='maximized';
assert(waitForMaximized(owner,10),'Owner did not initialize maximized.');
oldCreate=get(groot,'DefaultFigureCreateFcn');
oldVisible=get(groot,'DefaultFigureVisible');
defaultsCleanup=onCleanup(@() restoreDefaults(oldCreate,oldVisible));
owner.UserData=struct('tags',{{}},'visibility',{{}});
set(groot,'DefaultFigureCreateFcn',@(fig,~) recordCreation(owner,fig),'DefaultFigureVisible','on');
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=60;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
leotherm.plotScenario(r,fullfile(outputDirectory,'scenario.png'),'en');
summary=table([500;500],[0;30],[0.3;0.2],[12;11],[2000;1900],[2;1], ...
    repmat({'complete'},2,1),'VariableNames',{'altitude_km','actual_beta_deg', ...
    'eclipse_fraction','response_temperature_span_k','forcing_to_rf_lag_s', ...
    'code_bias_span_m','status'});
leotherm.plotSweep(summary,fullfile(outputDirectory,'sweep.png'),'en');
drawnow;
createdTags=owner.UserData.tags; createdVisibility=owner.UserData.visibility;
assert(isequal(createdTags,{'ScenarioExportFigure','SweepExportFigure'}),'Unexpected export figures.');
assert(all(strcmp(createdVisibility,'off')),'Report export created a visible window.');
assert(isempty(findall(groot,'Tag','ScenarioExportFigure')),'Scenario figure leaked.');
assert(isempty(findall(groot,'Tag','SweepExportFigure')),'Sweep figure leaked.');
assert(strcmp(char(owner.WindowState),'maximized'),'App window state changed to %s.',char(owner.WindowState));
result=struct('version',leotherm.version,'outcome','passed','figureTags',{createdTags}, ...
    'visibilityAtCreation',{createdVisibility},'ownerState',char(owner.WindowState));
clear defaultsCleanup ownerCleanup
end

function ok=waitForMaximized(owner,timeoutSeconds)
% Window managers apply a requested window state asynchronously, so the value read back
% immediately after the request may still be the previous state. Only the settled state is
% meaningful. This waits passively: it never re-requests the state, so a request that the
% window manager never honours still fails the caller's assertion.
ok=false; deadline=tic;
while toc(deadline)<timeoutSeconds
    drawnow;
    if ~isvalid(owner), return; end
    if strcmp(char(owner.WindowState),'maximized'), ok=true; return; end
    pause(0.05);
end
drawnow;
ok=isvalid(owner) && strcmp(char(owner.WindowState),'maximized');
end

function recordCreation(owner,fig)
data=owner.UserData;
data.tags{end+1}=fig.Tag;
data.visibility{end+1}=char(fig.Visible);
owner.UserData=data;
end

function restoreDefaults(create,visible)
set(groot,'DefaultFigureCreateFcn',create,'DefaultFigureVisible',visible);
end
