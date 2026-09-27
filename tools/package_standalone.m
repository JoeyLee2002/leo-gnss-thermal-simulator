function archive = package_standalone
%PACKAGE_STANDALONE Create a relocatable Windows GitHub Release archive.
root = fileparts(fileparts(mfilename('fullpath')));
versionTag = strtrim(fileread(fullfile(root, 'VERSION')));
results = fullfile(root, 'results');
build = fullfile(results, ['standalone_v' strrep(versionTag, '.', '_')]);
executable = fullfile(build, 'LEOTherm.exe');
if ~isfile(executable)
    error('leotherm:StandalonePackage', 'Build the standalone executable first.');
end
staging = fullfile(results, ['release_staging_v' strrep(versionTag, '.', '_')]);
archive = fullfile(results, ['LEOTherm_' versionTag '_windows.zip']);
if isfolder(staging) || isfile(archive)
    error('leotherm:StandalonePackage', 'Release staging or archive already exists.');
end
mkdir(staging);
copyfile(executable, fullfile(staging, 'LEOTherm.exe'));
copyfile(fullfile(build, 'readme.txt'), fullfile(staging, 'MATLAB_Runtime_readme.txt'));
copyfile(fullfile(root, 'docs', '独立版使用_v1.2.0.md'), ...
    fullfile(staging, 'README_CN.md'));
copyfile(fullfile(root, 'docs', '统一任务流水线_v1.1.0.md'), ...
    fullfile(staging, 'TASK_GUIDE_CN.md'));
copyfile(fullfile(root, 'LICENSE'), fullfile(staging, 'LICENSE'));
copyfile(fullfile(root, 'NOTICE.md'), fullfile(staging, 'NOTICE.md'));
copyfile(fullfile(root, 'templates'), fullfile(staging, 'templates'));
files = {'LEOTherm.exe','MATLAB_Runtime_readme.txt','README_CN.md', ...
    'TASK_GUIDE_CN.md', ...
    'LICENSE','NOTICE.md','templates'};
zip(archive, files, staging);
fprintf('STANDALONE_RELEASE=%s\n', archive);
end
