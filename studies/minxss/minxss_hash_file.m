function hex = minxss_hash_file(path)
%MINXSS_HASH_FILE Streaming source-file identity without loading it into RAM.
fid=fopen(path,'rb'); assert(fid>=0,'Cannot read source file.');
cleanup=onCleanup(@()fclose(fid));
digest=java.security.MessageDigest.getInstance('SHA-256');
while true
    block=fread(fid,1024*1024,'*uint8');
    if isempty(block),break;end
    digest.update(typecast(block,'int8'));
end
bytes=typecast(digest.digest(),'uint8');
hex=upper(reshape(dec2hex(bytes,2).',1,[]));
end
