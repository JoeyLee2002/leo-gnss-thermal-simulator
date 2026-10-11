function [scenario,network] = sweep36_case(p,h,b,g,n)
scenario = p.scenario;
scenario.orbit.altitudeM = h*1000;
[raan,accessible] = leotherm.solveRaanForBeta(scenario.startEpoch,scenario.orbit.inclinationDeg,b,1);
assert(accessible,'Requested beta cannot be reached');
scenario.orbit.raanDeg = raan;
c = leotherm.constants;
period = 2*pi*sqrt((c.radiusEarth+h*1000)^3/c.muEarth);
scenario.durationS = p.analysisOrbits*period;
scenario.timeStepS = period/n;
scenario.name = sprintf('paper36_h%d_b%d_g%.2f',h,b,g);
network = p.network;
assert(strcmp(network.nodeNames{7},'structure') || contains(network.nodeNames{7},'structure'));
assert(network.roles.response==9);
network.conductanceWK(7,9) = g;
network.conductanceWK(9,7) = g;
end
