function writeScenario(result, outDir)
%WRITESCENARIO Export one simulation as MAT and analysis-ready CSV files.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end
save(fullfile(outDir, 'scenario_result.mat'), 'result', '-v7.3');

epochText = string(result.orbit.epoch, 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
timeseries = table(epochText, result.timeS, result.orbit.betaDeg, ...
    result.loads.visibleFraction, sum(result.loads.directSolarW, 2), ...
    sum(result.loads.albedoW, 2), sum(result.loads.earthIRW, 2), ...
    result.codeBiasM, 'VariableNames', {'epoch_utc', 'elapsed_s', 'beta_deg', ...
    'solar_visible_fraction', 'direct_solar_w', 'albedo_w', 'earth_ir_w', ...
    'code_bias_m'});
for node = 1:numel(result.network.nodeNames)
    variable = matlab.lang.makeValidName(['temperature_k_' result.network.nodeNames{node}]);
    timeseries.(variable) = result.temperatureK(:, node);
end
writetable(timeseries, fullfile(outDir, 'timeseries.csv'));

metricNames = fieldnames(result.metrics);
metricValues = cell(numel(metricNames), 1);
for k = 1:numel(metricNames)
    metricValues{k} = result.metrics.(metricNames{k});
end
metrics = table(metricNames, metricValues, 'VariableNames', {'metric', 'value'});
writetable(metrics, fullfile(outDir, 'metrics.csv'));

networkTable = table(string(result.network.nodeNames(:)), ...
    result.network.capacityJK, result.network.internalPowerW, ...
    result.network.projectedAreaM2, result.network.radiatingAreaM2, ...
    result.network.solarAbsorptivity, result.network.irEmissivity, ...
    'VariableNames', {'node', 'capacity_j_k', 'internal_power_w', ...
    'projected_area_m2', 'radiating_area_m2', 'solar_absorptivity', ...
    'ir_emissivity'});
writetable(networkTable, fullfile(outDir, 'network_nodes.csv'));
writematrix(result.network.conductanceWK, fullfile(outDir, 'conductance_w_k.csv'));
end

