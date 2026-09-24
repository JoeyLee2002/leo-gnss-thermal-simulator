function results = selfTest
%SELFTEST Run the installed automated verification suite.

packageDir = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(packageDir));
results = runtests(fullfile(root, 'tests'), 'IncludeSubfolders', true);
if ~all([results.Passed])
    error('leotherm:SelfTestFailed', ...
        '%d of %d automated tests failed.', sum([results.Failed]), numel(results));
end
if nargout == 0
    fprintf('LEO GNSS Thermal Simulator %s: %d/%d tests passed.\n', ...
        leotherm.version, sum([results.Passed]), numel(results));
end
end
