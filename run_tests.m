function results = run_tests
%RUN_TESTS Execute the complete verification suite.

root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
results = runtests(fullfile(root, 'tests'), 'IncludeSubfolders', true);
% Optional external-data checks may be reported as Incomplete when their
% provider archive is unavailable. They are not failures and must not make
% the release gate red; only an actual Failed result blocks publication.
failed = [results.Failed];
incomplete = [results.Incomplete];
fprintf('TEST_FAILED=%d TEST_INCOMPLETE=%d\n', sum(failed), sum(incomplete));
assert(~any(failed), 'At least one verification test failed.');
end
