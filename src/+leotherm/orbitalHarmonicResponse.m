function out = orbitalHarmonicResponse(timeS, forcing, response, periodS)
%ORBITALHARMONICRESPONSE Signed orbital-frequency phase, without peak pairing.
% Simultaneous least squares separates offset, trend and three harmonics.
% This describes the two histories, not an identified single-input plant.
t=timeS(:); x=forcing(:); y=response(:);
validateattributes(t,{'numeric'},{'real','finite','increasing','nonempty'});
validateattributes(periodS,{'numeric'},{'real','finite','scalar','positive'});
if numel(t)~=numel(x) || numel(t)~=numel(y) || any(~isfinite(x)) || any(~isfinite(y)) || ~isreal(x) || ~isreal(y)
    error('leotherm:InvalidPhaseInput','Phase histories must be finite real arrays with matching epochs.');
end
out=struct('available',false,'status','duration_below_three_orbits','phaseDelayS',NaN, ...
    'phaseShiftRad',NaN,'forcingAmplitudeW',NaN,'responseAmplitudeK',NaN, ...
    'forcingFundamental',[],'responseFundamental',[],'timeS',t, ...
    'forcingFitRmseW',NaN,'responseFitRmseK',NaN,'halfWindowDifferenceS',NaN, ...
    'definition','signed_orbital_fundamental_phase_delay_within_half_period');
if numel(t)<48 || t(end)-t(1)<3*periodS, return; end
dt=diff(t);
if max(dt)>periodS/16 || max(dt)>2.5*median(dt)
    out.status='sampling_gap_or_low_resolution'; return
end
t=t-t(1); X=basis(t,periodS);
weights=[dt(1)/2;(dt(1:end-1)+dt(2:end))/2;dt(end)/2];
A=X.*sqrt(weights); z=A\([x,y].*sqrt(weights));
cx=complex(z(3,1),-z(4,1)); cy=complex(z(3,2),-z(4,2));
out.forcingAmplitudeW=abs(cx); out.responseAmplitudeK=abs(cy);
if abs(cx)<=max(1e-8,1e-6*max(abs(x))) || abs(cy)<=max(1e-8,1e-6*max(abs(y)))
    out.status='orbital_component_below_resolution'; return
end
out.phaseShiftRad=angle(cy/cx);
out.phaseDelayS=-out.phaseShiftRad*periodS/(2*pi);
out.forcingFundamental=X(:,3:4)*z(3:4,1);
out.responseFundamental=X(:,3:4)*z(3:4,2);
e=[x,y]-X*z;
rmse=sqrt(sum(weights.*e.^2,1)/sum(weights));
out.forcingFitRmseW=rmse(1); out.responseFitRmseK=rmse(2);
ph=zeros(2,1);
for k=1:2
    if k==1, at=t<=t(end)/2; else, at=t>=t(end)/2; end
    B=X(at,:).*sqrt(weights(at));
    zz=B\([x(at),y(at)].*sqrt(weights(at)));
    ph(k)=angle(complex(zz(3,2),-zz(4,2))/complex(zz(3,1),-zz(4,1)));
end
out.halfWindowDifferenceS=abs(angle(exp(1i*(ph(2)-ph(1)))))*periodS/(2*pi);
out.available=true; out.status='computed';
end

function X=basis(t,p)
w=2*pi/p;
X=[ones(size(t)),(t-mean(t))/(t(end)-t(1)), ...
    cos(w*t),sin(w*t),cos(2*w*t),sin(2*w*t),cos(3*w*t),sin(3*w*t)];
end
