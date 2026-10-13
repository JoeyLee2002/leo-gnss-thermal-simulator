function tests = test_gui_startup
tests = functiontests(localfunctions);
end

function testDeferredPagesPreserveState(testCase)
directory = tempname;
cleanup = onCleanup(@() removeFolder(directory));
record = leotherm.checkGuiStartup(directory,'off');
verifyEqual(testCase,record.outcome,'passed');
verifyEqual(testCase,record.initialAxes,0);
verifyEqual(testCase,numel(record.pages),6);
end

function testPageNavigationBuildsOnlySelectedPage(testCase)
app = leotherm.ThermalSimulatorApp('off');
cleanup = onCleanup(@() delete(app));
tab = findobj(app.Figure,'Type','uitab','Title','3-D geometry');
tab.Parent.SelectedTab = tab;
callback = tab.Parent.SelectionChangedFcn;
callback(tab.Parent,[]);
verifyNotEmpty(testCase,findobj(app.Figure,'Tag','RunSurfaceButton'));
verifyEmpty(testCase,findobj(app.Figure,'Tag','RunTelemetryButton'));
verifyFalse(testCase,app.CalibrationWorkspace.UIReady);
end

function testLanguageRebuildPreservesLazyState(testCase)
app = leotherm.ThermalSimulatorApp('off');
cleanup = onCleanup(@() delete(app));
before = app.getState;
app.setLanguage('zh');
verifyFalse(testCase,app.TelemetryWorkspace.UIReady);
verifyFalse(testCase,app.CalibrationWorkspace.UIReady);
verifyEmpty(testCase,findall(app.Figure,'Type','axes'));
after = app.getState;
verifyEqual(testCase,after.scenario,before.scenario);
verifyEqual(testCase,after.calibration,before.calibration);
app.prepareWorkspace('telemetry');
verifyTrue(testCase,app.TelemetryWorkspace.UIReady);
verifyEmpty(testCase,findobj(app.Figure,'Tag','RunSurfaceButton'));
end

function testLoadedGeometryProjectStaysLazyAndPreservesState(testCase)
app = leotherm.ThermalSimulatorApp('off');
cleanup = onCleanup(@() delete(app));
app.loadProject(fullfile(leotherm.installRoot,'examples','projects','05_3d_geometry.mat'));
before = app.getState;
verifyNotEmpty(testCase,before.geometry);
verifyEmpty(testCase,findobj(app.Figure,'Tag','RunSurfaceButton'));
app.prepareWorkspace('geometry');
after = app.getState;
verifyTrue(testCase,isequaln(before,after));
verifyFalse(testCase,app.hasUnsavedChanges);
end

function testSaveProjectWithoutOpeningAdvancedPages(testCase)
app = leotherm.ThermalSimulatorApp('off');
cleanup = onCleanup(@() delete(app));
directory = tempname;
mkdir(directory);
folderCleanup = onCleanup(@() removeFolder(directory));
before = app.getState;
file = fullfile(directory,'startup_project.mat');
app.saveProject(file);
project = leotherm.readWorkspaceProject(file);
verifyTrue(testCase,isequaln(project,before));
verifyFalse(testCase,app.TelemetryWorkspace.UIReady);
verifyFalse(testCase,app.CalibrationWorkspace.UIReady);
end

function testFirstChartsPreserveOwnerState(testCase)
app = leotherm.ThermalSimulatorApp('on');
cleanup = onCleanup(@() delete(app));
drawnow;
image = [tempname '.png'];
imageCleanup = onCleanup(@() delete(image));
exportapp(app.Figure,image);
figure(app.Figure);
app.Figure.WindowState = 'maximized';
pause(0.5);
drawnow;
initial = char(app.Figure.WindowState);
verifyNotEqual(testCase,initial,'minimized');
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
app.runScenario(scenario,leotherm.defaultReceiverNetwork);
drawnow;
verifyEqual(testCase,char(app.Figure.WindowState),initial);
app.prepareWorkspace('geometry');
verifyEqual(testCase,char(app.Figure.WindowState),initial);
end

function removeFolder(directory)
if isfolder(directory), rmdir(directory,'s'); end
end
