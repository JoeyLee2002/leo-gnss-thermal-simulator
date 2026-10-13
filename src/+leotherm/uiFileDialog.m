function varargout=uiFileDialog(parent,picker,varargin)
%UIFILEDIALOG Restore the owning app after an unparented native chooser.
if ~isgraphics(parent,'figure') || ~isa(picker,'function_handle')
    error('leotherm:FileDialog','A valid app figure and picker callback are required.');
end
visible=char(parent.Visible);
windowState=char(parent.WindowState);
cleanup=onCleanup(@() restoreWindow(parent,visible,windowState));
[varargout{1:nargout}]=picker(varargin{:});
clear cleanup

end

function restoreWindow(parent,visible,windowState)
if ~isgraphics(parent,'figure'), return; end
parent.WindowState=windowState;
parent.Visible=visible;
if strcmp(visible,'on') && ~strcmp(windowState,'minimized')
    % Native pickers have no uifigure owner in R2021b.
    figure(parent);
    parent.WindowState=windowState;
end
end
