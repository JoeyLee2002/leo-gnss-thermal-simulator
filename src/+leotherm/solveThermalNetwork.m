function [temperatureK, diagnostics] = solveThermalNetwork(timeS, externalW, network, environment, limits, forcing)
%SOLVETHERMALNETWORK Error-controlled RK4 with sampled forcing kept intact.

leotherm.validateNetwork(network);
timeS = timeS(:);
if ~isnumeric(timeS) || numel(timeS) < 2 || any(~isfinite(timeS)) ...
        || any(diff(timeS) <= 0)
    error('leotherm:InvalidThermalInput', ...
        'timeS must contain at least two finite, strictly increasing epochs.');
end
nNode = numel(network.nodeNames);
if ~isnumeric(externalW) || ~isreal(externalW) ...
        || ~isequal(size(externalW), [numel(timeS), nNode]) ...
        || any(~isfinite(externalW), 'all')
    error('leotherm:InvalidThermalInput', ...
        'externalW must be a finite number-of-epochs by number-of-nodes matrix.');
end
if ~isstruct(environment) || ~isfield(environment, 'deepSpaceK') ...
        || ~isscalar(environment.deepSpaceK) || ~isfinite(environment.deepSpaceK) ...
        || environment.deepSpaceK < 0
    error('leotherm:InvalidThermalInput', ...
        'environment.deepSpaceK must be one finite nonnegative value.');
end
if ~isstruct(limits) || ~isfield(limits, 'minimumTemperatureK') ...
        || ~isfield(limits, 'maximumTemperatureK') ...
        || ~isscalar(limits.minimumTemperatureK) ...
        || ~isscalar(limits.maximumTemperatureK) ...
        || ~isfinite(limits.minimumTemperatureK) ...
        || ~isfinite(limits.maximumTemperatureK) ...
        || limits.minimumTemperatureK <= 0 ...
        || limits.minimumTemperatureK >= limits.maximumTemperatureK
    error('leotherm:InvalidThermalInput', ...
        'Thermal limits must be finite, positive, and strictly ordered.');
end

nEpoch = numel(timeS);
if nargin < 6
    forcing = struct;
end
if ~isfield(forcing, 'internalPowerW')
    forcing.internalPowerW = repmat(network.internalPowerW(:)', nEpoch, 1);
end
if ~isfield(forcing, 'holdPrevious'), forcing.holdPrevious = false; end
if ~isfield(forcing, 'maxStepS'), forcing.maxStepS = Inf; end
if ~isnumeric(forcing.internalPowerW) || ~isreal(forcing.internalPowerW) ...
        || ~isequal(size(forcing.internalPowerW), [nEpoch, nNode]) ...
        || any(~isfinite(forcing.internalPowerW), 'all') ...
        || any(forcing.internalPowerW < 0, 'all') ...
        || ~islogical(forcing.holdPrevious) || ~isscalar(forcing.holdPrevious) ...
        || ~isnumeric(forcing.maxStepS) || ~isreal(forcing.maxStepS) ...
        || ~isscalar(forcing.maxStepS) || isnan(forcing.maxStepS) || forcing.maxStepS <= 0
    error('leotherm:InvalidThermalInput', 'Invalid sampled internal power or forcing policy.');
end
hasBoundary = isfield(forcing, 'boundaryTemperatureK') || isfield(forcing, 'boundaryConductanceWK');
if hasBoundary
    if ~isfield(forcing, 'boundaryTemperatureK') || ~isfield(forcing, 'boundaryConductanceWK')
        error('leotherm:InvalidThermalBoundary', 'Boundary temperature and conductance must be supplied together.');
    end
    fields = {'boundaryTemperatureK', 'boundaryConductanceWK'};
    for f = 1:numel(fields)
        values = forcing.(fields{f});
        if ~isnumeric(values) || ~isreal(values) || ~isequal(size(values), [nEpoch, nNode]) ...
                || any(~isfinite(values), 'all') || any(values < 0, 'all')
            error('leotherm:InvalidThermalBoundary', 'Boundary inputs must be finite nonnegative epoch-by-node arrays.');
        end
    end
    if any(forcing.boundaryTemperatureK <= 0, 'all')
        error('leotherm:InvalidThermalBoundary', 'Boundary temperatures must be positive kelvin.');
    end
end
temperatureK = zeros(nEpoch, nNode);
temperatureK(1, :) = network.initialTemperatureK(:)';
if any(temperatureK(1, :) < limits.minimumTemperatureK) ...
        || any(temperatureK(1, :) > limits.maximumTemperatureK)
    error('leotherm:ThermalStateOutOfBounds', 'Initial temperature is outside the integration bounds.');
end

% These coefficients are invariant across every RK stage and sampled interval.
c = leotherm.constants;
conductance = network.conductanceWK;
laplacian = diag(sum(conductance, 2)) - conductance;
emission = network.irEmissivity(:) .* c.sigma .* network.radiatingAreaM2(:);
capacity = network.capacityJK(:);
spaceFourth = environment.deepSpaceK^4;
absoluteTolerance = option(limits, 'absoluteToleranceK', 1e-6);
relativeTolerance = option(limits, 'relativeTolerance', 1e-8);
maximumSteps = option(limits, 'maximumInternalSteps', 1e6);
diagnostics = struct('method','adaptive_rk4_step_doubling', ...
    'absoluteToleranceK',absoluteTolerance,'relativeTolerance',relativeTolerance, ...
    'acceptedSteps',0,'rejectedSteps',0,'maximumAcceptedErrorRatio',0, ...
    'maximumEnergyClosureJ',0);
diagnostics.integratedNetHeatJ = zeros(nEpoch,1);
diagnostics.integratedExternalHeatJ = zeros(nEpoch,1);
diagnostics.integratedInternalHeatJ = zeros(nEpoch,1);
diagnostics.integratedRadiatedHeatJ = zeros(nEpoch,1);
diagnostics.integratedBoundaryHeatJ = zeros(nEpoch,1);
diagnostics.energyClosureResidualJ = zeros(nEpoch,1);

for k = 1:(nEpoch - 1)
    dt = timeS(k + 1) - timeS(k);
    q0 = externalW(k, :)';
    q1 = externalW(k + 1, :)';
    p0 = forcing.internalPowerW(k, :)';
    p1 = forcing.internalPowerW(k + 1, :)';
    if forcing.holdPrevious
        q1 = q0; p1 = p0;
    end
    state = temperatureK(k, :)';
    boundaryG = zeros(nNode, 1); boundaryGT = boundaryG;
    effectiveStepS = forcing.maxStepS;
    if hasBoundary
        % Sampled boundary conditions are left-held, never interpolated.
        boundaryG = forcing.boundaryConductanceWK(k, :)';
        boundaryGT = boundaryG .* forcing.boundaryTemperatureK(k, :)';
    end
    rateBound = (2*sum(conductance,2) + boundaryG ...
        + 4*emission*limits.maximumTemperatureK^3) ./ capacity;
    if any(rateBound > 0), effectiveStepS = min(effectiveStepS,1/max(rateBound)); end
    elapsed = 0; heat = 0; h = min(dt,effectiveStepS);
    intervalAccount = zeroAccount;
    rhs = @(y,u) derivative(y,(1-u/dt)*q0+(u/dt)*q1, ...
        (1-u/dt)*p0+(u/dt)*p1,laplacian,emission,capacity,spaceFourth,boundaryG,boundaryGT);
    while elapsed < dt
        h = min([h,dt-elapsed,effectiveStepS]);
        if h <= eps(max(1,abs(timeS(k)+elapsed))) ...
                || diagnostics.acceptedSteps + diagnostics.rejectedSteps >= maximumSteps
            error('leotherm:ThermalNumerics','Integration cannot meet tolerance within the step budget. Check thermal stiffness and input units.');
        end
        coarse = rk4(rhs,state,elapsed,h);
        middle = rk4(rhs,state,elapsed,h/2);
        [~,account1] = rk4Accounting(rhs,state,elapsed,h/2, ...
            q0,q1,p0,p1,dt,emission,spaceFourth,boundaryG,boundaryGT);
        [fine,account2] = rk4Accounting(rhs,middle,elapsed+h/2,h/2, ...
            q0,q1,p0,p1,dt,emission,spaceFourth,boundaryG,boundaryGT);
        scale = absoluteTolerance + relativeTolerance*max(abs(state),abs(fine));
        ratio = max(abs(fine-coarse)./(15*scale));
        if ~all(isfinite(fine)) || ~isfinite(ratio), ratio = Inf; end
        if ratio <= 1
            state = fine;
            acceptedAccount = addAccounts(account1, account2);
            intervalAccount = addAccounts(intervalAccount, acceptedAccount);
            heat = heat + acceptedAccount.netJ;
            elapsed = min(dt,elapsed+h);
            diagnostics.acceptedSteps = diagnostics.acceptedSteps + 1;
            diagnostics.maximumAcceptedErrorRatio = max(diagnostics.maximumAcceptedErrorRatio,ratio);
            if any(state < limits.minimumTemperatureK) || any(state > limits.maximumTemperatureK)
                error('leotherm:ThermalStateOutOfBounds', ...
                    'Thermal state left physical bounds at t = %.6g s.', timeS(k)+elapsed);
            end
        else
            diagnostics.rejectedSteps = diagnostics.rejectedSteps + 1;
        end
        h = h*min(2,max(0.1,0.9*max(ratio,1e-12)^(-0.2)));
    end
    temperatureK(k + 1, :) = state';
    diagnostics.integratedNetHeatJ(k+1) = diagnostics.integratedNetHeatJ(k)+heat;
    diagnostics.integratedExternalHeatJ(k+1) = diagnostics.integratedExternalHeatJ(k) + intervalAccount.externalJ;
    diagnostics.integratedInternalHeatJ(k+1) = diagnostics.integratedInternalHeatJ(k) + intervalAccount.internalJ;
    diagnostics.integratedRadiatedHeatJ(k+1) = diagnostics.integratedRadiatedHeatJ(k) + intervalAccount.radiatedJ;
    diagnostics.integratedBoundaryHeatJ(k+1) = diagnostics.integratedBoundaryHeatJ(k) + intervalAccount.boundaryJ;
    expectedNet = intervalAccount.externalJ + intervalAccount.internalJ ...
        - intervalAccount.radiatedJ + intervalAccount.boundaryJ;
    closureResidual = sum(capacity.*(state-temperatureK(k,:)')) - expectedNet;
    diagnostics.energyClosureResidualJ(k+1) = diagnostics.energyClosureResidualJ(k) + closureResidual;
    closure = abs(closureResidual);
    diagnostics.maximumEnergyClosureJ = max(diagnostics.maximumEnergyClosureJ,closure);
end
diagnostics.energyClosureNote = ['Independent RK-stage ledger: stored-energy change is compared with ' ...
    'external + internal - radiated + boundary heat. This checks accounting only; ' ...
    'forcing-grid convergence and physical parameter validation remain separate.'];
end

function next = rk4(rhs,state,time,h)
k1 = rhs(state,time);
k2 = rhs(state+h*k1/2,time+h/2);
k3 = rhs(state+h*k2/2,time+h/2);
k4 = rhs(state+h*k3,time+h);
increment = h*(k1+2*k2+2*k3+k4)/6;
next = state+increment;
end

function [next,account] = rk4Accounting(rhs,state,time,h,q0,q1,p0,p1,dt,emission,spaceFourth,boundaryG,boundaryGT)
% Integrate state and independent power ledgers using the same RK4 stages.
k1 = rhs(state,time);
s2 = state + h*k1/2;
k2 = rhs(s2,time+h/2);
s3 = state + h*k2/2;
k3 = rhs(s3,time+h/2);
s4 = state + h*k3;
k4 = rhs(s4,time+h);
next = state + h*(k1+2*k2+2*k3+k4)/6;
states = {state,s2,s3,s4};
stageTimes = [time,time+h/2,time+h/2,time+h];
weights = [1,2,2,1] * (h/6);
external = zeros(1,4); internal = external; radiated = external; boundary = external;
for j = 1:4
    u = stageTimes(j);
    q = (1-u/dt)*q0 + (u/dt)*q1;
    p = (1-u/dt)*p0 + (u/dt)*p1;
    [external(j),internal(j),radiated(j),boundary(j)] = channelPowers( ...
        states{j},q,p,emission,spaceFourth,boundaryG,boundaryGT);
end
account.externalJ = weights * external';
account.internalJ = weights * internal';
account.radiatedJ = weights * radiated';
account.boundaryJ = weights * boundary';
account.netJ = account.externalJ + account.internalJ - account.radiatedJ + account.boundaryJ;
end

function [external,internal,radiated,boundary] = channelPowers(temperatureK,externalW,internalW,emission,spaceFourth,boundaryG,boundaryGT)
% Return whole-network powers; conductive exchange cancels in the sum.
external = sum(externalW);
internal = sum(internalW);
radiated = sum(emission .* (temperatureK.^4 - spaceFourth));
boundary = sum(boundaryGT - boundaryG .* temperatureK);
end

function account = zeroAccount
account.externalJ = 0;
account.internalJ = 0;
account.radiatedJ = 0;
account.boundaryJ = 0;
account.netJ = 0;
end

function total = addAccounts(left,right)
total.externalJ = left.externalJ + right.externalJ;
total.internalJ = left.internalJ + right.internalJ;
total.radiatedJ = left.radiatedJ + right.radiatedJ;
total.boundaryJ = left.boundaryJ + right.boundaryJ;
total.netJ = left.netJ + right.netJ;
end

function value = option(input,name,fallback)
value = fallback;
if isfield(input,name), value = input.(name); end
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
    error('leotherm:InvalidThermalInput','Invalid integration option: %s.',name);
end
end

function rate = derivative(temperatureK, externalW, internalW, laplacian, emission, capacity, spaceFourth, boundaryG, boundaryGT)
conductiveW = -laplacian * temperatureK;
emittedW = emission .* (temperatureK.^4 - spaceFourth);
netW = externalW + internalW + conductiveW - emittedW + boundaryGT - boundaryG .* temperatureK;
rate = netW ./ capacity;
end
