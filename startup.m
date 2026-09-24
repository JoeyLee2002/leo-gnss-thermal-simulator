function startup
%STARTUP Add project source and examples to the MATLAB path.

if isdeployed
    return
end

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
addpath(fullfile(root, 'examples'));
addpath(fullfile(root, 'tests'));
addpath(fullfile(root, 'tools'));
end
