function writeSurfaceMeshResult(result, outDir)
%WRITESURFACEMESHRESULT Export an auditable face-thermal result.
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'mesh') ...
        || ~isfield(result, 'timeS') || ~isfield(result, 'temperatureK')
    error('leotherm:MeshExportFailed', 'The face result is incomplete.');
end
mesh = result.mesh;
leotherm.validateSurfaceMesh(mesh);
if ~isfolder(outDir), mkdir(outDir); end
save(fullfile(outDir, 'surface_mesh_result.mat'), 'result', '-v7.3');

nFace = size(mesh.faces, 1);
if ~isequal(size(result.temperatureK), [numel(result.timeS), nFace])
    error('leotherm:MeshExportFailed', 'temperatureK dimensions do not match the mesh.');
end
face = table((1:nFace)', mesh.faceAreasM2(:), mesh.faceNormals(:, 1), ...
    mesh.faceNormals(:, 2), mesh.faceNormals(:, 3), ...
    faceField(mesh, 'faceSolarAbsorptivity', 0.60 * ones(nFace, 1)), ...
    faceField(mesh, 'faceIREmissivity', 0.80 * ones(nFace, 1)), ...
    faceField(mesh, 'faceHeatCapacityJK', mesh.faceAreasM2(:) * 5000), ...
    faceField(mesh, 'faceInitialTemperatureK', 293.15 * ones(nFace, 1)), ...
    'VariableNames', {'face_index', 'area_m2', 'normal_x', 'normal_y', ...
    'normal_z', 'solar_absorptivity', 'ir_emissivity', 'heat_capacity_j_k', ...
    'initial_temperature_k'});
writetable(face, fullfile(outDir, 'face_properties.csv'));

timeS = result.timeS(:);
epochText = strings(numel(timeS), 1);
if isfield(result, 'orbit') && isfield(result.orbit, 'epoch')
    epochText = string(result.orbit.epoch, 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX');
end
if isfield(result, 'eclipseVisibleFraction')
    eclipse = result.eclipseVisibleFraction(:);
else
    eclipse = nan(numel(timeS), 1);
end
if isfield(result, 'shadowedFaceCount')
    shadowed = result.shadowedFaceCount(:);
else
    shadowed = nan(numel(timeS), 1);
end
series = table(epochText, timeS, eclipse, shadowed, ...
    'VariableNames', {'epoch_utc', 'elapsed_s', 'eclipse_visible_fraction', ...
    'shadowed_face_count'});
for k = 1:nFace
    series.(sprintf('temperature_k_face_%04d', k)) = result.temperatureK(:, k);
    if isfield(result, 'directSolarW')
        series.(sprintf('direct_solar_w_face_%04d', k)) = result.directSolarW(:, k);
    end
    if isfield(result, 'faceVisibleFraction')
        series.(sprintf('visible_fraction_face_%04d', k)) = result.faceVisibleFraction(:, k);
    end
end
writetable(series, fullfile(outDir, 'surface_mesh_timeseries.csv'));

metadata = struct('softwareVersion', leotherm.version, ...
    'model', result.provenance, 'thermalNumerics', result.numerics, ...
    'meshThermalParameterProvenance', meshField(mesh, ...
    'thermalParameterProvenance', 'not_declared'));
save(fullfile(outDir, 'surface_mesh_metadata.mat'), 'metadata', '-v7.3');
end

function value = faceField(mesh, name, fallback)
value = fallback;
if isfield(mesh, name), value = mesh.(name); end
value = value(:);
end

function value = meshField(mesh, name, fallback)
value = fallback;
if isfield(mesh, name), value = mesh.(name); end
end
