function tests=test_module_run_buttons
tests=functiontests(localfunctions);
end

function testLocalCallbacksIgnoreGlobalStageChoices(testCase)
folder=tempname; cleanup=onCleanup(@() removeFolder(folder));
result=leotherm.checkModuleRunButtons(folder,'off');
verifyTrue(testCase,result.scenarioOnly && result.sweepOnly && result.scenarioRetained);
verifyFalse(testCase,result.automaticReport);
end

function testAllModuleButtonsAreVisibleAndBilingual(testCase)
app=leotherm.ThermalSimulatorApp('off','en'); cleanup=onCleanup(@() delete(app));
tags={'RunScenarioButton','RunSweepButton','RunSurfaceButton','RunVolumeButton', ...
    'CoupledRunButton','RunTelemetryButton','RunCalibrationButton'};
for language={'en','zh'}
    app.setLanguage(language{1});
    app.prepareWorkspace('geometry');
    app.prepareWorkspace('telemetry');
    app.prepareWorkspace('calibration');
    for index=1:numel(tags)
        button=findall(app.Figure,'Tag',tags{index});
        verifyEqual(testCase,numel(button),1);
        verifyEqual(testCase,char(button.Visible),'on');
        if strcmp(language{1},'en')
            verifyFalse(testCase,any(double(button.Text)>=hex2dec('4E00') & double(button.Text)<=hex2dec('9FFF')));
        end
    end
end
end

function testGlobalOptionsRemainInSimulationWorkspace(testCase)
app=leotherm.ThermalSimulatorApp('off'); cleanup=onCleanup(@() delete(app));
option=findobj(app.Figure,'Tag','PipelineSweepCheck');
tab=ancestor(option,'uitab');
verifyEqual(testCase,tab.Title,'Simulation');
button=findobj(app.Figure,'Tag','TaskRunButton');
verifyEqual(testCase,button.Text,'Run complete task and generate report');
verifyFalse(testCase,isequal(button.ButtonPushedFcn,findobj(app.Figure,'Tag','RunScenarioButton').ButtonPushedFcn));
end

function testSweepButtonIsOutsideScrollableInputs(testCase)
app=leotherm.ThermalSimulatorApp('off'); cleanup=onCleanup(@() delete(app));
button=findobj(app.Figure,'Tag','RunSweepButton');
verifyEqual(testCase,button.Layout.Row,2);
verifyEqual(testCase,char(button.Parent.Scrollable),'off');
end

function removeFolder(path)
if isfolder(path), rmdir(path,'s'); end
end
