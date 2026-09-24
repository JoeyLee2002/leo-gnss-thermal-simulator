function raw = readTelemetryTable(source)
%READTELEMETRYTABLE Read CSV text without guessing dates or physical units.
if istable(source)
    raw = source;
else
    if ~(ischar(source) || (isstring(source) && isscalar(source))) ...
            || ~isfile(source)
        error('leotherm:TelemetryFile', 'Select an existing telemetry CSV file.');
    end
    [~, ~, extension] = fileparts(source);
    if ~strcmpi(extension, '.csv')
        error('leotherm:TelemetryFile', 'Telemetry import accepts CSV files or MATLAB tables.');
    end
    opts = detectImportOptions(source, 'VariableNamingRule', 'preserve');
    opts = setvartype(opts, opts.VariableNames, 'string');
    raw = readtable(source, opts);
end
if height(raw) < 2
    error('leotherm:TelemetryFile', 'Telemetry must contain at least two data rows.');
end
end
