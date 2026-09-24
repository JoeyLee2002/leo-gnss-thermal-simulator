function artifact = build_standalone
%BUILD_STANDALONE Compile the Windows desktop app for MATLAB Runtime users.
if ~ispc
    error('leotherm:StandaloneBuild', 'This release build targets Windows.');
end
if isempty(which('mcc')) || ~license('test', 'Compiler')
    error('leotherm:StandaloneBuild', 'MATLAB Compiler is required to build the app.');
end
root = fileparts(fileparts(mfilename('fullpath')));
versionTag = strtrim(fileread(fullfile(root, 'VERSION')));
addpath(fullfile(root, 'src'));
projects = dir(fullfile(root, 'examples', 'projects', '*.mat'));
if isempty(projects)
    error('leotherm:StandaloneBuild', 'Example projects are missing.');
end
for k = 1:numel(projects)
    project = leotherm.readWorkspaceProject(fullfile(projects(k).folder, projects(k).name));
    if ~strcmp(project.version, versionTag)
        error('leotherm:StandaloneBuild', ...
            'Example project %s is not version %s.', projects(k).name, versionTag);
    end
end
output = fullfile(root, 'results', ['standalone_v' strrep(versionTag, '.', '_')]);
if isfolder(output) && ~isempty(dir(fullfile(output, 'LEOTherm.exe')))
    error('leotherm:StandaloneBuild', 'Build already exists: %s', output);
end
if ~isfolder(output), mkdir(output); end
entry = fullfile(root, 'standalone_main.m');
mcc('-e', entry, '-o', 'LEOTherm', '-d', output, ...
    '-I', fullfile(root, 'src'), ...
    '-a', fullfile(root, 'src'), ...
    '-a', fullfile(root, 'VERSION'), ...
    '-a', fullfile(root, 'templates'), ...
    '-a', fullfile(root, 'examples'));
executable = fullfile(output, 'LEOTherm.exe');
if ~isfile(executable)
    error('leotherm:StandaloneBuild', 'Compiler did not produce LEOTherm.exe.');
end
artifact = struct('version', versionTag, 'executable', executable, ...
    'runtimeRelease', version('-release'), 'buildDirectory', output);
save(fullfile(output, 'build_metadata.mat'), 'artifact');
fprintf('STANDALONE_EXE=%s\n', executable);
end
