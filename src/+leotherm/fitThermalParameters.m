function fit = fitThermalParameters(objective, bounds, settings, checkpointPrefix)
%FITTHERMALPARAMETERS Bounded multistart calibration with explicit diagnostics.
% The objective must use training data only. Convergence is not identifiability.
if nargin < 3, settings = struct; end
if nargin < 4, checkpointPrefix = ''; end
defaults = struct('maximumIterations',1200, 'maximumEvaluations',5000, ...
    'starts',4, 'solver','auto', 'display','off', 'gradientTolerance',1e-3, ...
    'nearOptimalRelativeTolerance',0.05, 'initialPoints',[]);
names = fieldnames(settings);
if any(~ismember(names, fieldnames(defaults)))
    error('leotherm:CalibrationOptions', 'Unknown calibration option.');
end
for k = 1:numel(names), defaults.(names{k}) = settings.(names{k}); end
settings = defaults;
if ~isa(objective, 'function_handle') || ~isstruct(bounds) ...
        || ~all(isfield(bounds, {'lower','upper','initial'}))
    error('leotherm:CalibrationOptions', 'Supply an objective and lower, upper, initial bounds.');
end
for name = {'lower','upper','initial'}
    x = bounds.(name{1});
    if ~isnumeric(x) || ~isreal(x) || ~isvector(x) || any(~isfinite(x))
        error('leotherm:CalibrationOptions', 'Bounds and initial values must be finite real vectors.');
    end
    bounds.(name{1}) = x(:)';
end
lower = bounds.lower;
if ~isequal(size(lower), size(bounds.upper), size(bounds.initial))
    error('leotherm:CalibrationOptions', 'Bound vectors must have equal lengths.');
end
span = bounds.upper-lower;
if any(~isfinite(span) | span <= 0) || any(bounds.initial < lower | bounds.initial > bounds.upper)
    error('leotherm:CalibrationOptions', 'Require lower < upper and an initial value inside the box.');
end
for name = {'maximumIterations','maximumEvaluations','starts'}
    validateattributes(settings.(name{1}), {'numeric'}, {'real','finite','scalar','integer','positive'});
end
validateattributes(settings.gradientTolerance, {'numeric'}, {'real','finite','scalar','positive'});
validateattributes(settings.nearOptimalRelativeTolerance, {'numeric'}, {'real','finite','scalar','nonnegative'});
if ~ismember(settings.solver, {'auto','fmincon','fminsearch'}) ...
        || ~ismember(settings.display, {'off','iter','final'})
    error('leotherm:CalibrationOptions', 'Unsupported solver or display option.');
end
hasConstrained = exist('fmincon','file') == 2 && license('test','Optimization_Toolbox');
solver = settings.solver;
if strcmp(solver,'auto')
    solver = 'fminsearch';
    if hasConstrained, solver = 'fmincon'; end
elseif strcmp(solver,'fmincon') && ~hasConstrained
    error('leotherm:CalibrationSolver', 'fmincon requires Optimization Toolbox; use fminsearch for base MATLAB.');
end
n = numel(lower);
initialPoints = settings.initialPoints;
if isempty(initialPoints)
    initialPoints = zeros(settings.starts,n);
    initialPoints(1,:) = bounds.initial;
    % Deterministic dispersed starts; no random seed or test data.
    for k = 2:settings.starts
        initialPoints(k,:) = lower + span .* (0.1 + 0.8*mod((k-1)*(sqrt(2)+(1:n)*sqrt(3)),1));
    end
end
if ~isnumeric(initialPoints) || ~isreal(initialPoints) ...
        || ~isequal(size(initialPoints),[settings.starts,n]) ...
        || any(~isfinite(initialPoints),'all') ...
        || any(initialPoints < lower | initialPoints > bounds.upper,'all')
    error('leotherm:CalibrationOptions', 'initialPoints must be starts-by-parameters and inside bounds.');
end
if ~isempty(checkpointPrefix)
    for k = 1:settings.starts
        if isfile(sprintf('%s_start%d.mat',checkpointPrefix,k))
            error('leotherm:CalibrationCheckpoint', 'Refusing to overwrite a completed-start checkpoint.');
        end
    end
end
fn = @(u) finiteObjective(objective, lower + span.*u(:)');
scale = max(1,abs(fn((bounds.initial-lower)./span)));
fit.starts = cell(1,settings.starts); fit.objective = Inf;
for k = 1:settings.starts
    initial = initialPoints(k,:); u0 = (initial-lower)./span;
    if strcmp(solver,'fmincon')
        options = optimoptions('fmincon','Algorithm','sqp','Display',settings.display, ...
            'MaxIterations',settings.maximumIterations,'MaxFunctionEvaluations',settings.maximumEvaluations, ...
            'OptimalityTolerance',1e-7,'StepTolerance',1e-8, ...
            'FiniteDifferenceType','central');
        [u,~,flag,output] = fmincon(@(u)fn(u)/scale,u0,[],[],[],[],zeros(1,n),ones(1,n),[],options);
    else
        options = optimset('Display',settings.display,'MaxIter',settings.maximumIterations, ...
            'MaxFunEvals',settings.maximumEvaluations,'TolX',1e-7,'TolFun',1e-9);
        [u,~,flag,output] = fminsearch(@(u)boxObjective(u,fn,scale),u0,options);
    end
    u = min(1,max(0,u(:)'));
    item.parameters = lower+span.*u;
    item.objective = fn(u); item.exitflag = flag; item.output = output;
    item.projectedGradient = projectedGradient(fn,u,item.objective);
    item.converged = flag > 0 && item.projectedGradient <= settings.gradientTolerance;
    item.solver = solver;
    if ~isempty(checkpointPrefix)
        save(sprintf('%s_start%d.mat',checkpointPrefix,k),'item','initial','bounds','settings');
    end
    fit.starts{k} = item;
    if item.objective < fit.objective
        fit.parameters = item.parameters; fit.objective = item.objective;
        fit.exitflag = item.exitflag; fit.output = item.output;
        fit.converged = item.converged; fit.projectedGradient = item.projectedGradient;
        fit.bestStart = k;
    end
end
fit.bounds = bounds; fit.settings = settings; fit.solver = solver;
u = (fit.parameters-lower)./span;
fit.nearBound = min(u,1-u) < 0.02;
values = cellfun(@(x)x.objective,fit.starts);
near = values <= fit.objective + settings.nearOptimalRelativeTolerance*max(1,abs(fit.objective));
parameters = cellfun(@(x)x.parameters,fit.starts(near),'UniformOutput',false);
parameters = vertcat(parameters{:});
fit.nearOptimalStarts = sum(near);
fit.normalizedParameterSpread = (max(parameters,[],1)-min(parameters,[],1))./span;
fit.parameterStabilityAssessed = sum(near) >= 2;
fit.parameterInstability = fit.parameterStabilityAssessed && any(fit.normalizedParameterSpread > 0.1);
fit.identifiabilityEstablished = false;
fit.globalOptimumEstablished = false;
fit.softwareVersion = leotherm.version;
fit.warningCodes = {};
if ~fit.converged, fit.warningCodes{end+1} = 'best_start_not_converged'; end
if any(fit.nearBound), fit.warningCodes{end+1} = 'parameters_near_bounds'; end
if ~fit.parameterStabilityAssessed, fit.warningCodes{end+1} = 'parameter_stability_not_assessed'; end
if fit.parameterInstability, fit.warningCodes{end+1} = 'near_optimal_parameter_instability'; end
end

function value = finiteObjective(objective, parameters)
value = objective(parameters);
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value)
    error('leotherm:CalibrationObjective', 'Training objective must return one finite real scalar.');
end
end

function value = boxObjective(u,fn,scale)
clipped = min(1,max(0,u));
value = fn(clipped)/scale + 1e6*sum((u-clipped).^2);
end

function value = projectedGradient(fn,u,objectiveValue)
gradient = zeros(size(u));
for k = 1:numel(u)
    left = u; right = u;
    left(k) = max(0,u(k)-1e-4); right(k) = min(1,u(k)+1e-4);
    gradient(k) = (fn(right)-fn(left))/(right(k)-left(k));
end
gradient = gradient/max(1,abs(objectiveValue));
value = max(abs(u-min(1,max(0,u-gradient))));
end
