function output = englishArtifactFilename(input, fallback)
%ENGLISHARTIFACTFILENAME Keep generated basenames ASCII without guessing text.
input=char(string(input)); fallback=char(string(fallback));
if isempty(input) || ~isempty(regexp(input,'[\\/]','once'))
    error('leotherm:ArtifactFilename','A single nonempty filename is required.');
end
if all(double(input)>=32 & double(input)<=126)
    output=input;
    return
end
[~,base,extension]=fileparts(input);
[~,defaultBase,defaultExtension]=fileparts(fallback);
base=regexprep(base,'[^A-Za-z0-9_-]+','_');
base=regexprep(base,'^_+|_+$','');
if isempty(base), base=defaultBase; end
if isempty(extension) || any(double(extension)>126), extension=defaultExtension; end
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(input,'UTF-8'));
bytes=typecast(digest.digest(),'uint8');
hash=lower(reshape(dec2hex(bytes,2)',1,[]));
output=[base(1:min(64,numel(base))) '_' hash(1:12) extension];
if isempty(output) || any(double(output)>126)
    error('leotherm:ArtifactFilename','Fallback filename must contain only ASCII characters.');
end
end
