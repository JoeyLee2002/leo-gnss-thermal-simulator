function tests = test_standalone_resources
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.root = root;
testCase.TestData.originalPath = path;
addpath(fullfile(root, 'tools'));
end

function teardownOnce(testCase)
path(testCase.TestData.originalPath);
end

function testResourcesExistAndPreserveRelativePaths(testCase)
root = testCase.TestData.root;
[resources, relative] = standalone_resources(root);
verifyNotEmpty(testCase, resources);
verifyTrue(testCase, all(cellfun(@isfile, resources)));
verifyFalse(testCase, any(cellfun(@isfolder, resources)));
verifyEqual(testCase, numel(unique(resources)), numel(resources));
for k = 1:numel(relative)
    verifyEqual(testCase, resources{k}, fullfile(root, strrep(relative{k}, '/', filesep)));
    verifyTrue(testCase, all(double(relative{k}) >= 32 & double(relative{k}) <= 126));
end
verifyEqual(testCase, standalone_resources(), resources);
end

function testNoReportsArchivesOrDocumentation(testCase)
[~, relative] = standalone_resources(testCase.TestData.root);
for k = 1:numel(relative)
    verifyEmpty(testCase, regexpi(relative{k}, ...
        '(^|/)(reports?|archive|results|docs|images|figures)(/|$)|\.(pdf|png|jpg|jpeg|gif|fig|zip|md)$', 'once'), ...
        sprintf('Unexpected non-runtime asset: %s', relative{k}));
end
verifyFalse(testCase, any(contains(relative, 'verify_sweep36_')));
end

function testRequiredExampleAndTemplateInputs(testCase)
[~, relative] = standalone_resources(testCase.TestData.root);
expected = { ...
    'VERSION'; ...
    'templates/01_first_simulation.json'; ...
    'templates/02_thermal_lag.json'; ...
    'templates/03_satmo_benchmark.json'; ...
    'templates/04_telemetry_validation.json'; ...
    'examples/projects/01_first_simulation.mat'; ...
    'examples/projects/02_thermal_lag_24h.mat'; ...
    'examples/projects/03_physical_sweep.mat'; ...
    'examples/projects/04_telemetry_validation.mat'; ...
    'examples/projects/05_3d_geometry.mat'; ...
    'examples/projects/06_surface_volume_coupled.mat'; ...
    'examples/projects/06_engineering_model_exchange.json'; ...
    'examples/assets/example_tetrahedron.obj'; ...
    'examples/assets/example_two_tetrahedra.msh'; ...
    'examples/assets/example_coupled_surface.obj'; ...
    'examples/telemetry_templates/orbit_template.csv'; ...
    'examples/telemetry_templates/heat_template.csv'; ...
    'examples/telemetry_templates/validation_template.csv'};
verifyTrue(testCase, all(ismember(expected, relative)));
verifyEqual(testCase, sum(startsWith(relative, 'examples/')), 13);
verifyEqual(testCase, sum(startsWith(relative, 'templates/')), 4);
end

function testLivePaperDependenciesAreBundled(testCase)
[~, relative] = standalone_resources(testCase.TestData.root);
names = { ...
    'paper_example_revision4'; 'run_paper_sweep36_v129'; ...
    'audit_sweep36_v129'; 'export_sweep36_open_data'; ...
    'make_sweep36_figure_v129'; 'sweep36_protocol'; ...
    'sweep36_readable_protocol'; 'sweep36_case'; ...
    'sweep36_validate_case'; 'sweep36_paths'; 'sweep36_safe_output'; ...
    'sweep36_source_fingerprint'; 'sweep36_file_sha256'; 'sweep36_write_json'};
expected = cellfun(@(name) ['studies/softwarex/sweep36/' name '.m'], ...
    names, 'UniformOutput', false);
verifyTrue(testCase, all(ismember(expected, relative)));
verifyEqual(testCase, sum(startsWith(relative, 'studies/')), numel(expected));
end

function testAllEngineSourcesRemainBundled(testCase)
root = testCase.TestData.root;
[resources, relative] = standalone_resources(root);
source = dir(fullfile(root, 'src', '**', '*.m'));
source = source(~[source.isdir]);
expected = fullfile({source.folder}, {source.name});
verifyEqual(testCase, sort(resources(startsWith(relative, 'src/'))), sort(expected(:)));
end

function testMissingRequiredResourceFailsBeforeCompilation(testCase)
root = tempname;
mkdir(fullfile(root, 'src'));
cleanup = onCleanup(@() rmdir(root, 's'));
copyfile(fullfile(testCase.TestData.root, 'src', '+leotherm', 'defaultScenario.m'), ...
    fullfile(root, 'src', 'defaultScenario.m'));
verifyError(testCase, @() standalone_resources(root), 'leotherm:StandaloneBuild');
end

function testRenamedDistributionGuidesPointToBundledFiles(testCase)
folder = tempname; mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's'));
names = {'USAGE_CN.md','USAGE_EN.md','PAPER_REPRODUCTION_CN.md','PAPER_REPRODUCTION_EN.md'};
references = {'reproduce_paper_v1.5_zh.md','reproduce_paper_v1.5.md', ...
    'usage_v1.5_zh.md','quickstart_v1.5.md'};
for k = 1:numel(names)
    fid = fopen(fullfile(folder, names{k}), 'w');
    fprintf(fid, 'See `%s` and [guide](%s).', references{k}, references{k});
    fclose(fid);
end
relocate_package_guides(folder, '1.5');
for k = 1:numel(names)
    text = fileread(fullfile(folder, names{k}));
    verifyFalse(testCase, contains(text, references{k}));
    target = names{mod(k+1,4)+1};
    verifyTrue(testCase, contains(text, ['`' target '`']));
    verifyTrue(testCase, isfile(fullfile(folder, target)));
end
before = fileread(fullfile(folder, names{1}));
relocate_package_guides(folder, '1.5');
verifyEqual(testCase, fileread(fullfile(folder, names{1})), before);
end
