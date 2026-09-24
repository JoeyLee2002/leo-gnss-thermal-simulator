function tests = test_mesh_thermal_config
tests = functiontests(localfunctions);
end

function testImportedMeshCarriesExplicitThermalDefaults(testCase)
file = [tempname '.obj'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n');
fclose(fid);
mesh = leotherm.readSurfaceMesh(file);
verifyEqual(testCase, mesh.faceHeatCapacityJK, 2500, 'AbsTol', 1e-12);
verifyEqual(testCase, mesh.faceInitialTemperatureK, 293.15, 'AbsTol', 1e-12);
verifyEqual(testCase, mesh.faceConductanceWK, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, mesh.thermalParameterProvenance, 'reference_defaults_not_calibrated');
end

function testMeshThermalSolverUsesMeshDefaultsAndReportsSources(testCase)
mesh = simpleMesh;
mesh.faceHeatCapacityJK = 7000;
mesh.faceInitialTemperatureK = 310;
mesh.faceConductanceWK = 0;
mesh.thermalParameterProvenance = 'synthetic_test_fixture';
[temperature, diagnostics] = leotherm.solveSurfaceMeshThermal((0:10:20)', ...
    zeros(3, 1), mesh, struct('deepSpaceK', 3, 'maximumStepS', 1));
verifyEqual(testCase, temperature(1), 310, 'AbsTol', 1e-12);
verifyEqual(testCase, diagnostics.capacitySource, 'mesh.faceHeatCapacityJK');
verifyEqual(testCase, diagnostics.initialTemperatureSource, 'mesh.faceInitialTemperatureK');
verifyEqual(testCase, diagnostics.conductanceSource, 'mesh.faceConductanceWK');
verifyEqual(testCase, diagnostics.emissivitySource, 'reference_emissivity_default');
verifyEqual(testCase, diagnostics.thermalParameterProvenance, 'synthetic_test_fixture');
end

function testFaceResultExportContainsTraceabilityFiles(testCase)
mesh = simpleMesh;
mesh.faceHeatCapacityJK = 7000;
mesh.faceInitialTemperatureK = 310;
mesh.faceConductanceWK = 0;
mesh.thermalParameterProvenance = 'synthetic_export_fixture';
[temperature, numerics] = leotherm.solveSurfaceMeshThermal((0:10:20)', ...
    zeros(3, 1), mesh, struct('deepSpaceK', 3, 'maximumStepS', 1));
result = struct('mesh', mesh, 'timeS', (0:10:20)', ...
    'temperatureK', temperature, 'numerics', numerics, ...
    'provenance', struct('model', 'test_model'), ...
    'eclipseVisibleFraction', ones(3, 1), 'shadowedFaceCount', zeros(3, 1), ...
    'directSolarW', zeros(3, 1), 'faceVisibleFraction', ones(3, 1));
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
leotherm.writeSurfaceMeshResult(result, outDir);
verifyTrue(testCase, isfile(fullfile(outDir, 'surface_mesh_result.mat')));
verifyTrue(testCase, isfile(fullfile(outDir, 'face_properties.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'surface_mesh_timeseries.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'surface_mesh_metadata.mat')));
properties = readtable(fullfile(outDir, 'face_properties.csv'));
verifyEqual(testCase, properties.heat_capacity_j_k, 7000, 'AbsTol', 1e-12);
series = readtable(fullfile(outDir, 'surface_mesh_timeseries.csv'));
verifyEqual(testCase, height(series), 3);
end

function mesh = simpleMesh
mesh.vertices = [0 0 0; 1 0 0; 0 1 0];
mesh.faces = [1 2 3];
mesh.faceNormals = [0 0 1];
mesh.faceAreasM2 = 0.5;
leotherm.validateSurfaceMesh(mesh);
end

function deleteIfPresent(file)
if isfile(file), delete(file); end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
