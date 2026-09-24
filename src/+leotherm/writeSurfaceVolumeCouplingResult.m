function writeSurfaceVolumeCouplingResult(result, outDir)
%WRITESURFACEVOLUMECOUPLINGRESULT Export conservative surface-volume loads.
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'timeS') ...
        || ~isfield(result, 'nodalPowerW') || ~isfield(result, 'diagnostics')
    error('leotherm:CouplingExportFailed', 'Coupling result is incomplete.');
end
timeS = result.timeS(:); power = result.nodalPowerW;
if ~isnumeric(timeS) || numel(timeS) < 1 || any(~isfinite(timeS)) ...
        || ~isnumeric(power) || size(power, 1) ~= numel(timeS) || any(~isfinite(power), 'all')
    error('leotherm:CouplingExportFailed', 'timeS and nodalPowerW dimensions are invalid.');
end
if ~isfolder(outDir), mkdir(outDir); end
save(fullfile(outDir, 'surface_volume_coupling_result.mat'), 'result', '-v7.3');
nNode = size(power, 2);
series = table(timeS, 'VariableNames', {'elapsed_s'});
for k = 1:nNode
    series.(sprintf('power_w_node_%04d', k)) = power(:, k);
end
if isfield(result.diagnostics, 'inputTotalPowerW')
    series.input_total_power_w = result.diagnostics.inputTotalPowerW(:);
    series.output_total_power_w = result.diagnostics.outputTotalPowerW(:);
    series.closure_w = result.diagnostics.energyClosureW(:);
end
writetable(series, fullfile(outDir, 'surface_volume_coupling_timeseries.csv'));
metadata = struct('softwareVersion', leotherm.version, 'diagnostics', result.diagnostics);
save(fullfile(outDir, 'surface_volume_coupling_metadata.mat'), 'metadata', '-v7.3');
end
