function hash = sweep36_file_sha256(filename)
%SWEEP36_FILE_SHA256 Hash exact file bytes for evidence integrity.
fid=fopen(filename,'rb');
assert(fid>=0,'sweep36:MissingFile','Cannot open %s.',filename);
cleanup=onCleanup(@() fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid)
    bytes=fread(fid,1024*1024,'*uint8');
    digest.update(bytes);
end
bytes=typecast(int8(digest.digest()),'uint8');
hash=lower(reshape(dec2hex(bytes,2).',1,[]));
end
