function app = launch_gui(language)
%LAUNCH_GUI Start the graphical LEO GNSS Thermal Simulator workbench.

if nargin < 1 || isempty(language)
    language = 'zh';
end

root = fileparts(mfilename('fullpath'));
addpath(root);
startup;
app = leotherm.launchApp(language);
if nargout == 0
    clear app
end
end
