function result=checkFileDialogWindow
%CHECKFILEDIALOGWINDOW Exercise picker cleanup using real app windows.
parent=uifigure('Visible','on','Position',[100 100 800 600]);
cleanup=onCleanup(@() deleteFigure(parent));
states={'normal','maximized'};
rows=struct([]);
for index=1:numel(states)
    parent.WindowState=states{index};
    drawnow;
    selected=leotherm.uiFileDialog(parent,@selectedFolder);
    drawnow;
    assert(strcmp(selected,'test_output'),'Picker result changed.');
    assert(waitForState(parent,states{index},10),'Window state was not restored.');
    assert(strcmp(char(parent.Visible),'on'),'Visible app became hidden.');
    rows(index).initialState=states{index};
    rows(index).restoredState=char(parent.WindowState);
end
cancelled=leotherm.uiFileDialog(parent,@cancelFolder);
assert(isequal(cancelled,0),'Picker cancellation changed.');
assert(waitForState(parent,'maximized',10),'Cancel did not restore window.');
try
    leotherm.uiFileDialog(parent,@failedPicker);
    error('leotherm:FocusCheck','Expected picker failure.');
catch exception
    assert(strcmp(exception.identifier,'leotherm:MockPickerFailure'),'Picker exception changed.');
end
assert(waitForState(parent,'maximized',10),'Error did not restore window.');
parent.Visible='off'; parent.WindowState='normal';
leotherm.uiFileDialog(parent,@selectedFolder);
assert(strcmp(char(parent.Visible),'off'),'Hidden app was displayed.');
result=struct('version',leotherm.version,'outcome','passed', ...
    'windowStates',rows,'cancelRestored',true,'errorRestored',true, ...
    'hiddenPreserved',true,'pickerMode','simulated callback; real uifigure');
clear cleanup

    function folder=selectedFolder
        parent.WindowState='minimized';
        parent.Visible='off';
        folder='test_output';
    end
    function folder=cancelFolder
        parent.WindowState='minimized';
        folder=0;
    end
    function failedPicker
        parent.WindowState='minimized';
        error('leotherm:MockPickerFailure','Simulated chooser failure.');
    end
end

function ok=waitForState(parent,desired,timeoutSeconds)
% The window manager applies a window-state change asynchronously, so the value read back
% immediately after the application restores it may still be the previous state. Only the
% settled state is meaningful. This waits passively: it never touches the state itself, so a
% restore the application never performs still fails the caller's assertion.
ok=false; deadline=tic;
while toc(deadline)<timeoutSeconds
    drawnow;
    if ~isvalid(parent), return; end
    if strcmp(char(parent.WindowState),desired), ok=true; return; end
    pause(0.05);
end
drawnow;
ok=isvalid(parent) && strcmp(char(parent.WindowState),desired);
end

function deleteFigure(parent)
if isgraphics(parent,'figure'), delete(parent); end
end
