function projects = create_example_projects
%CREATE_EXAMPLE_PROJECTS Generate portable projects for first-time users.
% The generated MAT files contain complete workspace states and can be opened
% directly from the GUI Project menu.

root = fileparts(fileparts(mfilename('fullpath')));
projectDir = fullfile(root, 'examples', 'projects');
if ~isfolder(projectDir), mkdir(projectDir); end
addpath(fullfile(root, 'src'));

projects = struct('name', {}, 'path', {}, 'purpose', {});

% 1. A small, fast project for checking the installation.
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
state = app.getState;
network = state.network;
state.scenario.name = 'example_first_simulation';
state.scenario.durationS = 2 * 3600;
state.scenario.timeStepS = 60;
state.scenario.warmupOrbits = 1;
state.scenario.convergence.enabled = false;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'scenario');
saveProject(projectDir, '01_first_simulation.mat', state, ...
    '第一次使用：600 km 对地定向、2 小时快速仿真。');
projects(end + 1) = projectEntry(projectDir, '01_first_simulation.mat', ...
    '第一次使用：600 km 对地定向、2 小时快速仿真。');

% 2. A complete 24-hour thermal-lag configuration.
state = app.getState;
state.scenario.name = 'example_thermal_lag_24h';
state.scenario.durationS = 24 * 3600;
state.scenario.timeStepS = 60;
state.scenario.convergence.enabled = true;
state.scenario.warmupOrbits = 30;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'scenario');
saveProject(projectDir, '02_thermal_lag_24h.mat', state, ...
    '热滞后分析：24 小时周期热状态收敛。');
projects(end + 1) = projectEntry(projectDir, '02_thermal_lag_24h.mat', ...
    '热滞后分析：24 小时周期热状态收敛。');

% 3. A physical date/inclination/RAAN sweep configuration.
state = app.getState;
state.scenario.name = 'example_physical_sweep';
state.scenario.durationS = 3 * 3600;
state.scenario.timeStepS = 60;
state.scenario.warmupOrbits = 5;
state.scanSettings.mode = 'physical';
state.scanSettings.dates = '2024-03-20,2024-06-21,2024-09-22,2024-12-21';
state.scanSettings.altitudes = '450,600,800';
state.scanSettings.inclinations = '45,70,97.6';
state.scanSettings.raans = '0:45:315';
state.pipelineOptions.sweep = true;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'sweep');
saveProject(projectDir, '03_physical_sweep.mat', state, ...
    '参数扫描：日期、倾角、RAAN 和轨道高度物理扫描。');
projects(end + 1) = projectEntry(projectDir, '03_physical_sweep.mat', ...
    '参数扫描：日期、倾角、RAAN 和轨道高度物理扫描。');

% 4. A portable telemetry-validation project with embedded synthetic input.
[raw, telemetryScenario, options] = leotherm.telemetryDemo(network, true);
% Run the same scenario once so the validation project opens with a reference
% result ready for comparison; the telemetry result itself remains unrun.
app.runScenario(telemetryScenario, network);
app.TelemetryWorkspace.importSource(raw);
app.TelemetryWorkspace.setWorkflow('validation');
state = app.getState;
state.scenario.name = 'example_telemetry_validation';
state.scenario.durationS = telemetryScenario.durationS;
state.scenario.timeStepS = telemetryScenario.timeStepS;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'scenario');
state.telemetry.options = options;
state.pipelineOptions.telemetry = true;
saveProject(projectDir, '04_telemetry_validation.mat', state, ...
    '遥测验证：内置合成输入，仅用于熟悉导入、映射和预检流程。');
projects(end + 1) = projectEntry(projectDir, '04_telemetry_validation.mat', ...
    '遥测验证：内置合成输入，仅用于熟悉导入、映射和预检流程。');

% 5. A geometry project covering both surface and volume input paths.
app.TelemetryWorkspace.setWorkflow('orbit');
objPath = fullfile(root, 'examples', 'assets', 'example_tetrahedron.obj');
mshPath = fullfile(root, 'examples', 'assets', 'example_two_tetrahedra.msh');
app.loadSurfaceMesh(objPath, 1);
app.setSurfaceMeshThermal(10000 * ones(4, 1), 293.15 * ones(4, 1), zeros(4), ...
    'example_declared_mesh_inputs');
app.loadVolumeMesh(mshPath);
state = app.getState;
state.scenario.name = 'example_3d_geometry';
state.scenario.durationS = 600;
state.scenario.timeStepS = 60;
state.scenario.convergence.enabled = false;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'scenario', ...
    state.geometry, state.volumeMesh);
saveProject(projectDir, '05_3d_geometry.mat', state, ...
    '三维输入：STL/OBJ 面片和 Gmsh 四面体体网格。两条求解链彼此独立。');
projects(end + 1) = projectEntry(projectDir, '05_3d_geometry.mat', ...
    '三维输入：STL/OBJ 面片和 Gmsh 四面体体网格。两条求解链彼此独立。');

% 6. A runnable, explicit one-way surface-volume coupling example.
% The surface and volume meshes are conforming by construction. Contact and
% fixed-temperature inputs are declared explicitly; nothing is inferred.
coupledSurfacePath = fullfile(root, 'examples', 'assets', 'example_coupled_surface.obj');
app.loadSurfaceMesh(coupledSurfacePath, 1);
app.setSurfaceMeshThermal(10000 * ones(6, 1), 293.15 * ones(6, 1), zeros(6), ...
    'example_declared_coupled_surface_inputs');
coupledOptions = struct( ...
    'contacts', struct('leftNodes', 1, 'rightNodes', 5, 'conductanceWK', 0.25), ...
    'volumeThermal', struct('initialTemperatureK', 293.15, ...
        'fixedNodeIndices', 1, 'fixedTemperatureK', 293.15, ...
        'maximumTemperatureK', 500));
coupledMaterial = struct('conductivityWmK', 3, 'densityKgM3', 2700, ...
    'specificHeatJkgK', 900);
coupledResult = app.runSurfaceVolume(state.scenario, coupledMaterial, coupledOptions); %#ok<NASGU>
state = app.getState;
state.scenario.name = 'example_surface_volume_coupled';
state.pipelineOptions.geometry = true;
state.task = leotherm.createSimulationTask(state.scenario, state.network, ...
    state.telemetry, state.calibration, state.scanSettings, 'scenario', ...
    state.geometry, state.volumeMesh);
saveProject(projectDir, '06_surface_volume_coupled.mat', state, ...
    '完整耦合：严格共同边界面、守恒外部热流、体内导热、显式接触和固定温度边界。');
projects(end + 1) = projectEntry(projectDir, '06_surface_volume_coupled.mat', ...
    '完整耦合：严格共同边界面、守恒外部热流、体内导热、显式接触和固定温度边界。');

writeIndex(projectDir, projects);
clear cleanup
if nargout == 0
    disp(struct2table(projects));
end
end

function saveProject(projectDir, fileName, state, purpose)
state.examplePurpose = purpose;
path = fullfile(projectDir, fileName);
if isfile(path), delete(path); end
leotherm.writeWorkspaceProject(path, state, false);
end

function entry = projectEntry(projectDir, fileName, purpose)
entry.name = fileName;
entry.path = fullfile(projectDir, fileName);
entry.purpose = purpose;
end

function writeIndex(projectDir, projects)
fid = fopen(fullfile(projectDir, 'README.md'), 'w');
assert(fid >= 0, 'Cannot write example-project index.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# 示例项目\n\n');
fprintf(fid, '这些 MAT 文件可以通过 GUI 的“打开项目”直接载入。它们用于熟悉软件流程，不代表具体卫星标定结果。\n\n');
for k = 1:numel(projects)
    fprintf(fid, '- `%s`：%s\n', projects(k).name, projects(k).purpose);
end
end
