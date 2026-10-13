function tests=test_file_dialog_window
tests=functiontests(localfunctions);
end

function testVisibleWindowLifecycle(testCase)
result=leotherm.checkFileDialogWindow;
verifyEqual(testCase,result.outcome,'passed');
verifyEqual(testCase,{result.windowStates.restoredState},{'normal','maximized'});
end

function testMultiplePickerOutputsAndArguments(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
[file,folder,index]=leotherm.uiFileDialog(parent,@picker,'*.mat','Save project');
verifyEqual(testCase,file,'project.mat');
verifyEqual(testCase,folder,'test_output'); verifyEqual(testCase,index,1);
    function [file,folder,index]=picker(filter,title)
        verifyEqual(testCase,filter,'*.mat'); verifyEqual(testCase,title,'Save project');
        file='project.mat'; folder='test_output'; index=1;
    end
end

function testDeletedOwnerIsNotRecreated(testCase)
parent=uifigure('Visible','off');
answer=leotherm.uiFileDialog(parent,@picker);
verifyEqual(testCase,answer,0); verifyFalse(testCase,isgraphics(parent));
    function answer=picker
        delete(parent); answer=0;
    end
end

function testPreviouslyMinimizedOwnerStaysMinimized(testCase)
parent=uifigure('Visible','off'); cleanup=onCleanup(@() delete(parent));
parent.WindowState='minimized';
leotherm.uiFileDialog(parent,@() 0);
verifyEqual(testCase,char(parent.WindowState),'minimized');
verifyEqual(testCase,char(parent.Visible),'off');
end

function testAllGuiNativePickersUseOwnerWrapper(testCase)
root=leotherm.installRoot;
files={'ThermalSimulatorApp.m','TelemetryPanel.m','CalibrationPanel.m'};
for index=1:numel(files)
    source=fileread(fullfile(root,'src','+leotherm',files{index}));
    verifyEmpty(testCase,regexp(source,'(?<!@)\<(uigetdir|uigetfile|uiputfile)\s*\(','once'));
end
end
