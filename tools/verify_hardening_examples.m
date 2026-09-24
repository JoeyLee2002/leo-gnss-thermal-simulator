function evidence = verify_hardening_examples(directory)
%VERIFY_HARDENING_EXAMPLES Persist analytical witnesses for the v0.4.4 fixes.
assert(~isfolder(directory) && ~isfile(directory),'Use a new evidence directory.');
mkdir(directory);
root = fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
s = leotherm.defaultScenario; n = leotherm.defaultReceiverNetwork;
n.capacityJK(:) = 100; n.conductanceWK(:) = 0;
n.conductanceWK(1,2) = 100; n.conductanceWK(2,1) = 100;
n.internalPowerW(:) = 0; n.radiatingAreaM2(:) = 0;
n.initialTemperatureK(:) = 300; n.initialTemperatureK(2) = 310;
[temperature,numerics] = leotherm.solveThermalNetwork([0;1.3],zeros(2,11),n,s.environment,s.integration);
evidence.version = leotherm.version;
evidence.conductionExpectedK = 305-5*exp(-2*1.3);
evidence.conductionActualK = temperature(end,1);
evidence.conductionErrorK = abs(evidence.conductionActualK-evidence.conductionExpectedK);
evidence.numerics = numerics;
t = (0:300)';
evidence.constantPhase = leotherm.orbitalPeakLagMetrics(t,ones(size(t)),300*ones(size(t)),100);
evidence.leadingPhase = leotherm.orbitalPeakLagMetrics(t,cos(2*pi*t/100),cos(2*pi*(t+10)/100),100);
c = leotherm.constants; radius = c.radiusEarth+600e3; alpha = asin(c.radiusEarth/radius);
mu = [1 0 -1];
evidence.earthViewExpected = [sin(alpha)^2 (alpha-sin(alpha)*cos(alpha))/pi 0];
evidence.earthViewActual = leotherm.earthDiskViewFactor(mu,radius);
view = table(["nadir";"tangent";"zenith"],evidence.earthViewExpected',evidence.earthViewActual', ...
    'VariableNames',{'orientation','analytic_view_factor','calculated_view_factor'});
writetable(view,fullfile(directory,'earth_view_analytic.csv'));
save(fullfile(directory,'analytical_witnesses.mat'),'evidence','s','n');
assert(evidence.conductionErrorK<1e-4);
assert(~evidence.constantPhase.identifiable && ~evidence.leadingPhase.identifiable);
assert(max(abs(evidence.earthViewActual-evidence.earthViewExpected))<2e-6);
disp(evidence);
end
