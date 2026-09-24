function writeTelemetryResults(result, report, data, outputDirectory, language)
%WRITETELEMETRYRESULTS Archive input, mappings, model, audit, comparisons and figures.
if nargin < 5, language = 'zh'; end
language = leotherm.normalizeLanguage(language);
if isfolder(outputDirectory)
    listing = dir(outputDirectory);
    if any(~ismember({listing.name}, {'.','..'}))
        error('leotherm:TelemetryExport', 'Use a new or empty directory; existing results are not overwritten.');
    end
else
    mkdir(outputDirectory);
end
save(fullfile(outputDirectory, 'telemetry_bundle.mat'), 'result', 'report', 'data', 'language', '-v7.3');
writetable(data.rawTable, fullfile(outputDirectory, 'input_data.csv'));
writetable(data.mapping, fullfile(outputDirectory, 'column_mapping.csv'));
writetable(data.audit, fullfile(outputDirectory, 'import_audit.csv'));
if isfield(result, 'audit')
    writetable(result.audit, fullfile(outputDirectory, 'simulation_audit.csv'));
    segments = removevars(result.segments, 'source_rows');
    segments.segment_id = (1:height(segments))';
    writetable(segments, fullfile(outputDirectory, 'segment_status.csv'));
end
if isfield(result, 'epoch'), epoch = result.epoch; else, epoch = result.orbit.epoch; end
epoch.TimeZone = 'UTC';
predictions = table(string(epoch, 'yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSS''Z'''), ...
    'VariableNames', {'epoch_utc'});
for k = 1:numel(result.network.nodeNames)
    key = ['temperature_k_' matlab.lang.makeValidName(result.network.nodeNames{k})];
    predictions.(key) = result.temperatureK(:, k);
end
writetable(predictions, fullfile(outputDirectory, 'predicted_temperatures.csv'));
if isfield(result, 'boundaryMapped') && any(result.boundaryMapped)
    boundaries = predictions(:, 1);
    for k = find(result.boundaryMapped)
        key = matlab.lang.makeValidName(result.network.nodeNames{k});
        boundaries.(['boundary_temperature_k_' key]) = result.boundaryTemperatureK(:, k);
        boundaries.(['boundary_conductance_wk_' key]) = result.boundaryConductanceWK(:, k);
        boundaries.(['boundary_heat_w_' key]) = result.boundaryHeatW(:, k);
    end
    writetable(boundaries, fullfile(outputDirectory, 'thermal_boundaries.csv'));
end
writetable(report.metrics, fullfile(outputDirectory, 'temperature_metrics.csv'));
if ~isempty(report.samples)
    writetable(report.samples, fullfile(outputDirectory, 'paired_samples.csv'));
end
for k = 1:height(report.metrics)
    leotherm.plotTelemetry(result, report, report.metrics.node(k), ...
        fullfile(outputDirectory, sprintf('temperature_comparison_%02d_%s.png', k, language)), language);
end
if isempty(report.metrics)
    leotherm.plotTelemetry(result, report, result.network.nodeNames{1}, ...
        fullfile(outputDirectory, ['temperature_simulation_' language '.png']), language);
end
metadata.softwareVersion = leotherm.version;
metadata.source = data.source;
metadata.datasetKind = data.datasetKind;
metadata.language = language;
metadata.options = report.options;
metadata.alignment = report.alignment;
metadata.independence = report.independence;
metadata.conclusion = report.conclusion;
metadata.interpolation = false;
if isfield(result, 'provenance'), metadata.simulationProvenance = result.provenance; end
fid = fopen(fullfile(outputDirectory, 'manifest.json'), 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:TelemetryExport', 'Cannot write export manifest.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(metadata, 'PrettyPrint', true));
leotherm.writeTelemetrySummary(result, report, data, ...
    fullfile(outputDirectory, ['validation_summary_' language '.md']), language);
end
