function tests = test_device_calibration_optional_solver
tests = functiontests(localfunctions);
end

function testOptionalSolverInterior(testCase)
f = leotherm.deviceCalibrationDemo;
f.settings.solverSettings.solver = 'auto';
r = leotherm.calibrateTelemetry(f.data,f.scenario,f.network,f.profile,f.split,f.settings);
verifyTrue(testCase,r.fit.converged);
verifyTrue(testCase,r.withinDeclaredCriteria);
verifyTrue(testCase,all(r.parameterReport.within_bounds));
verifyEqual(testCase,r.fit.parameters,110,'AbsTol',0.5);
end

function testOptionalSolverCannotEscapeDeviceBounds(testCase)
f = leotherm.deviceCalibrationDemo;
f.trueNetwork.capacityJK = 150;
truth = leotherm.simulateTelemetry(f.data,f.scenario,f.trueNetwork,f.settings.telemetryOptions);
f.raw.temperature_k_device = truth.temperatureK + f.noiseK;
f.data = leotherm.readTelemetry(f.raw,[],f.network);
f.settings.solverSettings.solver = 'auto';
r = leotherm.calibrateTelemetry(f.data,f.scenario,f.network,f.profile,f.split,f.settings);
verifyTrue(testCase,r.fit.converged);
verifyTrue(testCase,all(r.parameterReport.within_bounds));
verifyEqual(testCase,r.fit.parameters,120,'AbsTol',1e-6);
verifyFalse(testCase,r.withinDeclaredCriteria);
verifyEqual(testCase,r.status,'criteria_not_met');
end
