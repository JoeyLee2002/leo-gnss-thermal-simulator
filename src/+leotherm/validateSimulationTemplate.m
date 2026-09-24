function template = validateSimulationTemplate(template)
%VALIDATESIMULATIONTEMPLATE Check a JSON template or an in-memory copy.
if ~isstruct(template) || ~isscalar(template)
    invalid('Template root must be one JSON object.');
end
required = {'schema','templateVersion','engineApi','id','nameZh','nameEn', ...
    'descriptionZh','descriptionEn','mode','networkPreset','scenario'};
optional = {'requiredInputs','editableFields','sourcePath'};
for k = 1:numel(required)
    name = required{k};
    if ~isfield(template, name) || isempty(template.(name))
        invalid('Template requires field %s.', name);
    end
end
rejectUnknown(template, [required optional], 'template');
textFields = required(1:end-1);
for k = 1:numel(textFields)
    name = textFields{k};
    if ~isText(template.(name)) || isempty(strtrim(char(template.(name))))
        invalid('%s must be nonempty text.', name);
    end
end
if ~strcmp(char(template.schema), 'leotherm.simulation_template.v1')
    error('leotherm:UnsupportedSimulationTemplate', 'Unsupported template schema.');
end
if isempty(regexp(char(template.templateVersion), '^1\.[0-9]+\.[0-9]+$', 'once')) ...
        || ~strcmp(char(template.engineApi), '1')
    error('leotherm:UnsupportedSimulationTemplate', ...
        'Template requires schema version 1.x and engine API 1.');
end
if ~ismember(char(template.mode), {'scenario','telemetry'})
    invalid('mode must be scenario or telemetry.');
end
if ~ismember(char(template.networkPreset), ...
        {'default','satmo','symmetric','current'})
    invalid('Unknown networkPreset: %s.', char(template.networkPreset));
end
if ~isstruct(template.scenario) || ~isscalar(template.scenario)
    invalid('scenario must be one JSON object.');
end
checkScenarioFields(template.scenario, leotherm.defaultScenario, 'scenario');
if ~isfield(template, 'requiredInputs'), template.requiredInputs = struct([]); end
inputs = template.requiredInputs;
if ~isempty(inputs)
    if ~isstruct(inputs)
        invalid('requiredInputs must be an array of input objects.');
    end
    for k = 1:numel(inputs)
        rejectUnknown(inputs(k), {'kind','labelZh','labelEn','required'}, ...
            sprintf('requiredInputs(%d)', k));
        fields = {'kind','labelZh','labelEn','required'};
        for j = 1:numel(fields)
            if ~isfield(inputs(k), fields{j})
                invalid('requiredInputs(%d).%s is required.', k, fields{j});
            end
        end
        if ~isText(inputs(k).kind) || ~strcmp(char(inputs(k).kind), 'telemetry_csv') ...
                || ~isText(inputs(k).labelZh) || ~isText(inputs(k).labelEn) ...
                || ~islogical(inputs(k).required) || ~isscalar(inputs(k).required) ...
                || ~inputs(k).required || ~strcmp(char(template.mode), 'telemetry')
            invalid('requiredInputs(%d) must be a required telemetry_csv in telemetry mode.', k);
        end
    end
end
if ~isfield(template, 'editableFields')
    template.editableFields = {'name','durationHours','timeStepS'};
end
if ~iscellstr(template.editableFields) ...
        || ~all(ismember(template.editableFields, {'name','durationHours','timeStepS'}))
    invalid('editableFields must list supported wizard fields.');
end
if isfield(template, 'sourcePath') && ~isText(template.sourcePath)
    invalid('sourcePath must be text.');
end
end

function checkScenarioFields(override, reference, path)
if ~isstruct(override) || ~isscalar(override)
    invalid('%s must be one object.', path);
end
names = fieldnames(override);
for k = 1:numel(names)
    name = names{k};
    if ~isfield(reference, name)
        invalid('Unknown field %s.%s. Check the spelling.', path, name);
    end
    if isstruct(reference.(name))
        checkScenarioFields(override.(name), reference.(name), [path '.' name]);
    end
end
end

function rejectUnknown(value, allowed, path)
names = fieldnames(value);
for k = 1:numel(names)
    if ~ismember(names{k}, allowed)
        invalid('Unknown field %s.%s. Check the spelling.', path, names{k});
    end
end
end

function result = isText(value)
result = ischar(value) && isrow(value) ...
    || isstring(value) && isscalar(value) && ~ismissing(value);
end

function invalid(message, varargin)
error('leotherm:InvalidSimulationTemplate', message, varargin{:});
end
