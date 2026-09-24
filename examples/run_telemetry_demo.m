function [result, report] = run_telemetry_demo(language, outputDirectory, includeBoundary)
%RUN_TELEMETRY_DEMO Exercise import, propagation, comparison, and export.
if nargin < 1, language = 'zh'; end
if nargin < 3, includeBoundary = false; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'));
if nargin < 2
    outputDirectory = fullfile(root,'results',['telemetry_demo_' datestr(now,'yyyymmdd_HHMMSS')]);
end
network = leotherm.defaultReceiverNetwork;
[raw, scenario, options] = leotherm.telemetryDemo(network, includeBoundary);
data = leotherm.readTelemetry(raw, [], network);
result = leotherm.simulateTelemetry(data, scenario, network, options);
report = leotherm.validateTelemetry(result, data, options);
leotherm.writeTelemetryResults(result, report, data, outputDirectory, language);
assert(all(abs(report.metrics.rmse_k - 0.2) < 1e-9), 'Known synthetic offset was not recovered.');
disp(report.metrics);
fprintf('SYNTHETIC DEMO ONLY. Results: %s\n', outputDirectory);
end
