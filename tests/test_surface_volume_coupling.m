function tests = test_surface_volume_coupling
tests = functiontests(localfunctions);
end

function testExactBoundaryMappingConservesPower(testCase)
[surface, volume] = tetraFixtures;
loads = [2; 3; 5; 7];
[nodal, d] = leotherm.coupleSurfaceToVolumeThermal(surface, volume, loads);
verifyEqual(testCase, size(nodal), [1 4]);
verifyEqual(testCase, sum(nodal, 2), sum(loads), 'AbsTol', 1e-12);
verifyEqual(testCase, d.maximumAbsoluteClosureW, 0, 'AbsTol', 1e-12);
verifyEqual(testCase, d.boundarySource, 'volumeMesh.boundaryTriangles');
verifyEqual(testCase, d.matchedBoundaryFaceCount, 4);
end

function testHeatFluxAndEpochSeriesAreSupported(testCase)
[surface, volume] = tetraFixtures;
flux = [4; 6; 8; 10];
[nodal, d] = leotherm.coupleSurfaceToVolumeThermal(surface, volume, struct('heatFluxWm2', flux));
verifyEqual(testCase, sum(nodal, 2), sum(flux .* surface.faceAreasM2), 'AbsTol', 1e-12);
verifyEqual(testCase, d.inputKind, 'heat_flux_w_m2_times_face_area');
epoch = [1 2 3 4; 2 4 6 8];
[nodalEpoch, d2] = leotherm.coupleSurfaceToVolumeThermal(surface, volume, epoch);
verifyEqual(testCase, size(nodalEpoch), [2 4]);
verifyEqual(testCase, sum(nodalEpoch, 2), sum(epoch, 2), 'AbsTol', 1e-12);
verifyEqual(testCase, d2.inputTotalPowerW, sum(epoch, 2), 'AbsTol', 1e-12);
end

function testCoupledPowerFeedsVolumeSolver(testCase)
[surface, volume] = tetraFixtures;
[~, model] = deal([], leotherm.assembleVolumeThermalModel(volume, struct( ...
    'conductivityWmK', 1, 'densityKgM3', 1000, 'specificHeatJkgK', 1000)));
[nodal, d] = leotherm.coupleSurfaceToVolumeThermal(surface, volume, [4; 0; 0; 0]);
timeS = [0; 1];
[temperature, vd] = leotherm.solveVolumeThermal(timeS, repmat(nodal, 2, 1), model, ...
    struct('initialTemperatureK', 293.15, 'maximumTemperatureK', 400));
verifyTrue(testCase, all(isfinite(temperature), 'all'));
verifyEqual(testCase, vd.integratedNodalPowerJ(end), d.inputTotalPowerW * 1, 'AbsTol', 1e-12);
end

function testNonconformingSurfaceIsRejected(testCase)
[surface, volume] = tetraFixtures;
volume.nodesM(1, :) = volume.nodesM(1, :) + [1e-3 0 0];
verifyError(testCase, @() leotherm.coupleSurfaceToVolumeThermal(surface, volume, ones(4,1)), ...
    'leotherm:MeshCouplingMismatch');
end

function testDerivedBoundaryFacetsWhenVolumeOmitsBoundaryList(testCase)
[surface, volume] = tetraFixtures;
volume = rmfield(volume, {'boundaryTriangles', 'boundaryPhysicalTags'});
[nodal, d] = leotherm.coupleSurfaceToVolumeThermal(surface, volume, ones(4,1));
verifyEqual(testCase, sum(nodal), 4, 'AbsTol', 1e-12);
verifyEqual(testCase, d.boundarySource, 'derived_exterior_tetra_facets');
end

function [surface, volume] = tetraFixtures
v = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
f = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
surface = struct('vertices', v, 'faces', f);
surface.faceNormals = zeros(4,3); surface.faceAreasM2 = zeros(4,1);
for k = 1:4
    a = v(f(k,2),:) - v(f(k,1),:); b = v(f(k,3),:) - v(f(k,1),:);
    n = cross(a,b); surface.faceAreasM2(k) = norm(n)/2; surface.faceNormals(k,:) = n/norm(n);
end
leotherm.validateSurfaceMesh(surface);
volume = struct('nodesM', v, 'tetrahedra', [1 2 3 4], ...
    'boundaryTriangles', f, 'boundaryPhysicalTags', [1; 1; 1; 1]);
leotherm.validateVolumeMesh(volume);
end
