function network = satmoStyleNetwork
%SATMOSTYLENETWORK Public seven-node box benchmark inspired by SATMO.
% This is not an exact reproduction of a SATMO validation spacecraft. It is a
% transparent six-face plus internal-node configuration for trend comparison.

network.name = 'satmo_style_7_node_box';
network.nodeNames = {'face_+X', 'face_-X', 'face_+Y', 'face_-Y', ...
    'face_+Z_nadir', 'face_-Z_zenith', 'internal'};
network.capacityJK = [80, 80, 80, 80, 80, 80, 500]';
network.initialTemperatureK = 293.15 * ones(7, 1);
network.internalPowerW = [0, 0, 0, 0, 0, 0, 2]';
network.projectedAreaM2 = [0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0]';
network.radiatingAreaM2 = network.projectedAreaM2;
network.normalBody = [1,0,0; -1,0,0; 0,1,0; 0,-1,0; 0,0,1; 0,0,-1; 0,0,0];
network.solarAbsorptivity = [0.60 * ones(6, 1); 0];
network.irEmissivity = [0.80 * ones(6, 1); 0];
network.conductanceWK = zeros(7);
for face = 1:6
    network.conductanceWK(face, 7) = 0.15;
    network.conductanceWK(7, face) = 0.15;
end
network.bias.linearMPerK = zeros(7, 1);
network.bias.quadraticNode = 7;
network.bias.quadraticMPerK2 = 0;
network.roles.response = 7;
network.roles.antenna = [];
network.roles.oscillator = [];
leotherm.validateNetwork(network);
end
