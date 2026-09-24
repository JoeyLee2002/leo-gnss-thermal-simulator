function fingerprint = simulationTaskFingerprint(value)
copy = value;
if isstruct(copy) && isfield(copy, 'inputFingerprint')
    copy.inputFingerprint = '';
end
bytes = getByteStreamFromArray(copy);
digest = java.security.MessageDigest.getInstance('SHA-256');
digestBytes = digest.digest(bytes);
digestBytes = typecast(int8(digestBytes), 'uint8');
fingerprint = lower(reshape(dec2hex(digestBytes, 2).', 1, []));
end
