function tests = test_simulation_templates
tests = functiontests(localfunctions);
end

function testBuiltInTemplatesAreReadable(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
templates = leotherm.listSimulationTemplates(fullfile(root, 'templates'));
verifyGreaterThanOrEqual(testCase, numel(templates), 4);
verifyEqual(testCase, templates(1).id, 'first_simulation');
verifyTrue(testCase, all(cellfun(@isfile, {templates.path})));
end

function testFirstTemplateInstantiatesValidatedModels(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
path = fullfile(root, 'templates', '01_first_simulation.json');
configuration = leotherm.applySimulationTemplate(path);
verifyEqual(testCase, configuration.scenario.durationS, 7200);
verifyEqual(testCase, configuration.scenario.timeStepS, 60);
verifyFalse(testCase, configuration.scenario.convergence.enabled);
verifyEqual(testCase, configuration.network.name, 'reference_11_node_gnss_receiver');
end

function testNestedTemplateOverridePreservesRequiredFields(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = leotherm.readSimulationTemplate(fullfile(root, 'templates', '02_thermal_lag.json'));
configuration = leotherm.applySimulationTemplate(template);
verifyTrue(testCase, configuration.scenario.convergence.enabled);
verifyEqual(testCase, configuration.scenario.convergence.maximumCycles, 80);
verifyEqual(testCase, configuration.scenario.durationS, 86400);
end

function testUnknownPresetIsRejected(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = leotherm.readSimulationTemplate(fullfile(root, 'templates', '01_first_simulation.json'));
template.networkPreset = 'guess_a_network';
verifyError(testCase, @() leotherm.applySimulationTemplate(template), ...
    'leotherm:InvalidSimulationTemplate');
end

function testMisspelledScenarioFieldIsRejected(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = leotherm.readSimulationTemplate(fullfile(root, 'templates', '01_first_simulation.json'));
template.scenario.orbit.altituteM = 500000;
verifyError(testCase, @() leotherm.applySimulationTemplate(template), ...
    'leotherm:InvalidSimulationTemplate');
end

function testUnsupportedModeAndVersionAreRejected(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = leotherm.readSimulationTemplate(fullfile(root, 'templates', '01_first_simulation.json'));
template.mode = 'calibration';
verifyError(testCase, @() leotherm.applySimulationTemplate(template), ...
    'leotherm:InvalidSimulationTemplate');
template.mode = 'scenario';
template.templateVersion = '2.0.0';
verifyError(testCase, @() leotherm.applySimulationTemplate(template), ...
    'leotherm:UnsupportedSimulationTemplate');
end

function testRequiredInputMustMatchSupportedWorkflow(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
template = leotherm.readSimulationTemplate(fullfile(root, 'templates', '04_telemetry_validation.json'));
template.requiredInputs(1).kind = 'unknown_file';
verifyError(testCase, @() leotherm.applySimulationTemplate(template), ...
    'leotherm:InvalidSimulationTemplate');
end
