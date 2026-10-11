function verify_sweep36_archive
%VERIFY_SWEEP36_ARCHIVE Check SHA-256 and the archived 36-case results.
[root,~,out]=sweep36_paths;
archive=fullfile(root,'archive');
manifest=jsondecode(fileread(fullfile(archive,'manifest.json')));
for k=1:numel(manifest.files)
    entry=manifest.files(k);
    path=char(java.io.File(fullfile(archive,entry.path)).getCanonicalPath());
    assert(startsWith(path,[char(java.io.File(archive).getCanonicalPath()) filesep]), ...
        'sweep36:ManifestPath','Manifest path is outside the archive.');
    assert(strcmp(sweep36_file_sha256(path),entry.sha256), ...
        'sweep36:ChecksumMismatch','Checksum mismatch: %s.',entry.path);
end
audit_sweep36_v129(fullfile(archive,'sweep36'),fullfile(out,'archive_audit.csv'));
fprintf('ARCHIVE_SHA256_PASSED=%d\n',numel(manifest.files));
end
