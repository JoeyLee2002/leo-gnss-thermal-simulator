function writeVolumeThermalResult(result, outDir)
%WRITEVOLUMETHERMALRESULT Export an auditable tetrahedral conduction result.
if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'mesh') ...
        || ~isfield(result, 'model') || ~isfield(result, 'timeS') ...
        || ~isfield(result, 'temperatureK') || ~isfield(result, 'nodalPowerW')
    error('leotherm:VolumeExportFailed', 'The volume result is incomplete.');
end
mesh = result.mesh; model = result.model; timeS = result.timeS(:);
leotherm.validateVolumeMesh(mesh);
nNode = size(mesh.nodesM, 1);
nTet = size(mesh.tetrahedra, 1);
if ~isequal(size(result.temperatureK), [numel(timeS), nNode]) ...
        || ~isequal(size(result.nodalPowerW), [numel(timeS), nNode])
    error('leotherm:VolumeExportFailed', 'Volume result dimensions do not match the mesh.');
end
if ~isfolder(outDir), mkdir(outDir); end
save(fullfile(outDir, 'volume_thermal_result.mat'), 'result', '-v7.3');
nodes = table((1:nNode)', mesh.nodesM(:,1), mesh.nodesM(:,2), mesh.nodesM(:,3), ...
    model.capacityJK(:), 'VariableNames', {'node_index', 'x_m', 'y_m', 'z_m', 'capacity_j_k'});
writetable(nodes, fullfile(outDir, 'volume_nodes.csv'));
elements = table((1:nTet)', mesh.tetrahedra(:,1), mesh.tetrahedra(:,2), ...
    mesh.tetrahedra(:,3), mesh.tetrahedra(:,4), model.elementVolumesM3(:), ...
    model.elementPhysicalTags(:), model.elementConductivityWmK(:), ...
    model.elementDensityKgM3(:), model.elementSpecificHeatJkgK(:), ...
    'VariableNames', {'element_index', 'node_1', 'node_2', 'node_3', 'node_4', ...
    'volume_m3', 'physical_tag', 'conductivity_w_m_k', 'density_kg_m3', ...
    'specific_heat_j_kg_k'});
writetable(elements, fullfile(outDir, 'volume_elements.csv'));
series = table(timeS, 'VariableNames', {'elapsed_s'});
for k = 1:nNode
    series.(sprintf('temperature_k_node_%04d', k)) = result.temperatureK(:, k);
    series.(sprintf('power_w_node_%04d', k)) = result.nodalPowerW(:, k);
end
writetable(series, fullfile(outDir, 'volume_timeseries.csv'));
metadata = struct('softwareVersion', leotherm.version, 'formulation', model.formulation, ...
    'material', model.material, 'solverDiagnostics', result.diagnostics);
save(fullfile(outDir, 'volume_metadata.mat'), 'metadata', '-v7.3');
end
