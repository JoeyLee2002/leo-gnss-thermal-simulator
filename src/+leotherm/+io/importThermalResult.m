function [result, report] = importThermalResult(filePath, varargin)
%IMPORTTHERMALRESULT Import a traceable leotherm.thermal_result.v1 result.
%   MAT and JSON are supported. Input bytes are fingerprinted exactly as
%   supplied. The importer never sorts, interpolates, fills, shifts time, or
%   performs implicit unit conversion.
opts = parseOptions(varargin{:});
filePath = char(filePath);
if ~isfile(filePath), error('leotherm:ThermalResultIOFile','Thermal-result file does not exist: %s',filePath); end
[~,~,ext] = fileparts(filePath); ext = lower(ext);
rawBytes = readBytes(filePath);
switch ext
    case '.json'
        txt = native2unicode(rawBytes,'UTF-8');
         try
             result = jsondecode(txt);
         catch err
             error('leotherm:ThermalResultIOJson','Invalid JSON: %s',err.message);
         end
    case '.mat'
        loaded = load(filePath);
        result = extractMatResult(loaded);
    otherwise
        error('leotherm:ThermalResultIOFormat','Only .mat and .json are supported.');
end
validation = leotherm.io.validateThermalResult(result);
fingerprint = sha256(rawBytes);
if isfield(result,'provenance') && isstruct(result.provenance) && isfield(result.provenance,'inputFingerprint') && ~isempty(result.provenance.inputFingerprint)
    declared = char(result.provenance.inputFingerprint);
    if ~strcmpi(declared,fingerprint), error('leotherm:ThermalResultIOFingerprint','Input fingerprint mismatch: declared %s, computed %s.',declared,fingerprint); end
end
if isfield(result,'modelFingerprint') && ~isempty(result.modelFingerprint) && ~isText(result.modelFingerprint)
    error('leotherm:ThermalResultIOField','modelFingerprint must be text.');
end
report = validation;
report.path = filePath; report.format = ext(2:end); report.inputFingerprint = fingerprint;
report.schema = result.schema; report.importValidationPassed = validation.validationPassed;
report.validationStatus = ternary(validation.validationPassed,'passed','needs_review');
if opts.RequireFingerprint && ~(isfield(result,'provenance') && isstruct(result.provenance) && isfield(result.provenance,'inputFingerprint'))
    error('leotherm:ThermalResultIOFingerprint','A provenance.inputFingerprint is required by this import option.');
end
end

function result = extractMatResult(loaded)
if isfield(loaded,'thermalResult'), result=loaded.thermalResult;
elseif isfield(loaded,'result'), result=loaded.result;
else
    names=fieldnames(loaded);
    if numel(names)~=1, error('leotherm:ThermalResultIOMat','MAT input must contain thermalResult (or one unambiguous variable).'); end
    result=loaded.(names{1});
end
end
function bytes=readBytes(path)
fid=fopen(path,'rb'); if fid<0, error('leotherm:ThermalResultIOFile','Cannot open %s.',path); end
try
    bytes=fread(fid,Inf,'*uint8')';
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end
end
function digest=sha256(bytes)
md=java.security.MessageDigest.getInstance('SHA-256'); md.update(int8(bytes)); h=typecast(md.digest(),'uint8'); digest=lower(reshape(dec2hex(h,2)',1,[]));
end
function opts=parseOptions(varargin)
opts.RequireFingerprint=false;
if mod(numel(varargin),2)~=0, error('leotherm:ThermalResultIOOptions','Options must be name-value pairs.'); end
for k=1:2:numel(varargin)
    switch lower(char(varargin{k})), case 'requirefingerprint', opts.RequireFingerprint=logical(varargin{k+1}); otherwise, error('leotherm:ThermalResultIOOptions','Unknown option: %s.',char(varargin{k})); end
end
end
function ok=isText(v), ok=ischar(v)||(isstring(v)&&isscalar(v)); end
function value=ternary(test,a,b), if test, value=a; else, value=b; end, end
