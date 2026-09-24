function tests = test_surface_volume_scenario
tests = functiontests(localfunctions);
end

function testScenarioRunsAndPreservesEnergyMapping(testCase)
[surface, volume] = tetraFixtures;
scenario = smallScenario;
material = struct('conductivityWmK', 1, 'densityKgM3', 1000, ...
    'specificHeatJkgK', 1000);
options = struct('volumeThermal', struct('initialTemperatureK', 293.15, ...
    'maximumTemperatureK', 400), ...
    'contacts', struct('leftNodes',1,'rightNodes',2,'conductanceWK',0.1));
result = leotherm.simulateSurfaceVolumeScenario(scenario, surface, volume, material, options);
verifyEqual(testCase, result.schema, 'leotherm.surface_volume_scenario_result.v1');
verifyFalse(testCase, result.provenance.surfaceTemperatureFeedback);
verifyTrue(testCase, result.provenance.exactBoundaryTriangleMatching);
verifyEqual(testCase, size(result.temperatureK), [3 4]);
verifyTrue(testCase, all(isfinite(result.temperatureK), 'all'));
verifyEqual(testCase, result.couplingDiagnostics.inputTotalPowerW, ...
    result.couplingDiagnostics.outputTotalPowerW, 'AbsTol', 1e-12);
verifyEqual(testCase, result.metrics.volumeInputEnergyJ, ...
    result.metrics.surfaceExternalEnergyJ, 'AbsTol', 1e-8);
verifyEqual(testCase, result.contactDiagnostics.pairCount, 1);
end

function testScenarioRejectsNonconformingMesh(testCase)
[surface, volume] = tetraFixtures;
volume.nodesM(1,1) = volume.nodesM(1,1) + 1e-3;
verifyError(testCase, @() leotherm.simulateSurfaceVolumeScenario( ...
    smallScenario, surface, volume, struct('conductivityWmK',1)), ...
    'leotherm:MeshCouplingMismatch');
end

function testScenarioCanUseFixedVolumeBoundary(testCase)
[surface, volume] = tetraFixtures;
thermal = struct('initialTemperatureK', 293.15, 'fixedNodeIndices', 1, ...
    'fixedTemperatureK', 300, 'maximumTemperatureK', 400);
result = leotherm.simulateSurfaceVolumeScenario(smallScenario, surface, volume, ...
    struct('conductivityWmK',1,'densityKgM3',1000,'specificHeatJkgK',1000), ...
    struct('volumeThermal',thermal));
verifyEqual(testCase, result.temperatureK(:,1), 300*ones(3,1), 'AbsTol', 1e-12);
end

function scenario = smallScenario
scenario = leotherm.defaultScenario;
scenario.durationS = 20;
scenario.timeStepS = 10;
scenario.warmupOrbits = 0;
scenario.convergence.enabled = false;
scenario.environment.freezeSunAtEpoch = true;
end

function [surface, volume] = tetraFixtures
v = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
f = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
surface = struct('vertices',v,'faces',f,'faceNormals',zeros(4,3), ...
    'faceAreasM2',zeros(4,1),'faceSolarAbsorptivity',ones(4,1), ...
    'faceIREmissivity',0.8*ones(4,1));
for k = 1:4
    n = cross(v(f(k,2),:)-v(f(k,1),:), v(f(k,3),:)-v(f(k,1),:));
    surface.faceAreasM2(k) = norm(n)/2;
    surface.faceNormals(k,:) = n/norm(n);
end
volume = struct('nodesM',v,'tetrahedra',[1 2 3 4], ...
    'boundaryTriangles',f,'boundaryPhysicalTags',ones(4,1));
leotherm.validateSurfaceMesh(surface);
leotherm.validateVolumeMesh(volume);
end
