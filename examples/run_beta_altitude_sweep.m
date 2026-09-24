function summary = run_beta_altitude_sweep(language)
%RUN_BETA_ALTITUDE_SWEEP Reproduce a controlled altitude-beta experiment.

if nargin < 1 || isempty(language)
    language = 'zh';
end

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));

scenario = leotherm.defaultScenario;
scenario.durationS = 6 * 3600;
scenario.warmupOrbits = 20;
network = leotherm.defaultReceiverNetwork;

altitudeKm = [400, 600, 800, 1000];
targetBetaDeg = [-60, -45, -20, 0, 20, 45, 60];
summary = leotherm.runBetaAltitudeSweep( ...
    scenario, network, altitudeKm, targetBetaDeg, 1);

outDir = fullfile(root, 'results', 'beta_altitude_sweep');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
writetable(summary, fullfile(outDir, 'summary.csv'));
save(fullfile(outDir, 'summary.mat'), 'summary');
leotherm.plotSweep(summary, ...
    fullfile(outDir, 'beta_altitude_summary.png'), language);

disp(summary(:, {'altitude_km', 'target_beta_deg', 'actual_beta_deg', ...
    'eclipse_fraction', 'rf_temperature_span_k', 'code_bias_span_m'}));
fprintf('Results written to %s\n', outDir);
end
