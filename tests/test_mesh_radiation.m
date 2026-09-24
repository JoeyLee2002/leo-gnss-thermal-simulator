function tests = test_mesh_radiation
tests = functiontests(localfunctions);
end

function testTetrahedronViewFactorsAreAdmissible(testCase)
mesh = tetrahedronMesh;
[F, diagnostics] = leotherm.computeMeshViewFactors(mesh, struct('visibility', 'centroid'));
verifyEqual(testCase, diag(F), zeros(size(F, 1), 1), 'AbsTol', 1e-12);
verifyGreaterThanOrEqual(testCase, F, -1e-12);
verifyLessThanOrEqual(testCase, sum(F, 2), 1 + 1e-10);
verifyLessThan(testCase, diagnostics.reciprocityError, 1e-10);
end

function testMeshThermalSolverReturnsFiniteFaceTemperatures(testCase)
mesh = tetrahedronMesh;
timeS = (0:60:600)';
external = zeros(numel(timeS), size(mesh.faces, 1));
thermal = struct('capacityJK', 100 * ones(size(mesh.faces, 1), 1), ...
    'initialTemperatureK', 293.15 * ones(size(mesh.faces, 1), 1), ...
    'deepSpaceK', 3, 'maximumStepS', 10);
[temperature, diagnostics] = leotherm.solveSurfaceMeshThermal(timeS, external, mesh, thermal);
verifyTrue(testCase, all(isfinite(temperature), 'all'));
verifyEqual(testCase, size(temperature), size(external));
verifyGreaterThan(testCase, diagnostics.acceptedSteps, 0);
end

function testFaceScenarioProducesIndependentMeshResult(testCase)
mesh = tetrahedronMesh;
scenario = leotherm.defaultScenario;
scenario.durationS = 120;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
result = leotherm.simulateSurfaceMeshScenario(scenario, mesh, ...
    struct('capacityJK', 10000 * ones(4, 1), 'maximumStepS', 10));
verifyEqual(testCase, size(result.temperatureK), [3 4]);
verifyTrue(testCase, result.provenance.faceToFaceRadiation);
verifyFalse(testCase, result.provenance.solidMeshConduction);
verifyTrue(testCase, all(isfinite(result.temperatureK), 'all'));
end

function mesh = tetrahedronMesh
mesh.vertices = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
mesh.faces = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
p1 = mesh.vertices(mesh.faces(:, 1), :);
p2 = mesh.vertices(mesh.faces(:, 2), :);
p3 = mesh.vertices(mesh.faces(:, 3), :);
normal = cross(p2 - p1, p3 - p1, 2);
mesh.faceAreasM2 = 0.5 * vecnorm(normal, 2, 2);
mesh.faceNormals = normal ./ vecnorm(normal, 2, 2);
mesh.faceCentroids = (p1 + p2 + p3) / 3;
mesh.faceSolarAbsorptivity = 0.6 * ones(4, 1);
mesh.faceIREmissivity = 0.8 * ones(4, 1);
leotherm.validateSurfaceMesh(mesh);
end
