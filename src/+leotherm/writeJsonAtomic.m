function writeJsonAtomic(file, value)
%WRITEJSONATOMIC Publish complete UTF-8 JSON without truncating the old record.
validateattributes(file, {'char','string'}, {'nonempty'});
file = char(java.io.File(char(file)).getCanonicalPath());
folder = fileparts(file);
if ~isfolder(folder) || isfolder(file)
    error('leotherm:AtomicJsonPath', 'JSON destination must be a file in an existing folder.');
end
try
    bytes = unicode2native(jsonencode(value, 'PrettyPrint', true), 'UTF-8');
catch exception
    error('leotherm:AtomicJsonEncode', 'Cannot encode JSON: %s', exception.message);
end
temporary = [tempname(folder) '.json.tmp'];
cleanup = onCleanup(@() removeTemporary(temporary));
fid = fopen(temporary, 'wb');
if fid < 0
    error('leotherm:AtomicJsonWrite', 'Cannot create temporary JSON file.');
end
fileCleanup = onCleanup(@() closeFile(fid));
written = fwrite(fid, bytes, 'uint8');
closeStatus = fclose(fid);
clear fileCleanup
if written ~= numel(bytes) || closeStatus ~= 0
    error('leotherm:AtomicJsonWrite', 'Cannot finish temporary JSON file.');
end
% Same-directory atomic rename is required; never fall back to copy/delete.
options = javaArray('java.nio.file.CopyOption', 2);
options(1) = java.nio.file.StandardCopyOption.ATOMIC_MOVE;
options(2) = java.nio.file.StandardCopyOption.REPLACE_EXISTING;
source = java.io.File(temporary).toPath();
destination = java.io.File(file).toPath();
for attempt = 1:25
    try
        java.nio.file.Files.move(source, destination, options);
        clear cleanup
        return
    catch exception
        if attempt == 25
            error('leotherm:AtomicJsonReplace', ...
                'Cannot atomically replace JSON; previous record retained: %s', exception.message);
        end
        pause(0.02);
    end
end
end

function closeFile(fid)
if any(fopen('all') == fid), fclose(fid); end
end

function removeTemporary(file)
if isfile(file), delete(file); end
end
