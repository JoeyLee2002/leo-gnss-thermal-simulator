function network = symmetricReceiverNetwork
%SYMMETRICRECEIVERNETWORK Strict symmetry control for signed-beta studies.
% The six exterior faces are identical and all GNSS receiver nodes are coupled
% through the spacecraft structure without a preferred exterior direction.

network = leotherm.defaultReceiverNetwork;
network.name = 'symmetric_11_node_gnss_receiver';

network.capacityJK(1:6) = 7000;
network.projectedAreaM2(1:6) = 1.0;
network.radiatingAreaM2(1:6) = 1.0;
network.solarAbsorptivity(1:6) = 0.50;
network.irEmissivity(1:6) = 0.80;
for face = 1:6
    network.conductanceWK(face, 7) = 1.40;
    network.conductanceWK(7, face) = 1.40;
end

% Remove directional antenna exposure and its preferred zenith attachment.
network.projectedAreaM2(8) = 0;
network.radiatingAreaM2(8) = 0;
network.normalBody(8, :) = 0;
network.solarAbsorptivity(8) = 0;
network.irEmissivity(8) = 0;
network.conductanceWK(6, 8) = 0;
network.conductanceWK(8, 6) = 0;
network.conductanceWK(7, 8) = 1.35;
network.conductanceWK(8, 7) = 1.35;

leotherm.validateNetwork(network);
end

