function result = runExternalThermalSolver(config)
%RUNEXTERNALTHERMALSOLVER Run a controlled external thermal-solver command.
%   The command is executed without a shell. Input and output directories are
%   explicit, output directories must be new or empty, and all artifacts are
%   hashed for later reporting. This is an execution adapter, not a vendor
%   file-format parser.

config = validateConfig(config);
started = datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX');
tokens = [{config.executable}, config.arguments(:)'];
javaTokens = javaArray('java.lang.String', numel(tokens));
for k = 1:numel(tokens)
    javaTokens(k) = java.lang.String(tokens{k});
end
builder = javaObject('java.lang.ProcessBuilder', javaTokens);
builder.directory(java.io.File(config.workingDirectory));
stdoutPath = fullfile(config.outputDirectory, 'external_stdout.txt');
stderrPath = fullfile(config.outputDirectory, 'external_stderr.txt');
builder.redirectOutput(java.io.File(stdoutPath));
builder.redirectError(java.io.File(stderrPath));
environment = builder.environment();
environment.put('LEOTHERM_INPUT_DIRECTORY', config.inputDirectory);
environment.put('LEOTHERM_OUTPUT_DIRECTORY', config.outputDirectory);
if ~isempty(config.environment)
    names = fieldnames(config.environment);
    for k = 1:numel(names)
        environment.put(names{k}, textValue(config.environment.(names{k}), names{k}));
    end
end
timer = tic;
process = builder.start();
timedOut = ~process.waitFor(config.timeoutS, java.util.concurrent.TimeUnit.SECONDS);
if timedOut
    process.destroyForcibly();
    process.waitFor(5, java.util.concurrent.TimeUnit.SECONDS);
end
stdout = readTextFile(stdoutPath);
stderr = readTextFile(stderrPath);
exitCode = -1;
if ~timedOut
    exitCode = process.exitValue();
end
durationS = toc(timer);
outputArtifacts = collectArtifacts(config.outputDirectory);
inputArtifacts = collectArtifacts(config.inputDirectory);
expected = cell(0, 1);
missing = cell(0, 1);
for k = 1:numel(config.expectedOutputs)
    relative = config.expectedOutputs{k};
    target = safeChild(config.outputDirectory, relative);
    expected{end + 1, 1} = relative; %#ok<AGROW>
    if ~isfile(target)
        missing{end + 1, 1} = relative; %#ok<AGROW>
    end
end
result = struct;
result.schema = 'leotherm.external_solver_run.v1';
result.adapterId = config.adapterId;
result.softwareVersion = config.softwareVersion;
result.startedUTC = char(started);
result.durationS = durationS;
result.exitCode = exitCode;
result.timedOut = timedOut;
result.success = ~timedOut && exitCode == 0 && isempty(missing);
result.stdout = stdout;
result.stderr = stderr;
result.expectedOutputs = expected;
result.missingOutputs = missing;
result.inputArtifacts = inputArtifacts;
result.outputArtifacts = outputArtifacts;
result.provenance = struct('workingDirectory', config.workingDirectory, ...
    'inputDirectory', config.inputDirectory, 'outputDirectory', config.outputDirectory, ...
    'command', {tokens}, 'noShellExecution', true, ...
    'physicalValidation', 'not_established');
result.status = 'succeeded';
result.failureIsReturnedForReporting = true;
if timedOut
    result.status = 'timed_out';
elseif exitCode ~= 0 || ~isempty(missing)
    result.status = 'failed';
end
end

function config = validateConfig(config)
if ~isstruct(config) || ~isscalar(config)
    error('leotherm:ExternalSolverConfig', 'Configuration must be a scalar structure.');
end
required = {'executable','outputDirectory'};
for k = 1:numel(required)
    if ~isfield(config, required{k})
        error('leotherm:ExternalSolverConfig', 'Missing field: %s.', required{k});
    end
end
config.executable = textValue(config.executable, 'executable');
if containsAny(config.executable)
    error('leotherm:ExternalSolverConfig', 'Executable must not contain shell metacharacters.');
end
if ~isfield(config, 'arguments') || isempty(config.arguments)
    config.arguments = {};
elseif isstring(config.arguments)
    config.arguments = cellstr(config.arguments(:));
elseif ischar(config.arguments)
    config.arguments = {config.arguments};
end
if ~iscell(config.arguments) || ~all(cellfun(@isText, config.arguments))
    error('leotherm:ExternalSolverConfig', 'arguments must be a cell array of text.');
end
config.arguments = cellfun(@(x) textValue(x, 'argument'), config.arguments, 'UniformOutput', false);
for k = 1:numel(config.arguments)
    if containsAny(config.arguments{k})
        error('leotherm:ExternalSolverConfig', 'Arguments must not contain shell metacharacters.');
    end
end
config.outputDirectory = absoluteDirectory(config.outputDirectory, 'outputDirectory');
if isfolder(config.outputDirectory)
    listing = dir(config.outputDirectory);
    if any(~ismember({listing.name}, {'.','..'}))
        error('leotherm:ExternalSolverConfig', 'outputDirectory must be new or empty.');
    end
else
    [ok, message] = mkdir(config.outputDirectory);
    if ~ok, error('leotherm:ExternalSolverConfig', 'Cannot create outputDirectory: %s', message); end
end
if ~isfield(config, 'inputDirectory') || isempty(config.inputDirectory)
    config.inputDirectory = config.workingDirectory;
else
    config.inputDirectory = absoluteDirectory(config.inputDirectory, 'inputDirectory');
end
if ~isfolder(config.inputDirectory)
    error('leotherm:ExternalSolverConfig', 'inputDirectory does not exist.');
end
if ~isfield(config, 'workingDirectory') || isempty(config.workingDirectory)
    config.workingDirectory = config.inputDirectory;
else
    config.workingDirectory = absoluteDirectory(config.workingDirectory, 'workingDirectory');
end
if ~isfolder(config.workingDirectory)
    error('leotherm:ExternalSolverConfig', 'workingDirectory does not exist.');
end
if ~isfield(config, 'timeoutS') || isempty(config.timeoutS), config.timeoutS = 3600; end
if ~isnumeric(config.timeoutS) || ~isscalar(config.timeoutS) || ~isfinite(config.timeoutS) || config.timeoutS <= 0
    error('leotherm:ExternalSolverConfig', 'timeoutS must be a positive finite scalar.');
end
if ~isfield(config, 'expectedOutputs') || isempty(config.expectedOutputs)
    config.expectedOutputs = {};
elseif ischar(config.expectedOutputs) || (isstring(config.expectedOutputs) && isscalar(config.expectedOutputs))
    config.expectedOutputs = {char(config.expectedOutputs)};
elseif isstring(config.expectedOutputs)
    config.expectedOutputs = cellstr(config.expectedOutputs(:));
end
if ~iscell(config.expectedOutputs) || ~all(cellfun(@isText, config.expectedOutputs))
    error('leotherm:ExternalSolverConfig', 'expectedOutputs must be text values.');
end
for k = 1:numel(config.expectedOutputs)
    safeChild(config.outputDirectory, config.expectedOutputs{k});
end
if ~isfield(config, 'adapterId') || isempty(config.adapterId), config.adapterId = 'external_command'; end
if ~isfield(config, 'softwareVersion'), config.softwareVersion = 'unspecified'; end
config.adapterId = textValue(config.adapterId, 'adapterId');
config.softwareVersion = textValue(config.softwareVersion, 'softwareVersion');
if ~isfield(config, 'environment') || isempty(config.environment), config.environment = struct; end
if ~isstruct(config.environment) || ~isscalar(config.environment)
    error('leotherm:ExternalSolverConfig', 'environment must be a scalar structure.');
end
end

function path = absoluteDirectory(value, name)
value = textValue(value, name);
file = java.io.File(value);
if ~file.isAbsolute(), file = java.io.File(fullfile(pwd, value)); end
path = char(file.getCanonicalPath());
end

function path = safeChild(root, relative)
relative = textValue(relative, 'relative path');
if containsAny(relative) || startsWith(relative, '\\') || startsWith(relative, '/') || ...
        ~isempty(regexp(relative, '^[A-Za-z]:', 'once'))
    error('leotherm:ExternalSolverConfig', 'Artifact path must be relative and shell-free.');
end
candidate = java.io.File(fullfile(root, relative));
canonicalRoot = char(java.io.File(root).getCanonicalPath());
canonicalCandidate = char(candidate.getCanonicalPath());
prefix = [canonicalRoot filesep];
if ~startsWith(canonicalCandidate, prefix, 'IgnoreCase', ispc)
    error('leotherm:ExternalSolverConfig', 'Artifact path escapes its declared directory.');
end
path = canonicalCandidate;
end

function artifacts = collectArtifacts(root)
files = dir(fullfile(root, '**', '*'));
files = files(~[files.isdir]);
artifacts = repmat(struct('path','', 'bytes',0, 'sha256',''), numel(files), 1);
prefix = [char(java.io.File(root).getCanonicalPath()) filesep];
for k = 1:numel(files)
    absolute = fullfile(files(k).folder, files(k).name);
    artifacts(k).path = char(absolute(numel(prefix) + 1:end));
    artifacts(k).bytes = files(k).bytes;
    artifacts(k).sha256 = fileHash(absolute);
end
end

function value = fileHash(path)
fid = fopen(path, 'rb');
if fid < 0, error('leotherm:ExternalSolverIO', 'Cannot read artifact: %s.', path); end
cleanup = onCleanup(@() fclose(fid));
md = java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes = fread(fid, 1024 * 1024, '*uint8');
    if ~isempty(bytes), md.update(typecast(bytes, 'int8')); end
end
value = lower(reshape(dec2hex(typecast(md.digest(), 'uint8'), 2)', 1, []));
end

function text = readTextFile(path)
if ~isfile(path)
    text = '';
    return
end
bytes = fileread(path);
text = char(bytes);
end

function tf = containsAny(value)
tf = ~isempty(regexp(value, '[\r\n&|<>;$`]', 'once'));
end

function tf = isText(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end

function value = textValue(value, name)
if isstring(value) && isscalar(value), value = char(value); end
if ~ischar(value) || ~isrow(value) || isempty(strtrim(value))
    error('leotherm:ExternalSolverConfig', '%s must be non-empty text.', name);
end
value = char(value);
end
