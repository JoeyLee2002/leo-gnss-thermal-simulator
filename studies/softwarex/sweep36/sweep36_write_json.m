function sweep36_write_json(filename,value)
%SWEEP36_WRITE_JSON Write structured generated metadata as UTF-8.
fid=fopen(filename,'w','n','UTF-8');
assert(fid>=0,'sweep36:WriteFailed','Cannot write %s.',filename);
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
