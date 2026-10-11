function outputDirectory = sweep36_safe_output(outputDirectory)
%SWEEP36_SAFE_OUTPUT Keep published evidence separate from generated files.
validateattributes(outputDirectory,{'char','string'},{'nonempty'});
outputDirectory=char(java.io.File(char(outputDirectory)).getCanonicalPath());
studyRoot=fileparts(mfilename('fullpath'));
archive=char(java.io.File(fullfile(studyRoot,'archive')).getCanonicalPath());
assert(~strcmpi(outputDirectory,archive) && ...
    ~startsWith(lower(outputDirectory),[lower(archive) filesep]), ...
    'sweep36:ArchiveReadOnly','Use a new output directory outside the published archive.');
end
