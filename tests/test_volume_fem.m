function tests = test_volume_fem
tests = functiontests(localfunctions);
end

function testGmshReaderLoadsTetrahedraAndBoundaryTags(testCase)
file = [tempname '.msh'];
cleanup = onCleanup(@() deleteIfPresent(file));
writeFixture(file);
mesh = leotherm.readVolumeMesh(file);
verifyEqual(testCase, mesh.nodeCount, 5);
verifyEqual(testCase, mesh.tetrahedronCount, 2);
verifyEqual(testCase, size(mesh.boundaryTriangles), [1 3]);
verifyEqual(testCase, mesh.boundaryPhysicalTags, 7);
verifyEqual(testCase, mesh.tetraPhysicalTags, [1; 2]);
leotherm.validateVolumeMesh(mesh);
end

function testPhysicalRegionsSelectElementMaterials(testCase)
mesh = fixtureMesh;
mesh.tetraPhysicalTags = [1; 2];
material = struct('regionProperties', struct( ...
    'physicalTag', {1, 2}, ...
    'conductivityWmK', {2, 0.5}, ...
    'densityKgM3', {1000, 2000}, ...
    'specificHeatJkgK', {500, 800}));
model = leotherm.assembleVolumeThermalModel(mesh, material);
verifyEqual(testCase, model.elementPhysicalTags, [1; 2]);
verifyEqual(testCase, model.elementConductivityWmK, [2; 0.5]);
verifyEqual(testCase, model.elementDensityKgM3, [1000; 2000]);
verifyEqual(testCase, model.elementSpecificHeatJkgK, [500; 800]);
verifyNotEqual(testCase, model.capacityJK(2), model.capacityJK(1));
uniform = leotherm.assembleVolumeThermalModel(mesh, struct('conductivityWmK', 2, ...
    'densityKgM3', 1000, 'specificHeatJkgK', 500));
verifyNotEqual(testCase, model.stiffnessWK(2, 2), uniform.stiffnessWK(2, 2));
end

function testPhysicalRegionsRejectMissingAndUnmatchedTags(testCase)
mesh = fixtureMesh;
material = struct('regionProperties', struct( ...
    'physicalTag', 1, 'conductivityWmK', 1, 'densityKgM3', 1, 'specificHeatJkgK', 1));
verifyError(testCase, @() leotherm.assembleVolumeThermalModel(mesh, material), ...
    'leotherm:MissingVolumePhysicalTag');
mesh.tetraPhysicalTags = [1; 9];
verifyError(testCase, @() leotherm.assembleVolumeThermalModel(mesh, material), ...
    'leotherm:UnmatchedVolumePhysicalTag');
end

function testBinaryGmshIsRejected(testCase)
file = [tempname '.msh'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, '$MeshFormat\n2.2 1 8\n$EndMeshFormat\n');
fclose(fid);
verifyError(testCase, @() leotherm.readVolumeMesh(file), 'leotherm:UnsupportedVolumeMeshFormat');
end

function testVolumeAssemblyHasSymmetricConductionAndPositiveCapacity(testCase)
mesh = fixtureMesh;
model = leotherm.assembleVolumeThermalModel(mesh, struct( ...
    'conductivityWmK', 2, 'densityKgM3', 1000, 'specificHeatJkgK', 500));
verifyEqual(testCase, full(model.stiffnessWK), full(model.stiffnessWK'), 'AbsTol', 1e-12);
verifyGreaterThan(testCase, min(model.capacityJK), 0);
verifyEqual(testCase, full(sum(model.stiffnessWK, 2)), zeros(5, 1), 'AbsTol', 1e-12);
verifyEqual(testCase, model.elementVolumesM3(1), 1/6, 'AbsTol', 1e-12);
end

function testVolumeSolverPreservesFixedTemperatureAndReportsResidual(testCase)
mesh = fixtureMesh;
model = leotherm.assembleVolumeThermalModel(mesh, struct( ...
    'conductivityWmK', 2, 'densityKgM3', 1000, 'specificHeatJkgK', 500));
timeS = (0:10:30)';
power = zeros(numel(timeS), 5);
thermal = struct('initialTemperatureK', 280, 'fixedNodeIndices', 1, ...
    'fixedTemperatureK', 300, 'theta', 1, 'maximumTemperatureK', 400);
[temperature, diagnostics] = leotherm.solveVolumeThermal(timeS, power, model, thermal);
verifyEqual(testCase, temperature(:, 1), 300 * ones(numel(timeS), 1), 'AbsTol', 1e-12);
verifyTrue(testCase, all(isfinite(temperature), 'all'));
verifyLessThan(testCase, diagnostics.maximumLinearResidual, 1e-8);
verifyEqual(testCase, diagnostics.acceptedSteps, numel(timeS) - 1);
end

function testVolumeReaderRejectsZeroVolumeTetrahedron(testCase)
file = [tempname '.msh'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, '$MeshFormat\n2.2 0 8\n$EndMeshFormat\n$Nodes\n4\n');
fprintf(fid, '1 0 0 0\n2 1 0 0\n3 0 1 0\n4 1 1 0\n$EndNodes\n');
fprintf(fid, '$Elements\n1\n1 4 0 1 2 3 4\n$EndElements\n');
fclose(fid);
verifyError(testCase, @() leotherm.readVolumeMesh(file), 'leotherm:InvalidVolumeMeshFile');
end

function testVolumeReaderRejectsDuplicateNodeIds(testCase)
file = [tempname '.msh'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, '$MeshFormat\n2.2 0 8\n$EndMeshFormat\n$Nodes\n4\n');
fprintf(fid, '1 0 0 0\n1 1 0 0\n3 0 1 0\n4 0 0 1\n$EndNodes\n');
fprintf(fid, '$Elements\n1\n1 4 0 1 3 4 3\n$EndElements\n');
fclose(fid);
verifyError(testCase, @() leotherm.readVolumeMesh(file), 'leotherm:InvalidVolumeMeshFile');
end

function testVolumeValidationRejectsBadBoundaryData(testCase)
mesh = fixtureMesh;
mesh.boundaryTriangles = [1 2 3; 3 2 1];
mesh.boundaryPhysicalTags = [7; 8];
verifyError(testCase, @() leotherm.validateVolumeMesh(mesh), 'leotherm:InvalidVolumeMesh');
mesh = fixtureMesh;
mesh.boundaryPhysicalTags = 7.5;
verifyError(testCase, @() leotherm.validateVolumeMesh(mesh), 'leotherm:InvalidVolumeMesh');
end

function testVolumeResultExportWritesMeshAndSeriesFiles(testCase)
mesh = fixtureMesh;
model = leotherm.assembleVolumeThermalModel(mesh, struct('conductivityWmK', 1, ...
    'densityKgM3', 1000, 'specificHeatJkgK', 1000));
timeS = (0:10:20)';
[temperature, diagnostics] = leotherm.solveVolumeThermal(timeS, zeros(3, 5), model, ...
    struct('initialTemperatureK', 293.15));
result = struct('mesh', mesh, 'model', model, 'timeS', timeS, ...
    'nodalPowerW', zeros(3, 5), 'temperatureK', temperature, 'diagnostics', diagnostics);
outDir = tempname;
cleanup = onCleanup(@() removeFolder(outDir));
leotherm.writeVolumeThermalResult(result, outDir);
verifyTrue(testCase, isfile(fullfile(outDir, 'volume_thermal_result.mat')));
verifyTrue(testCase, isfile(fullfile(outDir, 'volume_nodes.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'volume_elements.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'volume_timeseries.csv')));
verifyTrue(testCase, isfile(fullfile(outDir, 'volume_metadata.mat')));
series = readtable(fullfile(outDir, 'volume_timeseries.csv'));
verifyEqual(testCase, height(series), 3);
elements = readtable(fullfile(outDir, 'volume_elements.csv'));
verifyEqual(testCase, elements.physical_tag, [0; 0]);
verifyTrue(testCase, all(ismember({'conductivity_w_m_k', 'density_kg_m3', ...
    'specific_heat_j_kg_k'}, elements.Properties.VariableNames)));
end

function mesh = fixtureMesh
mesh.nodesM = [0 0 0; 1 0 0; 0 1 0; 0 0 1; 1 1 1];
mesh.tetrahedra = [1 2 3 4; 2 3 4 5];
mesh.boundaryTriangles = [1 2 3];
mesh.boundaryPhysicalTags = 7;
leotherm.validateVolumeMesh(mesh);
end

function writeFixture(file)
fid = fopen(file, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '$MeshFormat\n2.2 0 8\n$EndMeshFormat\n$Nodes\n5\n');
fprintf(fid, '1 0 0 0\n2 1 0 0\n3 0 1 0\n4 0 0 1\n5 1 1 1\n$EndNodes\n');
fprintf(fid, '$Elements\n3\n1 2 2 7 0 1 2 3\n2 4 1 1 1 2 3 4\n3 4 1 2 2 3 4 5\n$EndElements\n');
clear cleanup
end

function deleteIfPresent(file)
if isfile(file), delete(file); end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
