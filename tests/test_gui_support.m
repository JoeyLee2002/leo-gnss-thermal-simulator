function tests = test_gui_support
tests = functiontests(localfunctions);
end

function testWorkbenchInitializesActionableTaskState(testCase)
if ~usejava('jvm')
    return
end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
status = findobj(app.Figure, 'Tag', 'TaskStatusLabel');
guidance = findobj(app.Figure, 'Tag', 'TaskSummaryLabel');
verifyEqual(testCase, numel(status), 1);
verifyEqual(testCase, numel(guidance), 1);
verifyEqual(testCase, status.Text, '可运行');
verifyThat(testCase, string(guidance.Text), ...
    matlab.unittest.constraints.ContainsSubstring('场景：'));
end

function testQuickStartIsTheDefaultEntryPoint(testCase)
if ~usejava('jvm')
    return
end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
quickStart = findobj(app.Figure, 'Type', 'uitab', 'Title', '快速开始');
simulation = findobj(app.Figure, 'Type', 'uitab', 'Title', '仿真');
results = findobj(app.Figure, 'Type', 'uitab', 'Title', '结果与导出');
verifyEqual(testCase, numel(quickStart), 1);
verifyEqual(testCase, numel(simulation), 1);
verifyEqual(testCase, numel(results), 1);
verifyEqual(testCase, quickStart.Parent.SelectedTab, quickStart);
verifyEqual(testCase, findobj(app.Figure, 'Tag', 'QuickStartTemplate').Value, 'first');
verifyNotEmpty(testCase, findobj(app.Figure, 'Tag', 'QuickStartRunButton'));
verifyNotEmpty(testCase, findobj(app.Figure, 'Tag', 'QuickStartWizardButton'));
verifyNotEmpty(testCase, findobj(app.Figure, 'Tag', 'QuickStartOpenButton'));
verifyNotEmpty(testCase, findobj(app.Figure, 'Tag', 'QuickStartAdvancedButton'));
end

function testResultsPageStartsWithPlainLanguageConclusion(testCase)
if ~usejava('jvm')
    return
end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
conclusion = findobj(app.Figure, 'Tag', 'ResultConclusionLabel');
verifyEqual(testCase, numel(conclusion), 1);
verifyThat(testCase, string(conclusion.Text), ...
    matlab.unittest.constraints.ContainsSubstring('还没有结果'));
reportButton = findobj(app.Figure, 'Tag', 'GenerateReportButton');
verifyEqual(testCase, numel(reportButton), 1);
verifyEqual(testCase, reportButton.Text, '生成分析报告 PDF');
verifyEmpty(testCase, findobj(app.Figure, 'Tag', 'ResultActions'));
end

function testGeometryWorkspaceExposesCoupledRun(testCase)
if ~usejava('jvm')
    return
end
app = leotherm.ThermalSimulatorApp('off', 'zh');
cleanup = onCleanup(@() delete(app));
button = findobj(app.Figure, 'Tag', 'CoupledRunButton');
verifyEqual(testCase, numel(button), 1);
verifyEqual(testCase, button.Text, '运行表面—体耦合');
state = app.getState;
verifyTrue(testCase, isfield(state, 'surfaceVolumeResult'));
end

function testNumericListParsesValuesAndRanges(testCase)
values = leotherm.parseNumericList('400, 600 800:100:1000', 'altitude');
verifyEqual(testCase, values, [400, 600, 800, 900, 1000]);
end

function testNumericListParsesDescendingRange(testCase)
values = leotherm.parseNumericList('60:-30:-60', 'beta');
verifyEqual(testCase, values, [60, 30, 0, -30, -60]);
end

function testNumericListRejectsZeroStep(testCase)
verifyError(testCase, ...
    @() leotherm.parseNumericList('0:0:10', 'test'), ...
    'leotherm:InvalidList');
end

function testNumericListDoesNotEvaluateCode(testCase)
verifyError(testCase, ...
    @() leotherm.parseNumericList('system(''dir'')', 'test'), ...
    'leotherm:InvalidList');
end

function testDateListParsesUtcDates(testCase)
dates = leotherm.parseDateList('2024-03-20, 2024-06-21', 'dates');
verifyEqual(testCase, numel(dates), 2);
verifyEqual(testCase, dates.TimeZone, 'UTC');
verifyEqual(testCase, dates(1), ...
    datetime(2024, 3, 20, 'TimeZone', 'UTC'));
end

function testDateListRejectsInvalidFormat(testCase)
verifyError(testCase, ...
    @() leotherm.parseDateList('20/03/2024', 'dates'), ...
    'leotherm:InvalidDateList');
end
