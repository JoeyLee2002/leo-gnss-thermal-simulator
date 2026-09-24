function report = writeSurfaceVolumeScenarioResult(result, outputDirectory, language)
%WRITESURFACEVOLUMESCENARIORESULT Export a coupled surface-volume result.
%   Writes the complete MAT result, conservative coupling CSV/MAT, volume
%   mesh and time-series exports, and the established bilingual thermal report.
%   The destination must be new or empty so an earlier run cannot be hidden.

if nargin < 2 || isempty(outputDirectory)
    error('leotherm:CoupledExportFailed', 'An output directory is required.');
end
if nargin < 3 || isempty(language), language = 'both'; end
required = {'schema','scenario','surface','volume','couplingDiagnostics', ...
    'provenance','metrics'};
if ~isstruct(result) || ~isscalar(result) || ~all(isfield(result, required))
    error('leotherm:CoupledExportFailed', 'The coupled result is incomplete.');
end
if ~strcmp(result.schema, 'leotherm.surface_volume_scenario_result.v1')
    error('leotherm:CoupledExportFailed', 'Unsupported coupled-result schema.');
end
if isfolder(outputDirectory)
    listing = dir(outputDirectory);
    if any(~ismember({listing.name}, {'.','..'}))
        error('leotherm:CoupledExportFailed', ...
            'Output directory must be new or empty.');
    end
else
    [ok, message] = mkdir(outputDirectory);
    if ~ok, error('leotherm:CoupledExportFailed', ...
            'Cannot create output directory: %s', message); end
end
save(fullfile(outputDirectory, 'surface_volume_scenario_result.mat'), ...
    'result', '-v7.3');

couplingDir = fullfile(outputDirectory, 'surface_volume_coupling');
volumeDir = fullfile(outputDirectory, 'volume_thermal');
leotherm.writeSurfaceVolumeCouplingResult(struct( ...
    'timeS', result.timeS, 'nodalPowerW', result.nodalPowerW, ...
    'diagnostics', result.couplingDiagnostics), couplingDir);
leotherm.writeVolumeThermalResult(result.volume, volumeDir);
reportInput = result;
% The report consumes the nested thermal states, while this top-level
% coupling record is attached to the volume section for audit export.
reportInput.volume.couplingDiagnostics = result.couplingDiagnostics;
report = leotherm.writeThermalReport(reportInput, ...
    fullfile(outputDirectory, 'thermal_report'), language);
manifest = struct('schema', 'leotherm.surface_volume_export_manifest.v1', ...
    'softwareVersion', leotherm.version, 'resultSchema', result.schema, ...
    'couplingMode', result.provenance.couplingMode, ...
    'surfaceTemperatureFeedback', result.provenance.surfaceTemperatureFeedback, ...
    'reportDirectory', 'thermal_report', ...
    'couplingDirectory', 'surface_volume_coupling', ...
    'volumeDirectory', 'volume_thermal');
fid = fopen(fullfile(outputDirectory, 'surface_volume_manifest.json'), 'w', 'n', 'UTF-8');
if fid < 0, error('leotherm:CoupledExportFailed', 'Cannot write export manifest.'); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(manifest, 'PrettyPrint', true));
end
