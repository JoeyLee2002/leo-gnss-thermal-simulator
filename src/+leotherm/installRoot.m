function root = installRoot
%INSTALLROOT Locate bundled resources in MATLAB or a compiled application.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
end
