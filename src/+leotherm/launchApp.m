function app = launchApp(language)
%LAUNCHAPP Open the interactive LEO GNSS Thermal Simulator workbench.

if nargin < 1 || isempty(language)
    language = 'zh';
end

if ~usejava('jvm')
    error('leotherm:DesktopRequired', ...
        'The graphical workbench requires MATLAB with the Java desktop runtime.');
end
app = leotherm.ThermalSimulatorApp('on', language);
if nargout == 0
    clear app
end
end
