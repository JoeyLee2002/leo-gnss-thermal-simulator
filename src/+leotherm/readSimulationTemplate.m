function template = readSimulationTemplate(filePath)
%READSIMULATIONTEMPLATE Read and validate a human-editable task template.
if ~(ischar(filePath) || (isstring(filePath) && isscalar(filePath)))
    error('leotherm:InvalidSimulationTemplate', 'Template path must be text.');
end
filePath = char(filePath);
if ~isfile(filePath), error('leotherm:SimulationTemplateNotFound', ...
        'Template file does not exist: %s', filePath); end
[~,~,extension] = fileparts(filePath);
if ~strcmpi(extension, '.json')
    error('leotherm:InvalidSimulationTemplate', 'Templates must use JSON.');
end
try
    template = jsondecode(fileread(filePath));
catch exception
    error('leotherm:InvalidSimulationTemplate', ...
        'Cannot parse template JSON: %s', exception.message);
end
template.sourcePath = filePath;
template = leotherm.validateSimulationTemplate(template);
end
