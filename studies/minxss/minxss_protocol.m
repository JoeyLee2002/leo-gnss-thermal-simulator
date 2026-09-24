function p = minxss_protocol
%MINXSS_PROTOCOL Fixed protocol, defined before scoring flight temperatures.
p.id = 'minxss_deployed_panels_v3_development_convergence_audit';
p.evidenceRole = 'development_reanalysis_previously_inspected_dates_not_new_independent_validation';
p.sourceFile = 'minxss1_solar-sxr_level0c_20160516_v002.ncdf';
p.sourceSha256 = '14F2408AD9C3981FA11CE6CDA5CAEFDD351D8BA8AC2249B0C703F3C70F550D96';
p.maximumGapS = 60;
p.minimumArcS = 30*60;
p.excludeInitialS = 10*60;
p.inputOnlyAmendment = ['No 90 min arcs survive consistent input screening. ' ...
    'Use >=30 min valid phase segments, exclude the first 10 min; do not bridge ' ...
    'uncertain transitions. Changed before fitting or examining test errors.'];
p.trainBeforeJD = juliandate(datetime(2016,9,1));
p.testFromJD = juliandate(datetime(2016,10,20));
p.areaM2 = 0.030;
p.frontEmissivity = 0.87;
p.backEmissivity = 0.70;
p.solarConstantWm2 = 1361;
p.cellCapacityJK = 6;
p.deepSpaceK = 3;
p.maximumStepS = 10;
p.temperatureRangeK = [173.15 423.15];
p.maximumEclipseElectricalW = 0.25;
p.maximumSunPointErrorDeg = 20;
p.initialTemperaturePolicy = 'one_measured_initial_temperature_per_panel_no_updates';
p.forcingPolicy = 'left_hold_on_original_valid_intervals_no_gap_filling';
p.initializationScope = 'conditional_prediction_not_cold_start';
p.modelNames = {'literature_prior','one_node','two_node','no_storage','persistence'};
% Heat capacity, solar absorptivity, and constant environmental load per panel.
p.one.lower = [20 0.75 0 0];
p.one.upper = [250 0.95 15 15];
p.one.initial = [90 0.90 3 3];
% The extra parameter is cell-to-substrate conductance, not heat/cool tuning.
p.two.lower = [20 0.75 0 0 0.02];
p.two.upper = [250 0.95 15 15 0.60];
p.two.initial = [90 0.90 3 3 0.20];
p.fit.maximumIterations = 1200;
p.fit.maximumEvaluations = 5000;
p.fit.starts = 2;
p.fit.solver = 'auto';
p.acceptance.rmseK = 5;
p.acceptance.absoluteBiasK = 3;
p.acceptance.p95AbsoluteK = 10;
p.acceptance.amplitudeRelativeError = 0.20;
p.acceptance.amplitudeAbsoluteToleranceK = 3;
p.acceptance.label = 'engineering_targets_not_sensor_traceable_certification';
p.selection = 'lowest_validation_macro_rmse_choose_one_node_within_0.2K';
p.scope = ['Radiating deployed-panel reduced model; measured pointing, eclipse and ' ...
    'electrical extraction; globally fitted constant unmodeled environmental load; ' ...
    'no reconstructed orbit/Earth view factors or hinge conduction.'];
end
