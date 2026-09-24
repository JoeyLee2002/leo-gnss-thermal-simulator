function value = version
%VERSION Return the installed LEO GNSS Thermal Simulator version.

persistent cachedValue
if ~isempty(cachedValue)
    value = cachedValue;
    return
end
path = fullfile(leotherm.installRoot, 'VERSION');
lastException = [];
for attempt = 1:3
    try
        candidate = strtrim(fileread(path));
        if isempty(candidate)
            error('leotherm:VersionRead', 'VERSION is empty.');
        end
        cachedValue = candidate;
        value = cachedValue;
        return
    catch exception
        lastException = exception;
        pause(0.02 * attempt);
    end
end
error('leotherm:VersionRead', 'Cannot read VERSION after three attempts: %s', ...
    lastException.message);
end
