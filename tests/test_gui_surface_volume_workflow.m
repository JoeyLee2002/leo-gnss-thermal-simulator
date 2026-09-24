function tests = test_gui_surface_volume_workflow
tests = functiontests(localfunctions);
end

function testGuiPublicApiRunsSavesRestoresAndExports(testCase)
if ~usejava('jvm'), return; end
root = tempname; mkdir(root); testCase.addTeardown(@() removeFolder(root));
[objPath, mshPath] = writeMeshes(root);
app = leotherm.ThermalSimulatorApp('off', 'en');
testCase.addTeardown(@() deleteIfValid(app));
app.loadSurfaceMesh(objPath, 1);
app.loadVolumeMesh(mshPath);
scenario = leotherm.defaultScenario;
scenario.durationS = 60; scenario.timeStepS = 10; scenario.warmupOrbits = 0;
scenario.convergence.enabled = false; scenario.environment.freezeSunAtEpoch = true;
material = struct('conductivityWmK',1,'densityKgM3',1000,'specificHeatJkgK',1000);
result = app.runSurfaceVolume(scenario, material, struct);
verifyEqual(testCase, result.schema, 'leotherm.surface_volume_scenario_result.v1');
verifyFalse(testCase, result.provenance.surfaceTemperatureFeedback);
state = app.getState;
verifyEqual(testCase, state.surfaceVolumeResult.schema, result.schema);

projectPath = fullfile(root, 'coupled_project.mat');
app.saveProject(projectPath, false);
restored = leotherm.ThermalSimulatorApp('off', 'zh');
testCase.addTeardown(@() deleteIfValid(restored));
restored.loadProject(projectPath);
restoredState = restored.getState;
verifyEqual(testCase, restoredState.surfaceVolumeResult.schema, result.schema);
verifyEqual(testCase, restoredState.surfaceVolumeResult.couplingDiagnostics.maximumAbsoluteClosureW, ...
    result.couplingDiagnostics.maximumAbsoluteClosureW, 'AbsTol', 1e-12);

exportPath = fullfile(root, 'export');
restored.exportResults(exportPath);
verifyTrue(testCase, isfile(fullfile(exportPath, 'surface_volume', ...
    'surface_volume_manifest.json')));
verifyTrue(testCase, isfile(fullfile(exportPath, 'surface_volume', ...
    'thermal_report', 'thermal_report_en.md')));
end

function [objPath, mshPath] = writeMeshes(root)
objPath = fullfile(root, 'tetra.obj');
fid = fopen(objPath, 'w'); cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\n');
fprintf(fid, 'f 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n');
clear cleanup
mshPath = fullfile(root, 'tetra.msh');
fid = fopen(mshPath, 'w'); cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '$MeshFormat\n2.2 0 8\n$EndMeshFormat\n$Nodes\n4\n');
fprintf(fid, '1 0 0 0\n2 1 0 0\n3 0 1 0\n4 0 0 1\n$EndNodes\n');
fprintf(fid, '$Elements\n5\n');
fprintf(fid, '1 2 1 1 1 3 2\n2 2 1 1 1 2 4\n');
fprintf(fid, '3 2 1 1 1 4 3\n4 2 1 1 2 3 4\n');
fprintf(fid, '5 4 1 1 1 2 3 4\n$EndElements\n');
clear cleanup
end

function deleteIfValid(app)
if ~isempty(app) && isvalid(app), delete(app); end
end

function removeFolder(path)
if isfolder(path), rmdir(path, 's'); end
end
