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
copyfile(fullfile(root, 'docs', 'standalone_en.md'), ...
    fullfile(staging, 'README.md'));
copyfile(fullfile(root, 'docs', ['使用教程_v' versionTag '.md']), fullfile(staging, 'USAGE_CN.md'));
copyfile(fullfile(root, 'docs', ['quickstart_v' versionTag '.md']), fullfile(staging, 'USAGE_EN.md'));
copyfile(fullfile(root, 'docs', '统一任务流水线_v1.1.0.md'), ...
    fullfile(staging, 'TASK_GUIDE_CN.md'));
copyfile(fullfile(root, 'docs', '报告更新_v1.2.4.md'), ...
    fullfile(staging, 'REPORT_GUIDE_CN.md'));
copyfile(fullfile(root, 'docs', ['verification_v' versionTag '.md']), ...
    fullfile(staging, 'REPORT_AUDIT_CN.md'));
copyfile(fullfile(root, 'docs', ['科研图形导出_v' versionTag '.md']), ...
    fullfile(staging, 'PLOTTING_CN.md'));
copyfile(fullfile(root, 'docs', ['论文结果复现_v' versionTag '.md']), ...
    fullfile(staging, 'PAPER_REPRODUCTION_CN.md'));
copyfile(fullfile(root, 'docs', ['reproduce_paper_v' versionTag '.md']), ...
    fullfile(staging, 'PAPER_REPRODUCTION_EN.md'));
copyfile(fullfile(root, 'docs', '术语与指标.md'), ...
    fullfile(staging, 'METRICS_CN.md'));
copyfile(fullfile(root, 'tutorial', ['v' strrep(versionTag,'.','_')], 'RELEASE_LINKS.md'), ...
    fullfile(staging, 'TUTORIALS.md'));
tutorialDestination=fullfile(staging,'tutorial'); mkdir(tutorialDestination);
for language={'zh','en'}
    lang=language{1};
    for extension={'mp4','srt'}
        file=['LEOTherm_v' versionTag '_paper_tutorial_' lang '.' extension{1}];
        copyfile(fullfile(root,'tutorial',['v' strrep(versionTag,'.','_')],file),tutorialDestination);
    end
    copyfile(fullfile(root,'tutorial',['v' strrep(versionTag,'.','_')],['timeline_' lang '.json']),tutorialDestination);
end
copyfile(fullfile(root,'examples','reports',['thermal_report_v' versionTag '_zh.pdf']), ...
    fullfile(staging,'sample_report_zh.pdf'));
copyfile(fullfile(root,'examples','reports',['thermal_report_v' versionTag '_en.pdf']), ...
    fullfile(staging,'sample_report_en.pdf'));
copyfile(fullfile(root, 'patches', ['PATCH_v' versionTag '.md']), staging);
copyfile(fullfile(root, 'LICENSE'), fullfile(staging, 'LICENSE'));
copyfile(fullfile(root, 'NOTICE.md'), fullfile(staging, 'NOTICE.md'));
copyfile(fullfile(root, 'templates'), fullfile(staging, 'templates'));
files = {'LEOTherm.exe','MATLAB_Runtime_readme.txt','README.md','USAGE_CN.md','USAGE_EN.md', ...
    'TASK_GUIDE_CN.md','REPORT_GUIDE_CN.md','REPORT_AUDIT_CN.md',['PATCH_v' versionTag '.md'], ...
    'LICENSE','NOTICE.md','templates','PLOTTING_CN.md','sample_report_zh.pdf','sample_report_en.pdf', ...
    'PAPER_REPRODUCTION_CN.md','PAPER_REPRODUCTION_EN.md','METRICS_CN.md','TUTORIALS.md','tutorial'};
zip(archive, files, staging);
fprintf('STANDALONE_RELEASE=%s\n', archive);
end
