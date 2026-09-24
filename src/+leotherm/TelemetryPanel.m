classdef TelemetryPanel < handle
    %TELEMETRYPANEL CSV mapping, telemetry driving, and independent-data comparison.
    properties (SetAccess = private)
        Tab
    end
    properties (Access = private)
        Language
        ModelProvider
        BusyHandler
        State
        MappingTable
        MetricsTable
        AuditTable
        Mode
        FrameConfirmed
        MaxGap
        MaxStep
        ExcludeInitial
        UseInitial
        UseTolerance
        Tolerance
        NodePicker
        MoreActions
        FileLabel
        StatusLabel
        Axes
        Buttons = {}
    end
    methods
        function panel = TelemetryPanel(parent, language, provider, busyHandler)
            panel.Language = language;
            panel.ModelProvider = provider;
            panel.BusyHandler = busyHandler;
            panel.State = struct('source', [], 'mapping', table, 'data', [], ...
                'result', [], 'report', [], 'mode', 'orbit', 'selectedNode', '', ...
                'options', leotherm.telemetryOptions, 'demo', false, 'lastError', '');
            panel.State.nodeNames = {};
            panel.State.resultInputs = [];
            panel.State.resultStale = false;
            panel.build(parent);
        end

        function state = getState(panel)
            panel.refreshContext;
            state = panel.State;
            state.mode = panel.Mode.Value;
            state.options = panel.collectOptions;
            state.selectedNode = panel.NodePicker.Value;
        end

        function restoreState(panel, state)
            if ~isfield(state,'resultInputs'), state.resultInputs=[]; end
            if ~isfield(state,'resultStale'), state.resultStale=~isempty(state.result); end
            panel.State = state;
            panel.Mode.Value = state.mode;
            panel.syncOptions(state.options);
            panel.syncMapping;
            if ~isempty(state.result)
                panel.syncNodes(state.result.network, state.selectedNode);
                panel.draw;
            end
            panel.updateStatus;
        end

        function importSource(panel, source, mapping)
            raw = leotherm.readTelemetryTable(source);
            model = panel.ModelProvider();
            if nargin < 3 || isempty(mapping)
                mapping = leotherm.telemetryMapping(raw, model.network);
            end
            mapping = panel.normalizeMapping(mapping);
            previous = panel.State;
            panel.State.source = source;
            if isfield(panel.State,'sourceLabel'), panel.State=rmfield(panel.State,'sourceLabel'); end
            panel.State.mapping = mapping;
            panel.State.nodeNames = model.network.nodeNames;
            panel.State.data = []; panel.State.result = []; panel.State.report = [];
            panel.State.resultInputs = []; panel.State.resultStale = false;
            panel.State.demo = ismember('dataset_type', raw.Properties.VariableNames) ...
                && any(contains(string(raw.dataset_type), 'synthetic'));
            try
                panel.syncMapping;
            catch exception
                panel.State = previous;
                panel.syncMapping;
                rethrow(exception);
            end
            panel.syncNodes(model.network, '');
            for ax = panel.Axes(:)', cla(ax); end
            panel.MetricsTable.Data = table;
            panel.AuditTable.Data = table;
            panel.updateStatus;
        end

        function [result, report] = run(panel, options)
            model = panel.ModelProvider();
            panel.invalidateResults;
            if nargin < 2, options = panel.collectOptions; end
            options = leotherm.telemetryOptions(options);
            panel.syncOptions(options);
            panel.State.options = options;
            data = leotherm.readTelemetry(panel.State.source, panel.State.mapping, model.network);
            if strcmp(panel.Mode.Value, 'validation')
                if isfield(model,'referenceStale') && model.referenceStale
                    error('leotherm:StaleResult','The scenario inputs changed. Run the scenario again before validating it.');
                end
                if isempty(model.reference)
                    error('leotherm:TelemetryReference', 'Run a single scenario before validating its result.');
                end
                result = model.reference;
            else
                result = leotherm.simulateTelemetry(data, model.scenario, model.network, options);
            end
            report = leotherm.validateTelemetry(result, data, options);
            panel.State.data = data; panel.State.result = result; panel.State.report = report;
            panel.State.resultInputs = panel.currentInputs;
            panel.State.resultStale = false;
            node = find(data.hasTemperature, 1);
            if isfield(data, 'hasBoundaryTemperature')
                boundaryNode = find(data.hasTemperature & data.hasBoundaryTemperature, 1);
                if ~isempty(boundaryNode), node = boundaryNode; end
            end
            selected = result.network.nodeNames{1};
            if isfield(result.network, 'roles') && ~isempty(result.network.roles.response)
                selected = result.network.nodeNames{result.network.roles.response};
            end
            if ~isempty(node) && any(strcmp(result.network.nodeNames, data.nodeNames{node}))
                selected = data.nodeNames{node};
            end
            panel.syncNodes(result.network, selected);
            panel.draw;
            panel.updateStatus;
        end

        function setWorkflow(panel, mode)
            panel.Mode.Value = mode;
            panel.invalidateResults;
        end

        function exportResults(panel, directory)
            panel.refreshContext;
            if panel.State.resultStale
                error('leotherm:StaleResult','Inputs changed. Rerun telemetry before exporting its comparison.');
            end
            if isempty(panel.State.result)
                error('leotherm:TelemetryExport', 'No telemetry result is available.');
            end
            leotherm.writeTelemetryResults(panel.State.result, panel.State.report, ...
                panel.State.data, directory, panel.Language);
        end

        function setEnabled(panel, enabled)
            value = 'off'; if enabled, value = 'on'; end
            for k = 1:numel(panel.Buttons)
                if isvalid(panel.Buttons{k}), panel.Buttons{k}.Enable = value; end
            end
        end

        function refreshContext(panel)
            if isempty(panel.State.result), return; end
            try
                panel.State.resultStale = isempty(panel.State.resultInputs) ...
                    || ~isequaln(panel.currentInputs,panel.State.resultInputs);
            catch
                panel.State.resultStale = true;
            end
            if panel.State.resultStale
                panel.StatusLabel.Text=panel.t('输入已改变，图表为旧结果；请重新运行。', ...
                    'Inputs changed; the plots show older results. Rerun required.');
            end
        end

        function audit = preflight(panel)
            model=panel.ModelProvider();
            data=leotherm.readTelemetry(panel.State.source,panel.State.mapping,model.network);
            audit=leotherm.telemetryPreflight(data,panel.collectOptions,panel.Mode.Value);
        end
    end

    methods (Access = private)
        function inputs = currentInputs(panel)
            model=panel.ModelProvider();
            stamp=[];
            if ischar(panel.State.source) || (isstring(panel.State.source) && isscalar(panel.State.source))
                info=dir(char(panel.State.source));
                if ~isempty(info), stamp=struct('bytes',info.bytes,'datenum',info.datenum); end
            end
            inputs=struct('scenario',model.scenario,'network',model.network, ...
                'source',panel.State.source,'mapping',panel.State.mapping,'fileStamp',stamp, ...
                'mode',panel.Mode.Value,'options',panel.collectOptions,'reference',[]);
            if strcmp(panel.Mode.Value,'validation'), inputs.reference=model.reference; end
        end

        function preflightUI(panel)
            a=panel.preflight;
            if strcmp(panel.Language,'zh')
                text=sprintf('总记录：%d\n有效驱动记录：%d\n有效连续段：%d\n最长连续段：%.1f 秒\n映射测温节点：%d\n缺失或无效测温值：%d\n\n%s', ...
                    a.totalRows,a.validDriverRows,a.segmentCount,a.longestSegmentS,a.measuredNodes,a.invalidTemperatures, ...
                    strjoin(cellstr(leotherm.preflightText(a.codes,'zh')),newline));
            else
                text=sprintf('Records: %d\nValid driving records: %d\nSegments: %d\nLongest segment: %.1f s\nMeasured nodes: %d\nInvalid temperatures: %d\n\n%s', ...
                    a.totalRows,a.validDriverRows,a.segmentCount,a.longestSegmentS,a.measuredNodes,a.invalidTemperatures, ...
                    strjoin(cellstr(leotherm.preflightText(a.codes,'en')),newline));
            end
            icon='info'; if ~a.ready, icon='warning'; end
            uialert(ancestor(panel.Tab,'figure'),text,panel.t('数据预检','Data preflight'),'Icon',icon);
        end
        function build(panel, parent)
            panel.Tab = uitab(parent, 'Title', panel.t('遥测与验证', 'Telemetry and validation'));
            layout = uigridlayout(panel.Tab, [3,1]);
            layout.RowHeight = {38, '1x', 30}; layout.Padding = [12 10 12 5];
            toolbar = uigridlayout(layout, [1,5]);
            toolbar.ColumnWidth = {105,105,150,'1x',115};
            toolbar.Padding = [0 0 0 0];
            panel.button(toolbar, panel.t('导入遥测', 'Import CSV'), @() panel.importUI);
            panel.button(toolbar,panel.t('数据预检','Preflight'),@()panel.preflightUI);
            panel.NodePicker = uidropdown(toolbar, 'Items', {panel.t('未选择节点', 'No node selected')}, ...
                'ItemsData', {''}, 'Tooltip', panel.t('图中显示的热节点', 'Thermal node shown in the plots'), ...
                'ValueChangedFcn', @(~,~) panel.draw);
            panel.MoreActions = uidropdown(toolbar, ...
                'Items', panel.t({'更多操作','导出空模板','合成演示数据','保存列映射','读取列映射'}, ...
                {'More actions','CSV template','Synthetic demo data','Save column mapping','Load column mapping'}), ...
                'ItemsData', {'more','template','demo','save_mapping','load_mapping'}, ...
                'Value', 'more', 'ValueChangedFcn', @(~,~) panel.moreActionChanged);
            panel.Buttons{end+1} = panel.MoreActions;
            panel.button(toolbar, panel.t('导出遥测结果', 'Export telemetry'), @() panel.exportUI);

            middle = uigridlayout(layout, [1,2]); middle.Layout.Row = 2;
            middle.ColumnWidth = {445, '1x'}; middle.Padding = [0 0 0 0];
            left = uigridlayout(middle, [3,1]); left.RowHeight = {36,270,'1x'};
            left.Padding = [0 0 0 0];
            panel.FileLabel = uilabel(left, 'WordWrap', 'on', ...
                'Text', panel.t('尚未载入遥测', 'No telemetry loaded'));
            controls = uigridlayout(left, [8,2]); controls.Layout.Row = 2;
            controls.RowHeight = {30,30,30,30,30,30,30,30};
            controls.ColumnWidth = {225,'1x'}; controls.Padding = [0 0 0 0];
            controls.RowSpacing = 4;
            uilabel(controls, 'Text', panel.t('使用方式', 'Workflow'));
            panel.Mode = uidropdown(controls, ...
                'Items', panel.t({'轨道遥测驱动','热功率遥测驱动','验证已有单场景'}, ...
                {'Orbit telemetry','Measured heat loads','Validate current scenario'}), ...
                'ItemsData', {'orbit','heat','validation'});
            panel.FrameConfirmed = uicheckbox(controls, ...
                'Text', panel.t('确认轨道与太阳位置均为二〇〇〇年地心惯性系', ...
                'Orbit and Sun positions share geocentric J2000 ECI'));
            panel.FrameConfirmed.Layout.Row = 2; panel.FrameConfirmed.Layout.Column = [1 2];
            label = uilabel(controls, 'Text', panel.t('允许的最大相邻间隔（秒）', 'Maximum adjacent interval (s)'));
            label.Layout.Row = 3; label.Layout.Column = 1;
            panel.MaxGap = uieditfield(controls,'numeric','Limits',[0.001 Inf],'Value',60);
            panel.MaxGap.Layout.Row = 3; panel.MaxGap.Layout.Column = 2;
            label = uilabel(controls, 'Text', panel.t('每段起始排除时长（秒）', 'Exclude segment start (s)'));
            label.Layout.Row = 4; label.Layout.Column = 1;
            panel.ExcludeInitial = uieditfield(controls,'numeric','Limits',[0 Inf],'Value',600);
            panel.ExcludeInitial.Layout.Row = 4; panel.ExcludeInitial.Layout.Column = 2;
            panel.UseInitial = uicheckbox(controls, 'Text', ...
                panel.t('以首个有效实测温度初始化（属于条件验证）', ...
                'Initialize from measured temperatures (conditional validation)'));
            panel.UseInitial.Layout.Row = 5; panel.UseInitial.Layout.Column = [1 2];
            panel.UseTolerance = uicheckbox(controls, 'Text', ...
                panel.t('启用均方根误差上限（K）', 'User RMSE limit (K)'));
            panel.UseTolerance.Layout.Row = 6; panel.UseTolerance.Layout.Column = 1;
            panel.Tolerance = uieditfield(controls,'numeric','Limits',[0 Inf],'Value',1);
            panel.Tolerance.Layout.Row = 6; panel.Tolerance.Layout.Column = 2;
            label = uilabel(controls, 'Text', panel.t('积分最大子步长（秒）', 'Maximum integration step (s)'));
            label.Layout.Row = 7; label.Layout.Column = 1;
            panel.MaxStep = uieditfield(controls,'numeric','Limits',[0.001 Inf],'Value',10);
            panel.MaxStep.Layout.Row = 7; panel.MaxStep.Layout.Column = 2;
            runButton = panel.button(controls, panel.t('执行仿真或验证', 'Run simulation or comparison'), ...
                @() panel.runUI);
            runButton.Layout.Row = 8; runButton.Layout.Column = [1 2];
            panel.MappingTable = uitable(left, 'Data', cell(0,4), ...
                'ColumnName', panel.t({'源数据列','物理量','热节点','单位'}, ...
                {'Source column','Quantity','Thermal node','Unit'}), ...
                'ColumnEditable', [false true true true], ...
                'ColumnWidth', {120,110,120,75}, 'RowName', [], ...
                'CellEditCallback', @(~,~) panel.mappingChanged);
            panel.MappingTable.Layout.Row = 3;
            right = uigridlayout(middle, [3,1]); right.Layout.Column = 2;
            right.RowHeight = {'1x','1x',160}; right.Padding = [0 0 0 0];
            panel.Axes = gobjects(1,2);
            for k = 1:2
                panel.Axes(k) = uiaxes(right); panel.Axes(k).Layout.Row = k;
                panel.Axes(k).Box = 'on';
            end
            tables = uitabgroup(right); tables.Layout.Row = 3;
            metricsTab = uitab(tables, 'Title', panel.t('温度统计', 'Temperature metrics'));
            auditTab = uitab(tables, 'Title', panel.t('逐行质量记录', 'Row quality audit'));
            grid = uigridlayout(metricsTab, [1,1]); grid.Padding = [0 0 0 0];
            panel.MetricsTable = uitable(grid, 'Data', table);
            grid = uigridlayout(auditTab, [1,1]); grid.Padding = [0 0 0 0];
            panel.AuditTable = uitable(grid, 'Data', table);
            panel.StatusLabel = uilabel(layout, 'Text', panel.t( ...
                '未运行；对比吻合不等于物理模型已被证明正确', ...
                'Not run; agreement does not establish physical validity'));
            panel.StatusLabel.Layout.Row = 3;
            controls = {panel.Mode,panel.FrameConfirmed,panel.MaxGap,panel.MaxStep, ...
                panel.ExcludeInitial,panel.UseInitial,panel.UseTolerance,panel.Tolerance};
            for k = 1:numel(controls)
                controls{k}.ValueChangedFcn = @(~,~) panel.invalidateResults;
                panel.Buttons{end+1} = controls{k};
            end
        end

        function invalidateResults(panel)
            panel.State.result = []; panel.State.report = []; panel.State.data = [];
            for ax = panel.Axes(:)', cla(ax); end
            panel.MetricsTable.Data = table; panel.AuditTable.Data = table;
            panel.updateStatus;
        end

        function h = button(panel, parent, text, action)
            h = uibutton(parent, 'Text', text, 'ButtonPushedFcn', @(~,~) panel.perform(action));
            panel.Buttons{end+1} = h;
        end

        function perform(panel, action)
            panel.BusyHandler(true, panel.t('正在处理遥测...', 'Processing telemetry...'));
            cleanup = onCleanup(@() panel.BusyHandler(false, panel.t('就绪', 'Ready')));
            try
                action();
            catch exception
                panel.State.lastError = getReport(exception, 'extended');
                if strcmp(panel.Language, 'zh')
                    message = panel.chineseError(exception.identifier);
                else
                    message = exception.message;
                end
                panel.StatusLabel.Text = message;
                uialert(ancestor(panel.Tab, 'figure'), message, panel.t('遥测操作失败', 'Telemetry operation failed'));
            end
        end

        function importUI(panel)
            [file, folder] = uigetfile('*.csv', panel.t('选择遥测数据', 'Select telemetry data'));
            if isequal(file, 0), return; end
            panel.importSource(fullfile(folder, file));
        end

        function moreActionChanged(panel)
            action = panel.MoreActions.Value;
            if strcmp(action, 'more'), return; end
            panel.MoreActions.Value = 'more';
            switch action
                case 'template', panel.perform(@() panel.templateUI);
                case 'demo', panel.perform(@() panel.demoUI);
                case 'save_mapping', panel.perform(@() panel.saveMappingUI);
                case 'load_mapping', panel.perform(@() panel.loadMappingUI);
            end
        end

        function templateUI(panel)
            includeBoundary = false;
            if ~strcmp(panel.Mode.Value, 'validation')
                yes = panel.t('包含边界', 'Include boundary');
                no = panel.t('普通模板', 'Basic template');
                cancel = panel.t('取消', 'Cancel');
                choice = questdlg(panel.t('是否加入边界温度和导热系数列？', ...
                    'Include boundary temperature and conductance columns?'), ...
                    panel.t('模板类型', 'Template type'), yes, no, cancel, no);
                if isempty(choice) || strcmp(choice, cancel), return; end
                includeBoundary = strcmp(choice, yes);
            end
            [file, folder] = uiputfile('*.csv', panel.t('保存遥测模板', 'Save telemetry template'), 'telemetry_template.csv');
            if isequal(file, 0), return; end
            model = panel.ModelProvider();
            leotherm.writeTelemetryTemplate(fullfile(folder,file), model.network, panel.Mode.Value, includeBoundary);
            panel.StatusLabel.Text = panel.t('空模板已导出', 'Empty template exported');
        end

        function demoUI(panel)
            model = panel.ModelProvider();
            [raw, ~, options] = leotherm.telemetryDemo(model.network, true);
            panel.importSource(raw);
            panel.Mode.Value = 'orbit'; panel.syncOptions(options);
            panel.State.demo = true; panel.updateStatus;
        end

        function runUI(panel)
            panel.run;
        end

        function exportUI(panel)
            folder = uigetdir(pwd, panel.t('选择导出目录', 'Select export directory'));
            if isequal(folder, 0), return; end
            target = fullfile(folder, ['telemetry_' datestr(now, 'yyyymmdd_HHMMSS')]);
            panel.exportResults(target);
            panel.StatusLabel.Text = [panel.t('已导出：', 'Exported: ') target];
        end

        function saveMappingUI(panel)
            [file,folder] = uiputfile('*.csv', panel.t('保存列映射', 'Save column mapping'), 'telemetry_mapping.csv');
            if isequal(file,0), return; end
            writetable(panel.State.mapping, fullfile(folder,file));
        end

        function loadMappingUI(panel)
            [file,folder] = uigetfile('*.csv', panel.t('读取列映射', 'Load column mapping'));
            if isequal(file,0), return; end
            mapping = readtable(fullfile(folder,file), 'TextType','string');
            mapping = panel.normalizeMapping(mapping);
            previous = panel.State.mapping;
            panel.State.mapping = mapping;
            try
                panel.syncMapping;
            catch exception
                panel.State.mapping = previous; panel.syncMapping; rethrow(exception);
            end
            panel.invalidateResults;
        end

        function syncMapping(panel)
            if isempty(panel.State.source), return; end
            [targets, targetLabels, units, unitLabels] = panel.mappingVocabulary;
            nodeNames = panel.State.nodeNames;
            nodes = [{panel.t('无', 'None')}, leotherm.nodeDisplayNames(nodeNames, panel.Language)];
            mapping = panel.State.mapping;
            display = cell(height(mapping), 4);
            for k = 1:height(mapping)
                display{k,1} = char(mapping.source(k));
                i = find(strcmp(targets, mapping.target(k)), 1);
                if isempty(i), error('leotherm:TelemetryMapping', 'Unknown mapping target.'); end
                display{k,2} = targetLabels{i};
                i = find(strcmp(nodeNames, mapping.node(k)), 1);
                if isempty(i)
                    if strlength(string(mapping.node(k))) > 0
                        error('leotherm:TelemetryMapping', 'Mapped node is not in the current network.');
                    end
                    display{k,3} = nodes{1};
                else
                    display{k,3} = nodes{i+1};
                end
                i = find(strcmp(units, mapping.unit(k)), 1);
                if isempty(i), error('leotherm:TelemetryUnit', 'Unsupported mapping unit.'); end
                display{k,4} = unitLabels{i};
            end
            panel.MappingTable.ColumnFormat = {'char', targetLabels, nodes, unitLabels};
            panel.MappingTable.Data = display;
            if istable(panel.State.source)
                panel.FileLabel.Text = panel.t('内存中的遥测表', 'Telemetry table in memory');
                if isfield(panel.State,'sourceLabel')
                    panel.FileLabel.Text=[panel.t('项目内遥测快照：','Embedded telemetry snapshot: ') panel.State.sourceLabel];
                end
            else
                panel.FileLabel.Text = char(panel.State.source);
            end
        end

        function mappingChanged(panel)
            [targets, targetLabels, units, unitLabels] = panel.mappingVocabulary;
            nodeNames = panel.State.nodeNames;
            nodeLabels = leotherm.nodeDisplayNames(nodeNames, panel.Language);
            display = panel.MappingTable.Data; mapping = panel.State.mapping;
            for k = 1:size(display,1)
                mapping.target(k) = targets{strcmp(targetLabels, display{k,2})};
                i = find(strcmp(nodeLabels, display{k,3}),1);
                mapping.node(k) = "";
                if ~isempty(i), mapping.node(k) = nodeNames{i}; end
                mapping.unit(k) = units{strcmp(unitLabels, display{k,4})};
            end
            panel.State.mapping = mapping;
            panel.invalidateResults;
        end

        function [targets,labels,units,unitLabels] = mappingVocabulary(panel)
            targets = {'ignore','epoch','quality','position_x','position_y','position_z', ...
                'velocity_x','velocity_y','velocity_z','temperature','external_power','internal_power', ...
                'sun_x','sun_y','sun_z','boundary_temperature','boundary_conductance'};
            labels = panel.t({'忽略','时间','质量标记','位置横坐标','位置纵坐标','位置竖坐标', ...
                '速度横分量','速度纵分量','速度竖分量','温度','吸收的外部热功率','内部功耗', ...
                '太阳位置横坐标','太阳位置纵坐标','太阳位置竖坐标','边界温度','边界导热系数'}, ...
                {'Ignore','UTC epoch','Quality flag','Position X','Position Y','Position Z', ...
                'Velocity X','Velocity Y','Velocity Z','Temperature','Absorbed external power','Internal power', ...
                'Sun position X','Sun position Y','Sun position Z','Boundary temperature','Boundary conductance'});
            for a = 1:3
                for b = 1:3
                    targets{end+1} = sprintf('dcm_%d%d',a,b); %#ok<AGROW>
                    labels{end+1} = sprintf(panel.t('惯性系到本体系矩阵%d%d', 'ECI-to-body matrix %d%d'),a,b); %#ok<AGROW>
                end
            end
            units = {'','UTC','1','m','km','m/s','km/s','K','degC','W','W/K'};
            unitLabels = panel.t({'未指定','协调世界时','无量纲','米','千米','米/秒','千米/秒','开尔文','摄氏度','瓦','瓦/开尔文'}, ...
                {'Unset','UTC','Dimensionless','m','km','m/s','km/s','K','degC','W','W/K'});
        end

        function options = collectOptions(panel)
            options = leotherm.telemetryOptions;
            options.mode = panel.Mode.Value;
            if strcmp(options.mode,'validation'), options.mode = 'orbit'; end
            if panel.FrameConfirmed.Value, options.frame = 'J2000_ECI'; end
            options.maxGapS = panel.MaxGap.Value; options.maxStepS = panel.MaxStep.Value;
            options.excludeInitialS = panel.ExcludeInitial.Value;
            options.useInitialTemperature = panel.UseInitial.Value;
            if panel.UseTolerance.Value, options.rmseToleranceK = panel.Tolerance.Value; end
        end

        function syncOptions(panel, options)
            if ~strcmp(panel.Mode.Value, 'validation'), panel.Mode.Value = options.mode; end
            panel.FrameConfirmed.Value = strcmp(options.frame, 'J2000_ECI');
            panel.MaxGap.Value = options.maxGapS; panel.MaxStep.Value = options.maxStepS;
            panel.ExcludeInitial.Value = options.excludeInitialS;
            panel.UseInitial.Value = options.useInitialTemperature;
            panel.UseTolerance.Value = isfinite(options.rmseToleranceK);
            if panel.UseTolerance.Value, panel.Tolerance.Value = options.rmseToleranceK; end
        end

        function syncNodes(panel, network, selected)
            panel.NodePicker.Items = leotherm.nodeDisplayNames(network.nodeNames, panel.Language);
            panel.NodePicker.ItemsData = network.nodeNames;
            if any(strcmp(network.nodeNames, selected)), panel.NodePicker.Value = selected; end
        end

        function draw(panel)
            if isempty(panel.State.result), return; end
            leotherm.drawTelemetry(panel.Axes, panel.State.result, panel.State.report, ...
                panel.NodePicker.Value, panel.Language);
            metrics = panel.State.report.metrics;
            if ~isempty(metrics)
                labels = leotherm.nodeDisplayNames(cellstr(metrics.node), panel.Language);
                metrics.node = string(labels(:));
                values = unique(metrics.assessment);
                for k = 1:numel(values)
                    switch values(k)
                        case 'insufficient_samples', label = panel.t('样本不足', 'Insufficient samples');
                        case 'within_user_rmse_limit', label = panel.t('满足用户误差上限', 'Within user limit');
                        case 'outside_user_rmse_limit', label = panel.t('超出用户误差上限', 'Outside user limit');
                        otherwise, label = panel.t('仅作一致性对比', 'Comparison only');
                    end
                    metrics.assessment(metrics.assessment == values(k)) = label;
                end
            end
            panel.MetricsTable.Data = metrics;
            panel.MetricsTable.ColumnName = panel.t( ...
                {'节点','有效实测数','精确匹配数','统计样本数','平均偏差（K）','平均绝对误差（K）', ...
                '均方根误差（K）','最大绝对误差（K）','相关系数','用户判据'}, ...
                {'Node','Valid measured','Exact matches','Scored samples','Bias (K)','MAE (K)', ...
                'RMSE (K)','Max absolute (K)','Correlation','User criterion'});
            audit = panel.State.data.audit;
            if isfield(panel.State.result, 'audit'), audit = panel.State.result.audit; end
            codes = {'accepted','simulated','quality_rejected','invalid_utc_time', ...
                'invalid_internal_power','invalid_external_power','invalid_orbit', ...
                'invalid_attitude','isolated_sample','segment_failed','invalid_sun_position','invalid_thermal_boundary'};
            labels = panel.t({'已通过导入检查','已仿真','质量标记拒绝','时间无效', ...
                '内部功耗无效','外部热功率无效','轨道无效','姿态无效','孤立样本','整段计算失败','太阳位置无效','热边界输入无效'}, ...
                {'Import checks passed','Simulated','Quality rejected','Invalid UTC time', ...
                'Invalid internal power','Invalid external power','Invalid orbit', ...
                'Invalid attitude','Isolated sample','Segment failed','Invalid Sun position','Invalid thermal boundary'});
            for k = 1:numel(codes), audit.reason(audit.reason == codes{k}) = labels{k}; end
            panel.AuditTable.Data = audit;
            names = panel.t({'源数据行','协调世界时','是否采用','处理结果','弧段编号'}, ...
                {'Source row','UTC epoch','Accepted','Disposition','Segment ID'});
            panel.AuditTable.ColumnName = names(1:width(audit));
        end

        function updateStatus(panel)
            if isempty(panel.State.result)
                panel.StatusLabel.Text = panel.t('尚未运行；请确认列映射与单位', ...
                    'Not run; column mapping and units await confirmation');
            else
                report = panel.State.report;
                panel.StatusLabel.Text = sprintf(panel.t( ...
                    '已完成；%d个测温节点，%d个有效配对。仅评估一致性，不等于模型物理有效性已获证实。', ...
                    'Complete: %d measured nodes, %d scored pairs. Agreement is not proof of physical validity.'), ...
                    height(report.metrics), sum(report.metrics.used_samples));
                if isfield(panel.State.result, 'segments')
                    failed = sum(panel.State.result.segments.status ~= "complete");
                    panel.StatusLabel.Text = sprintf('%s %s%d', panel.StatusLabel.Text, ...
                        panel.t('未完成段数：', 'Incomplete segments: '), failed);
                end
            end
            if panel.State.demo
                panel.StatusLabel.Text = [panel.t('合成演示，非独立实测验证。', ...
                    'Synthetic demo, not independent validation. ') panel.StatusLabel.Text];
            end
        end

        function text = t(panel, chinese, english)
            if strcmp(panel.Language,'zh'), text = chinese; else, text = english; end
        end

        function mapping = normalizeMapping(~, mapping)
            required = {'source','target','node','unit'};
            if ~istable(mapping) || ~all(ismember(required,mapping.Properties.VariableNames))
                error('leotherm:TelemetryMapping', 'Mapping needs source, target, node, unit.');
            end
            for k = 1:numel(required)
                values = string(mapping.(required{k})); values(ismissing(values)) = "";
                mapping.(required{k}) = values;
            end
        end

        function message = chineseError(~, identifier)
            switch identifier
                case 'leotherm:StaleResult'
                    message='输入已变化，当前结果属于旧配置。请重新运行单场景或遥测，再进行验证或导出。';
                case 'leotherm:TelemetryTime'
                    message = '时间必须为明确的协调世界时，严格递增且不重复；例如2024-03-20T12:00:00Z。';
                case 'leotherm:TelemetryUnit'
                    message = '单位与物理量不匹配。温度使用开尔文或摄氏度，热功率使用瓦，导热系数使用瓦/开尔文。';
                case {'leotherm:TelemetryBoundary','leotherm:InvalidThermalBoundary'}
                    message = ['每个连接节点必须同时映射边界温度和导热系数。' ...
                        '开尔文温度必须大于零，导热系数不得为负，缺测会断段。'];
                case 'leotherm:TelemetryFrame'
                    message = '请确认轨道与太阳位置均为同一二〇〇〇年地心惯性系；本功能不自动转换地固系或其他时间系统。';
                case 'leotherm:TelemetryMapping'
                    message = ['请核对列映射：必须有唯一时间列；轨道模式需要完整的位置、速度和同坐标系太阳位置。' ...
                        '热功率模式需要每个节点的外部吸收热功率，零输入也须明确给零。'];
                case 'leotherm:TelemetryFile'
                    message = '请选择至少包含两行数据的逗号分隔文件。空模板不能直接用于仿真。';
                case 'leotherm:TelemetryReference'
                    message = '没有可用的参考仿真，或参考历元无效。请先运行单场景，再选择验证已有单场景。';
                case 'leotherm:TelemetryExport'
                    message = '没有可导出的遥测结果，或目标目录已含文件。请选择新的空目录。';
                otherwise
                    message = '操作未完成，请检查数据映射、参数范围及目录访问状态。';
            end
            message = sprintf('%s\n错误标识：%s',message,identifier);
        end
    end
end
