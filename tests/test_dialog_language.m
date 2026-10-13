function tests=test_dialog_language
tests=functiontests(localfunctions);
end

function testEnglishStopButtonNeverUsesRuntimeTranslation(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
d=leotherm.OperationProgressDialog(parent,'en','Title','Paper study progress', ...
    'Message','Computing case 1 of 36.','Cancelable','on','Indeterminate','on');
dialogCleanup=onCleanup(@() delete(d));
button=findobj(parent,'Tag','OperationStopButton');
verifyEqual(testCase,button.Text,'Stop computation');
callback=button.ButtonPushedFcn; callback(button,[]);
state=d.getDisplayState;
verifyTrue(testCase,state.cancelRequested);
verifyEqual(testCase,state.buttonText,'Stopping...');
verifyEqual(testCase,state.buttonEnabled,'off');
verifyFalse(testCase,hasChinese([state.title state.message state.buttonText]));
d.Message='Another engine progress event.';
verifyEqual(testCase,d.Message,'Stopping and recording task status...');
end

function testChineseStopTextIsPreserved(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
d=leotherm.OperationProgressDialog(parent,'zh','Title','计算进度','Cancelable','on');
dialogCleanup=onCleanup(@() delete(d));
verifyEqual(testCase,d.CancelText,'停止计算');
d.CancelRequested=true; state=d.getDisplayState;
verifyEqual(testCase,state.buttonText,'正在停止...');
verifyEqual(testCase,state.message,'正在停止并保存任务状态...');
end

function testClosingParentDisposesProgressTimer(testCase)
parent=uifigure('Visible','off');
d=leotherm.OperationProgressDialog(parent,'en');
delete(parent);
verifyFalse(testCase,isvalid(d));
end

function testEnglishInputDialogAcceptsValues(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
clock=timer('ExecutionMode','fixedSpacing','Period',0.2,'StartDelay',0.4, ...
    'TimerFcn',@acceptTaskValues);
timerCleanup=onCleanup(@() deleteClock(clock)); start(clock);
answer=leotherm.uiInputDialog(parent,'en',{'Task name','Duration (s)'}, ...
    'Task wizard',[1 60],{'demo','7200'});
verifyEqual(testCase,answer,{'custom_task';'7200'});
verifyEmpty(testCase,findall(groot,'Tag','LocalizedInputDialog'));
    function acceptTaskValues(~,~)
        button=findall(groot,'Tag','InputAcceptButton');
        if isempty(button), return; end
        fig=button.Parent;
        if strcmp(char(fig.Visible),'off'), return; end
        cancel=findall(fig,'Tag','InputCancelButton');
        if isempty(cancel), return; end
        verifyEqual(testCase,button.String,'OK');
        verifyEqual(testCase,cancel.String,'Cancel');
        field=findall(fig,'Tag','InputValue_1'); field.String='custom_task';
        stop(clock); callback=button.Callback; callback(button,[]);
    end
end

function testChineseInputDialogCancelReturnsNoValues(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
clock=timer('ExecutionMode','fixedSpacing','Period',0.2,'StartDelay',0.4, ...
    'TimerFcn',@cancelTaskValues);
timerCleanup=onCleanup(@() deleteClock(clock)); start(clock);
answer=leotherm.uiInputDialog(parent,'zh',{'任务名称'},'任务向导',[1 60],{'demo'});
verifyEmpty(testCase,answer);
verifyEmpty(testCase,findall(groot,'Tag','LocalizedInputDialog'));
    function cancelTaskValues(~,~)
        button=findall(groot,'Tag','InputCancelButton');
        if isempty(button), return; end
        fig=button.Parent;
        if strcmp(char(fig.Visible),'off'), return; end
        verifyEqual(testCase,double(button.String),[21462 28040]);
        stop(clock); callback=button.Callback; callback(button,[]);
    end
end

function testEnglishLanguageChoicesUseEnglishNames(testCase)
app=leotherm.ThermalSimulatorApp('off','en'); cleanup=onCleanup(@() delete(app));
controls=findall(app.Figure,'Type','uidropdown'); found=false;
for k=1:numel(controls)
    if isequal(controls(k).ItemsData,{'zh','en'})
        verifyEqual(testCase,controls(k).Items,{'Chinese','English'}); found=true;
    end
end
verifyTrue(testCase,found);
end

function yes=hasChinese(text)
yes=any(double(text)>=hex2dec('4E00') & double(text)<=hex2dec('9FFF'));
end
function deleteClock(clock)
if isvalid(clock), stop(clock); delete(clock); end
end
