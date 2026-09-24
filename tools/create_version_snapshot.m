function [archivePath, manifestPath] = create_version_snapshot(label)
%CREATE_VERSION_SNAPSHOT Archive the current source before an update.
% Run this function before changing VERSION or any source file.

toolDir = fileparts(mfilename('fullpath'));
root = fileparts(toolDir);
versionPath = fullfile(root, 'VERSION');
assert(isfile(versionPath), 'VERSION file is missing.');
version = strtrim(fileread(versionPath));
if nargin < 1 || isempty(label)
    label = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
end
label = matlab.lang.makeValidName(label);

[parent, projectName] = fileparts(root);
archiveRoot = fullfile(parent, [projectName '_versions']);
if ~exist(archiveRoot, 'dir')
    mkdir(archiveRoot);
end
archiveName = sprintf('%s_v%s_%s.zip', projectName, version, label);
archivePath = fullfile(archiveRoot, archiveName);
assert(~isfile(archivePath), 'Archive already exists: %s', archivePath);

files = recursiveFiles(root, root);
zip(archivePath, files, root);

manifestPath = [archivePath '.manifest.txt'];
fid = fopen(manifestPath, 'w');
assert(fid >= 0, 'Cannot create snapshot manifest.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'project=%s\n', projectName);
fprintf(fid, 'version=%s\n', version);
fprintf(fid, 'created_utc=%s\n', char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));
fprintf(fid, 'archive=%s\n', archivePath);
fprintf(fid, 'file_count=%d\n', numel(files));
for k = 1:numel(files)
    fprintf(fid, 'file=%s\n', files{k});
end
end

function files = recursiveFiles(folder, root)
listing = dir(folder);
files = {};
for k = 1:numel(listing)
    name = listing(k).name;
    if strcmp(name, '.') || strcmp(name, '..')
        continue
    end
    fullPath = fullfile(folder, name);
    relative = erase(fullPath, [root filesep]);
    firstPart = strtok(relative, filesep);
    if any(strcmp(firstPart, {'.git', 'results'}))
        continue
    end
    if listing(k).isdir
        files = [files, recursiveFiles(fullPath, root)]; %#ok<AGROW>
    else
        files{end + 1} = relative; %#ok<AGROW>
    end
end
end

