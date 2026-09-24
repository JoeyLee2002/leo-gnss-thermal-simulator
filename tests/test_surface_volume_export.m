function tests = test_surface_volume_export
tests = functiontests(localfunctions);
end

function testCoupledResultExportIncludesAllArtifacts(testCase)
[surface, volume] = tetraFixtures;
scenario = leotherm.defaultScenario;
scenario.durationS = 20; scenario.timeStepS = 10; scenario.warmupOrbits = 0;
scenario.convergence.enabled = false; scenario.environment.freezeSunAtEpoch = true;
result = leotherm.simulateSurfaceVolumeScenario(scenario, surface, volume, ...
    struct('conductivityWmK',1,'densityKgM3',1000,'specificHeatJkgK',1000));
out = tempname; testCase.addTeardown(@() removeFolder(out));
report = leotherm.writeSurfaceVolumeScenarioResult(result, out, 'both');
verifyEqual(testCase, report.softwareVersion, leotherm.version);
verifyTrue(testCase, any(strcmp(report.sections.section, 'surface_volume_coupling')));
verifyTrue(testCase, any(strcmp(report.sections.field, 'maximum_absolute_closure')));
verifyTrue(testCase, isfile(fullfile(out, 'surface_volume_scenario_result.mat')));
verifyTrue(testCase, isfile(fullfile(out, 'surface_volume_manifest.json')));
verifyTrue(testCase, isfile(fullfile(out, 'surface_volume_coupling', ...
    'surface_volume_coupling_timeseries.csv')));
verifyTrue(testCase, isfile(fullfile(out, 'volume_thermal', 'volume_timeseries.csv')));
verifyTrue(testCase, isfile(fullfile(out, 'thermal_report', 'thermal_report_zh.md')));
verifyTrue(testCase, isfile(fullfile(out, 'thermal_report', 'thermal_report_en.md')));
text = fileread(fullfile(out, 'thermal_report', 'thermal_report_zh.md'));
verifyTrue(testCase, contains(text, 'reference_600km_nadir'));
end

function [surface, volume] = tetraFixtures
v = [0 0 0; 1 0 0; 0 1 0; 0 0 1];
f = [1 3 2; 1 2 4; 1 4 3; 2 3 4];
surface = struct('vertices',v,'faces',f,'faceNormals',zeros(4,3), ...
    'faceAreasM2',zeros(4,1),'faceSolarAbsorptivity',ones(4,1), ...
    'faceIREmissivity',0.8*ones(4,1));
for k = 1:4
    n = cross(v(f(k,2),:)-v(f(k,1),:), v(f(k,3),:)-v(f(k,1),:));
    surface.faceAreasM2(k) = norm(n)/2; surface.faceNormals(k,:) = n/norm(n);
end
volume = struct('nodesM',v,'tetrahedra',[1 2 3 4], ...
    'boundaryTriangles',f,'boundaryPhysicalTags',ones(4,1));
leotherm.validateSurfaceMesh(surface); leotherm.validateVolumeMesh(volume);
end

function removeFolder(path)
if isfolder(path), rmdir(path, 's'); end
end
