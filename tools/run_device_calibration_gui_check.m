function diagnostics = run_device_calibration_gui_check(outputDirectory)
%RUN_DEVICE_CALIBRATION_GUI_CHECK Fit through the public GUI API and audit state.
% Call only after other MATLAB GUI checks finish. The output parent must not
% exist; the calibration core creates its own fit child without overwriting.

root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(outputDirectory)
    outputDirectory = fullfile(root, 'results', ...
        ['device_calibration_gui_check_' datestr(now, 'yyyymmdd_HHMMSS')]);
end
outputDirectory = char(outputDirectory);
assert(~isfile(outputDirectory) && ~isfolder(outputDirectory), ...
    'Use a nonexistent output directory; previous checks are never overwritten.');
addpath(root);
startup;
[ok, message] = mkdir(outputDirectory);
assert(ok, 'Cannot create the check directory: %s', message);
diagnostics = struct('version', leotherm.version, 'outcome', 'incomplete', ...
    'outputDirectory', outputDirectory, 'fitDirectory', fullfile(outputDirectory, 'fit'));

try
    f = leotherm.deviceCalibrationDemo(3);
    % Orbital GUI metrics need a declared response; thermal parameters stay fixed.
    f.network.roles = struct('response',1,'antenna',[],'oscillator',[]);
    f.profile.referenceNetwork = f.network;
    app = leotherm.ThermalSimulatorApp('on', 'zh');
    cleanup = onCleanup(@() delete(app));
    scenario = f.scenario;
    scenario.durationS = 600;
    scenario.timeStepS = 10;
    scenario.warmupOrbits = 0;
    scenario.convergence.enabled = false;
    app.runScenario(scenario, f.network);
    app.TelemetryWorkspace.importSource(f.raw);
    app.TelemetryWorkspace.run(f.settings.telemetryOptions);
    telemetryBefore = app.TelemetryWorkspace.getState;
    assert(isequaln(telemetryBefore.options, f.settings.telemetryOptions), ...
        'The telemetry workspace did not retain the demo driving options.');

    result = app.CalibrationWorkspace.run(f.profile, f.split, f.settings, diagnostics.fitDirectory);
    assert(isfield(result,'coverage') && ~result.coverageSufficient, ...
        'The short synthetic arcs must trigger the new default coverage review.');
    assert(any(result.warningCodes == "insufficient_dynamic_coverage"), ...
        'A short-arc coverage review flag is missing.');
    diagnostics.coverageRows = height(result.coverage);
    diagnostics.coverageSufficient = result.coverageSufficient;
    state = app.getState;
    assert(isequaln(state.network, f.network), 'Calibration automatically applied a fitted network.');
    assert(isequaln(state.calibration.profile, f.profile), 'Calibration replaced the editable original profile.');
    assert(isequaln(result.profileAfter.parameters, f.profile.parameters), ...
        'The fitted profile rebased nominal values or altered declared priors.');
    assert(isequal(result.withinDeclaredCriteria, true), ...
        'The synthetic demonstration did not meet its declared numerical criterion.');
    assert(~result.passed && ~strcmp(result.status, 'accepted_within_declared_scope'), ...
        'Synthetic agreement must not be accepted as independently validated hardware.');
    assert(any(string(result.warningCodes) == "synthetic_not_flight_validation"), ...
        'The fitted demonstration needs an explicit synthetic-data warning.');
    assert(~state.calibration.resultStale && ~state.calibration.profileStale, ...
        'A newly completed fit was immediately marked stale.');
    frozen = state.calibration;
    projectPath = fullfile(outputDirectory, 'fitted_workspace.mat');
    app.saveProject(projectPath);
    restored = leotherm.ThermalSimulatorApp('off', 'en');
    restoreCleanup = onCleanup(@() delete(restored));
    restored.loadProject(projectPath);
    restoredState = restored.getState;
    assert(isequaln(restoredState.calibration.result, frozen.result), ...
        'Project roundtrip changed the fitted calibration result.');
    assert(~restoredState.calibration.resultStale && ~restored.hasUnsavedChanges, ...
        'Restoring an unchanged fitted project made it stale or dirty.');
    diagnostics.fittedProjectRestored = true;
    clear restoreCleanup
    diagnostics.withinDeclaredCriteria = result.withinDeclaredCriteria;
    diagnostics.calibrationPassed = result.passed;
    diagnostics.calibrationStatus = result.status;
    diagnostics.noAutomaticApply = true;
    diagnostics.parameterRows = height(result.parameterReport);
    diagnostics.stageRows = height(result.stageMetrics);
    required = {'calibration_result.mat', 'original_device.mat', 'calibrated_device.mat', ...
        'parameter_changes.csv', 'stage_metrics.csv', 'report_zh.md', 'report_en.md','coverage.csv'};
    for k = 1:numel(required)
        assert(isfile(fullfile(diagnostics.fitDirectory, required{k})), ...
            'Missing calibration artifact: %s', required{k});
    end
    saved = load(fullfile(diagnostics.fitDirectory, 'calibration_result.mat'), 'result');
    assert(isequaln(saved.result, result), 'The saved result differs from the public run result.');

    % Keep the editable profile and settings visible; do not substitute the
    % parameter-report tab or stale-input state in these inspection images.
    sizes = [1380 860; 1120 780];
    languages = {'zh', 'en'};
    screenshots = cell(4, 1);
    screenshotBytes = zeros(4, 1);
    layoutParts = cell(4, 1);
    imageSize = zeros(4, 2);
    imageDynamicRange = zeros(4, 1);
    index = 0;
    for langIndex = 1:numel(languages)
        language = languages{langIndex};
        app.setLanguage(language);
        verifyFrozenState(app, frozen, f.network, language);
        for sizeIndex = 1:size(sizes, 1)
            index = index + 1;
            viewport = sizes(sizeIndex, :);
            app.Figure.Position = [80 60 viewport];
            selectCalibrationTables(app);
            drawnow;
            pause(0.5);
            drawnow;
            verifyFrozenState(app, frozen, f.network, language);
            screenshots{index} = fullfile(outputDirectory, ...
                sprintf('calibration_%s_%dx%d.png', language, viewport(1), viewport(2)));
            exportapp(app.Figure, screenshots{index});
            coverageTable = findall(app.Figure,'Tag','CalibrationCoverageTable');
            assert(size(coverageTable.Data,1) == height(result.coverage), ...
                'The coverage table is missing day/node rows.');
            verifyEqualCoverage(coverageTable,result.coverage);
            coverageTab = coverageTable.Parent.Parent;
            previousTab = coverageTab.Parent.SelectedTab;
            coverageTab.Parent.SelectedTab = coverageTab;
            coverageInput = findall(app.Figure,'Tag','MinimumCoverage');
            settingsTab = coverageInput.Parent.Parent;
            oldSettingsTab = settingsTab.Parent.SelectedTab;
            settingsTab.Parent.SelectedTab = settingsTab;
            drawnow;
            assert(contained(getpixelposition(coverageInput,true),getpixelposition(coverageInput.Parent,true)), ...
                'The coverage settings are clipped.');
            exportapp(app.Figure,fullfile(outputDirectory, ...
                sprintf('coverage_%s_%dx%d.png',language,viewport(1),viewport(2))));
            coverageTab.Parent.SelectedTab = previousTab;
            settingsTab.Parent.SelectedTab = oldSettingsTab;
            drawnow;
            info = dir(screenshots{index});
            screenshotBytes(index) = info.bytes;
            pixels = imread(screenshots{index});
            imageSize(index, :) = [size(pixels, 2), size(pixels, 1)];
            imageDynamicRange(index) = double(max(pixels(:))) - double(min(pixels(:)));
            assert(info.bytes > 10000 && imageDynamicRange(index) > 20, ...
                'The calibration screenshot is unexpectedly small or blank.');
            layoutParts{index} = auditLayout(app, language, viewport);
        end
    end
    diagnostics.screenshots = screenshots;
    diagnostics.screenshotBytes = screenshotBytes;
    diagnostics.imageSize = imageSize;
    diagnostics.imageDynamicRange = imageDynamicRange;
    diagnostics.layout = vertcat(layoutParts{:});
    diagnostics.layoutScope = 'Visible calibration control bounds only; inspect screenshots for text and scrolling.';
    writetable(diagnostics.layout, fullfile(outputDirectory, 'control_bounds.csv'));
    assert(all(diagnostics.layout.inside_figure & diagnostics.layout.inside_parents), ...
        'A calibration control is clipped; inspect control_bounds.csv and screenshots.');
    app.setLanguage('zh');
    verifyFrozenState(app, frozen, f.network, 'zh');
    diagnostics.languageStatePreserved = true;

    changedSource = f.raw;
    changedSource.temperature_k_device(1) = changedSource.temperature_k_device(1) + 0.01;
    app.TelemetryWorkspace.importSource(changedSource);
    staleSource = app.CalibrationWorkspace.getState;
    assert(staleSource.resultStale && staleSource.splitStale && ~staleSource.profileStale, ...
        'Changing telemetry must stale the frozen result and day assignments, not the device profile.');
    assert(isequaln(staleSource.result, result) && isequaln(staleSource.profile, f.profile), ...
        'A source edit changed the frozen result or original profile.');
    verifyStaleLabel(app, 'zh');
    diagnostics.sourceChangeFlagged = true;

    % Restore the captured inputs so model invalidation is tested independently
    % of source invalidation, without fitting again or rewriting old artifacts.
    app.TelemetryWorkspace.restoreState(telemetryBefore);
    app.CalibrationWorkspace.restoreState(frozen);
    verifyFrozenState(app, frozen, f.network, 'zh');
    changedNetwork = f.network;
    changedNetwork.capacityJK(1) = 1.01 * changedNetwork.capacityJK(1);
    app.runScenario(scenario, changedNetwork);
    staleModel = app.getState;
    assert(staleModel.calibration.profileStale && staleModel.calibration.resultStale, ...
        'A network capacity change must invalidate the exact profile reference and frozen result.');
    assert(isequaln(staleModel.network, changedNetwork), 'The explicit device edit was replaced by calibration.');
    assert(isequaln(staleModel.calibration.profile, frozen.profile) ...
        && isequaln(staleModel.calibration.result, result), ...
        'A device edit changed the historical priors or fitted result.');
    verifyStaleLabel(app, 'zh');
    app.setLanguage('en');
    staleEnglish = app.CalibrationWorkspace.getState;
    assert(staleEnglish.profileStale && staleEnglish.resultStale, ...
        'Language switching cleared a scientific invalidation flag.');
    verifyStaleLabel(app, 'en');
    diagnostics.modelChangeFlagged = true;
    diagnostics.staleStatePreserved = true;
    savedAfter = load(fullfile(diagnostics.fitDirectory, 'calibration_result.mat'), 'result');
    assert(isequaln(saved.result, savedAfter.result), 'Input changes modified the saved calibration result.');
    diagnostics.frozenArtifactPreserved = true;
    diagnostics.outcome = 'complete';
    save(fullfile(outputDirectory, 'device_calibration_gui_check.mat'), 'diagnostics');
    writeStatus(fullfile(outputDirectory, 'device_calibration_gui_check_status.txt'), diagnostics);
    clear cleanup
catch exception
    diagnostics.outcome = 'failed';
    diagnostics.failureIdentifier = exception.identifier;
    diagnostics.failure = getReport(exception, 'extended', 'hyperlinks', 'off');
    save(fullfile(outputDirectory, 'device_calibration_gui_check_failure.mat'), 'diagnostics');
    rethrow(exception);
end
end

function verifyEqualCoverage(control,expected)
for k = 4:8
    assert(isequaln(cell2mat(control.Data(:,k)),expected{:,k}), ...
        'The displayed coverage values differ from the frozen result.');
end
end

function verifyFrozenState(app, before, network, language)
state = app.getState;
after = state.calibration;
assert(isequaln(state.network, network), 'Display changes applied a different thermal network.');
assert(isequaln(after.result, before.result) && isequaln(after.profile, before.profile) ...
    && isequaln(after.split, before.split) && isequaln(after.settings, before.settings), ...
    'Language or viewport changes altered calibration state.');
assert(~after.resultStale && ~after.profileStale && ~after.splitStale, ...
    'Display changes incorrectly invalidated the fitted inputs.');
profile = tagged(app, 'CalibrationProfileTable');
report = tagged(app, 'CalibrationParameterReport');
stage = tagged(app, 'CalibrationStageTable');
assert(~any(profile.ColumnEditable(1:5)) && all(profile.ColumnEditable(6:11)), ...
    'The profile must retain read-only nominal values and editable declarations.');
assert(~any(report.ColumnEditable) && ~any(stage.ColumnEditable), 'Frozen report tables must be read-only.');
assert(size(report.Data, 1) == height(after.result.parameterReport) ...
    && size(stage.Data, 1) == height(after.result.stageMetrics), 'A fitted report table is missing rows.');
for column = {'used_samples','baseline_rmse_k','calibrated_rmse_k'}
    at = find(strcmp(after.result.stageMetrics.Properties.VariableNames, column{1}), 1);
    assert(isequaln(cell2mat(stage.Data(:, at)), after.result.stageMetrics.(column{1})), ...
        'The displayed stage values differ from the frozen report.');
end
assert(strcmp(profile.Data{1,1}, char(leotherm.deviceCalibrationText(after.profile.parameters.field(1), language))), ...
    'Parameter names were not localized.');
assert(strcmp(stage.Data{1,1}, char(leotherm.deviceCalibrationText(after.result.stageMetrics.role(1), language))), ...
    'Stage roles were not localized.');
if strcmp(language, 'zh')
    days = tagged(app, 'CalibrationDayTable');
    headings = [string(days.ColumnName(:)); string(stage.ColumnName(:))];
    assert(~any(contains(headings, 'UTC') | contains(headings, 'RMSE')), ...
        'Chinese date and error headers must not retain English abbreviations.');
else
    assert(profile.ColumnWidth{5} >= 160, 'The English nominal header needs enough display width.');
end
sensor = tagged(app, 'CalibrationSensorSigma');
evidence = tagged(app, 'CalibrationSensorEvidence');
useTolerance = tagged(app, 'CalibrationUseTolerance');
tolerance = tagged(app, 'CalibrationTolerance');
assert(sensor.Value == before.settings.temperatureSigmaK ...
    && strcmp(evidence.Value, before.settings.sensorEvidence), 'Fitted sensor settings are not displayed.');
assert(useTolerance.Value == before.toleranceEnabled ...
    && strcmp(tolerance.Value, before.toleranceDraft), 'The declared RMSE limit was not preserved.');
status = tagged(app, 'CalibrationStatus');
assert(contains(string(status.Text), leotherm.deviceCalibrationText(before.result.status, language)), ...
    'The frozen outcome is not displayed in the selected language.');
end

function selectCalibrationTables(app)
app.CalibrationWorkspace.Tab.Parent.SelectedTab = app.CalibrationWorkspace.Tab;
for tag = {'CalibrationProfileTable', 'CalibrationStageTable'}
    control = tagged(app, tag{1});
    tab = control.Parent;
    while ~isa(tab, 'matlab.ui.container.Tab'), tab = tab.Parent; end
    tab.Parent.SelectedTab = tab;
end
end

function audit = auditLayout(app, language, viewport)
controls = findall(app.CalibrationWorkspace.Tab, '-property', 'Enable');
records = struct('language', {}, 'viewport_width', {}, 'viewport_height', {}, ...
    'control', {}, 'x', {}, 'y', {}, 'width', {}, 'height', {}, ...
    'inside_figure', {}, 'inside_parents', {});
figurePosition = getpixelposition(app.Figure);
figureBounds = [1 1 figurePosition(3:4)];
for k = 1:numel(controls)
    h = controls(k);
    if ~isprop(h, 'Position') || ~displayed(h, app.Figure), continue; end
    position = getpixelposition(h, true);
    withinParents = true;
    parent = h.Parent;
    while ~isequal(parent, app.Figure)
        if isprop(parent, 'Position')
            withinParents = withinParents && contained(position, getpixelposition(parent, true));
        end
        parent = parent.Parent;
    end
    label = string(h.Tag);
    if strlength(label) == 0 && isprop(h, 'Text'), label = join(string(h.Text), ' '); end
    if strlength(label) == 0, label = string(class(h)); end
    records(end+1) = struct('language', string(language), ...
        'viewport_width', viewport(1), 'viewport_height', viewport(2), ...
        'control', label, 'x', position(1), 'y', position(2), ...
        'width', position(3), 'height', position(4), ...
        'inside_figure', contained(position, figureBounds), ...
        'inside_parents', withinParents); %#ok<AGROW>
end
audit = struct2table(records);
assert(height(audit) >= 10, 'The visible calibration controls were not available for geometry checks.');
assert(all(ismember(["CalibrationProfileTable","CalibrationDayTable","CalibrationStageTable", ...
    "CalibrationSensorSigma","CalibrationSensorEvidence"], audit.control)), ...
    'The profile, tables or sensor settings are hidden in the calibration screenshot.');
end

function yes = displayed(h, figureHandle)
yes = true;
while ~isequal(h, figureHandle)
    if isprop(h, 'Visible') && strcmp(h.Visible, 'off'), yes = false; return; end
    if isa(h, 'matlab.ui.container.Tab') && ~isequal(h.Parent.SelectedTab, h)
        yes = false; return
    end
    h = h.Parent;
end
end

function yes = contained(child, parent)
slack = 2;
yes = all(isfinite(child)) && all(child(3:4) > 0) ...
    && all(child(1:2) >= parent(1:2) - slack) ...
    && all(child(1:2) + child(3:4) <= parent(1:2) + parent(3:4) + slack);
end

function h = tagged(app, tag)
h = findall(app.CalibrationWorkspace.Tab, 'Tag', tag);
assert(isscalar(h), 'Missing or duplicate calibration control: %s', tag);
end

function verifyStaleLabel(app, language)
status = tagged(app, 'CalibrationStatus');
expected = 'Inputs changed';
if strcmp(language, 'zh'), expected = char([36755 20837 24050 21464 21270]); end
assert(contains(string(status.Text), expected), 'A stale result is not visibly identified as belonging to old inputs.');
end

function writeStatus(path, diagnostics)
file = fopen(path, 'w');
assert(file >= 0, 'Cannot write the GUI check status.');
cleanup = onCleanup(@() fclose(file));
fprintf(file, 'outcome=%s\n', diagnostics.outcome);
fprintf(file, 'version=%s\n', diagnostics.version);
fprintf(file, 'calibration_status=%s\n', diagnostics.calibrationStatus);
fprintf(file, 'within_declared_criteria=%d\n', diagnostics.withinDeclaredCriteria);
fprintf(file, 'calibration_passed=%d\n', diagnostics.calibrationPassed);
fprintf(file, 'no_automatic_apply=%d\n', diagnostics.noAutomaticApply);
fprintf(file, 'language_state_preserved=%d\n', diagnostics.languageStatePreserved);
fprintf(file, 'source_change_flagged=%d\n', diagnostics.sourceChangeFlagged);
fprintf(file, 'model_change_flagged=%d\n', diagnostics.modelChangeFlagged);
fprintf(file, 'stale_state_preserved=%d\n', diagnostics.staleStatePreserved);
fprintf(file, 'frozen_artifact_preserved=%d\n', diagnostics.frozenArtifactPreserved);
fprintf(file, 'screenshots=%d\n', numel(diagnostics.screenshots));
fprintf(file, 'control_bounds_passed=%d\n', all(diagnostics.layout.inside_figure & diagnostics.layout.inside_parents));
fprintf(file, 'layout_scope=%s\n', diagnostics.layoutScope);
clear cleanup
end
