function tests = test_surface_mesh
tests = functiontests(localfunctions);
end

function testReadObjComputesFaceGeometry(testCase)
file = [tempname '.obj'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 3\n');
fclose(fid);
mesh = leotherm.readSurfaceMesh(file);
verifyEqual(testCase, size(mesh.vertices), [3 3]);
verifyEqual(testCase, size(mesh.faces), [1 3]);
verifyEqual(testCase, mesh.faceAreasM2, 0.5, 'AbsTol', 1e-12);
verifyEqual(testCase, mesh.faceNormals, [0 0 1], 'AbsTol', 1e-12);
verifyEqual(testCase, mesh.totalAreaM2, 0.5, 'AbsTol', 1e-12);
end

function testObjQuadIsTriangulated(testCase)
file = [tempname '.obj'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n');
fclose(fid);
mesh = leotherm.readSurfaceMesh(file);
verifyEqual(testCase, size(mesh.faces, 1), 2);
verifyEqual(testCase, mesh.totalAreaM2, 1, 'AbsTol', 1e-12);
end

function testDegenerateFacesAreFilteredWithAlignedFaceGeometry(testCase)
file = [tempname '.obj'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 2 0 0\n');
fprintf(fid, 'f 1 2 4\nf 1 2 3\n');
fclose(fid);
mesh = leotherm.readSurfaceMesh(file);
verifyEqual(testCase, size(mesh.faces, 1), 1);
verifyEqual(testCase, size(mesh.faceCentroids), [1 3]);
verifyEqual(testCase, mesh.faceCentroids, [1/3 1/3 0], 'AbsTol', 1e-12);
verifyEqual(testCase, numel(mesh.faceHeatCapacityJK), 1);
end

function testMeshHeatLoadIsFaceResolved(testCase)
file = [tempname '.obj'];
cleanup = onCleanup(@() deleteIfPresent(file));
fid = fopen(file, 'w');
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 2 3\nf 1 4 2\n');
fclose(fid);
mesh = leotherm.readSurfaceMesh(file);
scenario = leotherm.defaultScenario;
environment = scenario.environment;
loads = leotherm.surfaceMeshLoads(mesh, [0 0 1], [0 0 -1], 1, environment);
verifyEqual(testCase, numel(loads.directSolarW), size(mesh.faces, 1));
verifyGreaterThan(testCase, loads.directSolarW(1), 0);
verifyEqual(testCase, loads.directSolarW(2), 0, 'AbsTol', 1e-12);
end

function testMeshValidationRejectsNonUnitNormal(testCase)
mesh = struct('vertices', [0 0 0; 1 0 0; 0 1 0], ...
    'faces', [1 2 3], 'faceNormals', [0 0 2], 'faceAreasM2', 0.5);
verifyError(testCase, @() leotherm.validateSurfaceMesh(mesh), ...
    'leotherm:InvalidSurfaceMesh');
end

function testMeshValidationRejectsInconsistentArea(testCase)
mesh = struct('vertices', [0 0 0; 1 0 0; 0 1 0], ...
    'faces', [1 2 3], 'faceNormals', [0 0 1], 'faceAreasM2', 0.25);
verifyError(testCase, @() leotherm.validateSurfaceMesh(mesh), ...
    'leotherm:InvalidSurfaceMesh');
end

function deleteIfPresent(file)
if isfile(file), delete(file); end
end
