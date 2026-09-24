function scenario = defaultScenario
%DEFAULTSCENARIO Reference 24 h LEO thermal simulation configuration.

scenario.name = 'reference_600km_nadir';
scenario.startEpoch = datetime(2024, 3, 20, 12, 0, 0, 'TimeZone', 'UTC');
scenario.durationS = 24 * 3600;
scenario.timeStepS = 20.0;
scenario.warmupOrbits = 30;
scenario.convergence.enabled = true;
scenario.convergence.minimumCycles = 5;
scenario.convergence.maximumCycles = 80;
scenario.convergence.requiredStableCycles = 2;
scenario.convergence.toleranceK = 1e-3;
scenario.convergence.failOnNonConvergence = true;

scenario.orbit.altitudeM = 600e3;
scenario.orbit.inclinationDeg = 97.6;
scenario.orbit.raanDeg = 20.0;
scenario.orbit.argumentLatitudeDeg = 0.0;
scenario.orbit.useJ2 = true;

scenario.attitude.mode = 'nadir';
scenario.attitude.eulerOffsetDeg = [0.0, 0.0, 0.0];

scenario.environment.solarConstantWm2 = 1361.0;
scenario.environment.earthIRWm2 = 239.0;
scenario.environment.earthIRModel = 'finite_disk';
scenario.environment.albedo = 0.30;
scenario.environment.deepSpaceK = 3.0;
scenario.environment.includeDirectSolar = true;
scenario.environment.includeAlbedo = true;
scenario.environment.includeEarthIR = true;
scenario.environment.freezeSunAtEpoch = false;

scenario.integration.minimumTemperatureK = 100.0;
scenario.integration.maximumTemperatureK = 500.0;
end
