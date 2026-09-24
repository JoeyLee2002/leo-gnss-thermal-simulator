function result = calibrateTelemetry(data, scenario, network, profile, split, settings, outputDirectory)
%CALIBRATETELEMETRY Device-bounded calibration and frozen whole-day checks.
% The loss is a day/node-balanced score, not an independent-sample likelihood.
if nargin < 6, settings = struct; end
if nargin < 7, outputDirectory = ''; end
leotherm.validateScenario(scenario);
profile = leotherm.validateDeviceCalibrationProfile(profile,network);
settings = leotherm.deviceCalibrationOptions(settings,numel(network.nodeNames));
if isempty(settings.sensorEvidence)
    error('leotherm:DeviceCalibrationEvidence','Specify the source or explicit assumption for sensor uncertainty.');
end
active = profile.parameters.estimate;
if ~any(active) || sum(active) > settings.maxFreeParameters
    error('leotherm:DeviceCalibrationParameters','Select at least one parameter, within maxFreeParameters.');
end
[role,dayKey,split] = validateSplit(data,split);
options = settings.telemetryOptions;
options.rmseToleranceK = settings.rmseToleranceK;
roles = ["train","validation","test"];
sets = cell(1,3);
% Retain source rows and every gap. No target samples from other roles enter a fit.
for k = 1:3
    sets{k} = isolate(data,role == roles(k));
end
checkDrivers(sets{1},profile,settings);
options.maxStepS = boundAwareStep(network,profile,scenario,options.maxStepS,sets{1});
outputDirectory = prepareDirectory(outputDirectory);
protocol = struct('profile',profile,'settings',settings,'split',split, ...
    'scenario',scenario,'softwareVersion',leotherm.version, ...
    'effectiveTelemetryOptions',options, ...
    'createdUTC',datetime('now','TimeZone','UTC'), ...
    'policy','whole_utc_days_chronological_no_interpolation_no_test_tuning', ...
    'weighting','equal_day_node_mean_squared_standardized_residual_plus_prior_penalty', ...
    'independence','user_declaration_not_verified_from_file_names');
if ~isempty(outputDirectory)
    save(fullfile(outputDirectory,'protocol_before_fit.mat'),'protocol');
    save(fullfile(outputDirectory,'input_snapshot.mat'),'data','-v7.3');
end
baseline = cell(1,3); baselineReports = cell(1,3);
[baseline{1},baselineReports{1}] = simulateChecked(sets{1},scenario,network,options);
requireDayCoverage(baselineReports{1},split,roles(1),dayKey,network,data.hasTemperature);
[mask,weights,observed,indices] = trainingScore(baselineReports{1},settings,dayKey,network);
train = sets{1};
selected = profile.parameters(active,:);
bounds = struct('lower',selected.lower','upper',selected.upper','initial',selected.nominal');
objective = @(theta) trainingObjective(theta,train,scenario,network,profile,options, ...
    indices,mask,observed,weights,selected,settings.regularizationWeight);
prefix = '';
if ~isempty(outputDirectory), prefix = fullfile(outputDirectory,'fit'); end
fit = leotherm.fitThermalParameters(objective,bounds,settings.solverSettings,prefix);
leotherm.requireCalibrationConvergence(fit);
fittedNetwork = leotherm.applyDeviceCalibrationProfile(network,profile,fit.parameters);
prediction = cell(1,3); reports = cell(1,3);
[prediction{1},reports{1}] = simulateChecked(train,scenario,fittedNetwork,options);
diagnostics = sensitivityDiagnostics(fit.parameters,train,scenario,network,profile, ...
    options,indices,mask,weights,selected);
halfOptions = options; halfOptions.maxStepS = options.maxStepS/2;
[halfPrediction,~] = simulateChecked(train,scenario,fittedNetwork,halfOptions);
diagnostics.stepHalvingMaxDifferenceK = max(abs(halfPrediction.temperatureK(indices)-prediction{1}.temperatureK(indices)));
diagnostics.stepHalvingToleranceK = min(0.01,0.1*min(settings.temperatureSigmaK(data.hasTemperature)));
if diagnostics.stepHalvingMaxDifferenceK > diagnostics.stepHalvingToleranceK
    error('leotherm:DeviceCalibrationNumerics','Training predictions fail the integration step-halving check. Reduce the maximum step.');
end
parameterReport = parameterChanges(profile,fit);
profileAfter = profile;
profileAfter.calibratedNetwork = fittedNetwork;
profileAfter.calibratedValues = parameterReport.calibrated;
profileAfter.parameterReport = parameterReport;
profileAfter.softwareVersion = leotherm.version;
profileAfter.note = 'Original nominal values and evidence remain unchanged; calibratedNetwork is a separate configuration.';
frozen = struct('profileBefore',profile,'profileAfter',profileAfter,'fit',fit, ...
    'diagnostics',diagnostics,'settings',settings,'split',split, ...
    'scenario',scenario,'network',fittedNetwork, ...
    'effectiveTelemetryOptions',options,'trainingSampleMask',mask, ...
    'trainingPredictionIndices',indices,'trainingWeights',weights, ...
    'frozenUTC',datetime('now','TimeZone','UTC'));
% Nothing below changes parameters, bounds, priors, weights, or model selection.
if ~isempty(outputDirectory)
    save(fullfile(outputDirectory,'frozen_before_checks.mat'),'frozen');
end
checkNumerics = table(strings(2,1),zeros(2,1),zeros(2,1), ...
    repmat(diagnostics.stepHalvingToleranceK,2,1), ...
    'VariableNames',{'role','maximum_step_s','step_halving_difference_k','tolerance_k'});
for k = 2:3
    checkDrivers(sets{k},profile,settings);
    checkOptions = options;
    checkOptions.maxStepS = boundAwareStep(network,profile,scenario,options.maxStepS,sets{k});
    [baseline{k},baselineReports{k}] = simulateChecked(sets{k},scenario,network,checkOptions);
    requireDayCoverage(baselineReports{k},split,roles(k),dayKey,network,data.hasTemperature);
    [prediction{k},reports{k}] = simulateChecked(sets{k},scenario,fittedNetwork,checkOptions);
    refinedOptions = checkOptions; refinedOptions.maxStepS = checkOptions.maxStepS/2;
    [refined,~] = simulateChecked(sets{k},scenario,fittedNetwork,refinedOptions);
    scored = reports{k}.samples(reports{k}.samples.used,:);
    [~,node] = ismember(scored.node,string(network.nodeNames));
    idx = sub2ind(size(refined.temperatureK),scored.source_row,node);
    difference = max(abs(refined.temperatureK(idx)-prediction{k}.temperatureK(idx)));
    if difference > diagnostics.stepHalvingToleranceK
        error('leotherm:DeviceCalibrationNumerics','A frozen check fails actual integration refinement. Reduce the maximum step; do not retune parameters on checks.');
    end
    checkNumerics(k-1,:) = {roles(k),checkOptions.maxStepS,difference,diagnostics.stepHalvingToleranceK};
end
for k = 1:3
    prediction{k}.provenance.parametersFitted = true;
    prediction{k}.provenance.parameterFitRole = 'train';
    prediction{k}.provenance.evaluationRole = char(roles(k));
    prediction{k}.provenance.devicePriorsPreserved = true;
    reports{k}.fittedToValidation = k == 1;
    reports{k}.calibrationRole = char(roles(k));
    reports{k}.parametersFittedOnTrainingOnly = true;
    if k == 1
        reports{k}.independence = 'in_sample_calibration_not_validation';
    end
end
[stageMetrics,dayMetrics,samples] = comparisonTables(baselineReports,reports,roles,dayKey);
coverage = leotherm.calibrationCoverage(reports,split,settings);
warningCodes = string(fit.warningCodes(:));
if ~all(coverage.sufficient), warningCodes(end+1) = "insufficient_dynamic_coverage"; end
if diagnostics.rankDeficient, warningCodes(end+1) = "training_sensitivity_rank_deficient"; end
if any(diagnostics.weakSensitivity), warningCodes(end+1) = "weak_parameter_sensitivity"; end
if any(selected.kind == "effective"), warningCodes(end+1) = "effective_parameters_not_component_measurements"; end
if ~settings.independentHoldoutConfirmed, warningCodes(end+1) = "holdout_history_not_confirmed"; end
if ~settings.forcingIndependenceConfirmed, warningCodes(end+1) = "forcing_independence_not_confirmed"; end
if ~settings.parameterEvidenceConfirmed, warningCodes(end+1) = "parameter_evidence_not_confirmed"; end
if options.useInitialTemperature, warningCodes(end+1) = "conditioned_on_measured_initial_state"; end
if any(data.hasBoundaryTemperature), warningCodes(end+1) = "conditional_boundary_driven_validation"; end
synthetic = strcmp(data.datasetKind,'synthetic_demo_not_flight_data');
if synthetic, warningCodes(end+1) = "synthetic_not_flight_validation"; end
review = ~fit.converged || any(fit.nearBound) || fit.parameterInstability ...
    || ~fit.parameterStabilityAssessed || diagnostics.rankDeficient ...
    || any(diagnostics.weakSensitivity) || ~settings.independentHoldoutConfirmed ...
    || ~settings.forcingIndependenceConfirmed || ~settings.parameterEvidenceConfirmed || synthetic ...
    || ~all(coverage.sufficient);
evaluated = dayMetrics.role ~= "train";
criteriaSpecified = isfinite(settings.rmseToleranceK);
withinCriteria = criteriaSpecified && all(dayMetrics.used_samples(evaluated) >= 3) ...
    && all(dayMetrics.calibrated_rmse_k(evaluated) <= settings.rmseToleranceK);
if ~criteriaSpecified, warningCodes(end+1) = "rmse_criterion_not_specified"; end
status = 'review_required';
if criteriaSpecified && ~withinCriteria
    status = 'criteria_not_met';
elseif withinCriteria && ~review
    status = 'accepted_within_declared_scope';
end
result = struct('status',status,'passed',strcmp(status,'accepted_within_declared_scope'), ...
    'withinDeclaredCriteria',withinCriteria,'physicalValidityEstablished',false, ...
    'profileBefore',profile,'profileAfter',profileAfter,'parameterReport',parameterReport, ...
    'fit',fit,'settings',settings,'split',split,'diagnostics',diagnostics, ...
    'stageMetrics',stageMetrics,'dayMetrics',dayMetrics,'samples',samples, ...
    'warningCodes',warningCodes,'outputDirectory',outputDirectory,'protocol',protocol, ...
    'source',data.source,'datasetKind',data.datasetKind, ...
    'softwareVersion',leotherm.version);
result.baseline = baseline; result.prediction = prediction;
result.coverage = coverage;
result.coverageSufficient = all(coverage.sufficient);
result.checkNumerics = checkNumerics;
result.baselineReports = baselineReports; result.reports = reports;
result.rowAudit = data.audit;
result.rowAudit.calibration_role = role;
result.rowAudit.calibration_temperature_valid = all(isfinite(data.temperatureK(:,data.hasTemperature)) ...
    & data.temperatureK(:,data.hasTemperature)>0,2);
result.rowAudit.calibration_disposition = repmat("excluded_day",numel(role),1);
result.rowAudit.calibration_segment_id = zeros(numel(role),1);
result.rowAudit.calibration_scored = ismember(result.rowAudit.source_row,samples.source_row);
for k = 1:3
    at = role == roles(k);
    result.rowAudit.calibration_disposition(at) = prediction{k}.audit.reason(at);
    result.rowAudit.calibration_segment_id(at) = prediction{k}.segmentId(at);
end
result.trainingObjective = struct('dataTerm',sum(weights .* ...
    (prediction{1}.temperatureK(indices)-observed).^2), ...
    'priorTerm',settings.regularizationWeight*sum(((fit.parameters'-selected.nominal)./selected.priorSigma).^2));
if ~isempty(outputDirectory)
    save(fullfile(outputDirectory,'calibration_result.mat'),'result','-v7.3');
    leotherm.writeDeviceCalibrationResults(result,outputDirectory);
end
end

function step = boundAwareStep(network,profile,scenario,requested,data)
% Bound the RK4 thermal decay rates over the complete declared parameter box.
capacity = network.capacityJK(:); conductance = network.conductanceWK;
area = network.radiatingAreaM2(:); emissivity = network.irEmissivity(:);
p = profile.parameters(profile.parameters.estimate,:);
for k = 1:height(p)
    i = find(strcmp(network.nodeNames,p.node(k)),1);
    switch p.field(k)
        case 'capacityJK', capacity(i) = p.lower(k);
        case 'radiatingAreaM2', area(i) = p.upper(k);
        case 'irEmissivity', emissivity(i) = p.upper(k);
        case 'conductanceWK'
            j = find(strcmp(network.nodeNames,p.peer(k)),1);
            conductance(i,j) = p.upper(k); conductance(j,i) = p.upper(k);
    end
end
c = leotherm.constants;
boundary = zeros(numel(capacity),1);
for k = find(data.hasBoundaryConductance)
    values = data.boundaryConductanceWK(data.accepted,k);
    values = values(isfinite(values) & values >= 0);
    if ~isempty(values), boundary(k) = max(values); end
end
rate = (2*sum(conductance,2) + boundary ...
    + 4*c.sigma*emissivity.*area*scenario.integration.maximumTemperatureK^3)./capacity;
step = requested;
if any(rate > 0), step = min(step,1/max(rate)); end
% Ensure step-halving actually refines sampled intervals and boundary caps.
rows = find(data.accepted);
intervals = seconds(diff(data.epoch(rows)));
intervals = intervals(diff(rows) == 1);
if ~isempty(intervals), step = min(step,min(intervals)); end
end

function requireDayCoverage(report,split,role,dayKey,network,hasTemperature)
days = split.day_utc(split.role == role);
names = string(network.nodeNames(hasTemperature));
s = report.samples;
for d = 1:numel(days)
    for n = 1:numel(names)
        count = sum(s.used & s.node == names(n) & dayKey(s.source_row) == days(d));
        if count < 3
            error('leotherm:DeviceCalibrationCoverage', ...
                'Every predeclared day/node needs three scored samples. Missing cell: %s %s %s.',role,days(d),names(n));
        end
    end
end
end

function checkDrivers(data,profile,settings)
if ~isequal(data.nodeNames,profile.nodeNames) || ~any(data.hasTemperature)
    error('leotherm:DeviceCalibrationData','Remap telemetry and include target temperatures.');
end
p = profile.parameters(profile.parameters.estimate,:);
for k = 1:height(p)
    node = find(strcmp(data.nodeNames,p.node(k)),1);
    if p.field(k) == "internalPowerW" && data.hasInternal(node)
        error('leotherm:DeviceCalibrationDriver','Measured internal power overrides this model parameter; lock it.');
    end
    if strcmp(settings.telemetryOptions.mode,'heat') ...
            && ismember(p.field(k),["projectedAreaM2","solarAbsorptivity"])
        error('leotherm:DeviceCalibrationDriver','Absorbed heat telemetry bypasses projected area and solar absorptivity; lock them.');
    end
end
% Screen same-unit boundary copies within this role, never on other targets.
drivers = data.boundaryTemperatureK(:,data.hasBoundaryTemperature);
targets = data.temperatureK(:,data.hasTemperature);
for a = 1:size(targets,2)
    for b = 1:size(drivers,2)
        valid = data.accepted & isfinite(targets(:,a)) & isfinite(drivers(:,b));
        if sum(valid) >= 3 && max(targets(valid,a))-min(targets(valid,a)) > 1e-8 ...
                && max(abs(targets(valid,a)-drivers(valid,b))) <= 1e-10
            error('leotherm:DeviceCalibrationLeakage','A target channel is duplicated in a forcing channel.');
        end
    end
end
end

function [role,dayKey,split] = validateSplit(data,split)
available = leotherm.calibrationDaySplit(data);
if ~istable(split) || ~all(ismember({'day_utc','role'},split.Properties.VariableNames))
    error('leotherm:DeviceCalibrationSplit','Supply a day_utc/role table.');
end
split.day_utc = string(split.day_utc); split.role = string(split.role);
if any(ismissing(split.day_utc)) || any(ismissing(split.role)) ...
        || numel(unique(split.day_utc)) ~= height(split) ...
        || ~isequal(sort(split.day_utc),available.day_utc) ...
        || any(~ismember(split.role,["train","validation","test","exclude"]))
    error('leotherm:DeviceCalibrationSplit','Assign every UTC day exactly once; roles are train, validation, test, exclude.');
end
split = sortrows(split,'day_utc');
stages = ["train","validation","test"];
last = 0;
for k = 1:3
    index = find(split.role == stages(k));
    if isempty(index) || min(index) <= last
        error('leotherm:DeviceCalibrationSplit','Need chronological, disjoint whole days for training, validation, and test.');
    end
    last = max(index);
end
epoch = data.epoch; epoch.TimeZone = 'UTC';
days = dateshift(epoch,'start','day'); days.Format = 'yyyy-MM-dd';
dayKey = string(days);
role = repmat("exclude",numel(epoch),1);
[found,index] = ismember(dayKey,split.day_utc);
role(found) = split.role(index(found));
end

function selected = isolate(data,inRole)
selected = data;
% Missing target measurements remove only that node's score, not valid forcing.
selected.accepted = data.accepted & inRole;
selected.audit.accepted = selected.accepted;
selected.audit.reason(~inRole) = "outside_calibration_role";
selected.temperatureK(~inRole,:) = NaN;
end

function directory = prepareDirectory(directory)
if isempty(directory), return; end
if ~((ischar(directory) && isrow(directory)) || (isstring(directory) && isscalar(directory)))
    error('leotherm:DeviceCalibrationExport','The output directory must be one path.');
end
target = java.io.File(char(directory));
if ~target.isAbsolute(), target = java.io.File(fullfile(pwd,char(directory))); end
directory = char(target.getCanonicalPath());
% mkdirs returns false if another process already claimed the final directory.
if ~target.mkdirs()
    error('leotherm:DeviceCalibrationExport','Cannot exclusively create output directory; use a new writable path.');
end
end

function [prediction,report] = simulateChecked(data,scenario,network,options)
prediction = leotherm.simulateTelemetry(data,scenario,network,options);
if any(prediction.segments.status == "failed")
    error('leotherm:DeviceCalibrationSimulation', ...
        'A thermal segment failed. No failed predictions are removed to improve calibration scores.');
end
report = leotherm.validateTelemetry(prediction,data,options);
if isempty(report.metrics) || any(report.metrics.used_samples < 3)
    error('leotherm:DeviceCalibrationCoverage','Every mapped node needs at least three scored samples in every role.');
end
end

function [mask,weights,observed,indices] = trainingScore(report,settings,dayKey,network)
s = report.samples;
mask = s.used;
[~,node] = ismember(s.node(mask),string(network.nodeNames));
rows = s.source_row(mask);
indices = sub2ind([numel(dayKey),numel(network.nodeNames)],rows,node);
observed = s.observed_k(mask);
keys = dayKey(rows) + ":" + s.node(mask);
[~,~,group] = unique(keys);
weights = zeros(sum(mask),1);
for k = 1:max(group)
    at = group == k;
    if sum(at) < 3
        error('leotherm:DeviceCalibrationCoverage','Each training day/node needs three scored samples.');
    end
    weights(at) = 1 / (sum(at)*max(group));
end
sigma = settings.temperatureSigmaK(node); sigma = sigma(:);
weights = weights ./ sigma.^2;
end

function value = trainingObjective(theta,data,scenario,network,profile,options,indices,mask,observed,weights,p,lambda)
predicted = predictFixedMask(theta,data,scenario,network,profile,options,indices,mask);
value = sum(weights .* (predicted-observed).^2) ...
    + lambda*sum(((theta(:)-p.nominal)./p.priorSigma).^2);
end

function values = predictFixedMask(theta,data,scenario,network,profile,options,indices,mask)
adjusted = leotherm.applyDeviceCalibrationProfile(network,profile,theta);
[prediction,report] = simulateChecked(data,scenario,adjusted,options);
if ~isequal(report.samples.used,mask)
    error('leotherm:DeviceCalibrationCoverage','A candidate changed the scoring rows; calibration has stopped.');
end
values = prediction.temperatureK(indices);
if any(~isfinite(values) | values <= 0)
    error('leotherm:DeviceCalibrationSimulation','All fixed scoring rows require valid predictions.');
end
end

function d = sensitivityDiagnostics(theta,data,scenario,network,profile,options,indices,mask,weights,p)
n = numel(theta); jacobian = zeros(numel(indices),n);
for k = 1:n
    step = max(1e-3*(p.upper(k)-p.lower(k)),4*eps(max(1,abs(theta(k)))));
    left = theta; right = theta;
    left(k) = max(p.lower(k),theta(k)-step);
    right(k) = min(p.upper(k),theta(k)+step);
    if right(k) <= left(k)
        error('leotherm:DeviceCalibrationNumerics','Sensitivity perturbations are not representable; lock this parameter.');
    end
    low = predictFixedMask(left,data,scenario,network,profile,options,indices,mask);
    high = predictFixedMask(right,data,scenario,network,profile,options,indices,mask);
    jacobian(:,k) = sqrt(weights).*(high-low)/(right(k)-left(k))*p.priorSigma(k);
end
s = svd(jacobian,0);
tolerance = max(1e-10,1e-6*max(s));
d.rank = sum(s > tolerance); d.parameterCount = n;
d.rankDeficient = d.rank < n; d.singularValues = s;
d.weightedSensitivityPerPriorSigma = vecnorm(jacobian,2,1);
d.weakSensitivity = d.weightedSensitivityPerPriorSigma < 0.01;
denom = d.weightedSensitivityPerPriorSigma' * d.weightedSensitivityPerPriorSigma;
d.sensitivityCosine = (jacobian'*jacobian)./denom;
d.conditionNumber = Inf;
if ~d.rankDeficient, d.conditionNumber = max(s)/min(s); end
d.method = 'training_only_finite_differences_prior_scaled_no_regularizer_in_jacobian';
d.thresholdPolicy = 'rank: max(1e-10,1e-6*smax); weak: weighted response per prior sigma < 0.01 sensor sigma';
d.identifiabilityEstablished = false;
d.confidenceIntervalsComputed = false;
d.note = 'Local sensitivity is a warning diagnostic, not proof of identifiability or a confidence interval; time samples are correlated.';
end

function report = parameterChanges(profile,fit)
report = profile.parameters;
report.calibrated = report.nominal;
report.calibrated(report.estimate) = fit.parameters(:);
report.change = report.calibrated-report.nominal;
report.change_percent = nan(height(report),1);
nz = report.nominal ~= 0;
report.change_percent(nz) = 100*report.change(nz)./abs(report.nominal(nz));
report.change_prior_sigma = zeros(height(report),1);
report.change_prior_sigma(report.estimate) = report.change(report.estimate)./report.priorSigma(report.estimate);
report.within_bounds = report.calibrated >= report.lower & report.calibrated <= report.upper;
report.near_bound = false(height(report),1);
report.near_bound(report.estimate) = fit.nearBound(:);
end

function [stages,days,samples] = comparisonTables(baselines,reports,roles,dayKey)
stageParts = cell(1,3); dayParts = {}; sampleParts = cell(1,3);
for k = 1:3
    a = baselines{k}; b = reports{k};
    if ~isequal(a.samples.used,b.samples.used)
        error('leotherm:DeviceCalibrationCoverage','Baseline and calibrated scores must use identical samples.');
    end
    stageParts{k} = table(repmat(roles(k),height(b.metrics),1),b.metrics.node, ...
        b.metrics.used_samples,a.metrics.rmse_k,b.metrics.rmse_k, ...
        'VariableNames',{'role','node','used_samples','baseline_rmse_k','calibrated_rmse_k'});
    s = b.samples(b.samples.used,:);
    s.baseline_predicted_k = a.samples.predicted_k(b.samples.used);
    s.role = repmat(roles(k),height(s),1);
    s.day_utc = dayKey(s.source_row);
    sampleParts{k} = s;
    keys = s.day_utc + ":" + s.node;
    [~,~,groups] = unique(keys);
    for g = 1:max(groups)
        at = groups == g; first = find(at,1);
        dayParts{end+1} = table(roles(k),s.day_utc(first),s.node(first),sum(at), ...
            sqrt(mean((s.baseline_predicted_k(at)-s.observed_k(at)).^2)), ...
            sqrt(mean(s.residual_k(at).^2)), ...
            'VariableNames',{'role','day_utc','node','used_samples','baseline_rmse_k','calibrated_rmse_k'}); %#ok<AGROW>
    end
end
stages = vertcat(stageParts{:}); days = vertcat(dayParts{:}); samples = vertcat(sampleParts{:});
end
