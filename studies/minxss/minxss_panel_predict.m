function [predictionK, details] = minxss_panel_predict(input, parameters, kind, p)
%MINXSS_PANEL_PREDICT Actual software solver; target series is not an input.
% Optional exogenous boundaries must come from independent physical inputs.
if ~ismember(kind, {'one_node','two_node'})
    error('minxss:ModelKind', 'Model kind must be one_node or two_node.');
end
t = input.elapsedS(:);
environmentW = repmat(parameters(3:4),numel(t),1);
environmentSource = 'fitted_constant_environment';
if isfield(input,'environmentPowerW')
    checkPanelArray(input.environmentPowerW,numel(t),'environmentPowerW',false);
    if any(parameters(3:4) ~= 0)
        error('minxss:BoundaryInput', 'Set constant Q_env parameters to zero when measured environmentPowerW is provided.');
    end
    environmentW = input.environmentPowerW;
    environmentSource = 'prescribed_time_varying_environment';
end
solar = p.solarConstantWm2 * p.areaM2 * parameters(2) * input.incidenceCosine(:);
solar = max(0,solar);
electrical = input.electricalW;
net = baseNetwork;
if strcmp(kind,'two_node')
    net.nodeNames = {'minus_y_cells','minus_y_substrate','plus_y_cells','plus_y_substrate'};
    net.capacityJK = [p.cellCapacityJK;parameters(1);p.cellCapacityJK;parameters(1)];
    net.initialTemperatureK = repelem(input.initialTemperatureK(:),2);
    net.radiatingAreaM2 = p.areaM2*ones(4,1);
    net.irEmissivity = [p.frontEmissivity;p.backEmissivity;p.frontEmissivity;p.backEmissivity];
    net.conductanceWK = zeros(4);
    net.conductanceWK(1,2) = parameters(5); net.conductanceWK(2,1) = parameters(5);
    net.conductanceWK(3,4) = parameters(5); net.conductanceWK(4,3) = parameters(5);
    q = [solar-electrical(:,1),environmentW(:,1), ...
        solar-electrical(:,2),environmentW(:,2)];
    target = [2 4];
else
    net.nodeNames = {'minus_y_panel','plus_y_panel'};
    net.capacityJK = repmat(parameters(1)+p.cellCapacityJK,2,1);
    net.initialTemperatureK = input.initialTemperatureK(:);
    net.radiatingAreaM2 = 2*p.areaM2*ones(2,1);
    net.irEmissivity = (p.frontEmissivity+p.backEmissivity)/2*ones(2,1);
    net.conductanceWK = zeros(2);
    q = [solar-electrical(:,1),solar-electrical(:,2)] + environmentW;
    target = [1 2];
end
m = numel(net.nodeNames);
net.internalPowerW = zeros(m,1);
net.projectedAreaM2 = zeros(m,1);
net.normalBody = zeros(m,3);
net.solarAbsorptivity = parameters(2)*ones(m,1);
net.bias.linearMPerK = zeros(m,1);
env.deepSpaceK = p.deepSpaceK;
limits.minimumTemperatureK = 80;
limits.maximumTemperatureK = 600;
forcing.holdPrevious = true;
forcing.maxStepS = p.maximumStepS;
hasBoundary = isfield(input,'boundaryTemperatureK') || isfield(input,'hingeConductanceWK');
if hasBoundary
    if ~isfield(input,'boundaryTemperatureK') || ~isfield(input,'hingeConductanceWK')
        error('minxss:BoundaryInput', 'Provide both independent body-boundary temperature and hinge conductance.');
    end
    checkPanelArray(input.boundaryTemperatureK,numel(t),'boundaryTemperatureK',true);
    checkPanelArray(input.hingeConductanceWK,numel(t),'hingeConductanceWK',false);
    forcing.boundaryTemperatureK = repmat(net.initialTemperatureK(:)',numel(t),1);
    forcing.boundaryConductanceWK = zeros(numel(t),m);
    forcing.boundaryTemperatureK(:,target) = input.boundaryTemperatureK;
    forcing.boundaryConductanceWK(:,target) = input.hingeConductanceWK;
end
trajectory = leotherm.solveThermalNetwork(t,q,net,env,limits,forcing);
predictionK = trajectory(:,target);
details.network = net;
details.netAppliedW = q;
details.trajectoryK = trajectory;
details.targetNodes = target;
details.environmentSource = environmentSource;
details.prescribedBodyBoundary = hasBoundary;
if hasBoundary
    details.hingeHeatW = input.hingeConductanceWK .* (input.boundaryTemperatureK-predictionK);
end
end

function checkPanelArray(value,n,name,positive)
if ~isnumeric(value) || ~isreal(value) || ~isequal(size(value),[n 2]) ...
        || any(~isfinite(value),'all') || any(value < 0,'all') ...
        || (positive && any(value <= 0,'all'))
    error('minxss:BoundaryInput', '%s must be a finite nonnegative epoch-by-two matrix (temperature > 0 K).',name);
end
end

function net = baseNetwork
net.name = 'minxss_deployed_panel_reduced_model';
net.bias.quadraticNode = 1;
net.bias.quadraticMPerK2 = 0;
end
