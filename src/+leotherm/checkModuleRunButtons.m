function result=checkModuleRunButtons(directory,visibility)
%CHECKMODULERUNBUTTONS Exercise local UI callbacks with all global stages on.
if nargin<2, visibility='on'; end
if isfolder(directory) || isfile(directory)
    error('leotherm:ModuleSmoke','Use a new output directory.');
end
mkdir(directory);
app=leotherm.ThermalSimulatorApp(visibility,'en');
cleanup=onCleanup(@() deleteApp(app));
state=app.getState;
state.scenario.durationS=120; state.scenario.timeStepS=60;
state.scenario.warmupOrbits=0; state.scenario.convergence.enabled=false;
state.scanSettings.altitudes='500'; state.scanSettings.betas='0';
state.pipelineOptions=struct('sweep',true,'geometry',true,'telemetry',true,'calibration',true);
project=fullfile(directory,'module_fixture.mat');
leotherm.writeWorkspaceProject(project,state,false);
app.loadProject(project);
simulation=findall(app.Figure,'Type','uitab','Title','Simulation');
simulation.Parent.SelectedTab=simulation;
scenario=findall(app.Figure,'Type','uitab','Title','Single scenario');
scenario.Parent.SelectedTab=scenario;
globalRun=findobj(app.Figure,'Tag','TaskRunButton');
assert(strcmp(char(globalRun.Enable),'off'),'Incomplete global task should be blocked.');
button=findobj(app.Figure,'Tag','RunScenarioButton');
assert(strcmp(char(button.Visible),'on') && strcmp(char(button.Enable),'on'),'Local scenario button unavailable.');
callback=button.ButtonPushedFcn; callback(button,[]);
afterScenario=app.getState;
assert(~isempty(afterScenario.result),'Local scenario did not run.');
assert(isempty(afterScenario.sweep) && isempty(afterScenario.lastPipelineRun),'Local scenario started other stages.');
assert(isequal(afterScenario.pipelineOptions,state.pipelineOptions),'Local run changed global choices.');
assert(numel(afterScenario.taskHistory)==1 && strcmp(afterScenario.taskHistory.runType,'scenario'),'Unexpected scenario history.');
assert(scenario.Parent.SelectedTab==scenario,'Local scenario changed the selected page.');
button=findobj(app.Figure,'Tag','RunSweepButton');
sweep=findall(app.Figure,'Type','uitab','Title','Parameter sweep'); sweep.Parent.SelectedTab=sweep;
callback=button.ButtonPushedFcn; callback(button,[]);
afterSweep=app.getState;
assert(height(afterSweep.sweep)==1 && strcmp(afterSweep.sweep.status{1},'complete'),'Local sweep did not produce one configured case.');
assert(isequal(afterScenario.result.temperatureK,afterSweep.result.temperatureK),'Sweep overwrote the single-scenario result.');
assert(isempty(afterSweep.lastPipelineRun),'Local sweep started a complete task.');
assert(numel(afterSweep.taskHistory)==2 && strcmp(afterSweep.taskHistory(2).runType,'sweep'),'Unexpected sweep history.');
assert(sweep.Parent.SelectedTab==sweep,'Local sweep changed the selected page.');
assert(isempty(dir(fullfile(directory,'**','*.pdf'))),'Local callbacks automatically generated a report.');
result=struct('version',leotherm.version,'outcome','passed', ...
    'scenarioOnly',true,'sweepOnly',true,'scenarioRetained',true, ...
    'globalChoicesRetained',true,'automaticReport',false, ...
    'globalRunLabel',globalRun.Text,'localHistory',{{afterSweep.taskHistory.runType}});
fid=fopen(fullfile(directory,'module_buttons_smoke.json'),'w','n','UTF-8');
assert(fid>=0,'Cannot write module result.');
fileCleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(result,'PrettyPrint',true));
clear fileCleanup cleanup
end

function deleteApp(app)
if isvalid(app), delete(app); end
end
