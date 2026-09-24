function tests = test_mesh_self_shadow
tests = functiontests(localfunctions);
end

function testParallelTrianglesBlockOnlyTheRearFace(testCase)
mesh = parallelPlateMesh;
[visible, diagnostics] = leotherm.meshSolarVisibility(mesh, [0 0 1]);
verifyEqual(testCase, visible, [true; false]);
verifyEqual(testCase, diagnostics.blockedFaces, 1);
verifyEqual(testCase, diagnostics.blockerFaceIndex, [0; 1]);
verifyEqual(testCase, diagnostics.blockedFraction, 0.5, 'AbsTol', 1e-12);
end

function testSurfaceLoadsKeepEclipseAndGeometryVisibilitySeparate(testCase)
mesh = parallelPlateMesh;
mesh.solarSelfShadowing = true;
environment = struct('solarConstantWm2', 1000, 'earthIRWm2', 0, ...
    'albedo', 0, 'earthViewFactor', 0, 'daysideFactor', 0);
loads = leotherm.surfaceMeshLoads(mesh, [0 0 1], [0 0 1], 0.25, environment);
verifyEqual(testCase, loads.faceVisibleFraction, [0.25; 0], 'AbsTol', 1e-12);
verifyEqual(testCase, loads.visibleFraction, 0.25, 'AbsTol', 1e-12);
verifyTrue(testCase, loads.selfShadowing);
verifyEqual(testCase, loads.shadowDiagnostics.blockedFaces, 1);
verifyEqual(testCase, loads.directSolarW(2), 0, 'AbsTol', 1e-12);
end

function testDisabledSelfShadowingRetainsUniformEclipseFactor(testCase)
mesh = parallelPlateMesh;
environment = struct('solarConstantWm2', 1000, 'earthIRWm2', 0, ...
    'albedo', 0, 'earthViewFactor', 0, 'daysideFactor', 0);
loads = leotherm.surfaceMeshLoads(mesh, [0 0 1], [0 0 1], 0.25, environment);
verifyEqual(testCase, loads.faceVisibleFraction, 0.25 * ones(2, 1), 'AbsTol', 1e-12);
verifyFalse(testCase, loads.selfShadowing);
verifyEqual(testCase, loads.shadowDiagnostics.method, 'disabled');
end

function testSelfShadowingRejectsPerFaceEclipseArray(testCase)
mesh = parallelPlateMesh;
mesh.solarSelfShadowing = true;
environment = struct('solarConstantWm2', 1000, 'earthIRWm2', 0, ...
    'albedo', 0, 'earthViewFactor', 0, 'daysideFactor', 0);
verifyError(testCase, @() leotherm.surfaceMeshLoads(mesh, [0 0 1], ...
    [0 0 1], [0.25; 0.25], environment), 'leotherm:InvalidMeshLoads');
end

function testMeshSolarVisibilityRejectsInvalidDirection(testCase)
mesh = parallelPlateMesh;
verifyError(testCase, @() leotherm.meshSolarVisibility(mesh, [0 0 0]), ...
    'leotherm:InvalidMeshSolarVisibility');
end

function testMeshScenarioReportsSeparateVisibility(testCase)
mesh = parallelPlateMesh;
mesh.solarSelfShadowing = true;
scenario = leotherm.defaultScenario;
scenario.durationS = 60;
scenario.timeStepS = 60;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
result = leotherm.simulateSurfaceMeshScenario(scenario, mesh, ...
    struct('capacityJK', 10000 * ones(2, 1), 'maximumStepS', 10));
verifyTrue(testCase, isfield(result, 'eclipseVisibleFraction'));
verifyEqual(testCase, size(result.faceVisibleFraction), [2 2]);
verifyTrue(testCase, result.provenance.directSolarSelfShadowing);
end

function mesh = parallelPlateMesh
mesh.vertices = [0 0 0; 1 0 0; 0 1 0; 0 0 -1; 1 0 -1; 0 1 -1];
mesh.faces = [1 2 3; 4 5 6];
p1 = mesh.vertices(mesh.faces(:, 1), :);
p2 = mesh.vertices(mesh.faces(:, 2), :);
p3 = mesh.vertices(mesh.faces(:, 3), :);
normal = cross(p2 - p1, p3 - p1, 2);
mesh.faceAreasM2 = 0.5 * vecnorm(normal, 2, 2);
mesh.faceNormals = normal ./ vecnorm(normal, 2, 2);
mesh.faceCentroids = (p1 + p2 + p3) / 3;
mesh.faceSolarAbsorptivity = 0.6 * ones(2, 1);
mesh.faceIREmissivity = 0.8 * ones(2, 1);
mesh.radiationSide = 'outward';
leotherm.validateSurfaceMesh(mesh);
end
