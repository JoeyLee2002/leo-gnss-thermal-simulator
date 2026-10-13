function capture_manual_v15(outputDirectory)
%CAPTURE_MANUAL_V15 Capture real UI states without changing release code.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'src'));
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
app = leotherm.ThermalSimulatorApp('off', 'en');
cleanup = onCleanup(@() delete(app));
app.Figure.Position = [20 20 1600 1100];
manifest = struct;
capture('01_start');
selector = findall(app.Figure, 'Tag', 'QuickStartTemplate');
selector.Value = 'paper';
selector.ValueChangedFcn(selector, []);
capture('02_paper');

scenario = leotherm.defaultScenario;
scenario.name = 'manual_single_scenario';
scenario.durationS = 7200;
scenario.timeStepS = 60;
scenario.warmupOrbits = 1;
scenario.convergence.enabled = false;
app.prepareWorkspace('scenario');
app.runScenario(scenario, leotherm.defaultReceiverNetwork);
selectPage('Simulation', 'Single scenario');
capture('03_scenario');
selectPage('Results and export', '');
capture('04_results');

app.prepareWorkspace('sweep');
setField('Altitude (km)', '600');
setField('Target beta angle (deg)', '0,30');
app.runSweep('beta_altitude', scenario, leotherm.defaultReceiverNetwork, 600, [0 30], 1);
selectPage('Simulation', 'Parameter sweep');
capture('05_sweep');
selectPage('Simulation', 'Thermal network');
capture('06_network');
app.prepareWorkspace('geometry');
app.loadSurfaceMesh(fullfile(root, 'examples', 'assets', 'example_coupled_surface.obj'), 1);
app.loadVolumeMesh(fullfile(root, 'examples', 'assets', 'example_two_tetrahedra.msh'));
selectPage('Simulation', '3-D geometry');
capture('07_geometry');
app.prepareWorkspace('thermal_model');
app.loadThermalModel(fullfile(root, 'examples', 'projects', '06_engineering_model_exchange.json'));
selectPage('Simulation', 'Engineering thermal model');
capture('08_model');
app.prepareWorkspace('telemetry');
selectPage('Simulation', 'Telemetry and validation');
capture('09_telemetry');
app.prepareWorkspace('calibration');
selectPage('Simulation', 'Device calibration');
capture('10_calibration');

inputTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 2, ...
    'TimerFcn', @captureInputs, 'BusyMode', 'drop');
inputCleanup = onCleanup(@() disposeTimer(inputTimer));
start(inputTimer);
leotherm.uiInputDialog(app.Figure, 'en', {'Task name', 'Duration (hours)', 'Time step (s)'}, ...
    'Task wizard: step 2', [1 1 1], {'my_first_run', '2', '60'});
clear inputCleanup

selectPage('Quick start', '');
timerObject = timer('ExecutionMode', 'fixedSpacing', 'Period', 2, ...
    'TimerFcn', @captureProgress, 'BusyMode', 'drop');
timerCleanup = onCleanup(@() disposeTimer(timerObject));
start(timerObject);
captureId = char(java.util.UUID.randomUUID);
app.runPaperTask(fullfile(outputDirectory, ['cancelled_progress_' captureId]), false);
clear timerCleanup
manifest.softwareVersion = leotherm.version;
manifest.captureNote = 'Real v1.5 MATLAB UI; small two-case tutorial sweep, not the 36-case study. Paper progress captured from an actual cancelled run.';
fid = fopen(fullfile(outputDirectory, 'capture_manifest.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s', jsonencode(manifest));
fclose(fid);
fprintf('MANUAL_CAPTURE_OK=%s\n', outputDirectory);
clear cleanup

    function selectPage(mainTitle, subTitle)
        main = findall(app.Figure, 'Type', 'uitab', 'Title', mainTitle);
        main.Parent.SelectedTab = main;
        if ~isempty(subTitle)
            detail = findall(app.Figure, 'Type', 'uitab', 'Title', subTitle);
            detail.Parent.SelectedTab = detail;
        end
        drawnow;
    end

    function setField(labelText, value)
        label = findall(app.Figure, 'Type', 'uilabel', 'Text', labelText);
        children = label.Parent.Children;
        for j = 1:numel(children)
            object = children(j);
            if isa(object, 'matlab.ui.control.EditField') && object.Layout.Row == label.Layout.Row
                object.Value = value;
                object.ValueChangedFcn(object, []);
                return
            end
        end
        error('ManualCapture:MissingField', 'Missing field: %s', labelText);
    end

    function captureInputs(~, ~)
        fig = findall(groot, 'Tag', 'LocalizedInputDialog');
        if isempty(fig), return; end
        stop(inputTimer);
        drawnow;
        pixels = getframe(fig);
        imwrite(pixels.cdata, fullfile(outputDirectory, '12_wizard_inputs.png'));
        objects = findall(fig, 'Type', 'uicontrol');
        entries = struct('type', {}, 'tag', {}, 'text', {}, 'position', {});
        for j = 1:numel(objects)
            entries(end+1) = struct('type', class(objects(j)), 'tag', objects(j).Tag, ...
                'text', char(join(string(objects(j).String), ' ')), ...
                'position', getpixelposition(objects(j), true)); %#ok<AGROW>
        end
        manifest.frame_12_wizard_inputs = entries;
        fprintf('CAPTURE=12_wizard_inputs\n');
        button = findall(fig, 'Tag', 'InputCancelButton');
        button.Callback(button, []);
    end

    function capture(name)
        drawnow;
        exportapp(app.Figure, fullfile(outputDirectory, [name '.png']));
        entries = struct('type', {}, 'tag', {}, 'text', {}, 'position', {});
        objects = findall(app.Figure);
        for k = 1:numel(objects)
            object = objects(k);
            if ~isprop(object, 'Position'), continue; end
            try
                p = getpixelposition(object, true);
                entry = struct('type', class(object), 'tag', '', 'text', '', 'position', p);
                if isprop(object, 'Tag'), entry.tag = char(object.Tag); end
                if isprop(object, 'Text'), entry.text = char(join(string(object.Text), ' ')); end
                if isprop(object, 'Title'), entry.text = char(object.Title); end
                entries(end + 1) = entry; %#ok<AGROW>
            catch
                continue
            end
        end
        manifest.(['frame_' name]) = entries;
        fprintf('CAPTURE=%s\n', name);
    end

    function captureProgress(~, ~)
        state = app.getOperationState;
        if ~state.busy || isempty(state.dialog), return; end
        stop(timerObject);
        capture('11_progress');
        app.stopOperation(false);
    end
end

function disposeTimer(object)
if isvalid(object), stop(object); delete(object); end
end
