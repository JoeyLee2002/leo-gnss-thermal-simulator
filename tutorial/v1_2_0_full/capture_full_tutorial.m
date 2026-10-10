function capture_full_tutorial(output)
% Reproducible captures of the production GUI and real solver outputs.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src'));
assert(~isfolder(output), 'Use a fresh capture directory.');
mkdir(output); mkdir(fullfile(output,'frames'));
app = leotherm.ThermalSimulatorApp('on','zh');
cleanup = onCleanup(@() delete(app));
app.Figure.Position = [40 40 1500 900];
app.Figure.Name = 'LEOTherm Tutorial 1.2.0';
cap('01_start','快速开始','');
fprintf('READY_FOR_WIZARD\n');
fid=fopen(fullfile(output,'ready.txt'),'w'); fprintf(fid,'ready'); fclose(fid);
while ~isfile(fullfile(output,'continue.txt')), pause(0.5); drawnow; end
app.loadProject(fullfile(root,'examples','projects','01_first_simulation.mat'));
app.Figure.Position=[40 40 1500 900];
cap('02_scenario','仿真','单场景');
cap('03_network','仿真','热网络');
toggle('PipelineTelemetryCheck',true);
cap('04_preflight','仿真','单场景');
toggle('PipelineTelemetryCheck',false);
cap('05_ready','仿真','单场景');
base=app.runPipeline(fullfile(output,'base_run'));
assert(strcmp(base.status,'complete') && base.acceptance.passed);
cap('06_base_results','结果与导出','');
cap('07_base_charts','仿真','单场景');
app.saveProject(fullfile(output,'base_project.mat'),false);
app.setLanguage('en');
cap('08_english','Simulation','Single scenario');
app.setLanguage('zh');
state=app.getState;
state.scenario.name='tutorial_six_case_sweep';
state.scenario.warmupOrbits=0;
state.pipelineOptions.sweep=true;
state.scanSettings.mode='beta_altitude';
state.scanSettings.altitudes='500,600';
state.scanSettings.betas='0,15,30';
state.scanSettings.branch=1;
restore(state,'scan_project');
cap('09_sweep_setup','仿真','参数扫描');
sweep=app.runPipeline(fullfile(output,'sweep_run'));
assert(strcmp(sweep.status,'complete') && height(sweep.sweep)==6);
cap('10_sweep_result','仿真','参数扫描');
state=app.getState;
state.scanSettings.mode='physical';
state.scanSettings.dates='2024-03-20,2024-06-21';
state.scanSettings.altitudes='600'; state.scanSettings.inclinations='45,97.6';
state.scanSettings.raans='0,90';
restore(state,'physical_scan_setup');
cap('11_physical_scan','仿真','参数扫描');
app.loadProject(fullfile(output,'base_project.mat'));
app.loadThermalModel(fullfile(root,'examples','projects','06_engineering_model_exchange.json'));
cap('12_exchange','仿真','工程热模型');
app.loadProject(fullfile(root,'examples','projects','06_surface_volume_coupled.mat'));
state=app.getState;
state.scenario.durationS=600; state.scenario.timeStepS=30;
state.scenario.warmupOrbits=0; state.scenario.convergence.enabled=false;
state.pipelineOptions=struct('sweep',false,'geometry',true,'telemetry',false,'calibration',false);
restore(state,'geometry_project');
cap('13_geometry','仿真','三维几何');
geometry=app.runPipeline(fullfile(output,'geometry_run'));
assert(strcmp(geometry.status,'complete'));
cap('14_geometry_result','仿真','三维几何');
axesList=findall(app.Figure,'Type','axes');
visibleAxes=[];
for k=1:numel(axesList)
    if ~isempty(findall(axesList(k),'Type','patch')), visibleAxes=axesList(k); break; end
end
if ~isempty(visibleAxes)
    mkdir(fullfile(output,'rotation'));
    for k=1:36
        view(visibleAxes,35+10*k,25); drawnow;
        exportapp(app.Figure,fullfile(output,'rotation',sprintf('%03d.png',k)));
    end
end
app.saveProject(fullfile(output,'geometry_completed.mat'),false);
app.loadProject(fullfile(root,'examples','projects','04_telemetry_validation.mat'));
cap('15_telemetry_inputs','仿真','遥测与验证');
telemetry=app.runPipeline(fullfile(output,'telemetry_run'));
assert(strcmp(telemetry.status,'complete'));
cap('16_telemetry_results','仿真','遥测与验证');
app.saveProject(fullfile(output,'telemetry_completed.mat'),false);
f=leotherm.deviceCalibrationDemo(3);
f.network.roles=struct('response',1,'antenna',[],'oscillator',[]);
f.profile.referenceNetwork=f.network;
scenario=f.scenario; scenario.durationS=600; scenario.timeStepS=10;
app.runScenario(scenario,f.network);
app.TelemetryWorkspace.importSource(f.raw);
app.TelemetryWorkspace.setWorkflow('heat');
app.TelemetryWorkspace.run(f.settings.telemetryOptions);
cap('17_heat_driver','仿真','遥测与验证');
calibration=app.CalibrationWorkspace.run(f.profile,f.split,f.settings,fullfile(output,'calibration_fit'));
assert(calibration.fit.converged && ~calibration.passed);
cap('18_calibration','仿真','设备标定');
tab=findall(app.Figure,'Type','uitab','Title','冻结运行：参数变化');
tab.Parent.SelectedTab=tab;
cap('19_calibration_result','仿真','设备标定');
app.saveProject(fullfile(output,'calibration_completed.mat'),false);
leotherm.plotDeviceCalibration(calibration,fullfile(output,'frames','calibration_chart.png'),'zh');
app.loadProject(fullfile(output,'base_project.mat'));
control=findobj(app.Figure,'Tag','ScenarioStartTime');
control.Value='12:01:00'; control.ValueChangedFcn(control,[]);
cap('20_stale','结果与导出','');
app.loadProject(fullfile(output,'base_project.mat'));
cap('21_restored','结果与导出','');
% Unified runs already exported their reports and audit data into each run.
save(fullfile(output,'capture_manifest.mat'),'base','sweep','geometry','telemetry','calibration','-v7.3');
fprintf('FULL_TUTORIAL_CAPTURE_COMPLETE\n');
clear cleanup

    function restore(state,name)
        path=fullfile(output,[name '.mat']);
        leotherm.writeWorkspaceProject(path,state,false); app.loadProject(path);
    end
    function toggle(tag,value)
        c=findobj(app.Figure,'Tag',tag); c.Value=value; c.ValueChangedFcn(c,[]); drawnow;
    end
    function cap(name,mainTitle,detailTitle)
        tab=findall(app.Figure,'Type','uitab','Title',mainTitle);
        assert(isscalar(tab),'Missing tab: %s',mainTitle); tab.Parent.SelectedTab=tab;
        if ~isempty(detailTitle)
            tab=findall(app.Figure,'Type','uitab','Title',detailTitle);
            assert(isscalar(tab),'Missing tab: %s',detailTitle); tab.Parent.SelectedTab=tab;
        end
        drawnow; pause(0.25); drawnow;
        exportapp(app.Figure,fullfile(output,'frames',[name '.png']));
        fprintf('CAPTURE=%s\n',name);
    end
end
