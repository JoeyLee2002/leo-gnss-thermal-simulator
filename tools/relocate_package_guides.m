function relocate_package_guides(folder, versionTag)
%RELOCATE_PACKAGE_GUIDES Keep renamed distribution guides mutually reachable.
sources = {['usage_v' versionTag '_zh.md'], ['quickstart_v' versionTag '.md'], ...
    ['reproduce_paper_v' versionTag '_zh.md'], ['reproduce_paper_v' versionTag '.md'], ...
    ['verification_v' versionTag '.md'], ['verification_v' versionTag '_startup_optimized.md'], ...
    ['verification_v' versionTag '_startup_final.md'], ['verification_v' versionTag '_release.md'], ...
    ['plotting_v' versionTag '_zh.md'], ...
    ['report_v' versionTag '_zh.md'], ['tutorials_v' versionTag '.md'], ...
    '术语与指标.md', 'patches/PATCH_v1.5.md'};
destinations = {'USAGE_CN.md','USAGE_EN.md','PAPER_REPRODUCTION_CN.md', ...
    'PAPER_REPRODUCTION_EN.md','REPORT_AUDIT_CN.md','REPORT_AUDIT_CN.md', ...
    'REPORT_AUDIT_CN.md','REPORT_AUDIT_CN.md','PLOTTING_CN.md','REPORT_GUIDE_CN.md','TUTORIALS.md', ...
    'METRICS_CN.md',['PATCH_v' versionTag '.md']};
files = dir(fullfile(folder, '*.md'));
for k = 1:numel(files)
    file = fullfile(files(k).folder, files(k).name);
    fid = fopen(file, 'rb');
    if fid < 0, error('leotherm:StandalonePackage', 'Cannot read package guide.'); end
    cleanup = onCleanup(@() fclose(fid));
    text = native2unicode(fread(fid, Inf, '*uint8')', 'UTF-8');
    clear cleanup
    for j = 1:numel(sources)
        text = strrep(text, ['docs/' sources{j}], destinations{j});
        text = strrep(text, sources{j}, destinations{j});
    end
    fid = fopen(file, 'wb');
    if fid < 0, error('leotherm:StandalonePackage', 'Cannot update package guide.'); end
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, unicode2native(text, 'UTF-8'), 'uint8');
    clear cleanup
end
end
