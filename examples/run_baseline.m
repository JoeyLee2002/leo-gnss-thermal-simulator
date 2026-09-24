function result = run_baseline(language)
%RUN_BASELINE Simulate and plot one 24 h reference LEO case.

if nargin < 1 || isempty(language)
    language = 'zh';
end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));

scenario = leotherm.defaultScenario;
network = leotherm.defaultReceiverNetwork;
result = leotherm.simulateScenario(scenario, network);

outDir = fullfile(root, 'results', 'baseline');
leotherm.writeScenario(result, outDir);
leotherm.plotScenario(result, fullfile(outDir, 'baseline_summary.png'), language);

disp(result.metrics)
fprintf('Results written to %s\n', outDir);
end
