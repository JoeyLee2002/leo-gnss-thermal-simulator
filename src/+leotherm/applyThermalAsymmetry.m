function network = applyThermalAsymmetry(baseNetwork, mode, level)
%APPLYTHERMALASYMMETRY Apply one controlled symmetry-breaking mechanism.
% level is a normalized contrast in [0, 1]. Modes are surface_optical,
% structural_coupling, receiver_mount, and combined.

assert(isscalar(level) && isfinite(level) && level >= 0 && level <= 1, ...
    'level must be a finite scalar in [0, 1].');
network = baseNetwork;
mode = lower(mode);
switch mode
    case 'none'
        network.name = sprintf('%s_none', baseNetwork.name);
    case 'surface_optical'
        plus = 3; minus = 4;
        meanAlpha = mean(baseNetwork.solarAbsorptivity([plus, minus]));
        meanEpsilon = mean(baseNetwork.irEmissivity([plus, minus]));
        network.solarAbsorptivity(plus) = min(meanAlpha * (1 + level), 1);
        network.solarAbsorptivity(minus) = max(meanAlpha * (1 - level), 0);
        network.irEmissivity(plus) = max(meanEpsilon * (1 - 0.5 * level), 0);
        network.irEmissivity(minus) = min(meanEpsilon * (1 + 0.5 * level), 1);
        network.name = sprintf('%s_surface_%03d', baseNetwork.name, round(100*level));
    case 'structural_coupling'
        plus = 3; minus = 4; structure = 7;
        meanConductance = mean(baseNetwork.conductanceWK([plus, minus], structure));
        network.conductanceWK(plus, structure) = meanConductance * (1 + level);
        network.conductanceWK(structure, plus) = network.conductanceWK(plus, structure);
        network.conductanceWK(minus, structure) = meanConductance * (1 - level);
        network.conductanceWK(structure, minus) = network.conductanceWK(minus, structure);
        network.name = sprintf('%s_coupling_%03d', baseNetwork.name, round(100*level));
    case 'receiver_mount'
        antenna = 8; zenith = 6; structure = 7;
        network.projectedAreaM2(antenna) = 0.10 * level;
        network.radiatingAreaM2(antenna) = 0.10 * level;
        if level > 0
            network.normalBody(antenna, :) = [0, 0, -1];
        end
        network.solarAbsorptivity(antenna) = 0.70;
        network.irEmissivity(antenna) = 0.86;
        baseMountConductance = baseNetwork.conductanceWK(antenna, structure);
        network.conductanceWK(antenna, structure) = ...
            baseMountConductance + level * (0.45 - baseMountConductance);
        network.conductanceWK(structure, antenna) = ...
            network.conductanceWK(antenna, structure);
        network.conductanceWK(antenna, zenith) = 0.90 * level;
        network.conductanceWK(zenith, antenna) = network.conductanceWK(antenna, zenith);
        network.name = sprintf('%s_mount_%03d', baseNetwork.name, round(100*level));
    case 'combined'
        network = leotherm.applyThermalAsymmetry(baseNetwork, 'surface_optical', level);
        network = leotherm.applyThermalAsymmetry(network, 'structural_coupling', level);
        network = leotherm.applyThermalAsymmetry(network, 'receiver_mount', level);
        network.name = sprintf('%s_combined_%03d', baseNetwork.name, round(100*level));
    otherwise
        error('Unsupported asymmetry mode: %s', mode);
end
leotherm.validateNetwork(network);
end
