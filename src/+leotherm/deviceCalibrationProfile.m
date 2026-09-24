function p = deviceCalibrationProfile(network)
%DEVICECALIBRATIONPROFILE Create a locked, unverified device parameter profile.
% Unlocking a row requires explicit bounds, prior uncertainty, evidence, and
% a physical/effective kind. Evidence records a claim, not its verification.

leotherm.validateNetwork(network);
p.schemaVersion = 1;
p.name = network.name;
p.nodeNames = network.nodeNames;
p.referenceNetwork = network;

vectorFields = ["capacityJK", "internalPowerW", "projectedAreaM2", ...
    "radiatingAreaM2", "solarAbsorptivity", "irEmissivity"];
vectorUnits = ["J/K", "W", "m^2", "m^2", "1", "1"];
names = string(network.nodeNames(:));
n = numel(names);
[left, right] = find(triu(network.conductanceWK > 0, 1));
count = numel(vectorFields) * n + numel(left);
field = strings(count, 1);
node = strings(count, 1);
peer = strings(count, 1);
unit = strings(count, 1);
nominal = zeros(count, 1);
for k = 1:numel(vectorFields)
    rows = (k - 1) * n + (1:n);
    field(rows) = vectorFields(k);
    node(rows) = names;
    unit(rows) = vectorUnits(k);
    values = network.(char(vectorFields(k)));
    nominal(rows) = double(values(:));
end
rows = numel(vectorFields) * n + (1:numel(left));
field(rows) = "conductanceWK";
node(rows) = names(left);
peer(rows) = names(right);
unit(rows) = "W/K";
nominal(rows) = double(network.conductanceWK( ...
    sub2ind([n, n], left, right)));
lower = nominal;
upper = nominal;
priorSigma = zeros(count, 1);
estimate = false(count, 1);
evidence = strings(count, 1);
kind = repmat("unverified", count, 1);
p.parameters = table(field, node, peer, unit, nominal, lower, upper, ...
    priorSigma, estimate, evidence, kind);
end
