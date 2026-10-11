function protocol = sweep36_protocol
%SWEEP36_PROTOCOL The fixed three-factor experiment used by the manuscript.
protocol.version=leotherm.version;
protocol.altitudeKm=[400 600 800];
protocol.betaDeg=[0 30 60 75];
protocol.conductanceWK=[0.31 0.62 1.24];
protocol.samplesPerOrbit=360;
protocol.analysisOrbits=6;
protocol.referenceConductanceWK=0.62;
protocol.parameterMeaning='Symmetric structure-to-RF conductance; other parameters fixed';
protocol.designBasis='Half, nominal and twice the reference value; not measured hardware';
protocol.scenario=leotherm.defaultScenario;
protocol.scenario.warmupOrbits=0;
protocol.scenario.orbit.useJ2=false;
protocol.scenario.environment.freezeSunAtEpoch=true;
protocol.scenario.convergence.enabled=true;
protocol.scenario.convergence.toleranceK=1e-3;
protocol.scenario.convergence.maximumCycles=80;
protocol.scenario.convergence.requiredStableCycles=2;
protocol.scenario.convergence.failOnNonConvergence=true;
protocol.network=leotherm.defaultReceiverNetwork;
protocol.id='v129_frozen_sun_6orbits_grid360_tol1e-3_G7_9';
end
