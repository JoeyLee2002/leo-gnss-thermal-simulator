function frame = quaternionToBodyAxes(quaternion, convention)
%QUATERNIONTOBODYAXES Convert explicit ECI-to-body quaternions to DCMs.
%   QUATERNION is N-by-4 in scalar-first [w x y z] order.  The only
%   supported convention is 'ECI_TO_BODY_WXYZ' (passive direction cosine
%   matrix mapping ECI components into body components).  No interpolation
%   or normalization is performed; non-unit quaternions are rejected.
if nargin < 2 || isempty(convention), convention = 'ECI_TO_BODY_WXYZ'; end
if ~ischar(convention) && ~(isstring(convention) && isscalar(convention))
    error('leotherm:QuaternionConvention', 'Quaternion convention must be ECI_TO_BODY_WXYZ.');
end
if ~strcmpi(char(convention), 'ECI_TO_BODY_WXYZ')
    error('leotherm:QuaternionConvention', 'Unsupported quaternion convention: %s.', char(convention));
end
if ~isnumeric(quaternion) || ~isreal(quaternion) || size(quaternion,2) ~= 4 ...
        || any(~isfinite(quaternion), 'all')
    error('leotherm:Quaternion', 'Quaternion input must be a finite N-by-4 real matrix.');
end
n = size(quaternion,1);
norms = vecnorm(quaternion,2,2);
if any(abs(norms-1) > 1e-6)
    error('leotherm:Quaternion', 'Quaternion rows must be unit length; normalize explicitly before import.');
end
w = quaternion(:,1); x = quaternion(:,2); y = quaternion(:,3); z = quaternion(:,4);
% Passive ECI-to-body DCM (transpose of the active Hamilton rotation).
frame = zeros(n,3,3);
frame(:,1,1) = 1-2*(y.^2+z.^2); frame(:,1,2) = 2*(x.*y+w.*z); frame(:,1,3) = 2*(x.*z-w.*y);
frame(:,2,1) = 2*(x.*y-w.*z); frame(:,2,2) = 1-2*(x.^2+z.^2); frame(:,2,3) = 2*(y.*z+w.*x);
frame(:,3,1) = 2*(x.*z+w.*y); frame(:,3,2) = 2*(y.*z-w.*x); frame(:,3,3) = 1-2*(x.^2+y.^2);
end
