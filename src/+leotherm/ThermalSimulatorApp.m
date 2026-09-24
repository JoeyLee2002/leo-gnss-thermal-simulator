classdef ThermalSimulatorApp < handle
    %THERMALSIMULATORAPP Interactive workbench for orbit-thermal studies.

    properties (SetAccess = private)
        Figure
        TelemetryWorkspace
        CalibrationWorkspace
    end

    properties (Access = private)
        RootGrid
        TabGroup
        MainTabGroup
        QuickStartTab
        SimulationTab
        TaskStatusLabel
        TaskSummaryLabel
        TaskGuidanceLabel
        TaskCheckButton
        TaskRunButton
        TaskSweepButton
        TaskResultsButton
        QuickStartTemplate
        QuickStartRunButton
        QuickStartWizardButton
        QuickStartOpenButton
        QuickStartExamplesButton
        QuickStartAdvancedButton
        QuickStartInfoLabel
        ScenarioTab
        SweepTab
        NetworkTab
        GeometryTab
        ThermalModelTab
        ResultsTab
        StatusLabel
        VersionLabel
        SelfTestButton
        LoadConfigButton
        SaveConfigButton
        LanguageDropdown

        StartDate
        StartTime
        ResultStateLabel
        DurationHours
        TimeStepS
        WarmupOrbits
        AltitudeKm
        InclinationDeg
        RaanDeg
        ArgumentLatitudeDeg
        UseJ2
        AttitudeMode
        RollDeg
        PitchDeg
        YawDeg
        DirectSolar
        Albedo
        EarthIR
        EarthIRModel
        UseConvergence
        RunScenarioButton
        ScenarioAxes

        ScanMode
        ScanAltitudeList
        ScanBetaList
        ScanBranch
        ScanDateList
        ScanInclinationList
        ScanRaanList
        RunSweepButton
        SweepAxes
        SweepTable

        NetworkPreset
        ResetNetworkButton
        NetworkActions
        NodeTable
        ConductanceTable
        ResponseRole
        AntennaRole
        OscillatorRole
        QuadraticNode
        QuadraticCoefficient
        ApplyRolesButton

        MeshAxes
        MeshStatusLabel
        MeshStatsLabel
        MeshUnit
        MeshRadiationSide
        MeshSelfShadowing
        MeshDisplayMode
        MeshImportButton
        MeshPreviewButton
        MeshThermalRunButton
        MeshClearButton
        VolumeImportButton
        VolumeRunButton
        CoupledRunButton
        CouplingOptionsButton
        VolumeStatusLabel
        VolumeConductivity
        VolumeDensity
        VolumeSpecificHeat

        ThermalModelImportButton
        ThermalModelExportMATButton
        ThermalModelExportJSONButton
        ThermalModelMappingImportButton
        ThermalModelMappingTemplateButton
        ThermalModelMappingPreviewButton
        ThermalModelMappingApplyButton
        ThermalModelMappingRollbackButton
        ThermalModelStatusLabel
        ThermalModelSummary

        MetricsTable
        SessionSummary
        ResultConclusionLabel
        ExportResultsButton

        CurrentScenario
        CurrentNetwork
        CurrentGeometry = []
        CurrentMeshResult = []
        CurrentVolumeMesh = []
        CurrentVolumeModel = []
        CurrentVolumeResult = []
        CurrentSurfaceVolumeResult = []
        CouplingOptions = struct('contacts', struct([]), 'volumeThermal', struct( ...
            'initialTemperatureK', 293.15, 'fixedNodeIndices', [], ...
            'fixedTemperatureK', 293.15, 'maximumTemperatureK', 500))
        CurrentThermalModel = []
        CurrentThermalModelMapping = []
        CurrentThermalModelPreview = []
        ThermalModelNetworkRollback = []
        CurrentResult
        CurrentSweep
        CurrentSweepMode
        CurrentTask = []
        LastTaskSnapshot = []
        TaskValidation = []
        TaskHistory = struct('taskId', {}, 'runType', {}, 'status', {}, ...
            'startedUTC', {}, 'completedUTC', {}, 'inputFingerprint', {})
        SweepContext = []
        ProjectPath = ''
        ActiveTemplateId = ''
        ActiveTemplatePath = ''
        ActiveTemplateSnapshot = []
        SavedProjectState = []
        BusyControls = {}
        Language = 'zh'
        IsBusy = false
        ProgressDialog
    end

    methods
        function app = ThermalSimulatorApp(visibility, language)
            if nargin < 1 || isempty(visibility)
                visibility = 'on';
            end
            if nargin < 2 || isempty(language)
                language = 'zh';
            end
            if ~usejava('jvm')
                error('leotherm:DesktopRequired', ...
                    'ThermalSimulatorApp requires MATLAB with Java enabled.');
            end
            app.Language = leotherm.normalizeLanguage(language);
            app.CurrentScenario = leotherm.defaultScenario;
            app.CurrentNetwork = leotherm.defaultReceiverNetwork;
            app.CurrentGeometry = [];
            app.CurrentMeshResult = [];
            app.CurrentVolumeMesh = [];
            app.CurrentVolumeModel = [];
            app.CurrentVolumeResult = [];
            app.CurrentSurfaceVolumeResult = [];
            app.CouplingOptions = leotherm.defaultCouplingOptions;
            app.CurrentThermalModel = [];
            app.CurrentThermalModelMapping = [];
            app.CurrentThermalModelPreview = [];
            app.ThermalModelNetworkRollback = [];
            app.CurrentResult = [];
            app.CurrentSweep = table;
            app.CurrentSweepMode = '';
            app.createComponents(visibility);
            app.syncScenarioControls;
            app.syncNetworkControls;
            if ~isempty(app.CurrentGeometry) && ~isempty(app.MeshRadiationSide) ...
                    && isvalid(app.MeshRadiationSide)
                app.MeshRadiationSide.Value = app.CurrentGeometry.radiationSide;
            end
            app.updateMeshUI;
            app.CalibrationWorkspace.loadCurrentDevice;
            app.updateResultSummary;
            % Show the initial configuration state before the first edit.
            app.updateTaskPanel;
            app.updateResultState;
            app.updateQuickStartPanel;
            setappdata(app.Figure, 'LEOThermalSimulatorApp', app);
            app.SavedProjectState = app.getState;
        end

        function delete(app)
            if ~isempty(app.ProgressDialog) && isvalid(app.ProgressDialog)
                close(app.ProgressDialog);
            end
            if ~isempty(app.Figure) && isvalid(app.Figure)
                app.Figure.CloseRequestFcn = [];
                delete(app.Figure);
            end
        end

        function state = getState(app)
            %GETSTATE Return the current GUI model without UI handles.
            state.version = leotherm.version;
            state.scenario = app.collectScenario;
            state.network = app.CurrentNetwork;
            state.geometry = app.CurrentGeometry;
            state.meshResult = app.CurrentMeshResult;
            state.volumeMesh = app.CurrentVolumeMesh;
            state.volumeModel = app.CurrentVolumeModel;
            state.volumeResult = app.CurrentVolumeResult;
            state.surfaceVolumeResult = app.CurrentSurfaceVolumeResult;
            state.surfaceVolumeOptions = app.CouplingOptions;
            state.thermalModel = app.CurrentThermalModel;
            state.thermalModelMapping = app.CurrentThermalModelMapping;
            state.thermalModelPreview = app.CurrentThermalModelPreview;
            state.thermalModelNetworkRollback = app.ThermalModelNetworkRollback;
            state.result = app.CurrentResult;
            state.sweep = app.CurrentSweep;
            state.sweepMode = app.CurrentSweepMode;
            state.language = app.Language;
            state.busy = app.IsBusy;
            state.sweepContext = app.SweepContext;
            state.scanSettings = app.captureScanSettings;
            state.resultStale = app.resultIsStale;
            state.sweepStale = app.sweepIsStale;
            if ~isempty(app.TelemetryWorkspace)
                state.telemetry = app.TelemetryWorkspace.getState;
            end
            if ~isempty(app.CalibrationWorkspace)
                state.calibration = app.CalibrationWorkspace.getState;
            end
            state.task = app.buildSimulationTask(state.scenario, state.network, ...
                state.telemetry, state.calibration, state.scanSettings, 'scenario');
            state.taskValidation = app.taskValidationReport(state.task);
            state.lastTaskSnapshot = app.LastTaskSnapshot;
            state.taskHistory = app.TaskHistory;
            state.activeTemplateId = app.ActiveTemplateId;
            state.activeTemplatePath = app.ActiveTemplatePath;
            state.activeTemplateSnapshot = app.ActiveTemplateSnapshot;
            state.task.template = app.ActiveTemplateSnapshot;
        end

        function setLanguage(app, language)
            %SETLANGUAGE Rebuild all visible controls in one language.
            language = leotherm.normalizeLanguage(language);
            if strcmp(language, app.Language)
                return
            end
            app.CurrentScenario = app.collectScenario;
            app.Language = language;
            app.rebuildInterface;
        end

        function result = runScenario(app, scenario, network)
            %RUNSCENARIO Execute and display one scenario programmatically.
            if nargin < 2 || isempty(scenario)
                scenario = app.collectScenario;
            end
            if nargin < 3 || isempty(network)
                network = app.CurrentNetwork;
            end
            leotherm.validateScenario(scenario);
            leotherm.validateNetwork(network);
            result = leotherm.simulateScenario(scenario, network);
            result.geometry = app.CurrentGeometry;
            task = leotherm.createSimulationTask(scenario, network, ...
                app.TelemetryWorkspace.getState, app.CalibrationWorkspace.getState, ...
                app.captureScanSettings, 'scenario', app.CurrentGeometry, app.CurrentVolumeMesh);
            snapshot = leotherm.freezeSimulationTask(task);
            result.taskId = snapshot.taskId;
            result.taskInputFingerprint = snapshot.inputFingerprint;
                app.CurrentScenario = scenario;
                app.CurrentNetwork = network;
            app.CurrentResult = result;
            app.CurrentTask = snapshot;
            app.LastTaskSnapshot = snapshot;
            app.recordTaskRun(snapshot, 'scenario', 'complete');
            app.syncScenarioControls;
            app.syncNetworkControls;
            app.updateScenarioPlots;
            app.updateResultSummary;
        end

        function summary = runSweep(app, mode, scenario, network, varargin)
            %RUNSWEEP Execute and display a parameter sweep programmatically.
            leotherm.validateScenario(scenario);
            leotherm.validateNetwork(network);
            switch lower(mode)
                case 'beta_altitude'
                    if numel(varargin) ~= 3
                        error('leotherm:InvalidSweepInput', ...
                            'beta_altitude requires altitudeKm, betaDeg, and branch.');
                    end
                    summary = leotherm.runBetaAltitudeSweep(scenario, network, ...
                        varargin{1}, varargin{2}, varargin{3});
                case 'physical'
                    if numel(varargin) ~= 4
                        error('leotherm:InvalidSweepInput', ...
                            ['physical requires dates, altitudeKm, ' ...
                            'inclinationDeg, and raanDeg.']);
                    end
                    summary = leotherm.runPhysicalSweep(scenario, network, ...
                        varargin{1}, varargin{2}, varargin{3}, varargin{4});
                otherwise
                    error('leotherm:InvalidSweepInput', ...
                        'Sweep mode must be beta_altitude or physical.');
            end
                app.CurrentScenario = scenario;
                app.CurrentNetwork = network;
            app.CurrentSweep = summary;
            app.CurrentSweepMode = lower(mode);
            app.SweepContext = struct('scenario',scenario,'network',network,'mode',lower(mode), ...
                'scanSettings',app.captureScanSettings,'arguments',{varargin}, ...
                'geometry',app.CurrentGeometry);
            task = leotherm.createSimulationTask(scenario, network, ...
                app.TelemetryWorkspace.getState, app.CalibrationWorkspace.getState, ...
                app.captureScanSettings, 'sweep', app.CurrentGeometry, app.CurrentVolumeMesh);
            snapshot = leotherm.freezeSimulationTask(task);
            app.CurrentTask = snapshot;
            app.LastTaskSnapshot = snapshot;
            app.recordTaskRun(snapshot, 'sweep', 'complete');
            app.updateSweepPlots;
            app.updateResultSummary;
        end

        function mesh = loadSurfaceMesh(app, filePath, unitScale)
            %LOADSURFACEMESH Load a surface mesh through the public app API.
            if nargin < 3 || isempty(unitScale), unitScale = 1; end
            if ~isnumeric(unitScale) || ~isscalar(unitScale) || ~isfinite(unitScale) || unitScale <= 0
                error('leotherm:InvalidMeshScale', 'unitScale must be one positive finite scale to metres.');
            end
            mesh = leotherm.readSurfaceMesh(filePath);
            mesh.vertices = mesh.vertices * unitScale;
            mesh.faceAreasM2 = mesh.faceAreasM2 * unitScale^2;
            mesh.faceCentroids = mesh.faceCentroids * unitScale;
            mesh.totalAreaM2 = sum(mesh.faceAreasM2);
            mesh.boundingBoxM = [min(mesh.vertices, [], 1); max(mesh.vertices, [], 1)];
            mesh.sourceUnitScaleToM = unitScale;
            if ~isempty(app.MeshRadiationSide) && isvalid(app.MeshRadiationSide)
                mesh.radiationSide = app.MeshRadiationSide.Value;
            end
            if ~isempty(app.MeshSelfShadowing) && isvalid(app.MeshSelfShadowing)
                mesh.solarSelfShadowing = strcmp(app.MeshSelfShadowing.Value, 'on');
            end
            leotherm.validateSurfaceMesh(mesh);
            app.CurrentGeometry = mesh;
            app.CurrentMeshResult = [];
            app.CurrentSurfaceVolumeResult = [];
            if ~isempty(app.MeshStatusLabel) && isvalid(app.MeshStatusLabel)
                app.updateMeshUI;
                app.updateTaskPanel;
                app.updateResultState;
            end
        end

        function result = runSurfaceMesh(app, scenario, thermal)
            %RUNSURFACEMESH Run and retain a face-resolved mesh result.
            if nargin < 2 || isempty(scenario), scenario = app.collectScenario; end
            if nargin < 3, thermal = struct; end
            if isempty(app.CurrentGeometry)
                error('leotherm:NoSurfaceMesh', 'Load a surface mesh before running the face solver.');
            end
            result = leotherm.simulateSurfaceMeshScenario(scenario, app.CurrentGeometry, thermal);
            app.CurrentMeshResult = result;
            app.CurrentSurfaceVolumeResult = [];
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function result = runSurfaceVolume(app, scenario, material, options)
            %RUNSURFACEVOLUME Run and retain the public coupled 3-D workflow.
            if nargin < 2 || isempty(scenario), scenario = app.collectScenario; end
            if nargin < 3 || isempty(material)
                material = struct('conductivityWmK', app.VolumeConductivity.Value, ...
                    'densityKgM3', app.VolumeDensity.Value, ...
                    'specificHeatJkgK', app.VolumeSpecificHeat.Value);
            end
            if nargin < 4 || isempty(options), options = app.CouplingOptions; end
            if isempty(app.CurrentGeometry)
                error('leotherm:NoSurfaceMesh', 'Load a surface mesh before the coupled 3-D run.');
            end
            if isempty(app.CurrentVolumeMesh)
                error('leotherm:NoVolumeMesh', 'Load a Gmsh volume mesh before the coupled 3-D run.');
            end
            boundaryOptions = leotherm.normalizeCouplingOptions(options, app.CurrentVolumeMesh);
            options.contacts = boundaryOptions.contacts;
            options.volumeThermal = boundaryOptions.volumeThermal;
            result = leotherm.simulateSurfaceVolumeScenario(scenario, ...
                app.CurrentGeometry, app.CurrentVolumeMesh, material, options);
            app.CurrentScenario = scenario;
            app.syncScenarioControls;
            app.CurrentSurfaceVolumeResult = result;
            app.CouplingOptions = boundaryOptions;
            app.CurrentMeshResult = result.surface;
            app.CurrentVolumeModel = result.volume.model;
            app.CurrentVolumeResult = result.volume;
            app.updateMeshUI;
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function mesh = loadVolumeMesh(app, filePath)
            %LOADVOLUMEMESH Load an ASCII Gmsh 2.x tetrahedral mesh.
            mesh = leotherm.readVolumeMesh(filePath);
            app.CurrentVolumeMesh = mesh;
            app.CurrentVolumeModel = [];
            app.CurrentVolumeResult = [];
            app.CurrentSurfaceVolumeResult = [];
            app.updateVolumeUI;
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function [model, report] = loadThermalModel(app, filePath)
            %LOADTHERMALMODEL Import and validate a canonical MAT/JSON model.
            % Validation is completed before CurrentThermalModel is replaced,
            % so a failed import cannot mutate the active workspace.
            if app.IsBusy
                error('leotherm:ProjectBusy', 'Wait for the current operation before importing a thermal model.');
            end
            try
                [candidate, candidateReport] = leotherm.io.importThermalModel(filePath);
            catch primaryException
                % The model package uses the network/geometry canonical form,
                % while the exchange adapter uses metadata/nodes form.  Accept
                % the former here as well, but only after its own full validator.
                [candidate, candidateReport, accepted] = app.importNormalizedThermalModel(filePath);
                if ~accepted, rethrow(primaryException); end
            end
            % Keep the assignment as the final operation after all checks.
            previousNetwork = app.CurrentNetwork;
            app.CurrentThermalModel = candidate;
            app.CurrentThermalModelMapping = [];
            app.CurrentThermalModelPreview = [];
            app.ThermalModelNetworkRollback = previousNetwork;
            model = candidate;
            report = candidateReport;
            app.updateThermalModelUI;
            app.updateResultState;
            app.setStatus(sprintf(app.t('工程热模型已载入：%s', ...
                'Engineering thermal model loaded: %s'), char(filePath)));
        end

        function [model, report] = importThermalModel(app, filePath)
            %IMPORTTHERMALMODEL Programmatic alias for loadThermalModel.
            [model, report] = app.loadThermalModel(filePath);
        end

        function [mapping, report] = loadThermalModelMapping(app, filePath)
            %LOADTHERMALMODELMAPPING Load an explicit mapping without guessing.
            if app.IsBusy
                error('leotherm:ProjectBusy', 'Wait for the current operation before loading a mapping.');
            end
            [candidate, candidateReport] = app.readThermalModelMapping(filePath);
            if ~isempty(app.CurrentThermalModel)
                leotherm.model.validateNetworkMapping(app.CurrentThermalModel, app.CurrentNetwork, candidate);
            end
            app.CurrentThermalModelMapping = candidate;
            app.CurrentThermalModelPreview = [];
            mapping = candidate;
            report = candidateReport;
            app.updateThermalModelUI;
            app.setStatus(sprintf(app.t('显式映射已载入：%s', 'Explicit mapping loaded: %s'), char(filePath)));
        end

        function mapping = generateThermalModelMappingTemplate(app)
            %GENERATETHERMALMODELMAPPINGTEMPLATE Generate a blank explicit template.
            if isempty(app.CurrentThermalModel)
                error('leotherm:ThermalModelUnavailable', 'Load an engineering thermal model first.');
            end
            if isfield(app.CurrentThermalModel, 'nodes')
                nodes = app.CurrentThermalModel.nodes;
                ids = cell(numel(nodes), 1);
                for k = 1:numel(nodes), ids{k} = char(string(nodes(k).id)); end
            else
                ids = app.CurrentThermalModel.network.nodeNames(:);
            end
            entries = repmat(struct('exchangeNodeId', '', 'networkNodeIndex', [], 'fields', {{}}), numel(ids), 1);
            for k = 1:numel(ids), entries(k).exchangeNodeId = ids{k}; end
            mapping = struct('schema', 'leotherm.thermal_model_mapping.v1', ...
                'allowedFields', {{'capacityJK','internalPowerW','projectedAreaM2','radiatingAreaM2', ...
                'solarAbsorptivity','irEmissivity','initialTemperatureK'}}, 'entries', entries);
            app.CurrentThermalModelMapping = mapping;
            app.CurrentThermalModelPreview = [];
            app.updateThermalModelUI;
            app.setStatus(app.t('已生成空白显式映射模板；请填写每个网络节点索引后预览。', ...
                'Blank explicit mapping template generated; fill each network node index before previewing.'));
        end

        function preview = previewThermalModelMapping(app, mapping)
            %PREVIEWTHERMALMODELMAPPING Preview writes and retain the report.
            if nargin < 2 || isempty(mapping), mapping = app.CurrentThermalModelMapping; end
            if isempty(app.CurrentThermalModel)
                error('leotherm:ThermalModelUnavailable', 'Load an engineering thermal model first.');
            end
            if isempty(mapping)
                error('leotherm:NetworkMappingUnavailable', 'Load or generate an explicit mapping first.');
            end
            preview = leotherm.model.previewNetworkMapping(app.CurrentThermalModel, app.CurrentNetwork, mapping);
            app.CurrentThermalModelMapping = mapping;
            app.CurrentThermalModelPreview = preview;
            app.updateThermalModelUI;
        end

        function [network, result] = applyThermalModelMapping(app, confirmationToken)
            %APPLYTHERMALMODELMAPPING Apply only a matching, reviewed preview.
            if isempty(app.CurrentThermalModelPreview)
                error('leotherm:NetworkMappingPreviewRequired', 'Preview the mapping before applying it.');
            end
            if nargin < 2 || isempty(confirmationToken)
                error('leotherm:NetworkMappingConfirmationRequired', 'A preview confirmation token is required.');
            end
            [network, result] = leotherm.model.applyNetworkMapping(app.CurrentThermalModel, ...
                app.CurrentNetwork, app.CurrentThermalModelMapping, 'ConfirmationToken', confirmationToken);
            app.CurrentNetwork = network;
            app.CurrentThermalModelPreview = [];
            app.CurrentResult = [];
            app.CurrentSweep = table;
            app.CurrentSweepMode = '';
            app.SweepContext = [];
            task = app.buildSimulationTask(app.collectScenario, app.CurrentNetwork, ...
                app.TelemetryWorkspace.getState, app.CalibrationWorkspace.getState, ...
                app.captureScanSettings, 'scenario');
            app.CurrentTask = leotherm.freezeSimulationTask(task);
            app.LastTaskSnapshot = app.CurrentTask;
            app.syncNetworkControls;
            app.updateThermalModelUI;
            app.updateTaskPanel;
            app.updateResultSummary;
            app.updateResultState;
            app.setStatus(sprintf(app.t('显式映射已应用（%d 个字段）；可回滚。', ...
                'Explicit mapping applied (%d fields); rollback is available.'), result.changedFieldCount));
        end

        function network = rollbackThermalModelNetwork(app)
            %ROLLBACKTHERMALMODELNETWORK Restore the network captured on import.
            if isempty(app.ThermalModelNetworkRollback)
                error('leotherm:NetworkMappingRollbackUnavailable', 'No pre-import network is available for rollback.');
            end
            network = app.ThermalModelNetworkRollback;
            leotherm.validateNetwork(network);
            app.CurrentNetwork = network;
            app.CurrentThermalModelPreview = [];
            app.CurrentResult = [];
            app.CurrentSweep = table;
            app.CurrentSweepMode = '';
            app.SweepContext = [];
            task = app.buildSimulationTask(app.collectScenario, app.CurrentNetwork, ...
                app.TelemetryWorkspace.getState, app.CalibrationWorkspace.getState, ...
                app.captureScanSettings, 'scenario');
            app.CurrentTask = leotherm.freezeSimulationTask(task);
            app.LastTaskSnapshot = app.CurrentTask;
            app.syncNetworkControls;
            app.updateThermalModelUI;
            app.updateTaskPanel;
            app.updateResultSummary;
            app.updateResultState;
            app.setStatus(app.t('已回滚到工程热模型导入前的热网络。', ...
                'Rolled back to the thermal network captured before model import.'));
        end

        function report = saveThermalModel(app, filePath)
            %SAVETHERMALMODEL Export the active canonical model to MAT/JSON.
            if isempty(app.CurrentThermalModel)
                error('leotherm:ThermalModelUnavailable', ...
                    'No canonical engineering thermal model is loaded.');
            end
            [~, ~, ext] = fileparts(char(filePath));
            try
                report = leotherm.io.exportThermalModel(app.CurrentThermalModel, filePath, ...
                    'PrettyPrint', strcmpi(ext, '.json'));
            catch primaryException
                if ~isfield(app.CurrentThermalModel, 'network')
                    rethrow(primaryException);
                end
                % Preserve the +model canonical contract when exporting a
                % normalized workspace model; no solver state is changed.
                leotherm.model.validate(app.CurrentThermalModel);
                if strcmpi(ext, '.json')
                    text = jsonencode(app.CurrentThermalModel);
                    fid = fopen(char(filePath), 'w', 'n', 'UTF-8');
                    if fid < 0, rethrow(primaryException); end
                    cleaner = onCleanup(@() fclose(fid));
                    fwrite(fid, unicode2native(text, 'UTF-8'), 'uint8');
                    clear cleaner;
                    info = dir(char(filePath));
                    report = struct('path', char(filePath), 'format', 'json', ...
                        'bytes', info.bytes, 'schema', app.CurrentThermalModel.schema);
                elseif strcmpi(ext, '.mat')
                    thermalModel = app.CurrentThermalModel;
                    save(char(filePath), 'thermalModel', '-v7.3');
                    clear thermalModel
                    info = dir(char(filePath));
                    report = struct('path', char(filePath), 'format', 'mat', ...
                        'bytes', info.bytes, 'schema', app.CurrentThermalModel.schema);
                else
                    rethrow(primaryException);
                end
            end
            app.setStatus(sprintf(app.t('工程热模型已导出：%s', ...
                'Engineering thermal model exported: %s'), char(filePath)));
        end

        function report = exportThermalModel(app, filePath)
            %EXPORTTHERMALMODEL Programmatic alias for saveThermalModel.
            report = app.saveThermalModel(filePath);
        end

        function result = runVolumeThermal(app, timeS, nodalPowerW, material, thermal)
            %RUNVOLUMETHERMAL Assemble and solve the independent volume path.
            if isempty(app.CurrentVolumeMesh)
                error('leotherm:NoVolumeMesh', 'Load a Gmsh volume mesh before running volume thermal simulation.');
            end
            if nargin < 4 || isempty(material), material = struct; end
            if nargin < 5, thermal = struct; end
            app.CurrentVolumeModel = leotherm.assembleVolumeThermalModel(app.CurrentVolumeMesh, material);
            [temperatureK, diagnostics] = leotherm.solveVolumeThermal(timeS, nodalPowerW, ...
                app.CurrentVolumeModel, thermal);
            app.CurrentVolumeResult = struct('mesh', app.CurrentVolumeMesh, ...
                'model', app.CurrentVolumeModel, 'timeS', timeS(:), ...
                'nodalPowerW', nodalPowerW, 'temperatureK', temperatureK, ...
                'diagnostics', diagnostics);
            app.CurrentSurfaceVolumeResult = [];
            result = app.CurrentVolumeResult;
            app.updateVolumePlot;
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function mesh = setSurfaceMeshThermal(app, capacityJK, initialTemperatureK, conductanceWK, provenance)
            %SETSURFACEMESHTHERMAL Set auditable thermal inputs for the loaded mesh.
            if isempty(app.CurrentGeometry)
                error('leotherm:NoSurfaceMesh', ...
                    'Load a surface mesh before setting face thermal inputs.');
            end
            nFace = size(app.CurrentGeometry.faces, 1);
            mesh = app.CurrentGeometry;
            mesh.faceHeatCapacityJK = app.validateFaceVector(capacityJK, nFace, 'capacityJK');
            mesh.faceInitialTemperatureK = app.validateFaceVector(initialTemperatureK, nFace, 'initialTemperatureK');
            if nargin >= 4 && ~isempty(conductanceWK)
                if ~isnumeric(conductanceWK) || ~isequal(size(conductanceWK), [nFace nFace])
                    error('leotherm:InvalidMeshThermalInput', ...
                        'conductanceWK must be an N-by-N matrix.');
                end
                mesh.faceConductanceWK = conductanceWK;
            end
            if nargin < 5 || isempty(provenance)
                provenance = 'user_declared_mesh_thermal_inputs';
            end
            mesh.thermalParameterProvenance = char(provenance);
            leotherm.validateSurfaceMesh(mesh);
            app.CurrentGeometry = mesh;
            app.CurrentMeshResult = [];
            app.CurrentSurfaceVolumeResult = [];
            app.updateMeshUI;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function saveProject(app,path,overwrite)
            if nargin<3, overwrite=false; end
            if app.IsBusy, error('leotherm:ProjectBusy','Wait for the current operation before saving.'); end
            state = app.getState;
            app.ProjectPath = leotherm.writeWorkspaceProject(path,state,overwrite);
            app.SavedProjectState = state;
            app.updateResultState;
        end

        function loadProject(app,path)
            if app.IsBusy, error('leotherm:ProjectBusy','Wait for the current operation before opening a project.'); end
            state = leotherm.readWorkspaceProject(path);
            previous = app.getState;
            try
                app.applyWorkspaceState(state);
            catch exception
                app.applyWorkspaceState(previous);
                rethrow(exception);
            end
            app.ProjectPath = char(java.io.File(char(path)).getCanonicalPath());
            app.SavedProjectState = app.getState;
            app.updateResultState;
        end

        function changed = hasUnsavedChanges(app)
            try
                changed = ~isequaln(app.getState,app.SavedProjectState);
            catch
                changed = true;
            end
        end

        function exportResults(app,directory)
            telemetryState = app.TelemetryWorkspace.getState;
            if isempty(app.CurrentResult) && isempty(app.CurrentSweep) ...
                    && isempty(app.CurrentMeshResult) && isempty(app.CurrentVolumeResult) ...
                    && isempty(app.CurrentSurfaceVolumeResult) ...
                    && isempty(telemetryState.result) && isempty(telemetryState.report)
                error('leotherm:ExportFailed','There are no results to export.');
            end
            target = java.io.File(char(directory));
            if ~target.isAbsolute(), target = java.io.File(fullfile(pwd,char(directory))); end
            directory = char(target.getCanonicalPath());
            if ~target.mkdirs(), error('leotherm:ExportFailed','Select a new result directory.'); end
            if ~isempty(app.CurrentResult)
                leotherm.writeScenario(app.CurrentResult,fullfile(directory,'scenario'));
                scenario = app.CurrentResult.scenario; network = app.CurrentResult.network;
                save(fullfile(directory,'scenario_configuration.mat'),'scenario','network');
            end
            if ~isempty(app.CurrentGeometry)
                exportData = struct('geometry', app.CurrentGeometry);
                save(fullfile(directory,'surface_mesh.mat'), '-struct', 'exportData', '-v7.3');
            end
            if ~isempty(app.CurrentMeshResult)
                leotherm.writeSurfaceMeshResult(app.CurrentMeshResult, ...
                    fullfile(directory, 'surface_mesh'));
            end
            if ~isempty(app.CurrentVolumeResult)
                leotherm.writeVolumeThermalResult(app.CurrentVolumeResult, ...
                    fullfile(directory, 'volume_mesh'));
            end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                leotherm.writeSurfaceVolumeScenarioResult(app.CurrentSurfaceVolumeResult, ...
                    fullfile(directory, 'surface_volume'), app.Language);
            end
            if ~isempty(app.CurrentSweep)
                summary = app.CurrentSweep; context = app.SweepContext;
                save(fullfile(directory,'sweep.mat'),'summary','context');
                writetable(summary,fullfile(directory,'sweep.csv'));
            end
            % Add a standalone auditable report while preserving legacy exports.
            reportBundle = struct;
            if ~isempty(app.CurrentResult), reportBundle.scenarioResult = app.CurrentResult; end
            if ~isempty(app.CurrentMeshResult), reportBundle.surfaceResult = app.CurrentMeshResult; end
            if ~isempty(app.CurrentVolumeResult), reportBundle.volumeResult = app.CurrentVolumeResult; end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                reportBundle.surfaceResult = app.CurrentSurfaceVolumeResult.surface;
                reportBundle.volumeResult = app.CurrentSurfaceVolumeResult.volume;
                reportBundle.volumeResult.couplingDiagnostics = ...
                    app.CurrentSurfaceVolumeResult.couplingDiagnostics;
            end
            if ~isempty(app.CurrentSweep)
                reportBundle.sweep = app.CurrentSweep;
                reportBundle.sweepContext = app.SweepContext;
            end
            if ~isempty(telemetryState.result) || ~isempty(telemetryState.report)
                reportBundle.telemetry = telemetryState;
            end
            taskId = '';
            if ~isempty(app.LastTaskSnapshot)
                taskId = app.LastTaskSnapshot.taskId;
            end
            reportBundle.metadata = struct('taskId', taskId, ...
                'templateId', app.ActiveTemplateId, ...
                'coupledPresent', ~isempty(app.CurrentSurfaceVolumeResult), ...
                'scenarioStale', app.resultIsStale, ...
                'sweepStale', app.sweepIsStale, ...
                'meshStale', app.meshResultIsStale, ...
                'volumeStale', app.volumeResultIsStale, ...
                'coupledStale', app.surfaceVolumeResultIsStale);
            leotherm.writeThermalReport(reportBundle, fullfile(directory, 'report'), app.Language);
            metadata = struct('softwareVersion',leotherm.version,'scenarioStale',app.resultIsStale, ...
                'sweepStale',app.sweepIsStale,'configurationPolicy','each_result_owns_its_original_inputs');
            save(fullfile(directory,'export_metadata.mat'),'metadata');
        end
    end

    methods (Access = private)
        function settings = captureScanSettings(app)
            settings = struct('mode',app.ScanMode.Value,'altitudes',app.ScanAltitudeList.Value, ...
                'betas',app.ScanBetaList.Value,'branch',app.ScanBranch.Value, ...
                'dates',app.ScanDateList.Value,'inclinations',app.ScanInclinationList.Value, ...
                'raans',app.ScanRaanList.Value);
        end

        function restoreScanSettings(app,s)
            app.ScanMode.Value=s.mode; app.ScanAltitudeList.Value=s.altitudes;
            app.ScanBetaList.Value=s.betas; app.ScanBranch.Value=s.branch;
            app.ScanDateList.Value=s.dates; app.ScanInclinationList.Value=s.inclinations;
            app.ScanRaanList.Value=s.raans;
            app.updateScanControlState;
            app.updateMeshUI;
        end

        function stale = resultIsStale(app)
            stale = false;
            if isempty(app.CurrentResult), return; end
            try
                stale = ~leotherm.sameSimulationInputs(app.collectScenario,app.CurrentNetwork, ...
                    app.CurrentResult.scenario,app.CurrentResult.network, ...
                    app.CurrentGeometry,app.fieldOrEmpty(app.CurrentResult,'geometry'));
            catch
                stale = true;
            end
        end

        function stale = sweepIsStale(app)
            stale = false;
            if isempty(app.CurrentSweep), return; end
            if isempty(app.SweepContext), stale=true; return; end
            try
                stale = ~leotherm.sameSimulationInputs(app.collectScenario,app.CurrentNetwork, ...
                    app.SweepContext.scenario,app.SweepContext.network, ...
                    app.CurrentGeometry,app.fieldOrEmpty(app.SweepContext,'geometry')) ...
                    || ~isequaln(app.captureScanSettings,app.SweepContext.scanSettings);
            catch
                stale = true;
            end
        end

        function updateResultState(app)
            if isempty(app.ResultStateLabel) || ~isvalid(app.ResultStateLabel), return; end
            states = {};
            stale = false;
            if ~isempty(app.CurrentResult)
                if app.resultIsStale
                    states{end + 1} = app.t('单场景结果已过期：请重新运行', ...
                        'Scenario result is stale; rerun required');
                    stale = true;
                else
                    states{end + 1} = app.t('单场景结果有效', ...
                        'Scenario result is current');
                end
            end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                if app.surfaceVolumeResultIsStale
                    states{end + 1} = app.t('表面—体耦合结果已过期：请重新运行', ...
                        'Surface-volume coupling result is stale; rerun required');
                    stale = true;
                else
                    states{end + 1} = app.t('表面—体耦合结果有效', ...
                        'Surface-volume coupling result is current');
                end
            end
            if ~isempty(app.CurrentSweep)
                if app.sweepIsStale
                    states{end + 1} = app.t('扫描结果已过期：请重新运行', ...
                        'Sweep result is stale; rerun required');
                    stale = true;
                else
                    states{end + 1} = app.t('扫描结果有效', ...
                        'Sweep result is current');
                end
            end
            if ~isempty(app.CurrentMeshResult)
                if app.meshResultIsStale
                    states{end + 1} = app.t('面片结果已过期：请重新运行', ...
                        'Face result is stale; rerun required');
                    stale = true;
                else
                    states{end + 1} = app.t('面片结果有效', ...
                        'Face result is current');
                end
            end
            if ~isempty(app.CurrentVolumeResult)
                if app.volumeResultIsStale
                    states{end + 1} = app.t('体网格结果已过期：请重新运行', ...
                        'Volume result is stale; rerun required');
                    stale = true;
                else
                    states{end + 1} = app.t('体网格结果有效', ...
                        'Volume result is current');
                end
            end
            if isempty(states)
                text = app.t('尚未运行结果', 'No results have been run yet');
            else
                text = strjoin(states, ' | ');
            end
            app.ResultStateLabel.Text=['  ' text];
            app.ResultStateLabel.FontColor=[0.18 0.35 0.29];
            if stale, app.ResultStateLabel.FontColor=[0.70 0.20 0.10]; end
        end

        function scenarioEdited(app)
            try
                app.CurrentScenario = app.collectScenario;
                app.updateResultSummary;
                app.TelemetryWorkspace.refreshContext;
            catch exception
                app.showException(app.t('场景输入未完成','Incomplete scenario input'),exception);
            end
            app.updateResultState;
        end

        function scanEdited(app)
            app.updateScanControlState;
            app.updateResultState;
        end

        function cancelled = sweepProgress(app,done,total)
            cancelled=false;
            if isempty(app.ProgressDialog) || ~isvalid(app.ProgressDialog), return; end
            app.ProgressDialog.Value=done/max(total,1);
            app.ProgressDialog.Message=sprintf(app.t('已处理 %d / %d 个工况。取消会在当前工况结束后生效。', ...
                'Processed %d / %d cases. Cancellation takes effect between cases.'),done,total);
            drawnow;
            cancelled=app.ProgressDialog.CancelRequested;
        end

        function applyWorkspaceState(app,state)
            app.CurrentScenario=state.scenario; app.CurrentNetwork=state.network;
            if isfield(state,'geometry'), app.CurrentGeometry=state.geometry; else, app.CurrentGeometry=[]; end
            if isfield(state,'meshResult'), app.CurrentMeshResult=state.meshResult; else, app.CurrentMeshResult=[]; end
            if isfield(state,'volumeMesh'), app.CurrentVolumeMesh=state.volumeMesh; else, app.CurrentVolumeMesh=[]; end
            if isfield(state,'volumeModel'), app.CurrentVolumeModel=state.volumeModel; else, app.CurrentVolumeModel=[]; end
            if isfield(state,'volumeResult'), app.CurrentVolumeResult=state.volumeResult; else, app.CurrentVolumeResult=[]; end
            if isfield(state,'surfaceVolumeResult'), app.CurrentSurfaceVolumeResult=state.surfaceVolumeResult; else, app.CurrentSurfaceVolumeResult=[]; end
            if isfield(state,'activeTemplateId'), app.ActiveTemplateId = char(state.activeTemplateId); else, app.ActiveTemplateId = ''; end
            if isfield(state,'activeTemplatePath'), app.ActiveTemplatePath = char(state.activeTemplatePath); else, app.ActiveTemplatePath = ''; end
            if isfield(state,'activeTemplateSnapshot'), app.ActiveTemplateSnapshot = state.activeTemplateSnapshot; else, app.ActiveTemplateSnapshot = []; end
            if isfield(state,'surfaceVolumeOptions') && ~isempty(state.surfaceVolumeOptions)
                app.CouplingOptions = leotherm.normalizeCouplingOptions( ...
                    state.surfaceVolumeOptions, app.CurrentVolumeMesh);
            else
                app.CouplingOptions = leotherm.defaultCouplingOptions;
            end
            if isfield(state,'thermalModel') && ~isempty(state.thermalModel)
                leotherm.io.validateThermalModel(state.thermalModel);
                app.CurrentThermalModel = state.thermalModel;
            else
                app.CurrentThermalModel = [];
            end
            if isfield(state,'thermalModelMapping') && ~isempty(state.thermalModelMapping)
                if ~isempty(app.CurrentThermalModel)
                    leotherm.model.validateNetworkMapping(app.CurrentThermalModel, app.CurrentNetwork, state.thermalModelMapping);
                end
                app.CurrentThermalModelMapping = state.thermalModelMapping;
            else
                app.CurrentThermalModelMapping = [];
            end
            if isfield(state,'thermalModelPreview')
                app.CurrentThermalModelPreview = state.thermalModelPreview;
            else
                app.CurrentThermalModelPreview = [];
            end
            if isfield(state,'thermalModelNetworkRollback')
                app.ThermalModelNetworkRollback = state.thermalModelNetworkRollback;
            else
                app.ThermalModelNetworkRollback = [];
            end
            app.CurrentResult=state.result; app.CurrentSweep=state.sweep;
            app.CurrentSweepMode=state.sweepMode; app.SweepContext=state.sweepContext;
            if isfield(state,'task'), app.CurrentTask=state.task; else, app.CurrentTask=[]; end
            if isfield(state,'lastTaskSnapshot'), app.LastTaskSnapshot=state.lastTaskSnapshot; else, app.LastTaskSnapshot=[]; end
            if isfield(state,'taskHistory'), app.TaskHistory=state.taskHistory; else, app.TaskHistory=struct('taskId',{},'runType',{},'status',{},'startedUTC',{},'completedUTC',{},'inputFingerprint',{}); end
            app.Language=state.language;
            app.rebuildInterface(state);
        end

        function saved = saveProjectUI(app,saveAs)
            saved=false;
            if app.IsBusy, return; end
            try
                path=app.ProjectPath;
                if saveAs || isempty(path)
                    [file,folder]=uiputfile('*.mat',app.t('保存完整项目','Save complete project'),'leotherm_project.mat');
                    if isequal(file,0), return; end
                    path=fullfile(folder,file);
                end
                app.saveProject(path,true);
                app.setStatus([app.t('项目已保存：','Project saved: ') path]);
                saved=true;
            catch exception
                app.showException(app.t('项目保存失败','Project save failed'),exception);
            end
        end

        function proceed = confirmLeave(app)
            proceed=true;
            if ~app.hasUnsavedChanges, return; end
            saveLabel=app.t('保存项目','Save project');
            discardLabel=app.t('放弃未保存修改','Discard changes');
            cancelLabel=app.t('取消','Cancel');
            choice=uiconfirm(app.Figure,app.t('当前工作有未保存的修改。','The workspace has unsaved changes.'), ...
                app.t('未保存的项目','Unsaved project'),'Options',{saveLabel,discardLabel,cancelLabel}, ...
                'DefaultOption',1,'CancelOption',3);
            proceed=strcmp(choice,discardLabel);
            if strcmp(choice,saveLabel), proceed=app.saveProjectUI(false); end
        end

        function requestClose(app)
            if app.IsBusy
                uialert(app.Figure,app.t('计算正在进行，请在完成后关闭窗口。','An operation is running. Close the window after it finishes.'), ...
                    app.t('正在运行','Operation running'));
                return
            end
            if app.confirmLeave, delete(app); end
        end

        function openProjectUI(app)
            if app.IsBusy, return; end
            try
                if ~app.confirmLeave, return; end
                [file,folder]=uigetfile('*.mat',app.t('打开完整项目','Open complete project'));
                if isequal(file,0), return; end
                app.loadProject(fullfile(folder,file));
                app.setStatus([app.t('项目已恢复：','Project restored: ') file]);
            catch exception
                app.showException(app.t('项目打开失败','Project open failed'),exception);
            end
        end

        function createComponents(app, visibility)
            app.Figure = uifigure('Name', app.t('低轨卫星热仿真工作台', ...
                'LEO Thermal Simulation Workbench'), ...
                'Position', [80, 60, 1380, 860], ...
                'Color', [0.96, 0.97, 0.97], 'Visible', visibility, ...
                'CloseRequestFcn', @(~, ~) app.requestClose);
            app.RootGrid = uigridlayout(app.Figure, [4, 1]);
            app.RootGrid.RowHeight = {58, 30, '1x', 30};
            app.RootGrid.Padding = [0, 0, 0, 0];
            app.RootGrid.RowSpacing = 0;

            app.createHeader;
            app.ResultStateLabel = uilabel(app.RootGrid,'WordWrap','on','Tag','ResultStateLabel');
            app.ResultStateLabel.Layout.Row = 2;
            app.MainTabGroup = uitabgroup(app.RootGrid);
            app.MainTabGroup.Layout.Row = 3;
            app.createQuickStartTab;
            app.SimulationTab = uitab(app.MainTabGroup, ...
                'Title', app.t('仿真', 'Simulation'));
            simulationLayout = uigridlayout(app.SimulationTab, [2, 1]);
            simulationLayout.RowHeight = {112, '1x'};
            simulationLayout.Padding = [0, 0, 0, 0];
            app.createTaskPanel(simulationLayout);
            app.TabGroup = uitabgroup(simulationLayout);
            app.TabGroup.Layout.Row = 2;
            app.createScenarioTab;
            app.createSweepTab;
            app.createNetworkTab;
            app.createGeometryTab;
            app.createThermalModelTab;
            app.TelemetryWorkspace = leotherm.TelemetryPanel(app.TabGroup, app.Language, ...
                @() app.telemetryModel, @(value, message) app.setBusy(value, message));
            app.createResultsTab;
            app.CalibrationWorkspace = leotherm.CalibrationPanel(app.TabGroup, app.Language, ...
                @() app.telemetryModel, @() app.TelemetryWorkspace.getState, ...
                @(value, message) app.setBusy(value, message));
            app.TabGroup.SelectionChangedFcn = @(~,~) app.configTabChanged;
            app.MainTabGroup.SelectionChangedFcn = @(~,~) app.mainTabChanged;
            fileMenu = uimenu(app.Figure,'Text',app.t('项目','Project'));
            uimenu(fileMenu,'Text',app.t('打开项目...','Open project...'),'MenuSelectedFcn',@(~,~)app.openProjectUI);
            uimenu(fileMenu,'Text',app.t('保存项目','Save project'),'MenuSelectedFcn',@(~,~)app.saveProjectUI(false));
            uimenu(fileMenu,'Text',app.t('项目另存为...','Save project as...'),'MenuSelectedFcn',@(~,~)app.saveProjectUI(true));
            uimenu(fileMenu,'Text',app.t('导入设备配置...','Import device configuration...'), ...
                'Separator','on','MenuSelectedFcn',@(~,~)app.loadConfiguration);
            uimenu(fileMenu,'Text',app.t('导出设备配置...','Export device configuration...'), ...
                'MenuSelectedFcn',@(~,~)app.saveConfiguration);
            toolsMenu = uimenu(app.Figure,'Text',app.t('工具','Tools'));
            uimenu(toolsMenu,'Text',app.t('软件自检','Self-test'), ...
                'MenuSelectedFcn',@(~,~)app.executeSelfTest);
            uimenu(toolsMenu,'Text',app.t('关于','About'), ...
                'MenuSelectedFcn',@(~,~)app.showAbout);

            footer = uigridlayout(app.RootGrid, [1, 2]);
            footer.Layout.Row = 4;
            footer.ColumnWidth = {'1x', 390};
            footer.Padding = [14, 3, 14, 3];
            footer.BackgroundColor = [0.91, 0.93, 0.93];
            app.StatusLabel = uilabel(footer, 'Text', app.t('就绪', 'Ready'), ...
                'FontColor', [0.18, 0.28, 0.28]);
            boundary = uilabel(footer, ...
                'Text', app.t('研究级模型，不替代任务热控鉴定', ...
                'Research model; not a substitute for mission thermal qualification'), ...
                'HorizontalAlignment', 'right', ...
                'FontColor', [0.42, 0.45, 0.45]);
            boundary.Layout.Column = 2;
        end

        function createHeader(app)
            header = uigridlayout(app.RootGrid, [1, 7]);
            header.Layout.Row = 1;
            header.ColumnWidth = {340, 70, '1x', 112, 130, 105, 12};
            header.Padding = [18, 8, 8, 8];
            header.ColumnSpacing = 8;
            header.BackgroundColor = [0.10, 0.20, 0.21];

            uilabel(header, 'Text', app.t('低轨卫星热仿真工作台', ...
                'LEO Thermal Simulation Workbench'), ...
                'FontSize', 20, 'FontWeight', 'bold', ...
                'FontColor', [0.96, 0.98, 0.97]);
            app.VersionLabel = uilabel(header, ...
                'Text', ['v' leotherm.version], ...
                'HorizontalAlignment', 'center', ...
                'FontColor', [0.55, 0.85, 0.78]);
            app.VersionLabel.Layout.Column = 2;

            app.LanguageDropdown = uidropdown(header, ...
                'Items', {'中文', 'English'}, 'ItemsData', {'zh', 'en'}, ...
                'Value', app.Language, ...
                'Tooltip', app.t('选择界面和图表语言', ...
                'Select the interface and chart language'), ...
                'ValueChangedFcn', @(~, ~) app.changeLanguage);
            app.LanguageDropdown.Layout.Column = 4;

            app.LoadConfigButton = uibutton(header, 'push', ...
                'Text', app.t('保存项目', 'Save project'), ...
                'ButtonPushedFcn', @(~, ~) app.saveProjectUI(false), ...
                'Tooltip', app.t('保存完整工作，包括遥测数据和标定设置', ...
                'Save the complete workspace including telemetry and calibration settings'));
            app.LoadConfigButton.Layout.Column = 5;
            app.SaveConfigButton = uibutton(header, 'push', ...
                'Text', app.t('打开项目', 'Open project'), ...
                'ButtonPushedFcn', @(~, ~) app.openProjectUI, ...
                'Tooltip', app.t('恢复完整仿真工作区', 'Restore the complete simulation workspace'));
            app.SaveConfigButton.Layout.Column = 6;
        end

        function createTaskPanel(app, parent)
            task = uigridlayout(parent, [3, 1]);
            task.Layout.Row = 1;
            task.RowHeight = {26, '1x', 34};
            task.Padding = [14, 5, 14, 4];
            task.RowSpacing = 2;
            task.BackgroundColor = [0.93, 0.96, 0.95];

            heading = uigridlayout(task, [1, 3]);
            heading.ColumnWidth = {180, 170, '1x'};
            heading.Padding = [0, 0, 0, 0];
            uilabel(heading, 'Text', app.t('当前仿真任务', 'Current simulation task'), ...
                'FontWeight', 'bold', 'FontSize', 14);
            app.TaskStatusLabel = uilabel(heading, 'Text', app.t('正在检查', 'Checking'), ...
                'FontWeight', 'bold', 'Tag', 'TaskStatusLabel');
            app.TaskStatusLabel.Layout.Column = 2;
            app.TaskGuidanceLabel = uilabel(heading, 'Text', '', 'HorizontalAlignment', 'right', ...
                'FontColor', [0.30, 0.38, 0.37], 'Tag', 'TaskGuidanceLabel');
            app.TaskGuidanceLabel.Layout.Column = 3;

            app.TaskSummaryLabel = uilabel(task, 'Text', '', 'WordWrap', 'on', ...
                'FontColor', [0.20, 0.28, 0.28], 'Tag', 'TaskSummaryLabel');
            app.TaskSummaryLabel.Layout.Row = 2;

            actions = uigridlayout(task, [1, 4]);
            actions.ColumnWidth = {145, 145, 145, '1x'};
            actions.Padding = [0, 0, 0, 0];
            app.TaskCheckButton = uibutton(actions, 'Text', app.t('检查仿真配置', 'Check configuration'), ...
                'Tag', 'TaskCheckButton', 'ButtonPushedFcn', @(~,~) app.checkTaskUI);
            app.TaskRunButton = uibutton(actions, 'Text', app.t('运行仿真', 'Run simulation'), ...
                'FontWeight', 'bold', 'BackgroundColor', [0.12, 0.53, 0.46], ...
                'FontColor', [1, 1, 1], 'Tag', 'TaskRunButton', 'ButtonPushedFcn', @(~,~) app.runTaskScenario);
            app.TaskSweepButton = uibutton(actions, 'Text', app.t('运行参数扫描', 'Run parameter sweep'), ...
                'Tag', 'TaskSweepButton', 'ButtonPushedFcn', @(~,~) app.runTaskSweep);
            app.TaskResultsButton = uibutton(actions, 'Text', app.t('查看结果', 'View results'), ...
                'Tag', 'TaskResultsButton', 'ButtonPushedFcn', @(~,~) app.openTaskResults);
            app.TaskResultsButton.Layout.Column = 4;
            app.TaskResultsButton.HorizontalAlignment = 'right';
        end

        function createQuickStartTab(app)
            app.QuickStartTab = uitab(app.MainTabGroup, ...
                'Title', app.t('快速开始', 'Quick start'));
            layout = uigridlayout(app.QuickStartTab, [6, 1]);
            layout.RowHeight = {72, 38, 44, 116, 92, '1x'};
            layout.Padding = [34, 28, 34, 24];
            layout.RowSpacing = 12;

            title = uilabel(layout, 'Text', app.t('从一个可复现的仿真任务开始', ...
                'Start with a reproducible simulation task'), ...
                'FontSize', 22, 'FontWeight', 'bold');
            title.VerticalAlignment = 'center';
            subtitle = uilabel(layout, 'Text', app.t( ...
                '选择一个目标，软件会准备合理的起始配置；专业参数仍可在“高级仿真”中调整。', ...
                'Choose a goal and the software will prepare a sensible starting configuration; expert parameters remain available under Advanced simulation.'), ...
                'WordWrap', 'on', 'FontColor', [0.28, 0.35, 0.35]);
            subtitle.VerticalAlignment = 'center';

            selection = uigridlayout(layout, [1, 2]);
            selection.ColumnWidth = {170, 360};
            selection.Padding = [0, 0, 0, 0];
            uilabel(selection, 'Text', app.t('我要做什么', 'I want to'));
            app.QuickStartTemplate = uidropdown(selection, ...
                'Items', app.t({'第一次仿真', '热滞后分析', '遥测验证'}, ...
                {'First simulation', 'Thermal-lag analysis', 'Telemetry validation'}), ...
                'ItemsData', {'first', 'lag', 'telemetry'}, 'Value', 'first', ...
                'Tag', 'QuickStartTemplate', ...
                'Tooltip', app.t('选择任务目标，不需要先理解所有模型参数。', ...
                'Choose a task goal without learning every model parameter first.'), ...
                'ValueChangedFcn', @(~,~) app.updateQuickStartPanel);

            actions = uigridlayout(layout, [1, 5]);
            actions.ColumnWidth = {220, 150, 150, 150, 150};
            actions.Padding = [0, 0, 0, 0];
            app.QuickStartRunButton = uibutton(actions, 'push', ...
                'Text', app.t('使用模板并开始仿真', 'Use template and run'), ...
                'FontWeight', 'bold', 'BackgroundColor', [0.12, 0.53, 0.46], ...
                'FontColor', [1, 1, 1], 'Tag', 'QuickStartRunButton', ...
                'ButtonPushedFcn', @(~,~) app.executeQuickStart);
            app.QuickStartWizardButton = uibutton(actions, 'push', ...
                'Text', app.t('任务向导', 'Task wizard'), ...
                'Tag', 'QuickStartWizardButton', ...
                'ButtonPushedFcn', @(~,~) app.openTaskWizardUI);
            app.QuickStartOpenButton = uibutton(actions, 'push', ...
                'Text', app.t('打开已有项目', 'Open existing project'), ...
                'Tag', 'QuickStartOpenButton', ...
                'ButtonPushedFcn', @(~,~) app.openProjectUI);
            app.QuickStartExamplesButton = uibutton(actions, 'push', ...
                'Text', app.t('打开示例项目', 'Open example project'), ...
                'Tag', 'QuickStartExamplesButton', ...
                'ButtonPushedFcn', @(~,~) app.openExampleProjectUI);
            app.QuickStartAdvancedButton = uibutton(actions, 'push', ...
                'Text', app.t('高级仿真设置', 'Advanced simulation'), ...
                'Tag', 'QuickStartAdvancedButton', ...
                'ButtonPushedFcn', @(~,~) app.openAdvancedWorkspace);

            info = uigridlayout(layout, [2, 1]);
            info.Padding = [16, 10, 16, 10];
            info.BackgroundColor = [0.93, 0.96, 0.95];
            app.QuickStartInfoLabel = uilabel(info, 'Text', '', ...
                'WordWrap', 'on', 'Tag', 'QuickStartInfoLabel');
            app.QuickStartInfoLabel.Layout.Row = 1;
            boundary = uilabel(info, 'Text', app.t( ...
                '结果会明确标记：是否与当前输入一致、是否使用参考热网络、是否属于半仿真观测模型。', ...
                'Results explicitly state whether inputs match, whether the reference network is used, and whether the observation model is semi-synthetic.'), ...
                'WordWrap', 'on', 'FontColor', [0.35, 0.42, 0.42]);
            boundary.Layout.Row = 2;

            help = uilabel(layout, 'Text', app.t( ...
                ['新手建议：先运行“第一次仿真”，确认流程和结果页正常，再尝试热滞后分析或导入遥测。' newline ...
                 '软件不会自动插值、补齐或把默认参数包装成真实卫星标定结果。'], ...
                ['For a first use, run “First simulation” to check the workflow before thermal-lag analysis or telemetry import.' newline ...
                 'The software does not silently interpolate, fill gaps, or present default parameters as mission calibration.']), ...
                'WordWrap', 'on', 'FontColor', [0.28, 0.35, 0.35]);
            help.VerticalAlignment = 'top';
        end

        function updateQuickStartPanel(app, varargin)
            if isempty(app.QuickStartTemplate) || ~isvalid(app.QuickStartTemplate)
                return
            end
            switch app.QuickStartTemplate.Value
                case 'first'
                    app.QuickStartInfoLabel.Text = app.t( ...
                        '第一次仿真：使用600 km对地定向参考场景，运行2小时，适合确认软件流程。', ...
                        'First simulation: a 600 km nadir-pointing reference scenario for 2 hours, suitable for checking the workflow.');
                    app.QuickStartRunButton.Text = app.t('使用模板并开始仿真', 'Use template and run');
                case 'lag'
                    app.QuickStartInfoLabel.Text = app.t( ...
                        '热滞后分析：使用24小时场景和周期热状态收敛，适合观察入影、温度变化和滞后指标。', ...
                        'Thermal-lag analysis: a 24-hour scenario with periodic thermal-state convergence for studying eclipse, temperature changes, and lag metrics.');
                    app.QuickStartRunButton.Text = app.t('开始热滞后仿真', 'Run thermal-lag simulation');
                case 'telemetry'
                    app.QuickStartInfoLabel.Text = app.t( ...
                        '遥测验证：先进入遥测页导入CSV并完成映射预检；没有测温或驱动数据时不会伪造验证结果。', ...
                        'Telemetry validation: open the telemetry page to import a CSV and complete the mapping preflight; no validation result is fabricated without measurements or drivers.');
                    app.QuickStartRunButton.Text = app.t('进入遥测验证', 'Open telemetry validation');
            end
        end

        function createScenarioTab(app)
            app.ScenarioTab = uitab(app.TabGroup, ...
                'Title', app.t('单场景', 'Single scenario'));
            layout = uigridlayout(app.ScenarioTab, [1, 2]);
            layout.ColumnWidth = {400, '1x'};
            layout.Padding = [12, 12, 12, 12];

            sidebar = uigridlayout(layout, [2, 1]);
            sidebar.Layout.Column = 1;
            sidebar.RowHeight = {'1x', 38};
            sidebar.Padding = [0, 0, 0, 0];
            controls = uigridlayout(sidebar, [19, 2]);
            controls.Layout.Row = 1;
            controls.ColumnWidth = {180, '1x'};
            controls.RowHeight = repmat({26}, 1, 19);
            controls.RowSpacing = 6;
            controls.Padding = [10, 8, 10, 8];
            controls.Scrollable = 'on';

            app.StartDate = uidatepicker(controls, 'DisplayFormat', 'yyyy-MM-dd');
            app.placeControl(controls, app.StartDate, 1, ...
                '分析日期（协调世界时）', 'Analysis date (UTC)');
            app.StartTime = uieditfield(controls,'text','Value','12:00:00','Tag','ScenarioStartTime', ...
                'Tooltip',app.t('协调世界时，时:分:秒，支持小数秒','UTC, HH:mm:ss, fractional seconds supported'));
            app.placeControl(controls,app.StartTime,2,'开始时刻（协调世界时）','Start time (UTC)');
            app.DurationHours = uieditfield(controls, 'numeric', ...
                'Limits', [0.01, Inf], 'LowerLimitInclusive', 'on');
            app.placeControl(controls, app.DurationHours, 3, ...
                '分析时长（h）', 'Analysis duration (h)');
            app.TimeStepS = uieditfield(controls, 'numeric', ...
                'Limits', [0.1, Inf]);
            app.placeControl(controls, app.TimeStepS, 4, ...
                '时间步长（s）', 'Time step (s)');
            app.WarmupOrbits = uieditfield(controls, 'numeric', ...
                'Limits', [0, Inf]);
            app.placeControl(controls, app.WarmupOrbits, 5, ...
                '固定预热圈数', 'Fixed warm-up orbits');
            app.AltitudeKm = uieditfield(controls, 'numeric', ...
                'Limits', [1, 50000]);
            app.placeControl(controls, app.AltitudeKm, 6, ...
                '轨道高度（km）', 'Orbit altitude (km)');
            app.InclinationDeg = uieditfield(controls, 'numeric', ...
                'Limits', [0, 180]);
            app.placeControl(controls, app.InclinationDeg, 7, ...
                '轨道倾角（°）', 'Orbit inclination (deg)');
            app.RaanDeg = uieditfield(controls, 'numeric');
            app.placeControl(controls, app.RaanDeg, 8, ...
                '升交点赤经（°）', 'RAAN (deg)');
            app.ArgumentLatitudeDeg = uieditfield(controls, 'numeric');
            app.placeControl(controls, app.ArgumentLatitudeDeg, 9, ...
                '初始纬度幅角（°）', 'Initial argument of latitude (deg)');
            app.AttitudeMode = uidropdown(controls, ...
                'Items', app.attitudeItems, ...
                'ItemsData', {'nadir', 'sun_pointing', 'inertial'});
            app.placeControl(controls, app.AttitudeMode, 10, ...
                '姿态模式', 'Attitude mode');
            app.RollDeg = uieditfield(controls, 'numeric');
            app.placeControl(controls, app.RollDeg, 11, ...
                '滚转角（°）', 'Roll angle (deg)');
            app.PitchDeg = uieditfield(controls, 'numeric');
            app.placeControl(controls, app.PitchDeg, 12, ...
                '俯仰角（°）', 'Pitch angle (deg)');
            app.YawDeg = uieditfield(controls, 'numeric');
            app.placeControl(controls, app.YawDeg, 13, ...
                '偏航角（°）', 'Yaw angle (deg)');

            app.UseJ2 = uicheckbox(controls, ...
                'Text', app.t('加入 J2 长期漂移', 'Include secular J2 drift'));
            app.placeWide(controls, app.UseJ2, 14);
            app.DirectSolar = uicheckbox(controls, ...
                'Text', app.t('太阳直射', 'Direct solar radiation'));
            app.placeWide(controls, app.DirectSolar, 15);
            app.Albedo = uicheckbox(controls, ...
                'Text', app.t('地球反照', 'Earth albedo'));
            app.placeWide(controls, app.Albedo, 16);
            app.EarthIR = uicheckbox(controls, ...
                'Text', app.t('地球红外', 'Earth infrared radiation'));
            app.placeWide(controls, app.EarthIR, 17);
            app.UseConvergence = uicheckbox(controls, ...
                'Text', app.t('自动周期热状态收敛', ...
                'Automatic periodic thermal convergence'));
            app.placeWide(controls, app.UseConvergence, 18);
            app.EarthIRModel = uidropdown(controls, ...
                'Items', {app.t('有限地球圆盘','Finite Earth disk'),app.t('旧版余弦近似','Legacy cosine')}, ...
                'ItemsData', {'finite_disk','legacy_cosine'}, 'Tag','EarthIRModel');
            app.placeControl(controls,app.EarthIRModel,19,'地球红外模型','Earth infrared model');

            app.RunScenarioButton = uibutton(sidebar, 'push', ...
                'Text', app.t('运行单场景', 'Run scenario'), ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.12, 0.53, 0.46], ...
                'FontColor', [1, 1, 1], ...
                'ButtonPushedFcn', @(~, ~) app.executeScenarioFromUI);
            app.RunScenarioButton.Layout.Row = 2;
            app.RunScenarioButton.Layout.Column = 1;

            scenarioInputs = {app.StartDate, app.StartTime, app.DurationHours, app.TimeStepS, ...
                app.WarmupOrbits, app.AltitudeKm, app.InclinationDeg, app.RaanDeg, ...
                app.ArgumentLatitudeDeg, app.UseJ2, app.AttitudeMode, ...
                app.RollDeg, app.PitchDeg, app.YawDeg, app.DirectSolar, ...
                app.Albedo, app.EarthIR, app.UseConvergence, app.EarthIRModel};
            for k = 1:numel(scenarioInputs)
                scenarioInputs{k}.ValueChangedFcn = @(~,~) app.scenarioEdited;
            end

            plotGrid = uigridlayout(layout, [2, 2]);
            plotGrid.Layout.Column = 2;
            plotGrid.RowHeight = {'1x', '1x'};
            plotGrid.ColumnWidth = {'1x', '1x'};
            plotGrid.Padding = [4, 4, 4, 4];
            app.ScenarioAxes = gobjects(4, 1);
            for k = 1:4
                app.ScenarioAxes(k) = uiaxes(plotGrid);
                app.styleAxes(app.ScenarioAxes(k));
            end
        end

        function createSweepTab(app)
            app.SweepTab = uitab(app.TabGroup, ...
                'Title', app.t('参数扫描', 'Parameter sweep'));
            layout = uigridlayout(app.SweepTab, [1, 2]);
            layout.ColumnWidth = {370, '1x'};
            layout.Padding = [12, 12, 12, 12];

            controls = uigridlayout(layout, [14, 2]);
            controls.ColumnWidth = {150, '1x'};
            controls.RowHeight = repmat({30}, 1, 14);
            controls.RowSpacing = 8;
            controls.Padding = [10, 8, 10, 8];
            app.ScanMode = uidropdown(controls, ...
                'Items', app.scanModeItems, ...
                'ItemsData', {'beta_altitude', 'physical'}, ...
                'ValueChangedFcn', @(~, ~) app.scanEdited);
            app.placeControl(controls, app.ScanMode, 1, ...
                '扫描模式', 'Sweep mode');
            app.ScanAltitudeList = uieditfield(controls, 'text', ...
                'Value', '400,600,800,1000', ...
                'Tooltip', app.t('支持逗号列表或400:100:1000', ...
                'Comma-separated list or 400:100:1000'));
            app.placeControl(controls, app.ScanAltitudeList, 2, ...
                '高度（km）', 'Altitude (km)');
            app.ScanBetaList = uieditfield(controls, 'text', ...
                'Value', '-60,-30,0,30,60', ...
                'Tooltip', app.t('支持逗号列表或-60:10:60', ...
                'Comma-separated list or -60:10:60'));
            app.placeControl(controls, app.ScanBetaList, 3, ...
                '目标β角（°）', 'Target beta angle (deg)');
            app.ScanBranch = uispinner(controls, 'Limits', [1, 2], ...
                'Step', 1, 'Value', 1);
            app.placeControl(controls, app.ScanBranch, 4, ...
                '升交点赤经解分支', 'RAAN solution branch');
            app.ScanDateList = uieditfield(controls, 'text', ...
                'Value', '2024-03-20,2024-06-21,2024-09-22,2024-12-21', ...
                'Tooltip', app.t('日期格式为yyyy-MM-dd，以逗号分隔', ...
                'Use yyyy-MM-dd dates separated by commas'));
            app.placeControl(controls, app.ScanDateList, 5, ...
                '日期（协调世界时）', 'Dates (UTC)');
            app.ScanInclinationList = uieditfield(controls, 'text', ...
                'Value', '45,70,97.6');
            app.placeControl(controls, app.ScanInclinationList, 6, ...
                '倾角（°）', 'Inclination (deg)');
            app.ScanRaanList = uieditfield(controls, 'text', ...
                'Value', '0:45:315');
            app.placeControl(controls, app.ScanRaanList, 7, ...
                '升交点赤经（°）', 'RAAN (deg)');

            note = uitextarea(controls, 'Editable', 'off', ...
                'Value', app.t( ...
                {'扫描沿用“单场景”页的时长、步长、姿态和环境设置。'; ...
                '不可达或失败案例保留状态，不插值。'}, ...
                {'The sweep uses duration, step, attitude, and environment from Single scenario.'; ...
                'Inaccessible and failed cases retain their status; no interpolation is used.'}), ...
                'BackgroundColor', [0.94, 0.96, 0.95]);
            note.Layout.Row = [9, 11];
            note.Layout.Column = [1, 2];
            app.RunSweepButton = uibutton(controls, 'push', ...
                'Text', app.t('运行参数扫描', 'Run parameter sweep'), ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.12, 0.53, 0.46], ...
                'FontColor', [1, 1, 1], ...
                'ButtonPushedFcn', @(~, ~) app.executeSweepFromUI);
            app.RunSweepButton.Layout.Row = 13;
            app.RunSweepButton.Layout.Column = [1, 2];
            scanInputs={app.ScanAltitudeList,app.ScanBetaList,app.ScanBranch, ...
                app.ScanDateList,app.ScanInclinationList,app.ScanRaanList};
            for k=1:numel(scanInputs), scanInputs{k}.ValueChangedFcn=@(~,~)app.scanEdited; end

            output = uigridlayout(layout, [2, 1]);
            output.Layout.Column = 2;
            output.RowHeight = {'1x', 210};
            charts = uigridlayout(output, [2, 2]);
            charts.Padding = [2, 2, 2, 2];
            app.SweepAxes = gobjects(4, 1);
            for k = 1:4
                app.SweepAxes(k) = uiaxes(charts);
                app.styleAxes(app.SweepAxes(k));
            end
            app.SweepTable = uitable(output, 'Data', table);
            app.SweepTable.Layout.Row = 2;
        end

        function createNetworkTab(app)
            app.NetworkTab = uitab(app.TabGroup, ...
                'Title', app.t('热网络', 'Thermal network'));
            layout = uigridlayout(app.NetworkTab, [3, 1]);
            layout.RowHeight = {42, '1x', 88};
            layout.Padding = [12, 12, 12, 12];

            toolbar = uigridlayout(layout, [1, 5]);
            toolbar.ColumnWidth = {100, 240, 130, '1x', 400};
            toolbar.Padding = [0, 0, 0, 0];
            uilabel(toolbar, 'Text', app.t('网络预设', 'Network preset'), ...
                'FontWeight', 'bold');
            app.NetworkPreset = uidropdown(toolbar, ...
                'Items', app.networkPresetItems, ...
                'ItemsData', {'default', 'symmetric', 'satmo'}, ...
                'ValueChangedFcn', @(~, ~) app.selectNetworkPreset);
            app.NetworkPreset.Layout.Column = 2;
            app.ResetNetworkButton = uidropdown(toolbar, ...
                'Items', app.t({'网络操作','恢复当前预设'}, ...
                {'Network actions','Restore current preset'}), ...
                'ItemsData', {'more','restore'}, 'Value', 'more', ...
                'ValueChangedFcn', @(~,~) app.networkActionChanged);
            app.ResetNetworkButton.Layout.Column = 3;
            networkHint = uilabel(toolbar, ...
                'Text', app.t('修改节点后立即校验；导热矩阵自动保持对称。', ...
                'Node edits are validated immediately; conductance remains symmetric.'), ...
                'HorizontalAlignment', 'right', ...
                'FontColor', [0.35, 0.40, 0.40]);
            networkHint.Layout.Column = 5;

            tables = uigridlayout(layout, [1, 2]);
            tables.Layout.Row = 2;
            tables.ColumnWidth = {'1.6x', '1x'};
            tables.Padding = [0, 4, 0, 4];
            app.NodeTable = uitable(tables, ...
                'ColumnEditable', [false, true(1, 11)], ...
                'Tag', 'NetworkNodeTable', ...
                'CellEditCallback', @(~, event) app.applyNodeTableEdit(event));
            app.NodeTable.Layout.Column = 1;
            app.ConductanceTable = uitable(tables, ...
                'CellEditCallback', @(~, event) app.applyConductanceEdit(event));
            app.ConductanceTable.Layout.Column = 2;

            roles = uigridlayout(layout, [2, 10]);
            roles.Layout.Row = 3;
            roles.ColumnWidth = {90, 145, 85, 145, 80, 145, 100, 145, 120, '1x'};
            roles.RowHeight = {28, 28};
            labels = app.t({'响应节点', '天线节点', '振荡器', '二次项节点'}, ...
                {'Response node', 'Antenna node', 'Oscillator', 'Quadratic node'});
            columns = [1, 3, 5, 7];
            for k = 1:4
                label = uilabel(roles, 'Text', labels{k});
                label.Layout.Row = 1;
                label.Layout.Column = columns(k);
            end
            app.ResponseRole = uidropdown(roles); app.ResponseRole.Layout.Column = 2;
            app.AntennaRole = uidropdown(roles); app.AntennaRole.Layout.Column = 4;
            app.OscillatorRole = uidropdown(roles); app.OscillatorRole.Layout.Column = 6;
            app.QuadraticNode = uidropdown(roles); app.QuadraticNode.Layout.Column = 8;
            coefficientLabel = uilabel(roles, ...
                'Text', app.t('二次系数', 'Quadratic coeff.'));
            coefficientLabel.Layout.Row = 2; coefficientLabel.Layout.Column = 7;
            app.QuadraticCoefficient = uieditfield(roles, 'numeric');
            app.QuadraticCoefficient.Layout.Row = 2;
            app.QuadraticCoefficient.Layout.Column = 8;
            app.ApplyRolesButton = uibutton(roles, 'push', ...
                'Text', app.t('应用角色与偏差设置', ...
                'Apply roles and bias settings'), ...
                'ButtonPushedFcn', @(~, ~) app.applyRoleSettings);
            app.ApplyRolesButton.Layout.Row = 2;
            app.ApplyRolesButton.Layout.Column = [9, 10];
        end

        function createGeometryTab(app)
            app.GeometryTab = uitab(app.TabGroup, ...
                'Title', app.t('三维几何', '3-D geometry'));
            layout = uigridlayout(app.GeometryTab, [3, 1]);
            layout.RowHeight = {48, 42, '1x'};
            layout.Padding = [12, 12, 12, 12];

            toolbar = uigridlayout(layout, [1, 12]);
            toolbar.ColumnWidth = {110, 75, 100, 110, 120, 100, 110, 125, 110, '1x', 110, 220};
            toolbar.Padding = [0, 0, 0, 0];
            app.MeshImportButton = uibutton(toolbar, 'push', ...
                'Text', app.t('导入 STL/OBJ', 'Import STL/OBJ'), ...
                'ButtonPushedFcn', @(~,~) app.importMeshUI);
            app.MeshImportButton.Layout.Column = 1;
            app.MeshUnit = uidropdown(toolbar, ...
                'Items', {'m', 'mm', 'cm', 'in'}, 'ItemsData', [1, 1e-3, 1e-2, 0.0254], ...
                'Value', 1, 'Tooltip', app.t('将输入几何缩放到米', 'Scale input geometry to metres'));
            app.MeshUnit.Layout.Column = 2;
            app.MeshRadiationSide = uidropdown(toolbar, ...
                'Items', app.t({'外法向表面', '内法向表面'}, {'Outward-facing', 'Inward-facing'}), ...
                'ItemsData', {'outward', 'inward'}, 'Value', 'outward', ...
                'Tooltip', app.t('外壳使用外法向；内部腔体使用内法向', ...
                'Use outward for an external shell and inward for an internal cavity'), ...
                'ValueChangedFcn', @(~,~) app.meshRadiationSideChanged);
            app.MeshRadiationSide.Layout.Column = 3;
            app.MeshSelfShadowing = uidropdown(toolbar, ...
                'Items', app.t({'太阳自遮挡：关', '太阳自遮挡：开'}, ...
                {'Solar self-shadowing: off', 'Solar self-shadowing: on'}), ...
                'ItemsData', {'off', 'on'}, 'Value', 'off', ...
                'Tooltip', app.t('用面片质心向太阳发射射线，检查结构遮挡。默认关闭以保持旧结果可复现。', ...
                'Cast centroid rays toward the Sun to detect structural blocking. Off by default for reproducibility.'), ...
                'ValueChangedFcn', @(~,~) app.meshSelfShadowingChanged);
            app.MeshSelfShadowing.Layout.Column = 4;
            app.MeshPreviewButton = uibutton(toolbar, 'push', ...
                'Text', app.t('预览网格', 'Preview mesh'), ...
                'ButtonPushedFcn', @(~,~) app.previewMeshUI);
            app.MeshPreviewButton.Layout.Column = 5;
            app.MeshThermalRunButton = uibutton(toolbar, 'push', ...
                'Text', app.t('运行面片热仿真', 'Run face thermal simulation'), ...
                'ButtonPushedFcn', @(~,~) app.runMeshThermalUI);
            app.MeshThermalRunButton.Layout.Column = 6;
            app.MeshDisplayMode = uidropdown(toolbar, ...
                'Items', app.t({'几何', '太阳直射功率', '总外部辐射功率', '末时刻面片温度', '体网格节点温度'}, ...
                {'Geometry', 'Direct solar power', 'Total external radiative power', 'Final face temperature', 'Volume nodal temperature'}), ...
                'ItemsData', {'geometry', 'direct_solar', 'total_external', 'final_temperature', 'volume_temperature'}, ...
                'Value', 'geometry', 'ValueChangedFcn', @(~,~) app.previewMeshUI);
            app.MeshDisplayMode.Layout.Column = 8;
            app.MeshClearButton = uibutton(toolbar, 'push', ...
                'Text', app.t('移除网格', 'Remove mesh'), ...
                'ButtonPushedFcn', @(~,~) app.clearMeshUI);
            app.MeshClearButton.Layout.Column = 7;
            app.MeshStatusLabel = uilabel(toolbar, ...
                'Text', app.t('未载入三维几何', 'No 3-D geometry loaded'), ...
                'FontWeight', 'bold');
            app.MeshStatusLabel.Layout.Column = 9;
            app.MeshStatsLabel = uilabel(toolbar, 'Text', '', 'HorizontalAlignment', 'right');
            app.MeshStatsLabel.Layout.Column = [10, 12];

            volume = uigridlayout(layout, [1, 11]);
            volume.Layout.Row = 2;
            volume.ColumnWidth = {130, 100, 95, 100, 95, 100, 95, 140, 110, 120, '1x'};
            app.VolumeImportButton = uibutton(volume, 'push', ...
                'Text', app.t('导入 Gmsh 体网格', 'Import Gmsh volume mesh'), ...
                'ButtonPushedFcn', @(~,~) app.importVolumeMeshUI);
            app.VolumeImportButton.Layout.Column = 1;
            label = uilabel(volume, 'Text', app.t('导热系数', 'Conductivity'));
            label.Layout.Column = 2;
            app.VolumeConductivity = uieditfield(volume, 'numeric', 'Value', 1, ...
                'Limits', [eps Inf], 'Tooltip', app.t('W/(m·K)', 'W/(m K)'), ...
                'ValueChangedFcn', @(~,~) app.volumeParameterChanged);
            app.VolumeConductivity.Layout.Column = 3;
            label = uilabel(volume, 'Text', app.t('密度', 'Density'));
            label.Layout.Column = 4;
            app.VolumeDensity = uieditfield(volume, 'numeric', 'Value', 1000, ...
                'Limits', [eps Inf], 'Tooltip', app.t('kg/m³', 'kg/m^3'), ...
                'ValueChangedFcn', @(~,~) app.volumeParameterChanged);
            app.VolumeDensity.Layout.Column = 5;
            label = uilabel(volume, 'Text', app.t('比热', 'Specific heat'));
            label.Layout.Column = 6;
            app.VolumeSpecificHeat = uieditfield(volume, 'numeric', 'Value', 1000, ...
                'Limits', [eps Inf], 'Tooltip', app.t('J/(kg·K)', 'J/(kg K)'), ...
                'ValueChangedFcn', @(~,~) app.volumeParameterChanged);
            app.VolumeSpecificHeat.Layout.Column = 7;
            app.VolumeRunButton = uibutton(volume, 'push', ...
                'Text', app.t('运行体导热', 'Run volume conduction'), ...
                'ButtonPushedFcn', @(~,~) app.runVolumeThermalUI);
            app.VolumeRunButton.Layout.Column = 8;
            app.CoupledRunButton = uibutton(volume, 'push', ...
                'Text', app.t('运行表面—体耦合', 'Run surface-volume coupling'), ...
                'Tag', 'CoupledRunButton', ...
                'ButtonPushedFcn', @(~,~) app.runSurfaceVolumeUI);
            app.CoupledRunButton.Layout.Column = 9;
            app.CouplingOptionsButton = uibutton(volume, 'push', ...
                'Text', app.t('耦合边界设置', 'Coupling boundaries'), ...
                'ButtonPushedFcn', @(~,~) app.configureCouplingOptionsUI);
            app.CouplingOptionsButton.Layout.Column = 10;
            app.VolumeStatusLabel = uilabel(volume, 'Text', ...
                app.t('未载入体网格', 'No volume mesh loaded'), 'FontWeight', 'bold');
            app.VolumeStatusLabel.Layout.Column = 11;

            content = uigridlayout(layout, [1, 2]);
            content.Layout.Row = 3;
            content.ColumnWidth = {'1.5x', '1x'};
            app.MeshAxes = uiaxes(content);
            app.MeshAxes.Layout.Column = 1;
            app.styleAxes(app.MeshAxes);
            app.MeshAxes.XLabel.String = 'X (m)';
            app.MeshAxes.YLabel.String = 'Y (m)';
            app.MeshAxes.ZLabel.String = 'Z (m)';
            info = uilabel(content, 'Text', sprintf(app.t( ...
                 ['三维几何支持面片级环境热流、面片热仿真和表面—体网格耦合。\n\n' ...
                  '耦合流程将外部面片辐射守恒传入体网格导热；当前为单向耦合，面片温度不反馈到体网格。'], ...
                 ['The mesh supports face-level environmental loads and 3-D face thermal simulation.\n\n' ...
                  'The coupled workflow transfers external face radiation conservatively into volume conduction. It is one-way: face temperature is not fed back into the volume state.'])), ...
                'WordWrap', 'on', 'VerticalAlignment', 'top', ...
                'FontColor', [0.25, 0.32, 0.32]);
            info.Layout.Column = 2;
        end

        function createResultsTab(app)
            app.ResultsTab = uitab(app.MainTabGroup, ...
                'Title', app.t('结果与导出', 'Results and export'));
            layout = uigridlayout(app.ResultsTab, [3, 2]);
            layout.RowHeight = {42, '1x', 52};
            layout.ColumnWidth = {'1.2x', '1x'};
            layout.Padding = [14, 14, 14, 14];
            app.ResultConclusionLabel = uilabel(layout, 'Text', '', ...
                'FontSize', 15, 'FontWeight', 'bold', 'WordWrap', 'on', ...
                'Tag', 'ResultConclusionLabel');
            app.ResultConclusionLabel.Layout.Row = 1;
            app.ResultConclusionLabel.Layout.Column = [1, 2];
            app.MetricsTable = uitable(layout, 'Data', table);
            app.MetricsTable.Layout.Row = 2;
            app.MetricsTable.Layout.Column = 1;
            app.SessionSummary = uitextarea(layout, 'Editable', 'off', ...
                'FontName', 'Consolas', 'BackgroundColor', [0.95, 0.96, 0.96]);
            app.SessionSummary.Layout.Row = 2;
            app.SessionSummary.Layout.Column = 2;

            actions = uigridlayout(layout, [1, 2]);
            actions.Layout.Row = 3;
            actions.Layout.Column = [1, 2];
            actions.ColumnWidth = {220, '1x'};
            app.ExportResultsButton = uibutton(actions, 'push', ...
                'Text', app.t('生成分析报告 PDF', 'Generate analysis PDF'), ...
                'Tag', 'GenerateReportButton', ...
                'Tooltip', app.t('同时导出报告、原始结果和复核数据。', ...
                    'Export the report, raw results, and audit data together.'), ...
                'ButtonPushedFcn', @(~, ~) app.exportCurrentResults);
        end

        function createThermalModelTab(app)
            %CREATETHERMALMODELTAB Engineering thermal-model exchange entry point.
            app.ThermalModelTab = uitab(app.TabGroup, ...
                'Title', app.t('工程热模型', 'Engineering thermal model'));
            layout = uigridlayout(app.ThermalModelTab, [4, 1]);
            layout.RowHeight = {48, 44, '1x', 58};
            layout.Padding = [14, 14, 14, 14];
            toolbar = uigridlayout(layout, [1, 5]);
            toolbar.ColumnWidth = {180, 150, 150, 170, '1x'};
            toolbar.Padding = [0, 0, 0, 0];
            app.ThermalModelImportButton = uibutton(toolbar, 'push', ...
                'Text', app.t('导入工程热模型...', 'Import thermal model...'), ...
                'Tag', 'ThermalModelImportButton', ...
                'ButtonPushedFcn', @(~,~) app.importThermalModelUI);
            app.ThermalModelExportMATButton = uibutton(toolbar, 'push', ...
                'Text', app.t('导出 MAT', 'Export MAT'), ...
                'Tag', 'ThermalModelExportMATButton', ...
                'ButtonPushedFcn', @(~,~) app.exportThermalModelUI('mat'));
            app.ThermalModelExportJSONButton = uibutton(toolbar, 'push', ...
                'Text', app.t('导出 JSON', 'Export JSON'), ...
                'Tag', 'ThermalModelExportJSONButton', ...
                'ButtonPushedFcn', @(~,~) app.exportThermalModelUI('json'));
            app.ThermalModelStatusLabel = uilabel(toolbar, ...
                'Text', app.t('未载入工程热模型', 'No engineering thermal model loaded'), ...
                'FontWeight', 'bold', 'Tag', 'ThermalModelStatusLabel');
            app.ThermalModelStatusLabel.Layout.Column = 4;
            hint = uilabel(toolbar, 'Text', app.t( ...
                'MAT/JSON 均执行完整 schema 校验；失败时保留当前工作区。', ...
                'MAT/JSON imports run full schema validation; failures leave the workspace unchanged.'), ...
                'HorizontalAlignment', 'right', 'WordWrap', 'on', ...
                'FontColor', [0.35, 0.40, 0.40]);
            hint.Layout.Column = 5;

            mappingBar = uigridlayout(layout, [1, 5]);
            mappingBar.ColumnWidth = {170, 190, 150, 150, 150};
            mappingBar.Padding = [0, 0, 0, 0];
            app.ThermalModelMappingImportButton = uibutton(mappingBar, 'push', ...
                'Text', app.t('载入显式映射...', 'Load explicit mapping...'), ...
                'Tag', 'ThermalModelMappingImportButton', ...
                'ButtonPushedFcn', @(~,~) app.importThermalModelMappingUI);
            app.ThermalModelMappingTemplateButton = uibutton(mappingBar, 'push', ...
                'Text', app.t('生成映射模板', 'Generate mapping template'), ...
                'Tag', 'ThermalModelMappingTemplateButton', ...
                'ButtonPushedFcn', @(~,~) app.generateThermalModelMappingTemplateUI);
            app.ThermalModelMappingPreviewButton = uibutton(mappingBar, 'push', ...
                'Text', app.t('预览映射', 'Preview mapping'), ...
                'Tag', 'ThermalModelMappingPreviewButton', ...
                'ButtonPushedFcn', @(~,~) app.previewThermalModelMappingUI);
            app.ThermalModelMappingApplyButton = uibutton(mappingBar, 'push', ...
                'Text', app.t('确认并应用', 'Confirm and apply'), ...
                'Tag', 'ThermalModelMappingApplyButton', ...
                'ButtonPushedFcn', @(~,~) app.applyThermalModelMappingUI);
            app.ThermalModelMappingRollbackButton = uibutton(mappingBar, 'push', ...
                'Text', app.t('回滚网络', 'Rollback network'), ...
                'Tag', 'ThermalModelMappingRollbackButton', ...
                'ButtonPushedFcn', @(~,~) app.rollbackThermalModelNetworkUI);
            mappingBar.Layout.Row = 2;

            app.ThermalModelSummary = uitextarea(layout, 'Editable', 'off', ...
                'Tag', 'ThermalModelSummary', 'FontName', 'Consolas', ...
                'BackgroundColor', [0.95, 0.97, 0.96], 'Value', ...
                app.t({'尚未载入规范工程热模型。'; ...
                       '可导入 leotherm.thermal_model.v1 的 MAT 或 JSON 文件。'}, ...
                      {'No canonical engineering thermal model is loaded.'; ...
                       'Import a MAT or JSON file with schema leotherm.thermal_model.v1.'}));
            app.ThermalModelSummary.Layout.Row = 3;

            note = uilabel(layout, 'Text', app.t( ...
                ['摘要显示 schema、模型 ID、SI 单位、来源、节点/材料数量和校验状态。' newline ...
                 '导出内容来自当前规范模型；未载入模型时导出按钮保持禁用。'], ...
                ['The summary shows schema, model ID, SI units, source, node/material counts, and validation status.' newline ...
                 'Exports are taken from the current canonical model; export buttons stay disabled when none is loaded.']), ...
                'WordWrap', 'on', 'VerticalAlignment', 'top', ...
                'FontColor', [0.28, 0.35, 0.35]);
            note.Layout.Row = 4;
            app.updateThermalModelUI;
        end

        function placeControl(app, parent, control, row, chinese, english)
            label = uilabel(parent, 'Text', app.t(chinese, english));
            label.Layout.Row = row;
            label.Layout.Column = 1;
            control.Layout.Row = row;
            control.Layout.Column = 2;
        end

        function placeWide(~, ~, control, row)
            control.Layout.Row = row;
            control.Layout.Column = [1, 2];
        end

        function styleAxes(~, axesHandle)
            axesHandle.FontSize = 11;
            axesHandle.Color = [1, 1, 1];
            axesHandle.XGrid = 'on';
            axesHandle.YGrid = 'on';
            axesHandle.Box = 'on';
        end

        function syncScenarioControls(app)
            scenario = app.CurrentScenario;
            value = scenario.startEpoch;
            value.TimeZone = 'UTC';
            app.StartTime.Value = char(string(value,'HH:mm:ss.SSSSSSSSS'));
            value.TimeZone = '';
            app.StartDate.Value = value;
            app.DurationHours.Value = scenario.durationS / 3600;
            app.TimeStepS.Value = scenario.timeStepS;
            app.WarmupOrbits.Value = scenario.warmupOrbits;
            app.AltitudeKm.Value = scenario.orbit.altitudeM / 1000;
            app.InclinationDeg.Value = scenario.orbit.inclinationDeg;
            app.RaanDeg.Value = scenario.orbit.raanDeg;
            app.ArgumentLatitudeDeg.Value = scenario.orbit.argumentLatitudeDeg;
            app.UseJ2.Value = logical(scenario.orbit.useJ2);
            app.AttitudeMode.Value = lower(scenario.attitude.mode);
            app.RollDeg.Value = scenario.attitude.eulerOffsetDeg(1);
            app.PitchDeg.Value = scenario.attitude.eulerOffsetDeg(2);
            app.YawDeg.Value = scenario.attitude.eulerOffsetDeg(3);
            app.DirectSolar.Value = logical(scenario.environment.includeDirectSolar);
            app.Albedo.Value = logical(scenario.environment.includeAlbedo);
            app.EarthIR.Value = logical(scenario.environment.includeEarthIR);
            app.EarthIRModel.Value = 'legacy_cosine';
            if isfield(scenario.environment,'earthIRModel')
                app.EarthIRModel.Value = scenario.environment.earthIRModel;
            end
            app.UseConvergence.Value = isfield(scenario, 'convergence') ...
                && logical(scenario.convergence.enabled);
        end

        function scenario = collectScenario(app)
            scenario = app.CurrentScenario;
            dateValue = app.StartDate.Value;
            scenario.startEpoch = leotherm.parseStartEpoch(dateValue,app.StartTime.Value);
            scenario.durationS = app.DurationHours.Value * 3600;
            scenario.timeStepS = app.TimeStepS.Value;
            scenario.warmupOrbits = app.WarmupOrbits.Value;
            scenario.orbit.altitudeM = app.AltitudeKm.Value * 1000;
            scenario.orbit.inclinationDeg = app.InclinationDeg.Value;
            scenario.orbit.raanDeg = app.RaanDeg.Value;
            scenario.orbit.argumentLatitudeDeg = app.ArgumentLatitudeDeg.Value;
            scenario.orbit.useJ2 = app.UseJ2.Value;
            scenario.attitude.mode = app.AttitudeMode.Value;
            scenario.attitude.eulerOffsetDeg = [app.RollDeg.Value, ...
                app.PitchDeg.Value, app.YawDeg.Value];
            scenario.environment.includeDirectSolar = app.DirectSolar.Value;
            scenario.environment.includeAlbedo = app.Albedo.Value;
            scenario.environment.includeEarthIR = app.EarthIR.Value;
            scenario.environment.earthIRModel = app.EarthIRModel.Value;
            scenario.convergence.enabled = app.UseConvergence.Value;
            app.WarmupOrbits.Enable = app.onOff(~app.UseConvergence.Value && ~app.IsBusy);
            leotherm.validateScenario(scenario);
        end

        function executeScenarioFromUI(app)
            if app.IsBusy
                return
            end
            app.ProgressDialog = [];
            app.setBusy(true, app.t('正在计算单场景...', ...
                'Computing single scenario...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                scenario = app.collectScenario;
                leotherm.validateNetwork(app.CurrentNetwork);
                app.ProgressDialog = uiprogressdlg(app.Figure, ...
                    'Title', app.t('单场景仿真', 'Single-scenario simulation'), ...
                    'Message', app.t('正在传播轨道、热流和多节点温度...', ...
                    'Propagating orbit, heat loads, and multi-node temperatures...'), ...
                    'Indeterminate', 'on');
                drawnow;
                app.runScenario(scenario, app.CurrentNetwork);
                app.setStatus(sprintf(app.t('单场景完成：%d个历元，β角 %.2f°', ...
                    'Scenario complete: %d epochs, beta angle %.2f deg'), ...
                    numel(app.CurrentResult.timeS), ...
                    app.CurrentResult.metrics.meanBetaDeg));
            catch exception
                app.showException(app.t('单场景计算失败', ...
                    'Single-scenario computation failed'), exception);
            end
            clear cleanup
        end

        function executeSweepFromUI(app)
            if app.IsBusy
                return
            end
            app.ProgressDialog = [];
            app.setBusy(true, app.t('正在运行参数扫描...', ...
                'Running parameter sweep...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                scenario = app.collectScenario;
                altitudes = leotherm.parseNumericList( ...
                    app.ScanAltitudeList.Value, ...
                    app.t('轨道高度', 'orbit altitude'));
                app.ProgressDialog = uiprogressdlg(app.Figure, ...
                    'Title', app.t('参数扫描', 'Parameter sweep'), ...
                    'Message', app.t('正在逐个计算并保留失败状态...', ...
                    'Computing each case and retaining failure states...'), ...
                    'Indeterminate', 'off','Cancelable','on');
                drawnow;
                if strcmp(app.ScanMode.Value, 'beta_altitude')
                    betas = leotherm.parseNumericList( ...
                        app.ScanBetaList.Value, ...
                        app.t('目标beta角', 'target beta angle'));
                    summary = leotherm.runBetaAltitudeSweep(scenario, ...
                        app.CurrentNetwork, altitudes, betas, app.ScanBranch.Value,@(done,total)app.sweepProgress(done,total));
                    mode = 'beta_altitude';
                else
                    dates = leotherm.parseDateList( ...
                        app.ScanDateList.Value, app.t('日期', 'date'));
                    inclinations = leotherm.parseNumericList( ...
                        app.ScanInclinationList.Value, ...
                        app.t('倾角', 'inclination'));
                    raan = leotherm.parseNumericList( ...
                        app.ScanRaanList.Value, 'RAAN');
                    summary = leotherm.runPhysicalSweep(scenario, ...
                        app.CurrentNetwork, dates, altitudes, inclinations, raan,@(done,total)app.sweepProgress(done,total));
                    mode = 'physical';
                end
                app.CurrentScenario = scenario;
                app.CurrentSweep = summary;
                app.CurrentSweepMode = mode;
                app.SweepContext = struct('scenario',scenario,'network',app.CurrentNetwork, ...
                    'mode',mode,'scanSettings',app.captureScanSettings, ...
                    'geometry',app.CurrentGeometry);
                task = app.buildSimulationTask(scenario, app.CurrentNetwork, ...
                    app.TelemetryWorkspace.getState, app.CalibrationWorkspace.getState, ...
                    app.captureScanSettings, 'sweep');
                app.LastTaskSnapshot = leotherm.freezeSimulationTask(task);
                app.CurrentTask = app.LastTaskSnapshot;
                app.recordTaskRun(app.LastTaskSnapshot, 'sweep', 'complete');
                app.updateSweepPlots;
                app.updateResultSummary;
                complete = sum(strcmp(summary.status, 'complete'));
                app.setStatus(sprintf(app.t('扫描完成：%d/%d个案例有效', ...
                    'Sweep complete: %d/%d valid cases'), ...
                    complete, height(summary)));
                if any(strcmp(summary.status,'cancelled'))
                    app.setStatus(sprintf(app.t('扫描已取消：保留 %d 个有效结果，%d 个工况未运行', ...
                        'Sweep cancelled: retained %d valid results; %d cases not run'), ...
                        complete,sum(strcmp(summary.status,'cancelled'))));
                end
            catch exception
                app.showException(app.t('参数扫描失败', ...
                    'Parameter sweep failed'), exception);
            end
            clear cleanup
        end

        function updateScenarioPlots(app)
            if isempty(app.CurrentResult)
                return
            end
            result = app.CurrentResult;
            timeHour = result.timeS / 3600;
            for k = 1:4
                cla(app.ScenarioAxes(k));
            end
            plot(app.ScenarioAxes(1), timeHour, ...
                result.loads.visibleFraction, 'k', 'LineWidth', 1.1, ...
                'DisplayName', app.t('太阳可见比例', 'Solar visibility'));
            title(app.ScenarioAxes(1), app.t('太阳可见比例', 'Solar visibility'));
            xlabel(app.ScenarioAxes(1), app.t('时间（h）', 'Time (h)'));
            ylim(app.ScenarioAxes(1), [-0.05, 1.05]);
            legend(app.ScenarioAxes(1), 'Location', 'best');

            hold(app.ScenarioAxes(2), 'on');
            plot(app.ScenarioAxes(2), timeHour, ...
                sum(result.loads.directSolarW, 2), 'LineWidth', 1.0, ...
                'DisplayName', app.t('太阳直射', 'Direct solar'));
            plot(app.ScenarioAxes(2), timeHour, ...
                sum(result.loads.albedoW, 2), 'LineWidth', 1.0, ...
                'DisplayName', app.t('地球反照', 'Earth albedo'));
            plot(app.ScenarioAxes(2), timeHour, ...
                sum(result.loads.earthIRW, 2), 'LineWidth', 1.0, ...
                'DisplayName', app.t('地球红外', 'Earth infrared'));
            hold(app.ScenarioAxes(2), 'off');
            title(app.ScenarioAxes(2), app.t('外部热流', 'External heat loads'));
            xlabel(app.ScenarioAxes(2), app.t('时间（h）', 'Time (h)'));
            ylabel(app.ScenarioAxes(2), app.t('功率（W）', 'Power (W)'));
            legend(app.ScenarioAxes(2), 'Location', 'best');

            [indices, labels] = app.displayNodes(result.network);
            hold(app.ScenarioAxes(3), 'on');
            for k = 1:numel(indices)
                plot(app.ScenarioAxes(3), timeHour, ...
                    result.temperatureK(:, indices(k)), 'LineWidth', 1.0);
            end
            hold(app.ScenarioAxes(3), 'off');
            title(app.ScenarioAxes(3), app.t('关键节点温度', ...
                'Key-node temperatures'));
            xlabel(app.ScenarioAxes(3), app.t('时间（h）', 'Time (h)'));
            ylabel(app.ScenarioAxes(3), app.t('温度（K）', 'Temperature (K)'));
            legend(app.ScenarioAxes(3), labels, 'Interpreter', 'none', ...
                'Location', 'best');

            plot(app.ScenarioAxes(4), timeHour, result.codeBiasM, ...
                'Color', [0.65, 0.16, 0.20], 'LineWidth', 1.1, ...
                'DisplayName', app.t('温度诱导码偏差', ...
                'Temperature-induced code bias'));
            title(app.ScenarioAxes(4), app.t('半仿真温度诱导码偏差', ...
                'Semi-synthetic temperature-induced code bias'));
            xlabel(app.ScenarioAxes(4), app.t('时间（h）', 'Time (h)'));
            ylabel(app.ScenarioAxes(4), app.t('偏差（m）', 'Bias (m)'));
            legend(app.ScenarioAxes(4), 'Location', 'best');
        end

        function updateSweepPlots(app)
            summary = app.CurrentSweep;
            if isempty(summary)
                return
            end
            valid = strcmp(summary.status, 'complete');
            if ismember('accessible', summary.Properties.VariableNames)
                valid = valid & summary.accessible;
            end
            data = summary(valid, :);
            if isempty(data)
                for k=1:numel(app.SweepAxes), cla(app.SweepAxes(k)); end
                app.updateSweepTable(summary(1:min(500,height(summary)),:));
                return
            end
            if ismember('actual_beta_deg', data.Properties.VariableNames)
                x = data.actual_beta_deg;
                temperatureName = 'response_temperature_span_k';
            else
                x = data.beta_deg;
                temperatureName = 'rf_temperature_span_k';
            end
            variables = {'eclipse_fraction', temperatureName, ...
                'forcing_to_rf_lag_s', 'code_bias_span_m'};
            labels = app.t({'入影比例', '响应温度跨度（K）', ...
                '热流到响应节点的时延（s）', '码偏差跨度（m）'}, ...
                {'Eclipse fraction', 'Response-temperature span (K)', ...
                'Forcing-to-response lag (s)', 'Code-bias span (m)'});
            altitudes = unique(data.altitude_km);
            colors = lines(numel(altitudes));
            for k = 1:4
                axesHandle = app.SweepAxes(k);
                cla(axesHandle);
                hold(axesHandle, 'on');
                for a = 1:numel(altitudes)
                    rows = data.altitude_km == altitudes(a);
                    panelValues = data.(variables{k});
                    scatter(axesHandle, x(rows), panelValues(rows), ...
                        34, colors(a, :), 'filled', ...
                        'DisplayName', app.altitudeLegend(altitudes(a)));
                end
                hold(axesHandle, 'off');
                xlabel(axesHandle, app.t('实际β角（°）', ...
                    'Actual beta angle (deg)'));
                ylabel(axesHandle, labels{k});
                title(axesHandle, labels{k});
                legend(axesHandle, 'Location', 'best');
            end
            displayRows = min(height(summary), 500);
            app.updateSweepTable(summary(1:displayRows, :));
        end

        function updateResultSummary(app)
            app.refreshCalibrationContext;
            app.updateResultState;
            app.updateTaskPanel;
            app.updateResultConclusion;
            if isempty(app.CurrentResult)
                app.MetricsTable.Data = table;
            else
                metrics = app.CurrentResult.metrics;
                names = fieldnames(metrics);
                values = strings(numel(names), 1);
                descriptions = strings(numel(names), 1);
                for k = 1:numel(names)
                    value = metrics.(names{k});
                    descriptions(k) = app.metricDescription(names{k});
                    if islogical(value) && isscalar(value)
                        values(k) = app.t('否','No');
                        if value, values(k) = app.t('是','Yes'); end
                    elseif isnumeric(value) && isscalar(value) && isnan(value)
                        values(k) = app.t('不可识别或不适用','Not identifiable or not applicable');
                    elseif isnumeric(value) && isscalar(value)
                        values(k) = sprintf('%.8g', value);
                    else
                        values(k) = app.t('<非标量>', '<non-scalar>');
                    end
                end
                app.MetricsTable.Data = table(descriptions, values, ...
                    'VariableNames', {'description', 'value'});
                app.MetricsTable.ColumnName = app.t({'指标', '数值'}, ...
                    {'Metric', 'Value'});
            end

            lines = {sprintf(app.t('软件版本：%s', 'Software version: %s'), ...
                leotherm.version); ...
                sprintf(app.t('场景：%s', 'Scenario: %s'), ...
                app.displayScenarioName); ...
                sprintf(app.t('热网络：%s', 'Thermal network: %s'), ...
                app.displayNetworkName); ...
                sprintf(app.t('节点数：%d', 'Number of nodes: %d'), ...
                numel(app.CurrentNetwork.nodeNames)); ...
                sprintf(app.t('分析时长：%.3f h', 'Analysis duration: %.3f h'), ...
                app.CurrentScenario.durationS / 3600); ...
                sprintf(app.t('时间步长：%.3f s', 'Time step: %.3f s'), ...
                app.CurrentScenario.timeStepS)};
            if ~isempty(app.CurrentResult)
                lines{end + 1} = sprintf(app.t('单场景历元：%d', ...
                    'Scenario epochs: %d'), ...
                    numel(app.CurrentResult.timeS));
                lines{end + 1} = sprintf(app.t('平均β角：%.4f°', ...
                    'Mean beta angle: %.4f deg'), ...
                    app.CurrentResult.metrics.meanBetaDeg);
                lines{end + 1} = sprintf(app.t('入影比例：%.4f', ...
                    'Eclipse fraction: %.4f'), ...
                    app.CurrentResult.metrics.eclipseFraction);
            end
            if ~isempty(app.CurrentMeshResult)
                lines{end + 1} = sprintf(app.t('面片历元/面数：%d / %d', ...
                    'Face epochs/faces: %d / %d'), ...
                    numel(app.CurrentMeshResult.timeS), ...
                    size(app.CurrentMeshResult.mesh.faces, 1));
                shadowed = 0;
                if isfield(app.CurrentMeshResult, 'shadowedFaceCount')
                    shadowed = max(app.CurrentMeshResult.shadowedFaceCount);
                end
                lines{end + 1} = sprintf(app.t('最大自遮挡面片数：%d', ...
                    'Maximum self-shadowed faces: %d'), shadowed);
            end
            if ~isempty(app.CurrentVolumeResult)
                lines{end + 1} = sprintf(app.t('体网格节点/历元：%d / %d', ...
                    'Volume nodes/epochs: %d / %d'), ...
                    app.CurrentVolumeResult.mesh.nodeCount, ...
                    numel(app.CurrentVolumeResult.timeS));
            end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                lines{end + 1} = sprintf(app.t('表面—体耦合闭合误差：%.6g W', ...
                    'Surface-volume coupling closure: %.6g W'), ...
                    app.CurrentSurfaceVolumeResult.couplingDiagnostics.maximumAbsoluteClosureW);
                lines{end + 1} = app.t('耦合模式：外部面片辐射到体导热（无面温反馈）', ...
                    'Coupling mode: external face radiation to volume conduction (no face-temperature feedback)');
            end
            if ~isempty(app.CurrentSweep)
                complete = sum(strcmp(app.CurrentSweep.status, 'complete'));
                failed = sum(strcmp(app.CurrentSweep.status, 'failed'));
                lines{end + 1} = ' ';
                lines{end + 1} = sprintf(app.t('扫描模式：%s', ...
                    'Sweep mode: %s'), app.displaySweepMode);
                lines{end + 1} = sprintf(app.t('扫描案例：%d', ...
                    'Sweep cases: %d'), height(app.CurrentSweep));
                lines{end + 1} = sprintf(app.t('完整/失败：%d / %d', ...
                    'Complete/failed: %d / %d'), complete, failed);
            end
            if ~isempty(app.LastTaskSnapshot)
                lines{end + 1} = ' ';
                lines{end + 1} = sprintf(app.t('最近任务ID：%s', 'Latest task ID: %s'), ...
                    app.LastTaskSnapshot.taskId);
                lines{end + 1} = sprintf(app.t('历史运行数：%d', 'Recorded runs: %d'), ...
                    numel(app.TaskHistory));
            end
            lines{end + 1} = ' ';
            lines{end + 1} = app.t('解释边界：', 'Interpretation boundary:');
            lines{end + 1} = app.t( ...
                '默认网络未经具体任务遥测或热真空试验标定。', ...
                'The default network is not calibrated against mission telemetry or thermal-vacuum tests.');
            lines{end + 1} = app.t( ...
                '温度诱导码偏差属于半仿真观测模型。', ...
                'The temperature-induced code bias is a semi-synthetic observation model.');
            app.SessionSummary.Value = lines;
        end

        function updateResultConclusion(app)
            if isempty(app.ResultConclusionLabel) || ~isvalid(app.ResultConclusionLabel)
                return
            end
            if isempty(app.CurrentResult) && isempty(app.CurrentSweep) ...
                    && isempty(app.CurrentMeshResult) && isempty(app.CurrentVolumeResult) ...
                    && isempty(app.CurrentSurfaceVolumeResult)
                app.ResultConclusionLabel.Text = app.t( ...
                    '还没有结果。请从“快速开始”选择一个任务，或进入“仿真”配置后运行。', ...
                    'No results yet. Choose a task in Quick start or configure and run it under Simulation.');
                app.ResultConclusionLabel.FontColor = [0.28 0.35 0.35];
                return
            end
            messages = {};
            stale = false;
            if ~isempty(app.CurrentResult)
                if app.resultIsStale
                    messages{end + 1} = app.t('单场景结果已过期，请重新运行。', ...
                        'The scenario result is stale; rerun it.');
                    stale = true;
                else
                    messages{end + 1} = app.t('单场景仿真已完成，结果与当前输入一致。', ...
                        'The scenario simulation is complete and matches the current inputs.');
                end
            end
            if ~isempty(app.CurrentSweep)
                if app.sweepIsStale
                    messages{end + 1} = app.t('参数扫描结果已过期，请重新运行。', ...
                        'The sweep result is stale; rerun it.');
                    stale = true;
                else
                    messages{end + 1} = app.t('参数扫描已完成，结果与当前输入一致。', ...
                        'The parameter sweep is complete and matches the current inputs.');
                end
            end
            if ~isempty(app.CurrentMeshResult)
                messages{end + 1} = app.t('面片热仿真已完成。', 'The face thermal simulation is complete.');
            end
            if ~isempty(app.CurrentVolumeResult)
                if app.volumeResultIsStale
                    messages{end + 1} = app.t('体网格结果已过期，请重新运行。', ...
                        'The volume result is stale; rerun it.');
                    stale = true;
                else
                    messages{end + 1} = app.t('体网格导热分析已完成。', ...
                        'The volume conduction analysis is complete.');
                end
            end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                if app.surfaceVolumeResultIsStale
                    messages{end + 1} = app.t('表面—体耦合结果已过期，请重新运行。', ...
                        'The surface-volume coupling result is stale; rerun it.');
                    stale = true;
                else
                    messages{end + 1} = app.t( ...
                        '表面—体网格单向守恒耦合已完成；面片温度未反馈到体网格。', ...
                        'The conservative one-way surface-volume run is complete; face temperature was not fed back into the volume state.');
                end
            end
            app.ResultConclusionLabel.Text = strjoin(messages, ' ');
            app.ResultConclusionLabel.FontColor = [0.70 0.25 0.12];
            if ~stale
                app.ResultConclusionLabel.FontColor = [0.10 0.45 0.30];
            end
        end

        function updateTaskPanel(app)
            if isempty(app.TaskStatusLabel) || ~isvalid(app.TaskStatusLabel)
                return
            end
            try
                scenario = app.collectScenario;
            catch exception
                app.TaskStatusLabel.Text = app.t('需要检查', 'Needs review');
                app.TaskStatusLabel.FontColor = [0.70, 0.25, 0.12];
                app.TaskGuidanceLabel.Text = app.localizedExceptionMessage(exception);
                app.TaskSummaryLabel.Text = app.t('场景输入尚未完整，暂不能生成仿真任务。', ...
                    'Scenario inputs are incomplete; the simulation task cannot be created yet.');
                app.TaskRunButton.Enable = 'off';
                app.TaskSweepButton.Enable = 'off';
                app.TaskResultsButton.Enable = app.onOff(~isempty(app.CurrentResult) ...
                    || ~isempty(app.CurrentSweep) || ~isempty(app.CurrentMeshResult) ...
                    || ~isempty(app.CurrentVolumeResult) || ~isempty(app.CurrentSurfaceVolumeResult));
                return
            end
            telemetry = app.TelemetryWorkspace.getState;
            sourceText = app.t('未载入遥测', 'No telemetry loaded');
            if ~isempty(telemetry.source)
                sourceText = app.t('已载入遥测', 'Telemetry loaded');
            end
            calibration = app.CalibrationWorkspace.getState;
            calibrationText = app.t('未标定', 'Not calibrated');
            if ~isempty(calibration.result)
                calibrationText = app.t('已有标定结果', 'Calibration result available');
            end
            resultStates = {};
            if ~isempty(app.CurrentResult)
                if app.resultIsStale
                    resultStates{end + 1} = app.t('单场景已过期', 'Scenario stale');
                else
                    resultStates{end + 1} = app.t('单场景有效', 'Scenario current');
                end
            end
            if ~isempty(app.CurrentSweep)
                if app.sweepIsStale
                    resultStates{end + 1} = app.t('扫描已过期', 'Sweep stale');
                else
                    resultStates{end + 1} = app.t('扫描有效', 'Sweep current');
                end
            end
            if ~isempty(app.CurrentMeshResult)
                if app.meshResultIsStale
                    resultStates{end + 1} = app.t('面片已过期', 'Face stale');
                else
                    resultStates{end + 1} = app.t('面片有效', 'Face current');
                end
            end
            if ~isempty(app.CurrentVolumeResult)
                if app.volumeResultIsStale
                    resultStates{end + 1} = app.t('体网格已过期', 'Volume stale');
                else
                    resultStates{end + 1} = app.t('体网格有效', 'Volume current');
                end
            end
            if ~isempty(app.CurrentSurfaceVolumeResult)
                if app.surfaceVolumeResultIsStale
                    resultStates{end + 1} = app.t('表面—体耦合已过期', ...
                        'Surface-volume coupling stale');
                else
                    resultStates{end + 1} = app.t('表面—体耦合有效', ...
                        'Surface-volume coupling current');
                end
            end
            if isempty(resultStates)
                resultText = app.t('未运行', 'Not run');
            else
                resultText = strjoin(resultStates, ', ');
            end
            task = app.buildSimulationTask(scenario, app.CurrentNetwork, telemetry, ...
                calibration, app.captureScanSettings, 'scenario');
            audit = app.taskValidationReport(task);
            ready = audit.ready;
            status = app.t('可运行', 'Ready to run');
            color = [0.10, 0.45, 0.30];
            guidance = app.t('配置完整，可以开始仿真。', ...
                'Configuration is complete and ready to run.');
            if ~ready
                status = app.t('需要检查', 'Needs review');
                color = [0.70, 0.25, 0.12];
                guidance = strjoin(cellstr(audit.errors), ' ');
            elseif ~isempty(audit.warnings)
                warningText = app.localizedTaskWarnings(audit);
                guidance = strjoin(warningText, ' ');
            end
            summary = sprintf(app.t( ...
                '场景：%s    热网络：%s    节点：%d\n数据：%s    标定：%s    结果：%s    设置：%.3f h / %.3f s / %d 圈', ...
                'Scenario: %s    Thermal network: %s    Nodes: %d\nData: %s    Calibration: %s    Result: %s    Settings: %.3f h / %.3f s / %d orbits'), ...
                app.displayScenarioName, app.displayNetworkName, numel(app.CurrentNetwork.nodeNames), ...
                sourceText, calibrationText, resultText, scenario.durationS / 3600, ...
                scenario.timeStepS, scenario.warmupOrbits);
            app.TaskStatusLabel.Text = status;
            app.TaskStatusLabel.FontColor = color;
            app.TaskSummaryLabel.Text = summary;
            app.TaskGuidanceLabel.Text = guidance;
            app.TaskRunButton.Enable = app.onOff(ready && ~app.IsBusy);
            app.TaskSweepButton.Enable = app.onOff(ready && ~app.IsBusy);
            app.TaskCheckButton.Enable = app.onOff(~app.IsBusy);
            app.TaskResultsButton.Enable = app.onOff(~isempty(app.CurrentResult) ...
                || ~isempty(app.CurrentSweep) || ~isempty(app.CurrentMeshResult) ...
                || ~isempty(app.CurrentVolumeResult) || ~isempty(app.CurrentSurfaceVolumeResult));
        end

        function [ready, message] = checkSimulationTask(app, varargin)
            runMode = 'scenario';
            if nargin > 1 && ~isempty(varargin), runMode = varargin{1}; end
            try
                scenario = app.collectScenario;
                telemetry = app.TelemetryWorkspace.getState;
                calibration = app.CalibrationWorkspace.getState;
                task = app.buildSimulationTask(scenario, app.CurrentNetwork, telemetry, ...
                    calibration, app.captureScanSettings, runMode);
                audit = app.taskValidationReport(task);
                ready = audit.ready;
                if ready
                    message = app.t('场景、热网络和任务设置均有效。可以运行仿真。', ...
                        'Scenario, thermal network and task settings are valid. The simulation can run.');
                    if ~isempty(audit.warnings)
                        message = [message newline strjoin(cellstr(audit.warnings), newline)];
                    end
                else
                    message = strjoin(cellstr(audit.errors), newline);
                end
            catch exception
                ready = false;
                message = app.localizedExceptionMessage(exception);
            end
        end

        function task = buildSimulationTask(app, scenario, network, telemetry, calibration, scanSettings, runMode)
            task = leotherm.createSimulationTask(scenario, network, telemetry, ...
                calibration, scanSettings, runMode, app.CurrentGeometry, app.CurrentVolumeMesh);
            task.createdUTC = datetime(2000, 1, 1, 'TimeZone', 'UTC');
        end

        function updateThermalModelUI(app)
            if isempty(app.ThermalModelStatusLabel) || ~isvalid(app.ThermalModelStatusLabel)
                return
            end
            loaded = ~isempty(app.CurrentThermalModel);
            app.ThermalModelExportMATButton.Enable = app.onOff(loaded && ~app.IsBusy);
            app.ThermalModelExportJSONButton.Enable = app.onOff(loaded && ~app.IsBusy);
            mappingLoaded = ~isempty(app.CurrentThermalModelMapping);
            previewed = ~isempty(app.CurrentThermalModelPreview);
            if ~isempty(app.ThermalModelMappingImportButton) && isvalid(app.ThermalModelMappingImportButton)
                app.ThermalModelMappingImportButton.Enable = app.onOff(loaded && ~app.IsBusy);
                app.ThermalModelMappingTemplateButton.Enable = app.onOff(loaded && ~app.IsBusy);
                app.ThermalModelMappingPreviewButton.Enable = app.onOff(loaded && mappingLoaded && ~app.IsBusy);
                app.ThermalModelMappingApplyButton.Enable = app.onOff(loaded && previewed && ...
                    app.CurrentThermalModelPreview.valid && isempty(app.CurrentThermalModelPreview.conflicts) && ~app.IsBusy);
                app.ThermalModelMappingRollbackButton.Enable = app.onOff(~isempty(app.ThermalModelNetworkRollback) && ~app.IsBusy);
            end
            if ~loaded
                app.ThermalModelStatusLabel.Text = app.t('未载入工程热模型', ...
                    'No engineering thermal model loaded');
                app.ThermalModelStatusLabel.FontColor = [0.35, 0.40, 0.40];
                app.ThermalModelSummary.Value = app.t( ...
                    {'尚未载入规范工程热模型。'; ...
                     '可导入 leotherm.thermal_model.v1 的 MAT 或 JSON 文件。'}, ...
                    {'No canonical engineering thermal model is loaded.'; ...
                     'Import a MAT or JSON file with schema leotherm.thermal_model.v1.'});
                return
            end
            model = app.CurrentThermalModel;
            [nodeCount, materialCount] = app.thermalModelCounts(model);
            schema = app.thermalModelText(model, {'schema','schemaVersion'}, '—');
            modelId = '—'; unitsText = '—'; source = '—';
            if isfield(model, 'metadata') && isstruct(model.metadata)
                modelId = app.thermalModelText(model.metadata, {'modelId'}, '—');
                if isfield(model.metadata, 'units') && isstruct(model.metadata.units)
                    unitsText = app.thermalUnitsText(model.metadata.units);
                end
            elseif isfield(model, 'units') && isstruct(model.units)
                unitsText = app.thermalUnitsText(model.units);
            end
            if isfield(model, 'provenance') && isstruct(model.provenance)
                source = app.thermalModelText(model.provenance, {'source'}, '—');
            end
            app.ThermalModelStatusLabel.Text = app.t('校验通过', 'Validated');
            app.ThermalModelStatusLabel.FontColor = [0.10, 0.45, 0.30];
            summary = { ...
                sprintf('schema: %s', schema), ...
                sprintf('%s: %s', app.t('模型 ID','model ID'), modelId), ...
                sprintf('%s: %s', app.t('单位','units'), unitsText), ...
                sprintf('%s: %s', app.t('来源','source'), source), ...
                sprintf('%s: %d    %s: %d', app.t('节点','nodes'), nodeCount, ...
                    app.t('材料','materials'), materialCount), ...
                app.t('校验状态: 通过（规范模型校验器）', ...
                    'validation status: passed (canonical model validator)')};
            if ~mappingLoaded
                summary{end+1} = app.t('映射：未载入（可载入或生成显式模板）', ...
                    'mapping: not loaded (load or generate an explicit template)');
            else
                summary{end+1} = app.t('映射：已载入显式文件/模板', 'mapping: explicit file/template loaded');
            end
            if previewed
                p = app.CurrentThermalModelPreview;
                summary{end+1} = sprintf('%s: %d    %s: %d    %s: %d', ...
                    app.t('预览变更','preview changes'), numel(p.changedFields), ...
                    app.t('未映射节点','unmapped nodes'), numel(p.unmappedExchangeNodeIds), ...
                    app.t('冲突','conflicts'), numel(p.conflicts));
                summary{end+1} = sprintf('%s: %s', app.t('预览指纹','preview fingerprint'), p.fingerprint);
            end
            app.ThermalModelSummary.Value = summary;
        end

        function [model, report, accepted] = importNormalizedThermalModel(~, filePath)
            model = []; report = struct; accepted = false;
            [~, ~, ext] = fileparts(char(filePath));
            try
                switch lower(ext)
                    case '.mat'
                        loaded = load(char(filePath));
                        names = fieldnames(loaded);
                        if isfield(loaded, 'thermalModel')
                            model = loaded.thermalModel;
                        elseif isfield(loaded, 'model')
                            model = loaded.model;
                        elseif numel(names) == 1
                            model = loaded.(names{1});
                        else
                            return
                        end
                    case '.json'
                        model = jsondecode(fileread(char(filePath)));
                    otherwise
                        return
                end
                if ~isstruct(model) || ~isfield(model, 'network'), return; end
                leotherm.model.validate(model);
                info = dir(char(filePath));
                report = struct('path', char(filePath), 'format', lower(ext(2:end)), ...
                    'bytes', info.bytes, 'schema', model.schema, ...
                    'validation', 'leotherm.model.validate');
                accepted = true;
            catch
                model = []; report = struct; accepted = false;
            end
        end

        function [mapping, report] = readThermalModelMapping(~, filePath)
            [~, ~, ext] = fileparts(char(filePath));
            switch lower(ext)
                case '.mat'
                    loaded = load(char(filePath));
                    names = fieldnames(loaded);
                    if isfield(loaded, 'mapping')
                        mapping = loaded.mapping;
                    elseif isfield(loaded, 'thermalModelMapping')
                        mapping = loaded.thermalModelMapping;
                    elseif numel(names) == 1
                        mapping = loaded.(names{1});
                    else
                        error('leotherm:NetworkMappingInvalid', ...
                            'MAT mapping must contain one mapping variable.');
                    end
                case '.json'
                    mapping = jsondecode(fileread(char(filePath)));
                otherwise
                    error('leotherm:NetworkMappingInvalid', 'Mapping file must be MAT or JSON.');
            end
            if ~isstruct(mapping) || ~isscalar(mapping)
                error('leotherm:NetworkMappingInvalid', 'Mapping must be a scalar structure.');
            end
            if ~isfield(mapping, 'schema') || ~strcmp(char(string(mapping.schema)), ...
                    'leotherm.thermal_model_mapping.v1')
                error('leotherm:NetworkMappingInvalid', ...
                    'mapping.schema must equal leotherm.thermal_model_mapping.v1.');
            end
            info = dir(char(filePath));
            report = struct('path', char(filePath), 'format', lower(ext(2:end)), ...
                'bytes', info.bytes, 'schema', mapping.schema);
        end

        function importThermalModelUI(app)
            if app.IsBusy, return; end
            [file, folder] = uigetfile({'*.mat;*.json', ...
                app.t('工程热模型 (*.mat, *.json)', 'Engineering thermal model (*.mat, *.json)')}, ...
                app.t('导入工程热模型', 'Import engineering thermal model'));
            if isequal(file, 0), return; end
            try
                app.loadThermalModel(fullfile(folder, file));
            catch exception
                app.showException(app.t('工程热模型导入失败', ...
                    'Engineering thermal model import failed'), exception);
            end
        end

        function importThermalModelMappingUI(app)
            if app.IsBusy || isempty(app.CurrentThermalModel), return; end
            [file, folder] = uigetfile({'*.mat;*.json', ...
                app.t('显式映射 (*.mat, *.json)', 'Explicit mapping (*.mat, *.json)')}, ...
                app.t('载入显式网络映射', 'Load explicit network mapping'));
            if isequal(file, 0), return; end
            try
                app.loadThermalModelMapping(fullfile(folder, file));
            catch exception
                app.showException(app.t('显式映射载入失败', 'Explicit mapping load failed'), exception);
            end
        end

        function generateThermalModelMappingTemplateUI(app)
            if app.IsBusy || isempty(app.CurrentThermalModel), return; end
            try
                mapping = app.generateThermalModelMappingTemplate;
                [file, folder] = uiputfile({'*.json', 'JSON (*.json)'}, ...
                    app.t('保存显式映射模板', 'Save explicit mapping template'), 'thermal_model_mapping.json');
                if isequal(file, 0), return; end
                target = fullfile(folder, file);
                fid = fopen(target, 'w', 'n', 'UTF-8');
                if fid < 0, error('leotherm:NetworkMappingIO', 'Cannot create mapping template.'); end
                cleaner = onCleanup(@() fclose(fid));
                fwrite(fid, unicode2native(jsonencode(mapping), 'UTF-8'), 'uint8');
                clear cleaner;
            catch exception
                app.showException(app.t('映射模板生成失败', 'Mapping template generation failed'), exception);
            end
        end

        function previewThermalModelMappingUI(app)
            if app.IsBusy || isempty(app.CurrentThermalModelMapping), return; end
            try
                app.previewThermalModelMapping;
            catch exception
                app.showException(app.t('映射预览失败', 'Mapping preview failed'), exception);
            end
        end

        function applyThermalModelMappingUI(app)
            if app.IsBusy || isempty(app.CurrentThermalModelPreview), return; end
            preview = app.CurrentThermalModelPreview;
            if ~preview.valid || ~isempty(preview.conflicts), return; end
            message = app.t( ...
                sprintf('预览包含 %d 个字段变更。确认应用到当前热网络吗？', numel(preview.changedFields)), ...
                sprintf('Preview contains %d field changes. Apply them to the current thermal network?', ...
                numel(preview.changedFields)));
            choice = uiconfirm(app.Figure, message, ...
                app.t('确认应用显式映射', 'Confirm explicit mapping application'), ...
                'Options', {app.t('应用', 'Apply'), app.t('取消', 'Cancel')}, ...
                'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(choice, app.t('应用', 'Apply')), return; end
            try
                app.applyThermalModelMapping(preview.confirmationToken);
            catch exception
                app.showException(app.t('应用映射失败', 'Mapping application failed'), exception);
            end
        end

        function rollbackThermalModelNetworkUI(app)
            if app.IsBusy || isempty(app.ThermalModelNetworkRollback), return; end
            choice = uiconfirm(app.Figure, app.t('确认回滚到工程热模型导入前的热网络吗？', ...
                'Roll back to the thermal network captured before model import?'), ...
                app.t('确认回滚', 'Confirm rollback'), 'Options', ...
                {app.t('回滚', 'Rollback'), app.t('取消', 'Cancel')}, 'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(choice, app.t('回滚', 'Rollback')), return; end
            try
                app.rollbackThermalModelNetwork;
            catch exception
                app.showException(app.t('回滚失败', 'Rollback failed'), exception);
            end
        end

        function exportThermalModelUI(app, format)
            if app.IsBusy || isempty(app.CurrentThermalModel)
                return
            end
            extension = ['*.' lower(char(format))];
            [file, folder] = uiputfile({extension, app.t( ...
                sprintf('工程热模型 (*.%s)', lower(char(format))), ...
                sprintf('Engineering thermal model (*.%s)', lower(char(format))))}, ...
                app.t('导出工程热模型', 'Export engineering thermal model'), ...
                ['thermal_model.' lower(char(format))]);
            if isequal(file, 0), return; end
            [~, ~, ext] = fileparts(file);
            if isempty(ext), file = [file extension(2:end)]; end
            try
                app.saveThermalModel(fullfile(folder, file));
            catch exception
                app.showException(app.t('工程热模型导出失败', ...
                    'Engineering thermal model export failed'), exception);
            end
        end

        function [nodeCount, materialCount] = thermalModelCounts(~, model)
            nodeCount = 0; materialCount = 0;
            if isfield(model, 'nodes'), nodeCount = numel(model.nodes); end
            if isfield(model, 'materials'), materialCount = numel(model.materials); end
            if isfield(model, 'network') && isstruct(model.network) && ...
                    isfield(model.network, 'nodeNames')
                nodeCount = numel(model.network.nodeNames);
            end
            if isfield(model, 'material') && ~isempty(model.material)
                materialCount = max(materialCount, numel(model.material));
            end
        end

        function value = thermalModelText(~, source, fields, fallback)
            value = fallback;
            for k = 1:numel(fields)
                if isfield(source, fields{k}) && ~isempty(source.(fields{k}))
                    value = char(string(source.(fields{k})));
                    return
                end
            end
        end

        function value = thermalUnitsText(app, units)
            names = {'length','mass','time','temperature','power','heatCapacity','conductance','area'};
            values = cell(1, numel(names));
            for k = 1:numel(names)
                if isfield(units, names{k}), values{k} = char(string(units.(names{k}))); else, values{k} = '—'; end
            end
            value = sprintf('%s: %s; %s: %s; %s: %s; %s: %s; %s: %s; %s: %s; %s: %s; %s: %s', ...
                app.t('长度','length'), values{1}, app.t('质量','mass'), values{2}, ...
                app.t('时间','time'), values{3}, app.t('温度','temperature'), values{4}, ...
                app.t('功率','power'), values{5}, app.t('热容','heat capacity'), values{6}, ...
                app.t('导热','conductance'), values{7}, app.t('面积','area'), values{8});
        end

        function importMeshUI(app)
            if app.IsBusy, return; end
            [file, folder] = uigetfile({'*.stl;*.obj', 'Surface mesh (*.stl, *.obj)'}, ...
                app.t('选择卫星表面网格', 'Select spacecraft surface mesh'));
            if isequal(file, 0), return; end
            try
                app.loadSurfaceMesh(fullfile(folder, file), app.MeshUnit.Value);
                app.setStatus(sprintf(app.t('三维网格已导入：%s', '3-D mesh imported: %s'), file));
            catch exception
                app.showException(app.t('三维网格导入失败', '3-D mesh import failed'), exception);
            end
        end

        function importVolumeMeshUI(app)
            if app.IsBusy, return; end
            [file, folder] = uigetfile('*.msh', app.t('选择 Gmsh 体网格', 'Select Gmsh volume mesh'));
            if isequal(file, 0), return; end
            try
                app.loadVolumeMesh(fullfile(folder, file));
                app.setStatus(sprintf(app.t('Gmsh 体网格已导入：%s', 'Gmsh volume mesh imported: %s'), file));
            catch exception
                app.showException(app.t('体网格导入失败', 'Volume mesh import failed'), exception);
            end
        end

        function runVolumeThermalUI(app)
            if app.IsBusy, return; end
            if isempty(app.CurrentVolumeMesh)
                uialert(app.Figure, app.t('请先导入 Gmsh 体网格。', 'Import a Gmsh volume mesh first.'), ...
                    app.t('没有体网格', 'No volume mesh'));
                return
            end
            app.setBusy(true, app.t('正在运行体网格导热...', 'Running volume conduction...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                scenario = app.collectScenario;
                timeS = (0:scenario.timeStepS:scenario.durationS)';
                if timeS(end) < scenario.durationS, timeS(end + 1) = scenario.durationS; end
                power = zeros(numel(timeS), app.CurrentVolumeMesh.nodeCount);
                material = struct('conductivityWmK', app.VolumeConductivity.Value, ...
                    'densityKgM3', app.VolumeDensity.Value, ...
                    'specificHeatJkgK', app.VolumeSpecificHeat.Value);
                app.runVolumeThermal(timeS, power, material, struct( ...
                    'initialTemperatureK', 293.15, 'maximumTemperatureK', 500));
                app.MeshDisplayMode.Value = 'volume_temperature';
                app.previewMeshUI;
                app.setStatus(app.t('体网格导热完成。', 'Volume conduction complete.'));
            catch exception
                app.showException(app.t('体网格导热失败', 'Volume conduction failed'), exception);
            end
            clear cleanup
        end

        function runSurfaceVolumeUI(app)
            if app.IsBusy, return; end
            if isempty(app.CurrentGeometry) || isempty(app.CurrentVolumeMesh)
                uialert(app.Figure, app.t( ...
                    '请先同时导入 STL/OBJ 表面网格和 Gmsh 体网格。', ...
                    'Import both an STL/OBJ surface mesh and a Gmsh volume mesh first.'), ...
                    app.t('缺少耦合网格', 'Coupling meshes required'));
                return
            end
            app.setBusy(true, app.t('正在运行表面—体网格耦合...', ...
                'Running surface-volume coupling...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                scenario = app.collectScenario;
                material = struct('conductivityWmK', app.VolumeConductivity.Value, ...
                    'densityKgM3', app.VolumeDensity.Value, ...
                    'specificHeatJkgK', app.VolumeSpecificHeat.Value);
                result = app.runSurfaceVolume(scenario, material, app.CouplingOptions);
                app.MeshDisplayMode.Value = 'volume_temperature';
                app.previewMeshUI;
                app.setStatus(sprintf(app.t( ...
                    '表面—体耦合完成：%d个面、%d个体节点，最大映射闭合误差 %.3g W。', ...
                    'Surface-volume coupling complete: %d faces, %d volume nodes, maximum mapping closure %.3g W.'), ...
                    size(result.surfaceMesh.faces, 1), result.volume.mesh.nodeCount, ...
                    result.couplingDiagnostics.maximumAbsoluteClosureW));
            catch exception
                app.showException(app.t('表面—体耦合失败', ...
                    'Surface-volume coupling failed'), exception);
            end
            clear cleanup
        end

        function configureCouplingOptionsUI(app)
            if app.IsBusy, return; end
            options = app.CouplingOptions;
            contact = struct('leftNodes', [], 'rightNodes', [], 'conductanceWK', []);
            if isfield(options, 'contacts') && ~isempty(options.contacts)
                contact = options.contacts(1);
            end
            volumeThermal = options.volumeThermal;
            prompt = { ...
                app.t('接触左侧节点索引（逗号分隔，留空禁用）', 'Contact left node indices (comma-separated; blank disables)'), ...
                app.t('接触右侧节点索引', 'Contact right node indices'), ...
                app.t('接触热导（W/K）', 'Contact conductance (W/K)'), ...
                app.t('固定温度节点索引（逗号分隔，留空禁用）', 'Fixed-temperature node indices (comma-separated; blank disables)'), ...
                app.t('固定温度（K）', 'Fixed temperature (K)')};
            defaults = { ...
                app.listText(app.fieldOrDefault(contact, 'leftNodes', [])), ...
                app.listText(app.fieldOrDefault(contact, 'rightNodes', [])), ...
                app.scalarText(app.fieldOrDefault(contact, 'conductanceWK', []), ''), ...
                app.listText(app.fieldOrDefault(volumeThermal, 'fixedNodeIndices', [])), ...
                app.scalarText(app.fieldOrDefault(volumeThermal, 'fixedTemperatureK', 293.15), '293.15')};
            answer = inputdlg(prompt, app.t('耦合边界设置', 'Coupling boundary settings'), ...
                [1 1 1 1 1], defaults);
            if isempty(answer), return; end
            try
                candidate = leotherm.parseCouplingOptions(answer, volumeThermal);
                leotherm.validateCouplingOptions(candidate, app.CurrentVolumeMesh);
                app.CouplingOptions = candidate;
                app.CurrentSurfaceVolumeResult = [];
                app.updateResultState;
                app.setStatus(app.t('耦合边界设置已更新；请重新运行耦合。', ...
                    'Coupling boundary settings updated; rerun the coupling.'));
            catch exception
                app.showException(app.t('耦合边界设置无效', 'Invalid coupling boundary settings'), exception);
            end
        end

        function previewMeshUI(app)
            try
                mode = app.MeshDisplayMode.Value;
                if strcmp(mode, 'volume_temperature')
                    if isempty(app.CurrentVolumeResult)
                        uialert(app.Figure, app.t('请先运行体网格导热。', ...
                            'Run volume conduction first.'), app.t('没有体网格结果', 'No volume result'));
                        return
                    end
                    values = app.CurrentVolumeResult.temperatureK(end, :)';
                    leotherm.plotVolumeMesh(app.CurrentVolumeResult.mesh, values, app.MeshAxes, app.Language);
                    return
                end
            catch exception
                app.showException(app.t('体网格预览失败', 'Volume mesh preview failed'), exception);
                return
            end
            if isempty(app.CurrentGeometry)
                uialert(app.Figure, app.t('请先导入 STL 或 OBJ 网格。', ...
                    'Import an STL or OBJ mesh first.'), app.t('没有网格', 'No mesh'));
                return
            end
            try
                mode = app.MeshDisplayMode.Value;
                values = [];
                if strcmp(mode, 'final_temperature')
                    if isempty(app.CurrentMeshResult) || app.meshResultIsStale
                        uialert(app.Figure, app.t('请先运行面片热仿真。', ...
                            'Run a face thermal simulation first.'), app.t('没有面片结果', 'No face result'));
                        return
                    end
                    values = app.CurrentMeshResult.temperatureK(end, :)';
                elseif ~strcmp(mode, 'geometry')
                    scenario = app.collectScenario;
                    orbit = leotherm.propagateCircularOrbit(scenario.startEpoch, 0, scenario.orbit);
                    frame = leotherm.bodyFrame(orbit.positionM, orbit.velocityMps, ...
                        orbit.sunPositionM, scenario.attitude);
                    sunBody = squeeze(frame(1, :, :)) * ...
                        ((orbit.sunPositionM - orbit.positionM) ./ norm(orbit.sunPositionM - orbit.positionM))';
                    earthBody = squeeze(frame(1, :, :)) * ...
                        ((-orbit.positionM) ./ norm(orbit.positionM))';
                    loads = leotherm.surfaceMeshLoads(app.CurrentGeometry, sunBody', ...
                        earthBody', 1, scenario.environment);
                    if strcmp(mode, 'direct_solar')
                        values = loads.directSolarW;
                    else
                        values = loads.totalExternalW;
                    end
                end
                leotherm.plotSurfaceMesh(app.CurrentGeometry, values, app.MeshAxes, app.Language);
            catch exception
                app.showException(app.t('网格预览失败', 'Mesh preview failed'), exception);
            end
        end

        function meshRadiationSideChanged(app)
            if isempty(app.CurrentGeometry), return; end
            app.CurrentGeometry.radiationSide = app.MeshRadiationSide.Value;
            app.CurrentMeshResult = [];
            app.CurrentSurfaceVolumeResult = [];
            leotherm.validateSurfaceMesh(app.CurrentGeometry);
            app.updateMeshUI;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function meshSelfShadowingChanged(app)
            if isempty(app.CurrentGeometry) || isempty(app.MeshSelfShadowing), return; end
            app.CurrentGeometry.solarSelfShadowing = strcmp(app.MeshSelfShadowing.Value, 'on');
            app.CurrentMeshResult = [];
            app.CurrentSurfaceVolumeResult = [];
            leotherm.validateSurfaceMesh(app.CurrentGeometry);
            app.updateMeshUI;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function clearMeshUI(app)
            if app.IsBusy, return; end
            app.CurrentGeometry = [];
            app.CurrentMeshResult = [];
            app.CurrentVolumeMesh = [];
            app.CurrentVolumeModel = [];
            app.CurrentVolumeResult = [];
            app.CurrentSurfaceVolumeResult = [];
            cla(app.MeshAxes);
            app.updateMeshUI;
            app.updateVolumeUI;
            app.updateTaskPanel;
            app.updateResultState;
            app.setStatus(app.t('已移除三维几何；集中参数模型仍可运行。', ...
                '3-D geometry removed; the lumped model remains available.'));
        end

        function runMeshThermalUI(app)
            if app.IsBusy, return; end
            if isempty(app.CurrentGeometry)
                uialert(app.Figure, app.t('请先导入 STL 或 OBJ 网格。', ...
                    'Import an STL or OBJ mesh first.'), app.t('没有网格', 'No mesh'));
                return
            end
            app.setBusy(true, app.t('正在运行面片热仿真...', 'Running face thermal simulation...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                scenario = app.collectScenario;
                app.runSurfaceMesh(scenario);
                app.MeshDisplayMode.Value = 'final_temperature';
                app.previewMeshUI;
                app.updateTaskPanel;
                if app.CurrentMeshResult.provenance.directSolarSelfShadowing
                    shadowText = sprintf(app.t('；最大自遮挡面片数=%d', ...
                        '; maximum self-shadowed faces=%d'), ...
                        max(app.CurrentMeshResult.shadowedFaceCount));
                else
                    shadowText = '';
                end
                app.setStatus(sprintf(app.t('面片热仿真完成：%d个面，%d个历元%s。', ...
                    'Face thermal simulation complete: %d faces, %d epochs%s.'), ...
                    size(app.CurrentGeometry.faces, 1), numel(app.CurrentMeshResult.timeS), shadowText));
            catch exception
                app.showException(app.t('面片热仿真失败', 'Face thermal simulation failed'), exception);
            end
            clear cleanup
        end

        function updateMeshUI(app)
            app.updateVolumeUI;
            if isempty(app.MeshStatusLabel) || ~isvalid(app.MeshStatusLabel), return; end
            if isempty(app.CurrentGeometry)
                app.MeshStatusLabel.Text = app.t('未载入三维几何', 'No 3-D geometry loaded');
                app.MeshStatusLabel.FontColor = [0.35, 0.40, 0.40];
                app.MeshStatsLabel.Text = '';
                return
            end
            mesh = app.CurrentGeometry;
            if isfield(mesh, 'solarSelfShadowing')
                app.MeshSelfShadowing.Value = 'off';
                if mesh.solarSelfShadowing, app.MeshSelfShadowing.Value = 'on'; end
            end
            app.MeshStatusLabel.Text = app.t('三维几何已载入', '3-D geometry loaded');
            app.MeshStatusLabel.FontColor = [0.10, 0.45, 0.30];
            app.MeshStatsLabel.Text = sprintf(app.t('%d个顶点 | %d个面 | %.4g m² | 闭合=%s', ...
                '%d vertices | %d faces | %.4g m² | watertight=%s'), ...
                size(mesh.vertices,1), size(mesh.faces,1), mesh.totalAreaM2, ...
                app.onOffText(mesh.isWatertight));
            app.previewMeshUI;
        end

        function volumeParameterChanged(app)
            app.updateVolumeUI;
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
        end

        function updateVolumeUI(app)
            if isempty(app.VolumeStatusLabel) || ~isvalid(app.VolumeStatusLabel), return; end
            if isempty(app.CurrentVolumeMesh)
                app.VolumeStatusLabel.Text = app.t('未载入体网格', 'No volume mesh loaded');
                app.VolumeStatusLabel.FontColor = [0.35 0.40 0.40];
                return
            end
            mesh = app.CurrentVolumeMesh;
            app.VolumeStatusLabel.Text = sprintf(app.t('%d节点 | %d四面体%s', ...
                '%d nodes | %d tetrahedra%s'), mesh.nodeCount, mesh.tetrahedronCount, ...
                app.t('', ''));
            app.VolumeStatusLabel.FontColor = [0.10 0.45 0.30];
            if ~isempty(app.CurrentVolumeResult)
                if app.volumeResultIsStale
                    app.VolumeStatusLabel.Text = sprintf(app.t('%d节点 | %d四面体 | 结果已过期', ...
                        '%d nodes | %d tetrahedra | result is stale'), ...
                        mesh.nodeCount, mesh.tetrahedronCount);
                    app.VolumeStatusLabel.FontColor = [0.70 0.25 0.12];
                else
                    app.VolumeStatusLabel.Text = sprintf(app.t('%d节点 | %d四面体 | 已完成', ...
                        '%d nodes | %d tetrahedra | complete'), ...
                        mesh.nodeCount, mesh.tetrahedronCount);
                end
            end
        end

        function updateVolumePlot(app)
            if isempty(app.CurrentVolumeResult) || isempty(app.MeshAxes) || ~isvalid(app.MeshAxes)
                return
            end
            leotherm.plotVolumeMesh(app.CurrentVolumeResult.mesh, ...
                app.CurrentVolumeResult.temperatureK(end, :)', app.MeshAxes, app.Language);
        end

        function stale = volumeResultIsStale(app)
            stale = isempty(app.CurrentVolumeResult);
            if stale, return; end
            try
                result = app.CurrentVolumeResult;
                material = result.model.material;
                stale = ~isequaln(result.mesh, app.CurrentVolumeMesh) ...
                    || ~isequaln(material.conductivityWmK, app.VolumeConductivity.Value) ...
                    || ~isequaln(material.densityKgM3, app.VolumeDensity.Value) ...
                    || ~isequaln(material.specificHeatJkgK, app.VolumeSpecificHeat.Value);
            catch
                stale = true;
            end
        end

        function stale = surfaceVolumeResultIsStale(app)
            stale = isempty(app.CurrentSurfaceVolumeResult);
            if stale, return; end
            try
                result = app.CurrentSurfaceVolumeResult;
                material = result.volume.model.material;
                stale = ~isequaln(result.scenario, app.collectScenario) ...
                    || ~isequaln(result.surfaceMesh, app.CurrentGeometry) ...
                    || ~isequaln(result.volumeMesh, app.CurrentVolumeMesh) ...
                    || ~isequaln(material.conductivityWmK, app.VolumeConductivity.Value) ...
                    || ~isequaln(material.densityKgM3, app.VolumeDensity.Value) ...
                    || ~isequaln(material.specificHeatJkgK, app.VolumeSpecificHeat.Value);
            catch
                stale = true;
            end
        end

        function value = onOffText(app, flag)
            if strcmp(app.Language, 'en')
                if flag, value = 'yes'; else, value = 'no'; end
            else
                if flag, value = '是'; else, value = '否'; end
            end
        end

        function value = fieldOrDefault(~, source, name, fallback)
            if isstruct(source) && isfield(source, name) && ~isempty(source.(name))
                value = source.(name);
            else
                value = fallback;
            end
        end

        function value = listText(~, values)
            if isempty(values)
                value = '';
            else
                value = strjoin(cellstr(string(values(:)')), ',');
            end
        end

        function value = scalarText(~, values, fallback)
            if isempty(values)
                value = fallback;
            else
                value = char(string(values(1)));
            end
        end

        function stale = meshResultIsStale(app)
            stale = isempty(app.CurrentMeshResult);
            if stale, return; end
            stale = ~isequaln(app.CurrentMeshResult.scenario, app.collectScenario) ...
                || ~isequaln(app.CurrentMeshResult.mesh, app.CurrentGeometry);
        end

        function value = fieldOrEmpty(~, structure, name)
            value = [];
            if isstruct(structure) && isfield(structure, name)
                value = structure.(name);
            end
        end

        function value = validateFaceVector(~, value, nFace, label)
            if ~isnumeric(value) || ~isvector(value) || numel(value) ~= nFace ...
                    || any(~isfinite(value)) || any(value <= 0)
                error('leotherm:InvalidMeshThermalInput', ...
                    '%s must contain %d positive finite values.', label, nFace);
            end
            value = value(:);
        end

        function audit = taskValidationReport(~, task)
            try
                audit = leotherm.validateSimulationTask(task);
            catch exception
                audit = struct('ready', false, 'errors', string(exception.message), ...
                    'warnings', strings(0,1), 'codes', "invalid_simulation_task", ...
                    'taskId', "");
            end
        end

        function recordTaskRun(app, snapshot, runType, status)
            entry = struct('taskId', snapshot.taskId, 'runType', char(runType), ...
                'status', char(status), 'startedUTC', snapshot.frozenUTC, ...
                'completedUTC', datetime('now', 'TimeZone', 'UTC'), ...
                'inputFingerprint', snapshot.inputFingerprint);
            app.TaskHistory(end + 1) = entry;
        end

        function checkTaskUI(app)
            [ready, message] = app.checkSimulationTask;
            app.updateTaskPanel;
            title = app.t('仿真配置检查', 'Simulation configuration check');
            if ready
                uialert(app.Figure, message, title, 'Icon', 'success');
            else
                uialert(app.Figure, message, title, 'Icon', 'warning');
            end
        end

        function runTaskScenario(app)
            [ready, ~] = app.checkSimulationTask('scenario');
            if ready
                app.executeScenarioFromUI;
            else
                app.checkTaskUI;
            end
        end

        function runTaskSweep(app)
            [ready, ~] = app.checkSimulationTask('sweep');
            if ready
                app.executeSweepFromUI;
            else
                app.checkTaskUI;
            end
        end

        function openTaskResults(app)
            if ~isempty(app.CurrentResult) || ~isempty(app.CurrentSweep) ...
                    || ~isempty(app.CurrentMeshResult) || ~isempty(app.CurrentVolumeResult) ...
                    || ~isempty(app.CurrentSurfaceVolumeResult)
                app.MainTabGroup.SelectedTab = app.ResultsTab;
            end
        end

        function openAdvancedWorkspace(app)
            app.MainTabGroup.SelectedTab = app.SimulationTab;
            app.TabGroup.SelectedTab = app.ScenarioTab;
        end

        function openExampleProjectUI(app)
            if app.IsBusy
                return
            end
            root = leotherm.installRoot;
            projectDir = fullfile(root, 'examples', 'projects');
            files = dir(fullfile(projectDir, '*.mat'));
            if isempty(files)
                uialert(app.Figure, app.t( ...
                    '尚未生成示例项目。请先运行 examples/create_example_projects。', ...
                    'Example projects are not generated yet. Run examples/create_example_projects first.'), ...
                    app.t('没有示例项目', 'No example projects'));
                return
            end
            names = {files.name};
            [index, ok] = listdlg('PromptString', app.t('选择示例项目', 'Choose an example project'), ...
                'SelectionMode', 'single', 'ListString', names, ...
                'Name', app.t('示例项目', 'Example projects'), 'ListSize', [360, 180]);
            if ~ok, return; end
            try
                if ~app.confirmLeave, return; end
                app.loadProject(fullfile(projectDir, names{index}));
                app.setStatus(sprintf(app.t('示例项目已打开：%s', ...
                    'Example project opened: %s'), names{index}));
            catch exception
                app.showException(app.t('示例项目打开失败', ...
                    'Example project failed to open'), exception);
            end
        end

        function executeQuickStart(app)
            if app.IsBusy
                return
            end
            if ismember(app.QuickStartTemplate.Value, {'first', 'lag'}) ...
                    && app.hasUnsavedChanges
                choice = uiconfirm(app.Figure, app.t( ...
                    '使用模板会替换当前未保存的场景和热网络设置；已保存的项目文件不会被修改。是否继续？', ...
                    'Using a template will replace unsaved scenario and network settings; saved project files will not be changed. Continue?'), ...
                    app.t('确认使用仿真模板', 'Confirm simulation template'), ...
                    'Options', {app.t('继续', 'Continue'), app.t('取消', 'Cancel')}, ...
                    'DefaultOption', 2, 'CancelOption', 2);
                if strcmp(choice, app.t('取消', 'Cancel'))
                    return
                end
            end
            switch app.QuickStartTemplate.Value
                case 'telemetry'
                    app.MainTabGroup.SelectedTab = app.SimulationTab;
                    app.TabGroup.SelectedTab = app.TelemetryWorkspace.Tab;
                    app.setStatus(app.t('请在遥测页导入数据并完成预检。', ...
                        'Import telemetry and complete the preflight on the telemetry page.'));
                    return
                case 'first'
                    scenario = leotherm.defaultScenario;
                    scenario.durationS = 2 * 3600;
                    scenario.timeStepS = 60;
                    scenario.warmupOrbits = 1;
                    scenario.convergence.enabled = false;
                case 'lag'
                    scenario = leotherm.defaultScenario;
                    scenario.durationS = 24 * 3600;
                    scenario.timeStepS = 60;
            end
            try
                app.CurrentScenario = scenario;
                app.CurrentNetwork = leotherm.defaultReceiverNetwork;
                app.syncScenarioControls;
                app.syncNetworkControls;
                app.CurrentResult = [];
                app.CurrentSweep = table;
                app.CurrentMeshResult = [];
                app.CurrentVolumeResult = [];
                app.CurrentSurfaceVolumeResult = [];
                app.CurrentSweepMode = '';
                app.SweepContext = [];
                app.MainTabGroup.SelectedTab = app.SimulationTab;
                app.TabGroup.SelectedTab = app.ScenarioTab;
                app.updateTaskPanel;
                app.updateResultState;
                app.executeScenarioFromUI;
            catch exception
                app.showException(app.t('快速开始失败', 'Quick start failed'), exception);
            end
        end

        function openTaskWizardUI(app)
            if app.IsBusy, return; end
            root = leotherm.installRoot;
            templates = leotherm.listSimulationTemplates(fullfile(root, 'templates'));
            if isempty(templates)
                uialert(app.Figure, app.t('没有可用任务模板。', 'No task templates are available.'), ...
                    app.t('任务向导', 'Task wizard'));
                return
            end
            if ~app.confirmLeave, return; end
            names = cell(1, numel(templates));
            for k = 1:numel(templates)
                names{k} = app.t(templates(k).nameZh, templates(k).nameEn);
            end
            names{end + 1} = app.t('选择其他 JSON 模板...', 'Choose another JSON template...');
            [index, ok] = listdlg('PromptString', app.t('选择任务模板', 'Choose a task template'), ...
                'SelectionMode', 'single', 'ListString', names, ...
                'Name', app.t('任务向导：第一步', 'Task wizard: step 1'), 'ListSize', [460 220]);
            if ~ok, return; end
            try
                if index > numel(templates)
                    [file, folder] = uigetfile('*.json', ...
                        app.t('选择任务模板', 'Choose a task template'));
                    if isequal(file, 0), return; end
                    path = fullfile(folder, file);
                    template = leotherm.readSimulationTemplate(path);
                    templateEntry = struct('path', path, 'id', char(template.id), ...
                        'nameZh', char(template.nameZh), 'nameEn', char(template.nameEn));
                else
                    templateEntry = templates(index);
                    template = leotherm.readSimulationTemplate(templateEntry.path);
                end
                configuration = leotherm.applySimulationTemplate(template, ...
                    leotherm.defaultScenario, leotherm.defaultReceiverNetwork);
                answer = inputdlg({ ...
                    app.t('任务名称', 'Task name'), ...
                    app.t('仿真时长（小时）', 'Duration (hours)'), ...
                    app.t('时间步长（秒）', 'Time step (s)')}, ...
                    app.t('任务向导：第二步', 'Task wizard: step 2'), [1 1 1], ...
                    {char(configuration.scenario.name), ...
                    char(string(configuration.scenario.durationS / 3600)), ...
                    char(string(configuration.scenario.timeStepS))});
                if isempty(answer), return; end
                name = strtrim(answer{1});
                durationHours = str2double(strtrim(answer{2}));
                timeStepS = str2double(strtrim(answer{3}));
                if isempty(name) || ~isfinite(durationHours) || durationHours <= 0 ...
                        || ~isfinite(timeStepS) || timeStepS <= 0
                    error('leotherm:InvalidSimulationTemplate', ...
                        'Task name, duration, and time step must be valid.');
                end
                configuration.scenario.name = name;
                configuration.scenario.durationS = durationHours * 3600;
                configuration.scenario.timeStepS = timeStepS;
                leotherm.validateScenario(configuration.scenario);
                app.applyWizardConfiguration(configuration, templateEntry);
            catch exception
                app.showException(app.t('任务模板无效', 'Invalid task template'), exception);
            end
        end

        function applyWizardConfiguration(app, configuration, templateEntry)
            app.CurrentScenario = configuration.scenario;
            app.CurrentNetwork = configuration.network;
            app.CurrentResult = [];
            app.CurrentSweep = table;
            app.CurrentMeshResult = [];
            app.CurrentVolumeResult = [];
            app.CurrentSurfaceVolumeResult = [];
            app.CurrentSweepMode = '';
            app.SweepContext = [];
            app.ActiveTemplateId = templateEntry.id;
            app.ActiveTemplatePath = templateEntry.path;
            app.ActiveTemplateSnapshot = configuration.template;
            app.syncScenarioControls;
            app.syncNetworkControls;
            if strcmp(configuration.mode, 'telemetry')
                app.MainTabGroup.SelectedTab = app.SimulationTab;
                app.TabGroup.SelectedTab = app.TelemetryWorkspace.Tab;
                [file, folder] = uigetfile('*.csv', app.t('选择遥测 CSV', 'Choose telemetry CSV'));
                if ~isequal(file, 0)
                    app.TelemetryWorkspace.importSource(fullfile(folder, file));
                    app.TelemetryWorkspace.setWorkflow('orbit');
                    audit = app.TelemetryWorkspace.preflight;
                    app.setStatus(sprintf(app.t( ...
                        '模板和遥测已载入：%d条记录，%d个连续段。请确认预检后运行。', ...
                        'Template and telemetry loaded: %d records, %d contiguous segments. Confirm preflight before running.'), ...
                        audit.totalRows, audit.segmentCount));
                else
                    app.setStatus(app.t('模板已载入。稍后可在遥测页选择 CSV。', ...
                        'Template loaded. You can select a CSV on the telemetry page later.'));
                end
            else
                app.MainTabGroup.SelectedTab = app.SimulationTab;
                app.TabGroup.SelectedTab = app.ScenarioTab;
                app.updateTaskPanel;
                app.updateResultState;
                app.setStatus(sprintf(app.t('模板已载入：%s。现在可以直接运行。', ...
                    'Template loaded: %s. You can run it now.'), ...
                    app.t(templateEntry.nameZh, templateEntry.nameEn)));
                choice = uiconfirm(app.Figure, app.t( ...
                    '模板配置已通过检查。是否现在运行？', ...
                    'The template configuration passed validation. Run it now?'), ...
                    app.t('任务向导：完成', 'Task wizard: ready'), ...
                    'Options', {app.t('立即运行', 'Run now'), app.t('只载入模板', 'Load only')}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if strcmp(choice, app.t('立即运行', 'Run now'))
                    app.runTaskScenario;
                end
            end
        end

        function syncNetworkControls(app)
            network = app.CurrentNetwork;
            displayNames = leotherm.nodeDisplayNames(network.nodeNames, app.Language);
            data = table(string(displayNames(:)), network.capacityJK(:), ...
                network.initialTemperatureK(:), network.internalPowerW(:), ...
                network.projectedAreaM2(:), network.radiatingAreaM2(:), ...
                network.normalBody(:, 1), network.normalBody(:, 2), ...
                network.normalBody(:, 3), network.solarAbsorptivity(:), ...
                network.irEmissivity(:), network.bias.linearMPerK(:), ...
                'VariableNames', {'node', 'capacity', 'initial_temperature', ...
                'internal_power', 'projected_area', 'radiating_area', ...
                'normal_x', 'normal_y', 'normal_z', 'absorptivity', ...
                'emissivity', 'bias_linear'});
            app.NodeTable.Data = data;
            app.NodeTable.ColumnName = app.t( ...
                {'节点', '热容（J/K）', '初温（K）', '功耗（W）', ...
                '投影面积', '辐射面积', '法向量X', '法向量Y', '法向量Z', ...
                '吸收率', '发射率', '偏差灵敏度'}, ...
                {'Node', 'Capacity (J/K)', 'Initial T (K)', 'Power (W)', ...
                'Projected area', 'Radiating area', 'Normal X', 'Normal Y', ...
                'Normal Z', 'Absorptivity', 'Emissivity', 'Bias sensitivity'});
            app.ConductanceTable.Data = network.conductanceWK;
            app.ConductanceTable.RowName = displayNames;
            app.ConductanceTable.ColumnName = displayNames;
            app.ConductanceTable.ColumnEditable = true(1, numel(network.nodeNames));

            optionalItems = [{app.t('<无>', '<None>')}, displayNames];
            optionalData = [{''}, network.nodeNames];
            app.ResponseRole.Items = displayNames;
            app.ResponseRole.ItemsData = network.nodeNames;
            app.AntennaRole.Items = optionalItems;
            app.AntennaRole.ItemsData = optionalData;
            app.OscillatorRole.Items = optionalItems;
            app.OscillatorRole.ItemsData = optionalData;
            app.QuadraticNode.Items = displayNames;
            app.QuadraticNode.ItemsData = network.nodeNames;
            app.ResponseRole.Value = network.nodeNames{app.resolveRole('response')};
            app.AntennaRole.Value = app.roleValue('antenna');
            app.OscillatorRole.Value = app.roleValue('oscillator');
            app.QuadraticNode.Value = network.nodeNames{network.bias.quadraticNode};
            app.QuadraticCoefficient.Value = network.bias.quadraticMPerK2;
            if contains(network.name, 'symmetric_11_node_gnss_receiver')
                app.NetworkPreset.Value = 'symmetric';
            elseif contains(network.name, 'satmo_style_7_node_box')
                app.NetworkPreset.Value = 'satmo';
            else
                app.NetworkPreset.Value = 'default';
            end
        end

        function applyNodeTableEdit(app, ~)
            previous = app.CurrentNetwork;
            try
                data = app.NodeTable.Data;
                network = previous;
                network.capacityJK = data.capacity;
                network.initialTemperatureK = data.initial_temperature;
                network.internalPowerW = data.internal_power;
                network.projectedAreaM2 = data.projected_area;
                network.radiatingAreaM2 = data.radiating_area;
                network.normalBody = [data.normal_x, data.normal_y, data.normal_z];
                network.solarAbsorptivity = data.absorptivity;
                network.irEmissivity = data.emissivity;
                network.bias.linearMPerK = data.bias_linear;
                network.name = [previous.name '_custom'];
                leotherm.validateNetwork(network);
                app.CurrentNetwork = network;
                app.setStatus(app.t('节点参数已通过物理约束校验', ...
                    'Node parameters passed physical validation'));
                app.updateResultSummary;
                app.updateTaskPanel;
                app.updateResultState;
            catch exception
                app.CurrentNetwork = previous;
                app.syncNetworkControls;
                app.showException(app.t('节点参数无效，已恢复', ...
                    'Invalid node parameters; previous values restored'), exception);
            end
        end

        function applyConductanceEdit(app, event)
            previous = app.CurrentNetwork;
            try
                matrix = app.ConductanceTable.Data;
                row = event.Indices(1);
                column = event.Indices(2);
                if row == column
                    matrix(row, column) = 0;
                else
                    matrix(column, row) = matrix(row, column);
                end
                network = previous;
                network.conductanceWK = matrix;
                network.name = [previous.name '_custom'];
                leotherm.validateNetwork(network);
                app.CurrentNetwork = network;
                app.ConductanceTable.Data = matrix;
                app.setStatus(app.t('导热矩阵已更新并保持对称', ...
                    'Conductance matrix updated and kept symmetric'));
                app.updateResultSummary;
                app.updateTaskPanel;
                app.updateResultState;
            catch exception
                app.CurrentNetwork = previous;
                app.syncNetworkControls;
                app.showException(app.t('导热参数无效，已恢复', ...
                    'Invalid conductance; previous values restored'), exception);
            end
        end

        function applyRoleSettings(app)
            previous = app.CurrentNetwork;
            try
                network = previous;
                network.roles.response = app.nodeIndex(app.ResponseRole.Value, false);
                network.roles.antenna = app.nodeIndex(app.AntennaRole.Value, true);
                network.roles.oscillator = app.nodeIndex(app.OscillatorRole.Value, true);
                network.bias.quadraticNode = app.nodeIndex( ...
                    app.QuadraticNode.Value, false);
                network.bias.quadraticMPerK2 = app.QuadraticCoefficient.Value;
                network.name = [previous.name '_custom'];
                leotherm.validateNetwork(network);
                app.CurrentNetwork = network;
                app.setStatus(app.t('节点角色和偏差映射已更新', ...
                    'Node roles and bias mapping updated'));
                app.updateResultSummary;
                app.updateTaskPanel;
                app.updateResultState;
            catch exception
                app.CurrentNetwork = previous;
                app.syncNetworkControls;
                app.showException(app.t('角色设置无效，已恢复', ...
                    'Invalid role settings; previous values restored'), exception);
            end
        end

        function selectNetworkPreset(app)
            try
                switch app.NetworkPreset.Value
                    case 'default'
                        network = leotherm.defaultReceiverNetwork;
                    case 'symmetric'
                        network = leotherm.symmetricReceiverNetwork;
                    otherwise
                        network = leotherm.satmoStyleNetwork;
                end
                app.CurrentNetwork = network;
                app.syncNetworkControls;
                app.updateResultSummary;
                app.updateTaskPanel;
                app.updateResultState;
                app.setStatus(sprintf(app.t('已载入网络：%s', ...
                    'Loaded network: %s'), app.displayNetworkName));
            catch exception
                app.showException(app.t('网络预设载入失败', ...
                    'Failed to load network preset'), exception);
            end
        end

        function networkActionChanged(app)
            action = app.ResetNetworkButton.Value;
            if strcmp(action, 'more'), return; end
            app.ResetNetworkButton.Value = 'more';
            if strcmp(action, 'restore')
                app.selectNetworkPreset;
            end
        end

        function updateScanControlState(app)
            controlled = strcmp(app.ScanMode.Value, 'beta_altitude');
            app.ScanBetaList.Enable = app.onOff(controlled);
            app.ScanBranch.Enable = app.onOff(controlled);
            app.ScanDateList.Enable = app.onOff(~controlled);
            app.ScanInclinationList.Enable = app.onOff(~controlled);
            app.ScanRaanList.Enable = app.onOff(~controlled);
        end

        function saveConfiguration(app)
            try
                scenario = app.collectScenario;
                network = app.CurrentNetwork;
                softwareVersion = leotherm.version;
                displayLanguage = app.Language;
                [file, folder] = uiputfile('*.mat', ...
                    app.t('保存仿真配置', 'Save simulation configuration'), ...
                    'leotherm_configuration.mat');
                if isequal(file, 0)
                    return
                end
                save(fullfile(folder, file), 'scenario', 'network', ...
                    'softwareVersion', 'displayLanguage');
                app.setStatus(sprintf(app.t('配置已保存：%s', ...
                    'Configuration saved: %s'), fullfile(folder, file)));
            catch exception
                app.showException(app.t('配置保存失败', ...
                    'Failed to save configuration'), exception);
            end
        end

        function loadConfiguration(app)
            try
                [file, folder] = uigetfile('*.mat', ...
                    app.t('导入仿真配置', 'Load simulation configuration'));
                if isequal(file, 0)
                    return
                end
                loaded = load(fullfile(folder, file));
                if ~isfield(loaded, 'scenario') || ~isfield(loaded, 'network')
                    error('leotherm:InvalidConfiguration', ...
                        '%s', app.t('配置文件必须包含场景和热网络。', ...
                        'The configuration must contain a scenario and network.'));
                end
                leotherm.validateScenario(loaded.scenario);
                leotherm.validateNetwork(loaded.network);
                if isfield(loaded, 'geometry') && ~isempty(loaded.geometry)
                    leotherm.validateSurfaceMesh(loaded.geometry);
                end
                if isfield(loaded, 'calibrationStatus')
                    status = string(loaded.calibrationStatus);
                    if ~isscalar(status) || ismissing(status)
                        error('leotherm:InvalidConfiguration', '%s', ...
                            app.t('标定状态必须是单个有效标识。', ...
                            'Calibration status must be one valid token.'));
                    end
                    if status ~= "accepted_within_declared_scope"
                        label = char(leotherm.deviceCalibrationText(status, app.Language));
                        proceed = app.t('仍然载入候选配置', 'Load candidate anyway');
                        cancel = app.t('取消', 'Cancel');
                        choice = uiconfirm(app.Figure, sprintf(app.t( ...
                            '该候选设备未获得接受结论（%s）。载入仅用于检查，不表示通过验证。是否替换当前场景与热网络？', ...
                            'This candidate is not accepted (%s). Loading it for inspection does not establish validation. Replace the current scenario and network?'), ...
                            label), app.t('未接受的标定候选', 'Unaccepted calibration candidate'), ...
                            'Options', {proceed, cancel}, 'DefaultOption', 2, ...
                            'CancelOption', 2, 'Icon', 'warning');
                        if ~strcmp(choice, proceed), return; end
                    end
                end
                app.CurrentScenario = loaded.scenario;
                app.CurrentNetwork = loaded.network;
                if isfield(loaded, 'geometry')
                    app.CurrentGeometry = loaded.geometry;
                else
                    app.CurrentGeometry = [];
                end
                % A configuration import replaces the geometry inputs. Any
                % face-level result belongs to the previous geometry and must
                % not remain selectable as if it were current.
                app.CurrentMeshResult = [];
                if isfield(loaded, 'displayLanguage')
                    app.Language = leotherm.normalizeLanguage(loaded.displayLanguage);
                    app.rebuildInterface;
                end
                app.syncScenarioControls;
                app.syncNetworkControls;
                app.updateMeshUI;
                app.updateResultSummary;
                app.updateTaskPanel;
                app.updateResultState;
                app.setStatus(sprintf(app.t('配置已导入：%s', ...
                    'Configuration loaded: %s'), fullfile(folder, file)));
            catch exception
                app.showException(app.t('配置导入失败', ...
                    'Failed to load configuration'), exception);
            end
        end

        function exportCurrentResults(app)
            telemetryState = app.TelemetryWorkspace.getState;
            if isempty(app.CurrentResult) && isempty(app.CurrentSweep) ...
                    && isempty(app.CurrentMeshResult) && isempty(app.CurrentVolumeResult) ...
                    && isempty(app.CurrentSurfaceVolumeResult) ...
                    && isempty(telemetryState.result) && isempty(telemetryState.report)
                uialert(app.Figure, app.t('当前没有可导出的结果。', ...
                    'There are no results to export.'), ...
                    app.t('没有结果', 'No results'));
                return
            end
            folder = uigetdir(pwd, app.t('选择结果导出目录', ...
                'Select result export directory'));
            if isequal(folder, 0)
                return
            end
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            outDir = fullfile(folder, ['leotherm_' timestamp]);
            try
                app.exportResults(outDir);
                app.writeExportManifest(outDir);
                pdfPath = fullfile(outDir, 'report', ...
                    ['thermal_report_' app.Language '.pdf']);
                if ~isfile(pdfPath)
                    error('leotherm:ExportFailed', 'The analysis PDF was not created.');
                end
                app.setStatus(sprintf(app.t('报告已生成：%s', ...
                    'Report created: %s'), pdfPath));
                choice = uiconfirm(app.Figure, ...
                    [app.t('分析报告已生成：', 'Analysis PDF created:') newline pdfPath], ...
                    app.t('报告完成', 'Report ready'), ...
                    'Options', {app.t('打开报告', 'Open PDF'), ...
                        app.t('稍后查看', 'View later')}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if strcmp(choice, app.t('打开报告', 'Open PDF'))
                    try
                        if ispc, winopen(pdfPath); else, open(pdfPath); end
                    catch openException
                        app.showException(app.t('报告已保存，但无法打开', ...
                            'Report saved, but could not open'), openException);
                    end
                end
            catch exception
                app.showException(app.t('结果导出失败', ...
                    'Result export failed'), exception);
            end
        end

        function writeExportManifest(app, outDir)
            file = fopen(fullfile(outDir, 'manifest.txt'), 'w');
            if file < 0
                error('leotherm:ExportFailed', '%s', ...
                    app.t('无法创建导出清单。', ...
                    'Unable to create the export manifest.'));
            end
            cleanup = onCleanup(@() fclose(file));
            fprintf(file, 'software_version=%s\n', leotherm.version);
            fprintf(file, 'generated_utc=%s\n', char(datetime('now', ...
                'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX')));
            fprintf(file, 'configuration_policy=each_result_owns_its_original_inputs\n');
            fprintf(file, 'scenario_stale=%d\n',app.resultIsStale);
            fprintf(file, 'sweep_stale=%d\n',app.sweepIsStale);
            fprintf(file, 'display_language=%s\n', app.Language);
            fprintf(file, 'telemetry_gap_filling=false\n');
            clear cleanup
        end

        function executeSelfTest(app)
            if app.IsBusy
                return
            end
            app.ProgressDialog = [];
            app.setBusy(true, app.t('正在运行软件自检...', ...
                'Running software self-test...'));
            cleanup = onCleanup(@() app.finishOperation);
            try
                app.ProgressDialog = uiprogressdlg(app.Figure, ...
                    'Title', app.t('软件自检', 'Software self-test'), ...
                    'Message', app.t('正在运行自动验证套件...', ...
                    'Running automated verification suite...'), ...
                    'Indeterminate', 'on');
                drawnow;
                results = leotherm.selfTest;
                passed = sum([results.Passed]);
                app.setStatus(sprintf(app.t('软件自检通过：%d/%d', ...
                    'Software self-test passed: %d/%d'), passed, numel(results)));
                uialert(app.Figure, sprintf(app.t('%d/%d项测试全部通过。', ...
                    'All %d/%d tests passed.'), passed, numel(results)), ...
                    app.t('自检通过', 'Self-test passed'), 'Icon', 'success');
            catch exception
                app.showException(app.t('软件自检失败', ...
                    'Software self-test failed'), exception);
            end
            clear cleanup
        end

        function showAbout(app)
            message = sprintf(app.t( ...
                ['低轨卫星热仿真工作台 v%s\n\n' ...
                '轨道几何、地影、环境热流、多节点温度与半仿真码偏差。\n' ...
                '纯MATLAB实现，默认网络尚未针对具体卫星标定。'], ...
                ['LEO Thermal Simulation Workbench v%s\n\n' ...
                'Orbit geometry, eclipse, environmental heat loads, multi-node temperatures, ' ...
                'and semi-synthetic code bias.\n' ...
                'Implemented in pure MATLAB; the default network is not mission calibrated.']), ...
                leotherm.version);
            uialert(app.Figure, message, app.t('关于', 'About'));
        end

        function finishOperation(app)
            if ~isempty(app.ProgressDialog) && isvalid(app.ProgressDialog)
                close(app.ProgressDialog);
            end
            app.ProgressDialog = [];
            currentMessage = app.StatusLabel.Text;
            app.setBusy(false, currentMessage);
        end

        function setBusy(app, value, message)
            if value && ~app.IsBusy
                controls=findall(app.Figure,'-property','Enable');
                app.BusyControls=cell(numel(controls),2);
                for k=1:numel(controls)
                    app.BusyControls(k,:)={controls(k),controls(k).Enable};
                    controls(k).Enable='off';
                end
            elseif ~value && app.IsBusy
                for k=1:size(app.BusyControls,1)
                    if isvalid(app.BusyControls{k,1}), app.BusyControls{k,1}.Enable=app.BusyControls{k,2}; end
                end
                app.BusyControls={};
            end
            app.IsBusy = value;
            state = app.onOff(~value);
            app.RunScenarioButton.Enable = state;
            app.RunSweepButton.Enable = state;
            app.LoadConfigButton.Enable = state;
            app.SaveConfigButton.Enable = state;
            app.ExportResultsButton.Enable = state;
            app.LanguageDropdown.Enable = state;
            if ~isempty(app.ThermalModelImportButton) && isvalid(app.ThermalModelImportButton)
                app.ThermalModelImportButton.Enable = state;
                app.updateThermalModelUI;
            end
            app.WarmupOrbits.Enable=app.onOff(~value && ~app.UseConvergence.Value);
            if ~isempty(app.TelemetryWorkspace)
                app.TelemetryWorkspace.setEnabled(~value);
            end
            if ~isempty(app.CalibrationWorkspace)
                app.CalibrationWorkspace.setEnabled(~value);
            end
            app.setStatus(message);
            drawnow;
        end

        function setStatus(app, message)
            if ~isempty(app.StatusLabel) && isvalid(app.StatusLabel)
                app.StatusLabel.Text = message;
            end
        end

        function showException(app, titleText, exception)
            message = app.localizedExceptionMessage(exception);
            app.setStatus([titleText app.t('：', ': ') message]);
            uialert(app.Figure, message, titleText, 'Icon', 'error');
        end

        function [indices, labels] = displayNodes(app, network)
            roles = {'antenna', 'response', 'oscillator'};
            indices = [];
            for k = 1:numel(roles)
                index = app.resolveRoleForNetwork(network, roles{k});
                if ~isempty(index) && ~ismember(index, indices)
                    indices(end + 1) = index; %#ok<AGROW>
                end
            end
            if isempty(indices)
                indices = 1;
            end
            labels = leotherm.nodeDisplayNames(network.nodeNames(indices), ...
                app.Language);
        end

        function index = resolveRole(app, role)
            index = app.resolveRoleForNetwork(app.CurrentNetwork, role);
            if isempty(index) && strcmp(role, 'response')
                index = 1;
            end
        end

        function index = resolveRoleForNetwork(~, network, role)
            index = [];
            if isfield(network, 'roles') && isfield(network.roles, role)
                index = network.roles.(role);
            end
            if isempty(index)
                legacy.response = 'gnss_rf_frontend';
                legacy.antenna = 'gnss_antenna';
                legacy.oscillator = 'gnss_oscillator';
                index = find(strcmp(network.nodeNames, legacy.(role)), 1);
            end
        end

        function value = roleValue(app, role)
            index = app.resolveRole(role);
            if isempty(index)
                value = '';
            else
                value = app.CurrentNetwork.nodeNames{index};
            end
        end

        function index = nodeIndex(app, value, allowEmpty)
            if allowEmpty && isempty(value)
                index = [];
                return
            end
            index = find(strcmp(app.CurrentNetwork.nodeNames, value), 1);
            if isempty(index)
                error('leotherm:InvalidNetworkRole', '%s', ...
                    sprintf(app.t('找不到节点：%s', 'Node not found: %s'), value));
            end
        end

        function changeLanguage(app)
            try
                app.CurrentScenario = app.collectScenario;
            catch
                % Numeric controls already enforce their basic limits. Keep the
                % last valid model if a partially edited value cannot be read.
            end
            app.Language = leotherm.normalizeLanguage(app.LanguageDropdown.Value);
            app.rebuildInterface;
            app.setStatus(app.t('显示语言已切换为中文', ...
                'Display language changed to English'));
        end

        function rebuildInterface(app,restored)
            visibility = 'on';
            position = [80, 60, 1380, 860];
            telemetryState = [];
            calibrationState = [];
            scanSettings = app.captureScanSettings;
            selectedConfigIndex = [];
            selectedMainIndex = [];
            if ~isempty(app.TelemetryWorkspace)
                telemetryState = app.TelemetryWorkspace.getState;
            end
            if ~isempty(app.CalibrationWorkspace)
                calibrationState = app.CalibrationWorkspace.getState;
            end
            if nargin>1
                telemetryState=restored.telemetry; calibrationState=restored.calibration;
                scanSettings=restored.scanSettings;
            end
            if ~isempty(app.Figure) && isvalid(app.Figure)
                selectedConfigIndex = find(app.TabGroup.Children == app.TabGroup.SelectedTab, 1);
                selectedMainIndex = find(app.MainTabGroup.Children == app.MainTabGroup.SelectedTab, 1);
                visibility = app.Figure.Visible;
                position = app.Figure.Position;
                app.Figure.CloseRequestFcn = [];
                delete(app.Figure);
            end
            app.createComponents(visibility);
            app.Figure.Position = position;
            app.syncScenarioControls;
            app.syncNetworkControls;
            app.restoreScanSettings(scanSettings);
            if ~isempty(telemetryState)
                app.TelemetryWorkspace.restoreState(telemetryState);
            end
            if ~isempty(calibrationState)
                app.CalibrationWorkspace.restoreState(calibrationState);
            end
            if ~isempty(selectedConfigIndex) && selectedConfigIndex <= numel(app.TabGroup.Children)
                app.TabGroup.SelectedTab = app.TabGroup.Children(selectedConfigIndex);
            end
            if ~isempty(selectedMainIndex) && selectedMainIndex <= numel(app.MainTabGroup.Children)
                app.MainTabGroup.SelectedTab = app.MainTabGroup.Children(selectedMainIndex);
            end
            app.updateScanControlState;
            if ~isempty(app.CurrentResult)
                app.updateScenarioPlots;
            end
            if ~isempty(app.CurrentSweep)
                app.updateSweepPlots;
            end
            app.updateResultSummary;
            app.updateTaskPanel;
            app.updateResultState;
            app.updateQuickStartPanel;
            app.TelemetryWorkspace.setEnabled(~app.IsBusy);
            app.CalibrationWorkspace.setEnabled(~app.IsBusy);
            setappdata(app.Figure, 'LEOThermalSimulatorApp', app);
            drawnow;
        end

        function model = telemetryModel(app)
            model.scenario = app.collectScenario;
            model.network = app.CurrentNetwork;
            model.reference = app.CurrentResult;
            model.referenceStale = app.resultIsStale;
        end

        function refreshCalibrationContext(app)
            if ~isempty(app.CalibrationWorkspace) && isvalid(app.CalibrationWorkspace.Tab)
                app.CalibrationWorkspace.refreshContext;
            end
            if ~isempty(app.TelemetryWorkspace), app.TelemetryWorkspace.refreshContext; end
        end

        function configTabChanged(app)
            app.refreshCalibrationContext;
            app.updateTaskPanel;
        end

        function mainTabChanged(app)
            app.refreshCalibrationContext;
            app.updateTaskPanel;
        end

        function value = t(app, chinese, english)
            if strcmp(app.Language, 'zh')
                value = chinese;
            else
                value = english;
            end
        end

        function items = attitudeItems(app)
            items = app.t({'对地定向', '对日定向', '惯性定向'}, ...
                {'Nadir pointing', 'Sun pointing', 'Inertially fixed'});
        end

        function items = scanModeItems(app)
            items = app.t({'高度与β角控制扫描', ...
                '日期、倾角与升交点赤经物理扫描'}, ...
                {'Altitude-beta control', ...
                'Date-inclination-RAAN sweep'});
        end

        function items = networkPresetItems(app)
            items = app.t({'默认11节点卫星导航网络', '严格对称11节点网络', ...
                '公开基础模型风格7节点网络'}, ...
                {'Default 11-node GNSS network', ...
                'Symmetric 11-node network', 'SATMO-style 7-node network'});
        end

        function value = displayNetworkName(app)
            name = app.CurrentNetwork.name;
            if contains(name, 'reference_11_node_gnss_receiver')
                value = app.t('默认11节点卫星导航网络', ...
                    'Default 11-node GNSS network');
            elseif contains(name, 'symmetric_11_node_gnss_receiver')
                value = app.t('严格对称11节点网络', ...
                    'Symmetric 11-node network');
            elseif contains(name, 'satmo_style_7_node_box')
                value = app.t('公开基础模型风格7节点网络', ...
                    'SATMO-style 7-node network');
            else
                value = app.t('自定义热网络', 'Custom thermal network');
            end
            if contains(name, '_custom')
                value = [value app.t('（已修改）', ' (modified)')];
            end
        end

        function value = displayScenarioName(app)
            name = app.CurrentScenario.name;
            if strcmp(app.Language, 'zh')
                if startsWith(name, 'gui_')
                    value = ['图形界面场景 ' strrep(name, 'gui_', '')];
                elseif strcmp(name, 'reference_600km_nadir')
                    value = '默认600千米对地场景';
                else
                    value = '自定义场景';
                end
            else
                value = strrep(name, '_', ' ');
            end
        end

        function value = displaySweepMode(app)
            switch app.CurrentSweepMode
                case 'beta_altitude'
                    value = app.t('高度与β角控制扫描', ...
                        'Controlled altitude-beta sweep');
                case 'physical'
                    value = app.t('日期、倾角与升交点赤经物理扫描', ...
                        'Physical date-inclination-RAAN sweep');
                otherwise
                    value = app.t('无', 'None');
            end
        end

        function value = altitudeLegend(app, altitudeKm)
            value = sprintf(app.t('%g千米', '%g km'), altitudeKm);
        end

        function message = localizedExceptionMessage(app, exception)
            if strcmp(app.Language, 'en')
                message = exception.message;
                return
            end
            identifier = exception.identifier;
            switch identifier
                case 'leotherm:InvalidStartTime'
                    summary='开始时刻无效，请填写协调世界时的时:分:秒，例如 00:00:00 或 12:30:05.125。';
                case 'leotherm:ProjectFormat'
                    summary='这不是受支持的完整项目文件。旧设备配置请通过“项目”菜单中的“导入设备配置”打开。';
                case {'leotherm:ProjectWrite','leotherm:ProjectPath','leotherm:ProjectExists'}
                    summary='项目保存失败，请检查目录权限、同名文件和文件占用。原有项目不会被直接删除。';
                case 'leotherm:ProjectSourceChanged'
                    summary='保存期间遥测文件发生变化，请重新导入后保存。';
                case 'leotherm:StaleResult'
                    summary='输入已经变化，请重新运行仿真或遥测处理，再使用该结果。';
                case 'leotherm:InvalidScenario'
                    summary = '场景参数无效，请检查单位、范围和时间设置。';
                case 'leotherm:InvalidNetwork'
                    summary = '热网络参数无效，请检查热容、面积、法向量和导热矩阵。';
                case 'leotherm:InvalidSweepInput'
                    summary = '参数扫描输入无效，请检查列表和取值范围。';
                case 'leotherm:InvalidList'
                    summary = '数值列表格式无效，请使用逗号列表或起点:步长:终点。';
                case 'leotherm:InvalidDateList'
                    summary = '日期列表格式无效，请使用yyyy-MM-dd并以逗号分隔。';
                case 'leotherm:NoCompleteCases'
                    summary = '没有可显示的完整有效案例。';
                case 'leotherm:ThermalStateOutOfBounds'
                    summary = '温度超出积分保护范围，请检查热参数和时间步长。';
                case 'leotherm:PeriodicInitializationFailed'
                    summary = '周期热状态未达到收敛要求。';
                case 'leotherm:InvalidConfiguration'
                    summary = '配置文件无效或缺少必要字段。';
                case 'leotherm:ExportFailed'
                    summary = '结果导出失败，请检查目录写入权限。';
                otherwise
                    summary = '操作未完成，请检查输入或计算设置。';
            end
            if isempty(identifier)
                message = summary;
            else
                message = sprintf('%s（错误标识：%s）', summary, identifier);
            end
        end

        function warnings = localizedTaskWarnings(app, audit)
            % Keep task diagnostics bilingual without exposing core English text.
            warnings = cellstr(audit.warnings);
            codes = string(audit.codes);
            for k = 1:numel(warnings)
                code = '';
                raw = warnings{k};
                if contains(raw, 'Task has not been frozen')
                    code = 'task_not_frozen';
                elseif contains(raw, 'surface mesh is loaded')
                    code = 'mesh_preview_only';
                elseif contains(raw, 'tetrahedral volume mesh is loaded')
                    code = 'volume_mesh_loaded';
                elseif contains(raw, 'Telemetry results are stale')
                    code = 'telemetry_result_stale';
                elseif contains(raw, 'Calibration results are stale')
                    code = 'calibration_result_stale';
                elseif k <= numel(codes) && ismember(codes(k), ...
                        ["task_not_frozen","mesh_preview_only", ...
                         "volume_mesh_loaded","telemetry_result_stale", ...
                         "calibration_result_stale"])
                    % Fallback for future localized core diagnostics.
                    code = char(codes(k));
                end
                switch code
                    case 'task_not_frozen'
                        warnings{k} = app.t('运行时将自动创建任务快照。', ...
                            'A task snapshot will be created automatically at run time.');
                    case 'mesh_preview_only'
                        warnings{k} = app.t('已载入表面网格：节点求解仍可用，也可单独运行面片级热求解。', ...
                            'A surface mesh is loaded: the node solver remains available, and the face-level solver can be run separately.');
                    case 'volume_mesh_loaded'
                        warnings{k} = app.t('已载入四面体体网格：当前体网格路径仅进行实体导热分析。', ...
                            'A tetrahedral volume mesh is loaded: the volume path currently performs conduction-only analysis.');
                    case 'telemetry_result_stale'
                        warnings{k} = app.t('遥测处理结果已过期，不会作为当前验证结果使用。', ...
                            'Telemetry results are stale and will not be used as current validation.');
                    case 'calibration_result_stale'
                        warnings{k} = app.t('标定结果已过期，不会作为当前模型使用。', ...
                            'Calibration results are stale and will not be used as the current model.');
                end
            end
        end

        function updateSweepTable(app, summary)
            display = summary;
            if ismember('status', display.Properties.VariableNames)
                for k = 1:height(display)
                    switch display.status{k}
                        case 'cancelled'
                            display.status{k}=app.t('已取消','Cancelled');
                        case 'complete'
                            display.status{k} = app.t('完成', 'Complete');
                        case 'failed'
                            display.status{k} = app.t('失败', 'Failed');
                        case 'inaccessible'
                            display.status{k} = app.t('不可达', 'Inaccessible');
                        otherwise
                            display.status{k} = app.t('等待', 'Pending');
                    end
                end
            end
            if ismember('message', display.Properties.VariableNames) ...
                    && strcmp(app.Language, 'zh')
                for k = 1:height(display)
                    if ~isempty(display.message{k})
                        display.message{k} = '详细信息见导出的数据文件';
                    end
                end
            end
            app.SweepTable.Data = display;
            names = display.Properties.VariableNames;
            headers = cell(size(names));
            for k = 1:numel(names)
                headers{k} = app.sweepColumnDescription(names{k});
            end
            app.SweepTable.ColumnName = headers;
        end

        function value = sweepColumnDescription(app, name)
            pairs = {
                'epoch', '日期', 'Epoch';
                'altitude_km', '高度（千米）', 'Altitude (km)';
                'inclination_deg', '倾角（°）', 'Inclination (deg)';
                'target_beta_deg', '目标β角（°）', 'Target beta angle (deg)';
                'actual_beta_deg', '实际β角（°）', 'Actual beta angle (deg)';
                'beta_deg', 'β角（°）', 'Beta angle (deg)';
                'raan_deg', '升交点赤经（°）', 'RAAN (deg)';
                'accessible', '是否可达', 'Accessible';
                'status', '状态', 'Status';
                'message', '说明', 'Message';
                'eclipse_fraction', '入影比例', 'Eclipse fraction';
                'umbra_fraction', '本影比例', 'Umbra fraction';
                'response_temperature_span_k', '响应温度跨度（K）', 'Response-temperature span (K)';
                'antenna_temperature_span_k', '天线温度跨度（K）', 'Antenna-temperature span (K)';
                'rf_temperature_span_k', '射频温度跨度（K）', 'RF-temperature span (K)';
                'oscillator_temperature_span_k', '振荡器温度跨度（K）', 'Oscillator-temperature span (K)';
                'code_bias_span_m', '码偏差跨度（m）', 'Code-bias span (m)';
                'code_bias_rms_m', '码偏差均方根（m）', 'Code-bias RMS (m)';
                'forcing_to_rf_lag_s', '热流到射频时延（s）', 'Forcing-to-RF lag (s)';
                'forcing_to_code_bias_lag_s', '热流到码偏差时延（s）', 'Forcing-to-code-bias lag (s)';
                'eclipse_entry_cooling_lag_s', '入影冷却时延（s）', 'Eclipse-entry cooling lag (s)';
                'eclipse_exit_heating_lag_s', '出影加热时延（s）', 'Eclipse-exit heating lag (s)';
                'eclipse_transition_count', '完整入出影次数', 'Eclipse transition count';
                'rf_hysteresis_area_wk', '射频滞回面积（W K）', 'RF hysteresis area (W K)';
                'response_hysteresis_area_wk', '响应滞回面积（W K）', 'Response hysteresis area (W K)';
                'response_normalized_hysteresis_area', '响应归一化滞回面积', 'Normalized response hysteresis';
                'rf_normalized_hysteresis_area', '射频归一化滞回面积', 'Normalized RF hysteresis';
                'oscillator_hysteresis_area_wk', '振荡器滞回面积（W K）', 'Oscillator hysteresis area (W K)';
                'oscillator_normalized_hysteresis_area', '振荡器归一化滞回面积', 'Normalized oscillator hysteresis';
                'periodic_error_k', '周期稳态误差（K）', 'Periodic-state error (K)';
                'convergence_cycles', '收敛圈数', 'Convergence cycles'};
            row = find(strcmp(pairs(:, 1), name), 1);
            if isempty(row)
                value = app.t('数据列', strrep(name, '_', ' '));
            else
                value = app.t(pairs{row, 2}, pairs{row, 3});
            end
        end

        function writeValue = onOff(~, logicalValue)
            if logicalValue
                writeValue = 'on';
            else
                writeValue = 'off';
            end
        end

        function description = metricDescription(app, name)
            chinese = struct( ...
                'peakPhaseIdentifiable','峰值相位可识别', ...
                'peakPhaseIdentifiableCycles','峰值相位有效周期数', ...
                'signedPeakPhaseMedianS','带符号峰值相位差（s）', ...
                'peakPhaseSamplingResolutionS','峰值相位采样分辨率（s）', ...
                'meanBetaDeg', '平均β角（°）', ...
                'minimumBetaDeg', '最小β角（°）', ...
                'maximumBetaDeg', '最大β角（°）', ...
                'eclipseFraction', '入影历元比例', ...
                'umbraFraction', '本影历元比例', ...
                'penumbraEpochs', '半影历元数', ...
                'antennaTemperatureSpanK', '天线温度跨度（K）', ...
                'responseTemperatureSpanK', '响应节点温度跨度（K）', ...
                'rfTemperatureSpanK', '射频节点温度跨度（K）', ...
                'oscillatorTemperatureSpanK', '振荡器温度跨度（K）', ...
                'codeBiasSpanM', '码偏差跨度（m）', ...
                'codeBiasRmsM', '码偏差均方根（m）', ...
                'totalAbsorbedHeatSpanW', '吸收热流跨度（W）', ...
                'forcingPeakToResponsePeakLagS', '峰值响应时延（s）', ...
                'forcingTroughToResponseTroughLagS', '谷值响应时延（s）', ...
                'forcingToResponseLagS', '热流–响应时延（s）', ...
                'forcingToRfLagS', '热流–射频节点时延（s）', ...
                'forcingToCodeBiasLagS', '热流–码偏差时延（s）', ...
                'eclipseEntryToTemperatureMinimumS', '入影至温度最低时延（s）', ...
                'eclipseExitToTemperatureMaximumS', '出影至温度最高时延（s）', ...
                'eclipseEntryCoolingLagS', '入影冷却时延（s）', ...
                'eclipseExitHeatingLagS', '出影加热时延（s）', ...
                'eclipseTransitionCount', '完整入出影次数', ...
                'responseHysteresisAreaWK', '响应滞回面积（W·K）', ...
                'responseNormalizedHysteresisArea', '响应归一化滞回面积', ...
                'rfHysteresisAreaWK', '射频节点滞回面积（W·K）', ...
                'rfNormalizedHysteresisArea', '射频节点归一化滞回面积', ...
                'oscillatorHysteresisAreaWK', '振荡器滞回面积（W·K）', ...
                'oscillatorNormalizedHysteresisArea', '振荡器归一化滞回面积', ...
                'hysteresisCompleteCycles', '完整滞回周期数');
            english = struct( ...
                'peakPhaseIdentifiable','Peak phase identifiable', ...
                'peakPhaseIdentifiableCycles','Identifiable peak-phase cycles', ...
                'signedPeakPhaseMedianS','Signed peak phase (s)', ...
                'peakPhaseSamplingResolutionS','Peak-phase sampling resolution (s)', ...
                'meanBetaDeg', 'Mean beta angle (deg)', ...
                'minimumBetaDeg', 'Minimum beta angle (deg)', ...
                'maximumBetaDeg', 'Maximum beta angle (deg)', ...
                'eclipseFraction', 'Eclipse-epoch fraction', ...
                'umbraFraction', 'Umbra-epoch fraction', ...
                'penumbraEpochs', 'Penumbra epochs', ...
                'antennaTemperatureSpanK', 'Antenna-temperature span (K)', ...
                'responseTemperatureSpanK', 'Response-temperature span (K)', ...
                'rfTemperatureSpanK', 'RF-temperature span (K)', ...
                'oscillatorTemperatureSpanK', 'Oscillator-temperature span (K)', ...
                'codeBiasSpanM', 'Code-bias span (m)', ...
                'codeBiasRmsM', 'Code-bias RMS (m)', ...
                'totalAbsorbedHeatSpanW', 'Absorbed-heat span (W)', ...
                'forcingPeakToResponsePeakLagS', 'Peak-response lag (s)', ...
                'forcingTroughToResponseTroughLagS', 'Trough-response lag (s)', ...
                'forcingToResponseLagS', 'Forcing-to-response lag (s)', ...
                'forcingToRfLagS', 'Forcing-to-RF lag (s)', ...
                'forcingToCodeBiasLagS', 'Forcing-to-code-bias lag (s)', ...
                'eclipseEntryToTemperatureMinimumS', 'Eclipse-entry to temperature-minimum lag (s)', ...
                'eclipseExitToTemperatureMaximumS', 'Eclipse-exit to temperature-maximum lag (s)', ...
                'eclipseEntryCoolingLagS', 'Eclipse-entry cooling lag (s)', ...
                'eclipseExitHeatingLagS', 'Eclipse-exit heating lag (s)', ...
                'eclipseTransitionCount', 'Complete eclipse transitions', ...
                'responseHysteresisAreaWK', 'Response hysteresis area (W K)', ...
                'responseNormalizedHysteresisArea', 'Normalized response hysteresis area', ...
                'rfHysteresisAreaWK', 'RF hysteresis area (W K)', ...
                'rfNormalizedHysteresisArea', 'Normalized RF hysteresis area', ...
                'oscillatorHysteresisAreaWK', 'Oscillator hysteresis area (W K)', ...
                'oscillatorNormalizedHysteresisArea', 'Normalized oscillator hysteresis area', ...
                'hysteresisCompleteCycles', 'Complete hysteresis cycles');
            labels = chinese;
            if strcmp(app.Language, 'en')
                labels = english;
            end
            if isfield(labels, name)
                description = string(labels.(name));
            else
                description = string(app.t('其他指标', strrep(name, '_', ' ')));
            end
        end
    end
end
