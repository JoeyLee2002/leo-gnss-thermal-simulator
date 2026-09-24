try
    label = getenv('LEOTHERM_SNAPSHOT_LABEL');
    if isempty(label)
        label = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    end
    [archivePath, manifestPath] = create_version_snapshot(label);
    fprintf('SNAPSHOT_ARCHIVE=%s\n', archivePath);
    fprintf('SNAPSHOT_MANIFEST=%s\n', manifestPath);
    exit(0);
catch exception
    fprintf(2, '%s\n', getReport(exception, 'extended'));
    exit(1);
end
