function network = defaultReceiverNetwork
%DEFAULTRECEIVERNETWORK Reference spacecraft/GNSS receiver thermal network.
% The parameters are physically plausible hypotheses and are not calibrated to
% a specific mission.

network.name = 'reference_11_node_gnss_receiver';
network.nodeNames = { ...
    'face_+X_forward', 'face_-X_aft', ...
    'face_+Y_orbit_left', 'face_-Y_orbit_right', ...
    'face_+Z_nadir', 'face_-Z_zenith', ...
    'spacecraft_structure', 'gnss_antenna', 'gnss_rf_frontend', ...
    'gnss_oscillator', 'receiver_digital'};

network.capacityJK = [6200, 6200, 7000, 7000, 8500, 8000, ...
    26000, 3200, 1800, 320, 5200]';
network.initialTemperatureK = 293.15 * ones(11, 1);
network.internalPowerW = [0, 0, 0, 0, 0, 0, 2.0, 0.4, 5.0, 0.8, 12.0]';

% Exposed projected areas and body-frame normals. Internal nodes have zero area.
network.projectedAreaM2 = [0.90, 0.90, 1.20, 1.20, 1.08, 0.96, ...
    0.0, 0.10, 0.0, 0.0, 0.0]';
network.radiatingAreaM2 = [0.90, 0.90, 1.20, 1.20, 1.08, 0.88, ...
    0.0, 0.10, 0.0, 0.0, 0.0]';
network.normalBody = [ ...
     1,  0,  0; ...
    -1,  0,  0; ...
     0,  1,  0; ...
     0, -1,  0; ...
     0,  0,  1; ...
     0,  0, -1; ...
     0,  0,  0; ...
     0,  0, -1; ...
     0,  0,  0; ...
     0,  0,  0; ...
     0,  0,  0];

network.solarAbsorptivity = [0.43, 0.43, 0.62, 0.62, 0.38, 0.55, ...
    0.0, 0.70, 0.0, 0.0, 0.0]';
network.irEmissivity = [0.78, 0.78, 0.84, 0.84, 0.76, 0.82, ...
    0.0, 0.86, 0.0, 0.0, 0.0]';

network.conductanceWK = zeros(11);
for face = 1:6
    network.conductanceWK = connect(network.conductanceWK, face, 7, 1.40);
end
network.conductanceWK = connect(network.conductanceWK, 6, 8, 0.90);
network.conductanceWK = connect(network.conductanceWK, 7, 8, 0.45);
network.conductanceWK = connect(network.conductanceWK, 8, 9, 0.32);
network.conductanceWK = connect(network.conductanceWK, 7, 9, 0.62);
network.conductanceWK = connect(network.conductanceWK, 9, 10, 0.24);
network.conductanceWK = connect(network.conductanceWK, 7, 10, 0.10);
network.conductanceWK = connect(network.conductanceWK, 9, 11, 0.45);
network.conductanceWK = connect(network.conductanceWK, 10, 11, 0.38);
network.conductanceWK = connect(network.conductanceWK, 7, 11, 0.85);

network.bias.linearMPerK = zeros(11, 1);
network.bias.linearMPerK(8) = 0.025;
network.bias.linearMPerK(9) = 0.080;
network.bias.linearMPerK(10) = 0.120;
network.bias.linearMPerK(11) = 0.020;
network.bias.quadraticNode = 9;
network.bias.quadraticMPerK2 = 8e-4;
network.roles.response = 9;
network.roles.antenna = 8;
network.roles.oscillator = 10;

leotherm.validateNetwork(network);
end

function matrix = connect(matrix, left, right, value)
matrix(left, right) = value;
matrix(right, left) = value;
end
