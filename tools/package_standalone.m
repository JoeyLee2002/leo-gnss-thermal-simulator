function archive = package_standalone(buildSuffix)
%PACKAGE_STANDALONE Create a relocatable Windows GitHub Release archive.
root = fileparts(fileparts(mfilename('fullpath')));
versionTag = strtrim(fileread(fullfile(root, 'VERSION')));
if nargin<1, buildSuffix=''; end
buildSuffix=char(string(buildSuffix));
if ~isempty(buildSuffix) && isempty(regexp(buildSuffix,'^[A-Za-z0-9_]+$','once'))
    error('leotherm:StandalonePackage','Build suffix must contain ASCII letters, digits or underscores.');
end
if ~isempty(buildSuffix), buildSuffix=['_' buildSuffix]; end
results = fullfile(root, 'results');
build = fullfile(results, ['standalone_v' strrep(versionTag, '.', '_') buildSuffix]);
executable = fullfile(build, 'LEOTherm.exe');
if ~isfile(executable)
    error('leotherm:StandalonePackage', 'Build the standalone executable first.');
end
staging = fullfile(results, ['release_staging_v' strrep(versionTag, '.', '_') buildSuffix]);
archive = fullfile(results, ['LEOTherm_' versionTag '_windows' buildSuffix '.zip']);
if isfolder(staging) || isfile(archive)
    error('leotherm:StandalonePackage', 'Release staging or archive already exists.');
end
mkdir(staging);
copyfile(executable, fullfile(staging, 'LEOTherm.exe'));
copyfile(fullfile(build, 'readme.txt'), fullfile(staging, 'MATLAB_Runtime_readme.txt'));
copyfile(fullfile(root, 'docs', 'standalone_en.md'), ...
    fullfile(staging, 'README.md'));
copyfile(fullfile(root, 'docs', ['usage_v' versionTag '_zh.md']), fullfile(staging, 'USAGE_CN.md'));
copyfile(fullfile(root, 'docs', ['quickstart_v' versionTag '.md']), fullfile(staging, 'USAGE_EN.md'));
copyfile(fullfile(root, 'docs', '统一任务流水线_v1.1.0.md'), ...
    fullfile(staging, 'TASK_GUIDE_CN.md'));
copyfile(fullfile(root, 'docs', ['report_v' versionTag '_zh.md']), ...
    fullfile(staging, 'REPORT_GUIDE_CN.md'));
copyfile(fullfile(root, 'docs', ['verification_v' versionTag buildSuffix '.md']), ...
    fullfile(staging, 'REPORT_AUDIT_CN.md'));
copyfile(fullfile(root, 'docs', ['plotting_v' versionTag '_zh.md']), ...
    fullfile(staging, 'PLOTTING_CN.md'));
copyfile(fullfile(root, 'docs', ['reproduce_paper_v' versionTag '_zh.md']), ...
    fullfile(staging, 'PAPER_REPRODUCTION_CN.md'));
copyfile(fullfile(root, 'docs', ['reproduce_paper_v' versionTag '.md']), ...
    fullfile(staging, 'PAPER_REPRODUCTION_EN.md'));
copyfile(fullfile(root, 'docs', '术语与指标.md'), ...
    fullfile(staging, 'METRICS_CN.md'));
copyfile(fullfile(root, 'docs', ['tutorials_v' versionTag '.md']), ...
    fullfile(staging, 'TUTORIALS.md'));
tutorialDestination=fullfile(staging,'tutorial'); mkdir(tutorialDestination);
tutorialVersion='1.2.10';
for language={'zh','en'}
    lang=language{1};
    for extension={'mp4','srt'}
        file=['LEOTherm_v' tutorialVersion '_paper_tutorial_' lang '.' extension{1}];
        copyfile(fullfile(root,'tutorial',['v' strrep(tutorialVersion,'.','_')],file),tutorialDestination);
    end
    copyfile(fullfile(root,'tutorial',['v' strrep(tutorialVersion,'.','_')],['timeline_' lang '.json']),tutorialDestination);
end
copyfile(fullfile(root,'examples','reports',['thermal_report_v' versionTag '_zh.pdf']), ...
    fullfile(staging,'sample_report_zh.pdf'));
copyfile(fullfile(root,'examples','reports',['thermal_report_v' versionTag '_en.pdf']), ...
    fullfile(staging,'sample_report_en.pdf'));
copyfile(fullfile(root, 'patches', ['PATCH_v' versionTag '.md']), staging);
copyfile(fullfile(root, 'LICENSE'), fullfile(staging, 'LICENSE'));
copyfile(fullfile(root, 'NOTICE.md'), fullfile(staging, 'NOTICE.md'));
copyfile(fullfile(root, 'templates'), fullfile(staging, 'templates'));
relocate_package_guides(staging, versionTag);
files = {'LEOTherm.exe','MATLAB_Runtime_readme.txt','README.md','USAGE_CN.md','USAGE_EN.md', ...
    'TASK_GUIDE_CN.md','REPORT_GUIDE_CN.md','REPORT_AUDIT_CN.md',['PATCH_v' versionTag '.md'], ...
    'LICENSE','NOTICE.md','templates','PLOTTING_CN.md','sample_report_zh.pdf','sample_report_en.pdf', ...
    'PAPER_REPRODUCTION_CN.md','PAPER_REPRODUCTION_EN.md','METRICS_CN.md','TUTORIALS.md','tutorial'};
entries=dir(fullfile(staging,'**','*'));
for k=1:numel(entries)
    if any(double(entries(k).name)>126)
        error('leotherm:StandalonePackage','Non-ASCII package entry: %s',entries(k).name);
    end
end
zip(archive, files, staging);
fprintf('STANDALONE_RELEASE=%s\n', archive);
end
