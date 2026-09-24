function summary = run_satmo_style_benchmark(outDir)
%RUN_SATMO_STYLE_BENCHMARK Seven-node box trend benchmark.
% This benchmark shares SATMO's public node topology and Earth-case matrix
% concept but does not claim exact numerical equivalence to a SATMO model.

root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1, outDir = fullfile(root, 'results', 'satmo_style_benchmark'); end
addpath(fullfile(root, 'src'));
scenario = leotherm.defaultScenario;
scenario.environment.earthIRModel = 'legacy_cosine'; % Preserve the historical geometry benchmark.
scenario.name = 'satmo_style_benchmark';
scenario.startEpoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
scenario.orbit.inclinationDeg = 90;
scenario.durationS = 6 * 3600;
scenario.timeStepS = 10;
network = leotherm.satmoStyleNetwork;

summary = leotherm.runBetaAltitudeSweep( ...
    scenario, network, [400, 800], [0, 45, 80], 1);
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
writetable(summary, fullfile(outDir, 'summary.csv'));
save(fullfile(outDir, 'summary.mat'), 'summary');
if nargout == 0
    disp(summary)
end
end
