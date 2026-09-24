function runDir = run_minxss_flight_validation
%RUN_MINXSS_FLIGHT_VALIDATION Actual original-epoch held-out flight-temperature test.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'),fullfile(root,'studies','minxss'));
p=minxss_protocol;
source=fullfile(root,'results','minxss_physical_validation','raw',p.sourceFile);
assert(isfile(source),['Download the original NASA Level 0C file described in ' ...
    'studies/minxss/README_CN.md before running.']);
runDir=run_minxss_validation('all');
fprintf('Flight-validation results: %s\n',runDir);
end
