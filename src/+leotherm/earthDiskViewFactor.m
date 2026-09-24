function factor = earthDiskViewFactor(cosineToEarth, radiusM, order)
%EARTHDISKVIEWFACTOR Uniform spherical Earth irradiance divided by exitance.
% Integrates positive panel incidence over the apparent Earth disk. No terrain,
% self-shadowing, spatial IR variability, or albedo illumination is included.
if nargin < 3, order = 48; end
validateattributes(cosineToEarth,{'numeric'},{'real','finite','2d','>=',-1,'<=',1});
c = leotherm.constants;
validateattributes(radiusM,{'numeric'},{'real','finite','column','>',c.radiusEarth});
validateattributes(order,{'numeric'},{'scalar','integer','>=',8,'<=',256});
if size(cosineToEarth,1) ~= numel(radiusM)
    error('leotherm:EarthViewInput','One geocentric radius is required per epoch.');
end
persistent cachedOrder abscissa weights
if isempty(cachedOrder) || cachedOrder ~= order
    k = (1:order-1)'; off = k./sqrt(4*k.^2-1);
    [v,d] = eig(diag(off,1)+diag(off,-1));
    [abscissa,ix] = sort(diag(d)); weights = 2*v(1,ix)'.^2;
    cachedOrder = order;
end
edge = sqrt(1-(c.radiusEarth./radiusM).^2);
mu = cosineToEarth;
transverse = sqrt(max(0,1-mu.^2));
factor = zeros(size(mu));
for k = 1:order
    u = edge+(1-edge)*(abscissa(k)+1)/2;
    a = mu.*u; b = transverse.*sqrt(max(0,1-u.^2));
    integral = 2*pi*max(a,0);
    partial = abs(a)<b;
    z = -a(partial)./b(partial);
    integral(partial) = 2*(a(partial).*acos(z)+b(partial).*sqrt(max(0,1-z.^2)));
    factor = factor + integral.*((1-edge)*weights(k)/(2*pi));
end
factor = min(1,max(0,factor));
end
