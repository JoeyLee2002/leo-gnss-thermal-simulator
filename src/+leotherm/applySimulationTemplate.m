function configuration = applySimulationTemplate(template, baseScenario, baseNetwork)
%APPLYSIMULATIONTEMPLATE Instantiate a validated template configuration.
if nargin < 2 || isempty(baseScenario), baseScenario = leotherm.defaultScenario; end
if nargin < 3 || isempty(baseNetwork), baseNetwork = leotherm.defaultReceiverNetwork; end
if ischar(template) || (isstring(template) && isscalar(template))
    template = leotherm.readSimulationTemplate(template);
end
template = leotherm.validateSimulationTemplate(template);
scenario = mergeStruct(baseScenario, template.scenario);
network = resolveNetworkPreset(template.networkPreset, baseNetwork);
leotherm.validateScenario(scenario);
leotherm.validateNetwork(network);
configuration = struct('template', template, 'scenario', scenario, ...
    'network', network, 'mode', char(template.mode), ...
    'requiredInputs', template.requiredInputs, ...
    'sourcePath', fieldOr(template, 'sourcePath', ''));
end

function output = mergeStruct(base, override)
output = base;
names = fieldnames(override);
for k = 1:numel(names)
    name = names{k}; value = override.(name);
    if isstruct(value) && isscalar(value) && isfield(output, name) ...
            && isstruct(output.(name)) && isscalar(output.(name))
        output.(name) = mergeStruct(output.(name), value);
    else
        output.(name) = value;
    end
end
end

function network = resolveNetworkPreset(name, fallback)
switch lower(char(name))
    case {'default','reference'}
        network = leotherm.defaultReceiverNetwork;
    case {'satmo','satmo_style'}
        network = leotherm.satmoStyleNetwork;
    case {'symmetric','symmetric_receiver'}
        network = leotherm.symmetricReceiverNetwork;
    case {'current'}
        network = fallback;
    otherwise
        error('leotherm:InvalidSimulationTemplate', ...
            'Unknown network preset: %s', char(name));
end
end

function value = fieldOr(source, name, fallback)
if isfield(source, name) && ~isempty(source.(name)), value = source.(name); else, value = fallback; end
end
