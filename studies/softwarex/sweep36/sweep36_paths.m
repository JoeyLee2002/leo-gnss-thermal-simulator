function [studyRoot, repoRoot, outputDirectory] = sweep36_paths(outputDirectory)
%SWEEP36_PATHS Locate the packaged engine without depending on pwd.
studyRoot=fileparts(mfilename('fullpath'));
repoRoot=fileparts(fileparts(fileparts(studyRoot)));
assert(isfile(fullfile(repoRoot,'VERSION')) && isfolder(fullfile(repoRoot,'src')), ...
    'sweep36:MissingSource','Keep studies/softwarex/sweep36 inside the source repository.');
addpath(fullfile(repoRoot,'src'),'-begin');
loaded=char(java.io.File(which('leotherm.defaultScenario')).getCanonicalPath());
expected=char(java.io.File(fullfile(repoRoot,'src','+leotherm','defaultScenario.m')).getCanonicalPath());
assert(strcmp(loaded,expected),'sweep36:SourcePath','Another LEOTherm source is shadowing this release.');
assert(strcmp(strtrim(fileread(fullfile(repoRoot,'VERSION'))),leotherm.version), ...
    'sweep36:Version','Loaded engine version differs from the repository VERSION.');
if nargin<1 || isempty(outputDirectory)
    outputDirectory=fullfile(repoRoot,'results','softwarex_sweep36');
end
outputDirectory=sweep36_safe_output(outputDirectory);
end
