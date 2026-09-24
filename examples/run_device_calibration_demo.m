function results = run_device_calibration_demo(outputDirectory)
%RUN_DEVICE_CALIBRATION_DEMO Verify recovery and honest out-of-range failure.
% This is a software verification experiment with synthetic data, not flight data.
if nargin < 1
    root = fileparts(fileparts(mfilename('fullpath')));
    outputDirectory = fullfile(root,'results',['device_calibration_demo_' datestr(now,'yyyymmdd_HHMMSS')]);
end
if isfolder(outputDirectory) || isfile(outputDirectory)
    error('leotherm:DeviceCalibrationExport','Demo output must be a new directory.');
end
mkdir(outputDirectory);
f = leotherm.deviceCalibrationDemo(6);
results.inside = leotherm.calibrateTelemetry(f.data,f.scenario,f.network, ...
    f.profile,f.split,f.settings,fullfile(outputDirectory,'truth_inside_declared_bounds'));
outside = f;
outside.trueNetwork.capacityJK = 150;
truth = leotherm.simulateTelemetry(f.data,f.scenario,outside.trueNetwork,f.settings.telemetryOptions);
outside.raw.temperature_k_device = truth.temperatureK + f.noiseK;
outside.data = leotherm.readTelemetry(outside.raw,[],f.network);
results.outside = leotherm.calibrateTelemetry(outside.data,f.scenario,f.network, ...
    f.profile,f.split,f.settings,fullfile(outputDirectory,'truth_outside_declared_bounds'));
assert(results.inside.withinDeclaredCriteria);
assert(~results.outside.withinDeclaredCriteria);
assert(all(results.inside.parameterReport.within_bounds));
assert(all(results.outside.parameterReport.within_bounds));
assert(isequal(results.outside.profileBefore.parameters,f.profile.parameters));
assert(~results.inside.physicalValidityEstablished && ~results.outside.physicalValidityEstablished);
for name = {'inside','outside'}
    r = results.(name{1});
    fprintf('%s: C=%.6f J/K, test RMSE=%.6f K, status=%s, physicalValidityEstablished=%d\n', ...
        name{1},r.fit.parameters, ...
        r.stageMetrics.calibrated_rmse_k(r.stageMetrics.role == "test"),r.status,r.physicalValidityEstablished);
end
save(fullfile(outputDirectory,'demo_summary.mat'),'results','-v7.3');
end
