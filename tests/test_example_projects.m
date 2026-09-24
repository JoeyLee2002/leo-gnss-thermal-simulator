function tests = test_example_projects
tests = functiontests(localfunctions);
end

function testExampleProjectsArePortableAndReadable(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
projectDir = fullfile(root, 'examples', 'projects');
expected = { ...
    '01_first_simulation.mat', ...
    '02_thermal_lag_24h.mat', ...
    '03_physical_sweep.mat', ...
    '04_telemetry_validation.mat', ...
    '05_3d_geometry.mat', ...
    '06_surface_volume_coupled.mat'};
for k = 1:numel(expected)
    path = fullfile(projectDir, expected{k});
    verifyTrue(testCase, isfile(path), ...
        sprintf('Missing example project: %s', expected{k}));
    state = leotherm.readWorkspaceProject(path);
    verifyEqual(testCase, state.version, leotherm.version);
    verifyTrue(testCase, isfield(state, 'examplePurpose'));
    verifyTrue(testCase, isstruct(state.scenario));
    verifyTrue(testCase, isstruct(state.network));
end
end

function testExampleProjectsCoverSpecializedInputs(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
telemetry = leotherm.readWorkspaceProject(fullfile(root, 'examples', ...
    'projects', '04_telemetry_validation.mat'));
geometry = leotherm.readWorkspaceProject(fullfile(root, 'examples', ...
    'projects', '05_3d_geometry.mat'));
coupled = leotherm.readWorkspaceProject(fullfile(root, 'examples', ...
    'projects', '06_surface_volume_coupled.mat'));
verifyTrue(testCase, istable(telemetry.telemetry.source));
verifyNotEmpty(testCase, telemetry.result);
verifyNotEmpty(testCase, geometry.geometry);
verifyNotEmpty(testCase, geometry.volumeMesh);
verifyNotEmpty(testCase, coupled.surfaceVolumeResult);
verifyEqual(testCase, coupled.surfaceVolumeResult.contactDiagnostics.pairCount, 1);
verifyFalse(testCase, coupled.surfaceVolumeResult.provenance.surfaceTemperatureFeedback);
verifyEqual(testCase, coupled.surfaceVolumeResult.couplingDiagnostics.maximumAbsoluteClosureW, 0, ...
    'AbsTol', 1e-12);
verifyTrue(testCase, isfile(fullfile(root, 'examples', 'projects', 'README.md')));
end
