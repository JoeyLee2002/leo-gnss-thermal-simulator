classdef CalibrationPanel < handle
    %CALIBRATIONPANEL Explicit device priors and frozen whole-day calibration.
    properties (SetAccess = private)
        Tab
    end
    properties (Access = private)
        Language
        ModelProvider
        SourceProvider
        BusyHandler
        State
        ProfileTable
        ParameterReportTable
        DayTable
        StageTable
        WarningTable
        CoverageTable
        ProfileName
        ProfileStatus
        StatusLabel
        OutputLabel
        SensorSigma
        SensorEvidence
        Regularization
        UseTolerance
        Tolerance
        MinimumCoverage
        MinimumContinuous
        MinimumSpan
        MinimumSamples
        HoldoutConfirmed
        ForcingConfirmed
        EvidenceConfirmed
        MoreActions
        Controls = {}
        Enabled = true
    end

    methods
        function panel = CalibrationPanel(parent, language, provider, sourceProvider, busyHandler)
            panel.Language = leotherm.normalizeLanguage(language);
            panel.ModelProvider = provider;
            panel.SourceProvider = sourceProvider;
            panel.BusyHandler = busyHandler;
            panel.State = struct('profile', [], 'split', table, ...
                'settings', leotherm.deviceCalibrationOptions, ...
                'result', [], 'resultInputs', [], 'resultStale', false, ...
                'splitInput', [], 'profileStale', false, 'splitStale', false, ...
                'outputDirectory', '', 'toleranceEnabled', false, ...
                'toleranceDraft', '', 'lastError', '', 'lastErrorId', '');
            panel.build(parent);
            panel.syncSettings;
            panel.syncTables;
            panel.updateStatus;
        end

        function state = getState(panel)
            panel.captureSettings;
            panel.refreshContext;
            state = panel.State;
        end

        function restoreState(panel, state)
            panel.State = state;
            panel.syncSettings;
            panel.syncTables;
            panel.refreshContext;
        end

        function setEnabled(panel, enabled)
            panel.Enabled = logical(enabled);
            value = 'off'; if enabled, value = 'on'; end
            for k = 1:numel(panel.Controls)
                if isvalid(panel.Controls{k}), panel.Controls{k}.Enable = value; end
            end
            panel.Tolerance.Enable = 'off';
            if enabled && panel.UseTolerance.Value, panel.Tolerance.Enable = 'on'; end
        end

        function loadCurrentDevice(panel)
            model = panel.ModelProvider();
            panel.State.profile = leotherm.deviceCalibrationProfile(model.network);
            panel.inputsChanged;
            panel.syncTables;
            panel.refreshContext;
        end

        function loadTelemetryDays(panel)
            model = panel.ModelProvider();
            source = panel.sourceInput;
            data = panel.readSource(source, model.network);
            panel.State.split = leotherm.calibrationDaySplit(data);
            panel.State.splitInput = panel.dayInput(source, model.network);
            panel.inputsChanged;
            panel.syncTables;
            panel.refreshContext;
        end

        function importProfile(panel, path)
            loaded = load(path, 'profile');
            if ~isfield(loaded, 'profile') || ~isstruct(loaded.profile) ...
                    || ~isfield(loaded.profile, 'referenceNetwork')
                error('leotherm:DeviceCalibrationProfile', '%s', ...
                    panel.t('MAT 文件必须包含设备档案 profile。', ...
                    'The MAT file must contain a device profile named profile.'));
            end
            % Import the declared reference, never substitute the current device.
            panel.State.profile = leotherm.validateDeviceCalibrationProfile( ...
                loaded.profile, loaded.profile.referenceNetwork);
            panel.inputsChanged;
            panel.syncTables;
            panel.refreshContext;
        end

        function exportProfile(panel, path)
            if isempty(panel.State.profile)
                error('leotherm:DeviceCalibrationProfile', '%s', ...
                    panel.t('尚未载入设备档案。', 'No device profile is loaded.'));
            end
            if isfile(path) || isfolder(path)
                error('leotherm:DeviceCalibrationExport', '%s', ...
                    panel.t('请选择新文件；不会覆盖已有档案。', ...
                    'Choose a new file; existing profiles are never overwritten.'));
            end
            profile = leotherm.validateDeviceCalibrationProfile( ...
                panel.State.profile, panel.State.profile.referenceNetwork);
            save(path, 'profile');
        end

        function result = run(panel, profile, split, settings, directory)
            %RUN Capture live sources; the core owns all fitting and artifacts.
            panel.captureSettings;
            model = panel.ModelProvider();
            source = panel.sourceInput;
            if nargin >= 2 && ~isempty(profile)
                panel.State.profile = profile;
            end
            if nargin >= 3 && ~isempty(split)
                panel.State.split = split;
                panel.State.splitInput = panel.dayInput(source, model.network);
            end
            if nargin >= 4 && ~isempty(settings)
                panel.State.settings = leotherm.deviceCalibrationOptions(settings, numel(model.network.nodeNames));
                sigma = panel.State.settings.temperatureSigmaK;
                if ~isscalar(sigma)
                    if any(sigma ~= sigma(1))
                        error('leotherm:DeviceCalibrationOptions', '%s', ...
                            panel.t('本界面要求统一的标量测温标准差。', ...
                            'This interface requires one scalar sensor uncertainty.'));
                    end
                    panel.State.settings.temperatureSigmaK = sigma(1);
                end
                panel.State.toleranceEnabled = isfinite(panel.State.settings.rmseToleranceK);
                panel.State.toleranceDraft = '';
                if panel.State.toleranceEnabled
                    panel.State.toleranceDraft = num2str(panel.State.settings.rmseToleranceK, 17);
                end
                panel.syncSettings;
            end
            panel.State.settings.telemetryOptions = source.options;
            panel.inputsChanged;
            panel.syncTables;
            panel.refreshContext;
            if nargin < 5 || strlength(string(directory)) == 0
                error('leotherm:DeviceCalibrationExport', '%s', ...
                    panel.t('必须指定新的运行目录。', 'A new run directory is required.'));
            end
            directory = char(directory);
            if isfile(directory) || isfolder(directory)
                error('leotherm:DeviceCalibrationExport', '%s', ...
                    panel.t('运行目录已存在；不会覆盖任何文件。', ...
                    'The run directory already exists; no files will be overwritten.'));
            end
            % Validate the exact reference before reading data or creating output.
            profile = leotherm.validateDeviceCalibrationProfile(panel.State.profile, model.network);
            settings = panel.State.settings;
            if panel.State.toleranceEnabled && (~isfinite(settings.rmseToleranceK) ...
                    || settings.rmseToleranceK <= 0)
                error('leotherm:DeviceCalibrationOptions', '%s', ...
                    panel.t('请明确填写正数误差上限。', 'Declare a positive RMSE limit.'));
            end
            settings = leotherm.deviceCalibrationOptions(settings, numel(model.network.nodeNames));
            if isempty(settings.sensorEvidence)
                error('leotherm:DeviceCalibrationEvidence', '%s', ...
                    panel.t('必须填写测温不确定度的依据或明确假设。', ...
                    'Sensor uncertainty needs evidence or an explicit assumption.'));
            end
            if isempty(panel.State.splitInput) || panel.State.splitStale
                error('leotherm:DeviceCalibrationSplit', '%s', ...
                    panel.t('遥测来源或映射已变化；请重新载入日期并明确分配角色。', ...
                    'Telemetry source or mapping changed; reload days and explicitly assign roles.'));
            end
            data = panel.readSource(source, model.network);
            inputs = struct('scenario', model.scenario, 'network', model.network, ...
                'source', source, 'profile', profile, 'split', panel.State.split, ...
                'settings', panel.State.settings);
            panel.State.outputDirectory = directory;
            panel.State.lastError = ''; panel.State.lastErrorId = '';
            panel.updateStatus;
            result = leotherm.calibrateTelemetry(data, model.scenario, model.network, ...
                profile, panel.State.split, settings, directory);
            panel.State.result = result;
            panel.State.resultInputs = inputs;
            panel.State.resultStale = false;
            % profileAfter and calibratedNetwork remain solely in the result.
            panel.syncTables;
            panel.refreshContext;
        end

        function refreshContext(panel)
            try
                model = panel.ModelProvider();
                source = panel.sourceInput;
                panel.State.profileStale = ~isempty(panel.State.profile) ...
                    && ~isequaln(panel.State.profile.referenceNetwork, model.network);
                panel.State.splitStale = ~isempty(panel.State.splitInput) ...
                    && ~isequaln(panel.State.splitInput, panel.dayInput(source, model.network));
                if ~isempty(panel.State.result)
                    current = struct('scenario', model.scenario, 'network', model.network, ...
                        'source', source, 'profile', panel.State.profile, ...
                        'split', panel.State.split, 'settings', panel.State.settings);
                    panel.State.resultStale = panel.State.resultStale ...
                        || ~isequaln(current, panel.State.resultInputs);
                end
            catch
                % Partially edited inputs cannot qualify a frozen result as current.
                panel.State.profileStale = true;
                panel.State.splitStale = true;
                if ~isempty(panel.State.result), panel.State.resultStale = true; end
            end
            panel.updateStatus;
        end
    end

    methods (Access = private)
        function build(panel, parent)
            panel.Tab = uitab(parent, 'Title', panel.t('设备标定', 'Device calibration'));
            layout = uigridlayout(panel.Tab, [5, 1]);
            layout.RowHeight = {36, 32, '1x', 300, 110};
            layout.Padding = [12 10 12 8]; layout.RowSpacing = 6;
            toolbar = uigridlayout(layout, [1, 4]);
            toolbar.ColumnWidth = {145, 120, '1x', 180};
            toolbar.Padding = [0 0 0 0];
            panel.button(toolbar, panel.t('准备标定', 'Prepare calibration'), @() panel.prepareUI);
            panel.MoreActions = uidropdown(toolbar, ...
                'Items', panel.t({'更多操作','载入当前设备','导入设备档案','导出设备档案','载入遥测日期'}, ...
                {'More actions','Load current device','Import device profile','Export device profile','Load telemetry days'}), ...
                'ItemsData', {'more','device','import','export','days'}, 'Value', 'more', ...
                'ValueChangedFcn', @(~,~) panel.moreActionChanged);
            panel.MoreActions.Layout.Column = 2;
            panel.Controls{end+1} = panel.MoreActions;
            panel.ProfileName = uieditfield(toolbar, 'text', ...
                'Tooltip', panel.t('设备档案名称', 'Device profile name'), ...
                'ValueChangedFcn', @(~,~) panel.nameChanged);
            panel.ProfileName.Layout.Column = 3;
            panel.Controls{end+1} = panel.ProfileName;
            runButton = panel.button(toolbar, panel.t('标定并保存新运行', 'Calibrate to new run'), @() panel.runUI);
            runButton.Layout.Column = 4;
            runButton.BackgroundColor = [0.12 0.53 0.46]; runButton.FontColor = [1 1 1];
            panel.ProfileStatus = uilabel(layout, 'WordWrap', 'on');
            panel.ProfileStatus.Layout.Row = 2;

            topTabs = uitabgroup(layout); topTabs.Layout.Row = 3;
            editor = uitab(topTabs, 'Title', panel.t('设备参数档案', 'Device parameter profile'));
            grid = uigridlayout(editor, [1, 1]); grid.Padding = [0 0 0 0];
            panel.ProfileTable = uitable(grid, 'Tag', 'CalibrationProfileTable', ...
                'RowName', [], 'ColumnEditable', [false(1,5) true(1,6)], ...
                'CellEditCallback', @(~,event) panel.profileEdited(event));
            panel.ProfileTable.ColumnWidth = {135,140,140,65,160,85,85,95,65,220,190};
            panel.ProfileTable.ColumnFormat = {'char','char','char','char', ...
                'numeric','numeric','numeric','numeric','logical','char', ...
                cellstr(leotherm.deviceCalibrationText(["unverified","physical","effective"], panel.Language))};
            panel.ProfileTable.Tooltip = panel.t( ...
                '标称值只读；真实设备参数在热网络页编辑。参数依据由用户声明，软件不核实真实性。', ...
                'Nominal values are read-only; edit the device in Thermal network. Evidence is a user declaration, not verified by software.');
            panel.Controls{end+1} = panel.ProfileTable;
            report = uitab(topTabs, 'Title', panel.t('冻结运行：参数变化', 'Frozen run: parameter changes'));
            grid = uigridlayout(report, [1, 1]); grid.Padding = [0 0 0 0];
            panel.ParameterReportTable = uitable(grid, 'Tag', 'CalibrationParameterReport', ...
                'RowName', [], 'ColumnEditable', false);

            bottom = uigridlayout(layout, [1, 3]); bottom.Layout.Row = 4;
            bottom.ColumnWidth = {245, 435, '1x'}; bottom.Padding = [0 0 0 0];
            days = uigridlayout(bottom, [2, 1]); days.Padding = [0 0 0 0];
            days.RowHeight = {25, '1x'};
            uilabel(days, 'Text', panel.t('完整协调世界时日期角色', 'Whole UTC day roles'));
            panel.DayTable = uitable(days, 'Tag', 'CalibrationDayTable', 'RowName', [], ...
                'ColumnEditable', [false true], 'ColumnWidth', {125,100}, ...
                'ColumnFormat', {'char', cellstr(leotherm.deviceCalibrationText( ...
                ["exclude","train","validation","test"], panel.Language))}, ...
                'CellEditCallback', @(~,event) panel.dayEdited(event));
            panel.Controls{end+1} = panel.DayTable;

            policyTabs = uitabgroup(bottom); policyTabs.Layout.Column = 2;
            fitTab = uitab(policyTabs,'Title',panel.t('标定设置','Calibration settings'));
            coverageSettings = uitab(policyTabs,'Title',panel.t('覆盖要求','Coverage requirements'));
            policy = uigridlayout(fitTab, [9, 2]);
            policy.ColumnWidth = {245, '1x'}; policy.RowHeight = {22,26,26,26,26,36,36,36,'1x'};
            policy.Padding = [0 0 0 0]; policy.RowSpacing = 4; policy.Scrollable = 'on';
            h = uilabel(policy, 'Text', panel.t('不确定度与声明', 'Uncertainty and declarations'), 'FontWeight', 'bold');
            h.Layout.Column = [1 2];
            panel.SensorSigma = uieditfield(policy, 'numeric', 'Value', 1, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'Tag', 'CalibrationSensorSigma');
            panel.place(policy, panel.SensorSigma, 2, '测温标准差（K）', 'Sensor standard deviation (K)');
            panel.SensorEvidence = uieditfield(policy, 'text', 'Tag', 'CalibrationSensorEvidence', ...
                'Tooltip', panel.t('必填：测温标准差的来源或明确假设', ...
                'Required: source or explicit assumption for sensor uncertainty'));
            panel.place(policy, panel.SensorEvidence, 3, '测温依据（必填）', 'Sensor evidence (required)');
            panel.Regularization = uieditfield(policy, 'numeric', 'Value', 1, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off');
            panel.place(policy, panel.Regularization, 4, '正则权重', 'Regularization weight');
            panel.UseTolerance = uicheckbox(policy, 'Text', panel.t('声明误差上限（K）', 'Declare RMSE limit (K)'), ...
                'Value', false, 'Tag', 'CalibrationUseTolerance');
            panel.UseTolerance.Layout.Row = 5; panel.UseTolerance.Layout.Column = 1;
            % Blank text avoids inventing a numerical acceptance tolerance.
            panel.Tolerance = uieditfield(policy, 'text', 'Value', '', 'Enable', 'off', ...
                'Tag', 'CalibrationTolerance');
            panel.Tolerance.Layout.Row = 5; panel.Tolerance.Layout.Column = 2;
            panel.HoldoutConfirmed = uicheckbox(policy, 'Value', false, ...
                'Text', panel.t('确认留出数据未用于选择参数、范围或模型', ...
                'Holdout data were not used to choose parameters, bounds or model'), 'WordWrap', 'on');
            panel.HoldoutConfirmed.Layout.Row = 6; panel.HoldoutConfirmed.Layout.Column = [1 2];
            panel.ForcingConfirmed = uicheckbox(policy, 'Value', false, ...
                'Text', panel.t('确认驱动数据独立于目标测温', ...
                'Forcing is independent of target temperature measurements'), 'WordWrap', 'on');
            panel.ForcingConfirmed.Layout.Row = 7; panel.ForcingConfirmed.Layout.Column = [1 2];
            panel.EvidenceConfirmed = uicheckbox(policy, 'Value', false, ...
                'Text', panel.t('确认参数范围、先验与设备依据一致', ...
                'Parameter bounds and priors agree with declared device evidence'), 'WordWrap', 'on');
            panel.EvidenceConfirmed.Layout.Row = 8; panel.EvidenceConfirmed.Layout.Column = [1 2];
            coverageGrid = uigridlayout(coverageSettings,[5 2]);
            coverageGrid.ColumnWidth = {245,'1x'}; coverageGrid.RowHeight = {28,28,28,28,'1x'};
            coverageGrid.Padding = [0 4 0 4]; coverageGrid.Scrollable = 'on';
            panel.MinimumCoverage = uieditfield(coverageGrid,'numeric','Limits',[0 Inf],'Tag','MinimumCoverage');
            panel.place(coverageGrid,panel.MinimumCoverage,1,'最低有效时长（s）','Minimum scored duration (s)');
            panel.MinimumContinuous = uieditfield(coverageGrid,'numeric','Limits',[0 Inf]);
            panel.place(coverageGrid,panel.MinimumContinuous,2,'最低连续时长（s）','Minimum continuous duration (s)');
            panel.MinimumSpan = uieditfield(coverageGrid,'numeric','Limits',[0 Inf]);
            panel.place(coverageGrid,panel.MinimumSpan,3,'最低温度变化（K）','Minimum temperature span (K)');
            panel.MinimumSamples = uieditfield(coverageGrid,'numeric','Limits',[3 Inf],'RoundFractionalValues','on');
            panel.place(coverageGrid,panel.MinimumSamples,4,'最低评分样本数','Minimum scored samples');
            settingsControls = {panel.SensorSigma, panel.SensorEvidence, panel.Regularization, ...
                panel.UseTolerance, panel.Tolerance, panel.HoldoutConfirmed, ...
                panel.ForcingConfirmed, panel.EvidenceConfirmed, panel.MinimumCoverage, ...
                panel.MinimumContinuous,panel.MinimumSpan,panel.MinimumSamples};
            for k = 1:numel(settingsControls)
                settingsControls{k}.ValueChangedFcn = @(~,~) panel.settingsChanged;
                panel.Controls{end+1} = settingsControls{k};
            end

            resultTabs = uitabgroup(bottom); resultTabs.Layout.Column = 3;
            metrics = uitab(resultTabs, 'Title', panel.t('阶段误差', 'Stage errors'));
            grid = uigridlayout(metrics, [1,1]); grid.Padding = [0 0 0 0];
            panel.StageTable = uitable(grid, 'Tag', 'CalibrationStageTable', ...
                'RowName', [], 'ColumnEditable', false, ...
                'ColumnWidth', {105,140,100,145,145});
            flags = uitab(resultTabs, 'Title', panel.t('复核提示', 'Review flags'));
            grid = uigridlayout(flags, [1,1]); grid.Padding = [0 0 0 0];
            panel.WarningTable = uitable(grid, 'RowName', [], 'ColumnEditable', false, ...
                'ColumnName', {panel.t('复核提示', 'Review flag')}, 'ColumnWidth', {'auto'});
            coverageTab = uitab(resultTabs,'Title',panel.t('数据覆盖','Data coverage'));
            grid = uigridlayout(coverageTab,[1 1]); grid.Padding = [0 0 0 0];
            panel.CoverageTable = uitable(grid,'RowName',[],'ColumnEditable',false,'Tag','CalibrationCoverageTable');
            footer = uigridlayout(layout, [3, 1]); footer.Layout.Row = 5;
            footer.RowHeight = {48, 26, 24}; footer.Padding = [0 0 0 0]; footer.RowSpacing = 2;
            panel.StatusLabel = uilabel(footer, 'Tag', 'CalibrationStatus', 'WordWrap', 'on');
            panel.OutputLabel = uilabel(footer, 'WordWrap', 'on');
            uilabel(footer, 'Text', panel.t( ...
                '拟合吻合不证明物理正确；声明不等于核实；标定模型不会自动应用。', ...
                'Agreement is not physical proof; declarations are not verification; calibrated models are never applied automatically.'), ...
                'FontColor', [0.42 0.45 0.45], 'WordWrap', 'on');
        end

        function h = button(panel, parent, text, action)
            h = uibutton(parent, 'Text', text, 'ButtonPushedFcn', @(~,~) panel.perform(action));
            panel.Controls{end+1} = h;
        end

        function place(panel, parent, control, row, chinese, english)
            label = uilabel(parent, 'Text', panel.t(chinese, english));
            label.Layout.Row = row; label.Layout.Column = 1;
            control.Layout.Row = row; control.Layout.Column = 2;
        end

        function captureSettings(panel)
            panel.State.settings.temperatureSigmaK = panel.SensorSigma.Value;
            panel.State.settings.sensorEvidence = panel.SensorEvidence.Value;
            panel.State.settings.regularizationWeight = panel.Regularization.Value;
            panel.State.settings.minimumCoverageS = panel.MinimumCoverage.Value;
            panel.State.settings.minimumContinuousS = panel.MinimumContinuous.Value;
            panel.State.settings.minimumTemperatureSpanK = panel.MinimumSpan.Value;
            panel.State.settings.minimumScoredSamples = panel.MinimumSamples.Value;
            panel.State.settings.independentHoldoutConfirmed = panel.HoldoutConfirmed.Value;
            panel.State.settings.forcingIndependenceConfirmed = panel.ForcingConfirmed.Value;
            panel.State.settings.parameterEvidenceConfirmed = panel.EvidenceConfirmed.Value;
            panel.State.toleranceEnabled = panel.UseTolerance.Value;
            panel.State.toleranceDraft = panel.Tolerance.Value;
            panel.State.settings.rmseToleranceK = NaN;
            if panel.UseTolerance.Value
                panel.State.settings.rmseToleranceK = str2double(panel.Tolerance.Value);
            end
        end

        function syncSettings(panel)
            s = leotherm.deviceCalibrationOptions(panel.State.settings,numel(panel.State.settings.temperatureSigmaK));
            panel.State.settings = s;
            panel.SensorSigma.Value = s.temperatureSigmaK;
            panel.SensorEvidence.Value = char(s.sensorEvidence);
            panel.Regularization.Value = s.regularizationWeight;
            panel.MinimumCoverage.Value = s.minimumCoverageS;
            panel.MinimumContinuous.Value = s.minimumContinuousS;
            panel.MinimumSpan.Value = s.minimumTemperatureSpanK;
            panel.MinimumSamples.Value = s.minimumScoredSamples;
            panel.HoldoutConfirmed.Value = s.independentHoldoutConfirmed;
            panel.ForcingConfirmed.Value = s.forcingIndependenceConfirmed;
            panel.EvidenceConfirmed.Value = s.parameterEvidenceConfirmed;
            panel.UseTolerance.Value = panel.State.toleranceEnabled;
            panel.Tolerance.Value = panel.State.toleranceDraft;
            panel.setEnabled(panel.Enabled);
        end

        function settingsChanged(panel)
            panel.captureSettings;
            panel.setEnabled(panel.Enabled);
            panel.inputsChanged;
        end

        function nameChanged(panel)
            if ~isempty(panel.State.profile)
                panel.State.profile.name = panel.ProfileName.Value;
                panel.inputsChanged;
            end
        end

        function inputsChanged(panel)
            if ~isempty(panel.State.result), panel.State.resultStale = true; end
            panel.State.lastError = ''; panel.State.lastErrorId = '';
            panel.updateStatus;
        end

        function profileEdited(panel, event)
            row = event.Indices(1); column = event.Indices(2);
            names = panel.State.profile.parameters.Properties.VariableNames;
            field = names{column};
            if ~panel.Enabled || ~ismember(field, {'lower','upper','priorSigma','estimate','evidence','kind'})
                panel.syncTables; return
            end
            value = event.NewData;
            switch field
                case {'lower','upper','priorSigma'}
                    if ~isnumeric(value), value = str2double(string(value)); end
                    if ~isscalar(value) || ~isreal(value) || ~isfinite(value)
                        panel.syncTables; return
                    end
                case 'estimate'
                    value = logical(value);
                case 'kind'
                    tokens = ["unverified","physical","effective"];
                    labels = leotherm.deviceCalibrationText(tokens, panel.Language);
                    index = find(labels == string(value), 1);
                    if isempty(index), panel.syncTables; return; end
                    value = tokens(index);
                case 'evidence'
                    value = string(value);
            end
            panel.State.profile.parameters.(field)(row) = value;
            panel.inputsChanged;
            panel.syncTables;
        end

        function dayEdited(panel, event)
            if ~panel.Enabled || event.Indices(2) ~= 2, panel.syncTables; return; end
            tokens = ["exclude","train","validation","test"];
            labels = leotherm.deviceCalibrationText(tokens, panel.Language);
            index = find(labels == string(event.NewData), 1);
            if ~isempty(index)
                panel.State.split.role(event.Indices(1)) = tokens(index);
                panel.inputsChanged;
            end
            panel.syncTables;
        end

        function syncTables(panel)
            if isempty(panel.State.profile)
                panel.ProfileName.Value = '';
                panel.ProfileTable.Data = cell(0,11);
            else
                panel.ProfileName.Value = char(panel.State.profile.name);
                panel.ProfileTable.Data = panel.displayTable(panel.State.profile.parameters);
            end
            panel.ProfileTable.ColumnName = panel.headers({'field','node','peer','unit', ...
                'nominal','lower','upper','priorSigma','estimate','evidence','kind'});
            panel.DayTable.ColumnName = panel.headers({'day_utc','role'});
            panel.DayTable.Data = cell(0,2);
            if ~isempty(panel.State.split)
                panel.DayTable.Data = panel.displayTable(panel.State.split);
            end
            panel.ParameterReportTable.Data = cell(0,0);
            panel.StageTable.Data = cell(0,5);
            panel.StageTable.ColumnName = panel.headers({'role','node','used_samples', ...
                'baseline_rmse_k','calibrated_rmse_k'});
            panel.WarningTable.Data = cell(0,1);
            panel.CoverageTable.Data = cell(0,8);
            if isempty(panel.State.result), return; end
            r = panel.State.result;
            panel.ParameterReportTable.Data = panel.displayTable(r.parameterReport);
            panel.ParameterReportTable.ColumnName = panel.headers(r.parameterReport.Properties.VariableNames);
            panel.StageTable.Data = panel.displayTable(r.stageMetrics);
            panel.StageTable.ColumnName = panel.headers(r.stageMetrics.Properties.VariableNames);
            if isfield(r,'coverage')
                panel.CoverageTable.Data = panel.displayTable(r.coverage);
                panel.CoverageTable.ColumnName = panel.headers(r.coverage.Properties.VariableNames);
            end
            codes = strings(0,1);
            if isfield(r, 'warningCodes'), codes = string(r.warningCodes(:));
            elseif isfield(r, 'warnings'), codes = string(r.warnings(:)); end
            panel.WarningTable.Data = cellstr(leotherm.deviceCalibrationText(codes, panel.Language));
        end

        function cells = displayTable(panel, raw)
            display = raw;
            names = raw.Properties.VariableNames;
            for k = 1:numel(names)
                name = names{k};
                if ismember(name, {'field','kind','role','status'})
                    display.(name) = leotherm.deviceCalibrationText(raw.(name), panel.Language);
                elseif ismember(name, {'node','peer'})
                    values = string(raw.(name));
                    nonempty = strlength(values) > 0;
                    labels = leotherm.nodeDisplayNames(cellstr(values(nonempty)), panel.Language);
                    values(nonempty) = string(labels);
                    display.(name) = values;
                end
            end
            cells = table2cell(display);
            for k = 1:numel(cells)
                if isstring(cells{k}), cells{k} = char(cells{k}); end
            end
        end

        function labels = headers(panel, names)
            pairs = {'field','参数','Parameter'; 'node','节点','Node'; 'peer','连接节点','Peer'; ...
                'scored_samples','评分样本数','Scored samples'; 'scored_duration_s','有效时长（s）','Scored duration (s)'; ...
                'longest_continuous_s','最长连续时长（s）','Longest continuous span (s)'; ...
                'temperature_span_k','温度变化（K）','Temperature span (K)'; 'sufficient','覆盖充分','Sufficient coverage'; ...
                'unit','单位','Unit'; 'nominal','标称值（只读）','Nominal (read-only)'; ...
                'lower','下界','Lower'; 'upper','上界','Upper'; 'priorSigma','先验标准差','Prior sigma'; ...
                'estimate','估计','Estimate'; 'evidence','依据或明确假设','Evidence or explicit assumption'; ...
                'kind','参数类别','Parameter kind'; 'day_utc','日期（协调世界时）','Day (UTC)'; ...
                'role','数据角色','Data role'; 'used_samples','有效样本数','Used samples'; ...
                'baseline_rmse_k','标定前均方根误差（K）','Baseline RMSE (K)'; ...
                'calibrated_rmse_k','标定后均方根误差（K）','Calibrated RMSE (K)'; ...
                'calibrated','标定值','Calibrated'; 'change','变化量','Change'; ...
                'change_percent','变化（%）','Change (%)'; ...
                'change_prior_sigma','变化 / 先验标准差','Change / prior sigma'; ...
                'within_bounds','范围内','Within bounds'; 'near_bound','接近边界','Near bound'};
            labels = cell(size(names));
            for k = 1:numel(names)
                at = find(strcmp(pairs(:,1), names{k}), 1);
                if isempty(at), labels{k} = names{k};
                else, labels{k} = panel.t(pairs{at,2}, pairs{at,3}); end
            end
        end

        function source = sourceInput(panel)
            state = panel.SourceProvider();
            source = struct('source', state.source, 'mapping', state.mapping, ...
                'options', state.options, 'mode', state.mode, 'fileStamp', []);
            if ischar(source.source) || (isstring(source.source) && isscalar(source.source))
                info = dir(char(source.source));
                if ~isempty(info)
                    source.fileStamp = struct('bytes', info(1).bytes, 'datenum', info(1).datenum);
                end
            end
        end

        function key = dayInput(~, source, network)
            key = struct('source', source.source, 'mapping', source.mapping, ...
                'fileStamp', source.fileStamp, 'nodeNames', {network.nodeNames});
        end

        function data = readSource(panel, source, network)
            if isempty(source.source)
                error('leotherm:DeviceCalibrationData', '%s', ...
                    panel.t('请先在遥测与验证页导入数据并配置映射。', ...
                    'Import and map data in Telemetry and validation first.'));
            end
            % Always reread: no previous telemetry simulation is required, and
            % cached data must not outlive mapping, file or network edits.
            data = leotherm.readTelemetry(source.source, source.mapping, network);
        end

        function updateStatus(panel)
            if isempty(panel.State.profile)
                panel.ProfileStatus.Text = panel.t('尚未载入设备档案', 'No device profile loaded');
            elseif panel.State.profileStale
                panel.ProfileStatus.Text = panel.t( ...
                    '档案与当前设备不一致：运行将被拒绝；请核对热网络并重新载入档案。', ...
                    'Profile differs from the current device: run will be rejected; review the network and reload the profile.');
            else
                panel.ProfileStatus.Text = panel.t( ...
                    '标称值只读（在热网络页修改）；默认参数全部锁定；依据不由软件核实。', ...
                    'Nominal values are read-only (edit in Thermal network); parameters default to locked; evidence is not verified.');
            end
            if isempty(panel.State.result)
                text = panel.t('未运行；尚无标定结论', 'Not run; no calibration conclusion');
            else
                outcome = char(leotherm.deviceCalibrationText(panel.State.result.status, panel.Language));
                text = [panel.t('冻结运行结论：', 'Frozen run outcome: ') outcome];
                if panel.State.resultStale
                    text = [panel.t('输入已变化；以下为旧配置的冻结结果。', ...
                        'Inputs changed; results below belong to a frozen older configuration. ') text];
                end
            end
            if panel.State.splitStale
                text = [text panel.t(' 日期角色已过期，需重新载入。', ' Day roles are stale; reload days.')];
            end
            if ~isempty(panel.State.lastErrorId)
                text = [panel.t('操作未完成：', 'Operation incomplete: ') panel.State.lastErrorId];
                if ~isempty(panel.State.result)
                    text = [text panel.t(' 表格保留旧配置的冻结结果。', ...
                        ' Tables retain a frozen result from an older configuration.')];
                end
            end
            panel.StatusLabel.Text = text;
            path = panel.State.outputDirectory;
            if ~isempty(panel.State.result) && isfield(panel.State.result, 'outputDirectory')
                path = panel.State.result.outputDirectory;
            end
            prefix = panel.t('运行目录：', 'Run directory: ');
            if ~isempty(panel.State.result)
                prefix = panel.t('冻结结果目录：', 'Frozen result directory: ');
            end
            panel.OutputLabel.Text = [prefix char(path)];
            panel.OutputLabel.Tooltip = char(path);
        end

        function perform(panel, action)
            if ~panel.Enabled, return; end
            panel.BusyHandler(true, panel.t('正在处理设备标定...', 'Processing device calibration...'));
            cleanup = onCleanup(@() panel.BusyHandler(false, panel.t('就绪', 'Ready')));
            try
                action();
            catch exception
                panel.State.lastError = getReport(exception, 'extended');
                panel.State.lastErrorId = exception.identifier;
                panel.updateStatus;
                message = exception.message;
                if strcmp(panel.Language, 'zh')
                    message = [panel.chineseError(exception.identifier) ...
                        sprintf('\n%s', exception.identifier)];
                end
                uialert(ancestor(panel.Tab, 'figure'), message, ...
                    panel.t('设备标定操作失败', 'Device calibration operation failed'));
            end
            clear cleanup
        end

        function loadDeviceUI(panel)
            if ~isempty(panel.State.profile) && ~panel.confirm( ...
                    '载入当前设备将重建全锁定档案，替换当前编辑内容。', ...
                    'Loading the current device replaces profile edits with a locked template.')
                return
            end
            panel.loadCurrentDevice;
        end

        function prepareUI(panel)
            panel.loadDeviceUI;
            panel.loadDaysUI;
        end

        function moreActionChanged(panel)
            action = panel.MoreActions.Value;
            if strcmp(action, 'more'), return; end
            panel.MoreActions.Value = 'more';
            switch action
                case 'device', panel.perform(@() panel.loadDeviceUI);
                case 'import', panel.perform(@() panel.importUI);
                case 'export', panel.perform(@() panel.exportUI);
                case 'days', panel.perform(@() panel.loadDaysUI);
            end
        end

        function loadDaysUI(panel)
            if ~isempty(panel.State.split) && ~panel.confirm( ...
                    '重新载入日期将把所有日期设为排除。', ...
                    'Reloading days resets every day to excluded.')
                return
            end
            panel.loadTelemetryDays;
        end

        function yes = confirm(panel, chinese, english)
            proceed = panel.t('继续', 'Continue'); cancel = panel.t('取消', 'Cancel');
            choice = uiconfirm(ancestor(panel.Tab, 'figure'), panel.t(chinese, english), ...
                panel.t('替换当前编辑', 'Replace current edits'), ...
                'Options', {proceed, cancel}, 'DefaultOption', 2, 'CancelOption', 2);
            yes = strcmp(choice, proceed);
        end

        function importUI(panel)
            [file, folder] = uigetfile('*.mat', panel.t('导入设备档案', 'Import device profile'));
            if isequal(file, 0), return; end
            panel.importProfile(fullfile(folder, file));
        end

        function exportUI(panel)
            [file, folder] = uiputfile('*.mat', panel.t('导出设备档案（新文件）', ...
                'Export device profile (new file)'), 'device_profile.mat');
            if isequal(file, 0), return; end
            panel.exportProfile(fullfile(folder, file));
        end

        function runUI(panel)
            folder = uigetdir(pwd, panel.t('选择新运行的父目录', 'Choose parent folder for a new run'));
            if isequal(folder, 0), return; end
            name = inputdlg(panel.t('新运行目录名称', 'New run directory name'), ...
                panel.t('保存标定运行', 'Save calibration run'), [1 65], ...
                {['device_calibration_' datestr(now, 'yyyymmdd_HHMMSS')]});
            if isempty(name), return; end
            name = strtrim(name{1});
            if isempty(name) || ismember(name, {'.','..'}) || ~isempty(regexp(name, '[\\/:*?"<>|]', 'once'))
                error('leotherm:DeviceCalibrationExport', '%s', ...
                    panel.t('请输入单个有效的新目录名称。', 'Enter one valid new folder name.'));
            end
            panel.run([], [], [], fullfile(folder, name));
        end

        function message = chineseError(~, identifier)
            switch identifier
                case 'leotherm:DeviceCalibrationProfile'
                    message = '设备档案与热网络或物理约束不一致。请核对标称值、范围、先验与依据。';
                case 'leotherm:DeviceCalibrationEvidence'
                    message = '必须提供测温不确定度的来源或明确假设。';
                case 'leotherm:DeviceCalibrationOptions'
                    message = '标定设置无效；标准差和正则权重须为正数，启用的误差上限须明确填写。';
                case 'leotherm:DeviceCalibrationParameters'
                    message = '需明确选择待估参数，并满足核心允许的参数数量限制。';
                case 'leotherm:DeviceCalibrationSplit'
                    message = '请载入当前遥测日期，并按时间顺序明确分配互不重叠的标定、验证与最终检查日期。';
                case 'leotherm:DeviceCalibrationExport'
                    message = '无法保存。请选择可写的新目录或新文件，已有输出不会被覆盖。';
                case {'leotherm:DeviceCalibrationData','leotherm:DeviceCalibrationDriver','leotherm:DeviceCalibrationLeakage'}
                    message = '遥测映射或驱动存在冲突。请核对目标测温、功率覆盖和驱动独立性。';
                case 'leotherm:DeviceCalibrationCoverage'
                    message = '预先指定的日期与节点缺少足够有效样本；不会通过删除失败样本改善结果。';
                case {'leotherm:DeviceCalibrationSimulation','leotherm:DeviceCalibrationNumerics'}
                    message = '仿真或积分精度检查失败；请核对热网络及积分步长。';
                case 'leotherm:CalibrationNotConverged'
                    message = '最优标定尚未收敛；仅保留诊断，不冻结参数，也不作通过判断。';
                otherwise
                    message = '标定未完成，不能据此宣称通过；请核对输入、收敛设置及已保存的诊断文件。';
            end
        end

        function value = t(panel, chinese, english)
            value = english;
            if strcmp(panel.Language, 'zh'), value = chinese; end
        end
    end
end
