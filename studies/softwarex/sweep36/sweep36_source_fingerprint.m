function fingerprint = sweep36_source_fingerprint
%SWEEP36_SOURCE_FINGERPRINT Detect any change to the engine used by caches.
[~,root]=sweep36_paths;
files=dir(fullfile(root,'src','**','*.m'));
relative=cell(numel(files),1); hashes=relative;
for k=1:numel(files)
    path=fullfile(files(k).folder,files(k).name);
    relative{k}=strrep(path(numel(root)+2:end),filesep,'/');
    hashes{k}=sweep36_file_sha256(path);
end
[relative,order]=sort(relative);
value=struct('paths',{relative},'hashes',{hashes(order)});
bytes=unicode2native(jsonencode(value),'UTF-8');
digest=java.security.MessageDigest.getInstance('SHA-256');
bytes=typecast(int8(digest.digest(bytes)),'uint8');
fingerprint=lower(reshape(dec2hex(bytes,2).',1,[]));
end
