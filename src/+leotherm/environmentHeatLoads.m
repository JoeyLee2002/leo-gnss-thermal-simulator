function loads = environmentHeatLoads(orbit, frame, network, environment)
%ENVIRONMENTHEATLOADS Compute node-resolved external radiative heat inputs.

c = leotherm.constants;
nEpoch = numel(orbit.elapsedS);
nNode = numel(network.nodeNames);
visible = leotherm.conicalShadowFraction(orbit.positionM, orbit.sunPositionM);
toSun = orbit.sunPositionM - orbit.positionM;
sunDistanceAU = vecnorm(toSun, 2, 2) / c.astronomicalUnit;
sunECI = toSun ./ vecnorm(toSun, 2, 2);
earthECI = -orbit.positionM ./ vecnorm(orbit.positionM, 2, 2);
radialECI = -earthECI;

sunBody = eciDirectionToBody(sunECI, frame);
earthBody = eciDirectionToBody(earthECI, frame);
sunIncidence = max(sunBody * network.normalBody', 0);
earthIncidence = max(earthBody * network.normalBody', 0);
earthIRModel = 'legacy_cosine';
if isfield(environment,'earthIRModel'), earthIRModel = char(environment.earthIRModel); end
if ~ismember(earthIRModel,{'legacy_cosine','finite_disk'})
    error('leotherm:EarthViewInput','Unknown Earth infrared model.');
end

solarFlux = environment.solarConstantWm2 ./ sunDistanceAU.^2;
radius = vecnorm(orbit.positionM, 2, 2);
earthView = min((c.radiusEarth ./ radius).^2, 1);
irView = earthView.*earthIncidence;
if strcmp(earthIRModel,'finite_disk') && environment.includeEarthIR
    mu = min(1,max(-1,earthBody*network.normalBody'));
    irView = leotherm.earthDiskViewFactor(mu,radius);
    irView(:,vecnorm(network.normalBody,2,2) == 0) = 0;
end
dayside = max(sum(radialECI .* sunECI, 2), 0);

area = network.projectedAreaM2(:)';
alpha = network.solarAbsorptivity(:)';
epsilon = network.irEmissivity(:)';

direct = zeros(nEpoch, nNode);
albedo = zeros(nEpoch, nNode);
earthIR = zeros(nEpoch, nNode);
if environment.includeDirectSolar
    direct = (visible .* solarFlux) .* sunIncidence .* (area .* alpha);
end
if environment.includeAlbedo
    albedoIrradiance = solarFlux .* environment.albedo .* earthView .* dayside;
    albedo = albedoIrradiance .* earthIncidence .* (area .* alpha);
end
if environment.includeEarthIR
    earthIR = environment.earthIRWm2 .* irView .* (area .* epsilon);
end

loads.visibleFraction = visible;
loads.directSolarW = direct;
loads.albedoW = albedo;
loads.earthIRW = earthIR;
loads.totalExternalW = direct + albedo + earthIR;
loads.sunIncidence = sunIncidence;
loads.earthIncidence = earthIncidence;
loads.earthViewFactor = earthView;
loads.daysideFactor = dayside;
loads.earthIRViewFactor = irView;
loads.earthIRModel = earthIRModel;
loads.albedoModel = 'legacy_dayside_cosine';
end

function body = eciDirectionToBody(direction, frame)
nEpoch = size(direction, 1);
body = zeros(nEpoch, 3);
for k = 1:nEpoch
    dcm = squeeze(frame(k, :, :));
    body(k, :) = (dcm * direction(k, :)')';
end
end
