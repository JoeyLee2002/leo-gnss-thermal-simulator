function path = writeWorkspaceProject(path,state,overwrite)
%WRITEWORKSPACEPROJECT Save a portable workspace with an embedded CSV snapshot.
if nargin<3, overwrite=false; end
path = char(java.io.File(char(path)).getCanonicalPath());
if isfolder(path) || (isfile(path) && ~overwrite)
    error('leotherm:ProjectExists','The project already exists. Use Save or choose another name.');
end
folder = fileparts(path);
if ~isfolder(folder), error('leotherm:ProjectPath','Select an existing writable folder.'); end
state = embedSource(state);
project = struct('schemaVersion',1,'softwareVersion',leotherm.version, ...
    'savedUTC',datetime('now','TimeZone','UTC'),'state',state);
temporary = [tempname(folder) '.mat'];
cleanup = onCleanup(@()removeTemporary(temporary));
save(temporary,'project','-v7.3');
leotherm.readWorkspaceProject(temporary);
if isfile(path)
    [ok,message] = copyfile(path,[path '.previous'],'f');
    if ~ok, error('leotherm:ProjectWrite','Cannot preserve previous project: %s',message); end
end
[ok,message] = movefile(temporary,path,'f');
if ~ok, error('leotherm:ProjectWrite','Cannot install saved project: %s',message); end
clear cleanup
end

function state = embedSource(state)
source = state.telemetry.source;
if isempty(source) || istable(source), return; end
info = dir(char(source));
raw = leotherm.readTelemetryTable(source);
after = dir(char(source));
if isempty(info) || isempty(after) || info.bytes~=after.bytes || info.datenum~=after.datenum
    error('leotherm:ProjectSourceChanged','Telemetry changed while saving. Import it again before saving.');
end
stamp = struct('bytes',info.bytes,'datenum',info.datenum);
state.telemetry.source = raw;
state.telemetry.sourceLabel = char(source);
% A changed source must not inherit the old comparison fingerprint.
if ~isempty(state.telemetry.data) && ~isequaln(state.telemetry.data.rawTable,raw)
    state.telemetry.resultStale = true;
    return
end
if isfield(state.telemetry,'resultInputs') && ~isempty(state.telemetry.resultInputs)
    state.telemetry.resultInputs = replaceSource(state.telemetry.resultInputs,source,raw,stamp);
end
cal = state.calibration;
if ~isempty(cal.splitInput), cal.splitInput = replaceSource(cal.splitInput,source,raw,stamp); end
if ~isempty(cal.resultInputs)
    cal.resultInputs.source = replaceSource(cal.resultInputs.source,source,raw,stamp);
end
state.calibration = cal;
end

function value = replaceSource(value,old,raw,stamp)
if isfield(value,'source') && isequaln(value.source,old) ...
        && isfield(value,'fileStamp') && isequaln(value.fileStamp,stamp)
    value.source = raw; value.fileStamp = [];
end
end

function removeTemporary(path)
if isfile(path), delete(path); end
end
