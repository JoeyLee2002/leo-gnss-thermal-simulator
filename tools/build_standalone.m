function artifact = build_standalone(buildSuffix)
%BUILD_STANDALONE Compile the Windows desktop app for MATLAB Runtime users.
if ~ispc
    error('leotherm:StandaloneBuild', 'This release build targets Windows.');
end
if isempty(which('mcc')) || ~license('test', 'Compiler')
    error('leotherm:StandaloneBuild', 'MATLAB Compiler is required to build the app.');
end
root = fileparts(fileparts(mfilename('fullpath')));
if nargin<1, buildSuffix=''; end
buildSuffix=char(string(buildSuffix));
if ~isempty(buildSuffix) && isempty(regexp(buildSuffix,'^[A-Za-z0-9_]+$','once'))
    error('leotherm:StandaloneBuild','Build suffix must contain ASCII letters, digits or underscores.');
end
if ~isempty(buildSuffix), buildSuffix=['_' buildSuffix]; end
versionTag = strtrim(fileread(fullfile(root, 'VERSION')));
addpath(fullfile(root, 'src'));
resources = standalone_resources(root);
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
output = fullfile(root, 'results', ['standalone_v' strrep(versionTag, '.', '_') buildSuffix]);
if isfolder(output) && ~isempty(dir(fullfile(output, 'LEOTherm.exe')))
    error('leotherm:StandaloneBuild', 'Build already exists: %s', output);
end
if ~isfolder(output), mkdir(output); end
entry = fullfile(root, 'standalone_main.m');
% Absolute file paths retain the repository layout in the Runtime archive.
resourceArguments = [repmat({'-a'}, 1, numel(resources)); resources(:).'];
mcc('-e', entry, '-o', 'LEOTherm', '-d', output, ...
    '-I', fullfile(root, 'src'), resourceArguments{:});
executable = fullfile(output, 'LEOTherm.exe');
if ~isfile(executable)
    error('leotherm:StandaloneBuild', 'Compiler did not produce LEOTherm.exe.');
end
artifact = struct('version', versionTag, 'executable', executable, ...
    'runtimeRelease', version('-release'), 'buildDirectory', output);
save(fullfile(output, 'build_metadata.mat'), 'artifact');
fprintf('STANDALONE_EXE=%s\n', executable);
end
