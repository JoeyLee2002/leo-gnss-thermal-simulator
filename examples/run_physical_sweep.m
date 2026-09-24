function summary = run_physical_sweep
%RUN_PHYSICAL_SWEEP Sweep date, inclination, RAAN, and altitude physically.

root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));

scenario = leotherm.defaultScenario;
scenario.durationS = 3 * 3600;
scenario.warmupOrbits = 15;
network = leotherm.defaultReceiverNetwork;

dates = [ ...
    datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC'), ...
    datetime(2024, 6, 21, 12, 0, 0, 'TimeZone', 'UTC'), ...
    datetime(2024, 9, 22, 12, 0, 0, 'TimeZone', 'UTC'), ...
    datetime(2024, 12, 21, 12, 0, 0, 'TimeZone', 'UTC')];
summary = leotherm.runPhysicalSweep(scenario, network, dates, ...
    [450, 600, 800], [45, 70, 97.6], 0:45:315);

outDir = fullfile(root, 'results', 'physical_sweep');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
writetable(summary, fullfile(outDir, 'summary.csv'));
save(fullfile(outDir, 'summary.mat'), 'summary');
fprintf('Results written to %s\n', outDir);
end
