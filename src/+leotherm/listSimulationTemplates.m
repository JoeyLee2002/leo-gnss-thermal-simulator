function templates = listSimulationTemplates(directory)
%LISTSIMULATIONTEMPLATES List valid JSON task templates in display order.
if nargin < 1 || isempty(directory), directory = fullfile(pwd, 'templates'); end
files = dir(fullfile(directory, '*.json'));
templates = struct('path', {}, 'id', {}, 'nameZh', {}, 'nameEn', {}, ...
    'descriptionZh', {}, 'descriptionEn', {});
for k = 1:numel(files)
    path = fullfile(files(k).folder, files(k).name);
    try
        value = leotherm.readSimulationTemplate(path);
    catch exception
        warning('leotherm:InvalidSimulationTemplate', ...
            'Ignoring invalid template %s: %s', path, exception.message);
        continue
    end
    entry = struct('path', path, 'id', char(value.id), ...
        'nameZh', char(value.nameZh), 'nameEn', char(value.nameEn), ...
        'descriptionZh', char(value.descriptionZh), ...
        'descriptionEn', char(value.descriptionEn));
    templates(end + 1) = entry; %#ok<AGROW>
end
[~, order] = sort({templates.id});
templates = templates(order);
end
