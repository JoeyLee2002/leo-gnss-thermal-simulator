function calibrated = applyDeviceCalibrationProfile(network, p, freeParameters)
%APPLYDEVICECALIBRATIONPROFILE Apply only estimated rows, in profile row order.
% Bounds are hard and inclusive. No tolerance, clipping, or prior recentering
% is applied. Locked values and all non-profile network fields stay fixed.

p = leotherm.validateDeviceCalibrationProfile(p, network);
selected = p.parameters(p.parameters.estimate, :);
count = height(selected);
emptyVector = isempty(freeParameters) && ismatrix(freeParameters) ...
    && (isequal(size(freeParameters), [0, 0]) ...
    || isequal(size(freeParameters), [0, 1]) ...
    || isequal(size(freeParameters), [1, 0]));
if ~isnumeric(freeParameters) || ~isreal(freeParameters) ...
        || ~(isvector(freeParameters) || emptyVector) ...
        || numel(freeParameters) ~= count || any(~isfinite(freeParameters(:)))
    error('leotherm:DeviceCalibrationParameters', ...
        'freeParameters must be a finite real vector with one value per estimated row.');
end
values = double(freeParameters(:));
if any(values < selected.lower | values > selected.upper)
    error('leotherm:DeviceCalibrationParameters', ...
        'freeParameters must lie inside the inclusive hard bounds.');
end
calibrated = network;
names = string(network.nodeNames(:));
for k = 1:count
    field = char(selected.field(k));
    node = find(names == selected.node(k), 1);
    % Promote edited numeric arrays so integer storage cannot truncate a fit.
    calibrated.(field) = double(calibrated.(field));
    if selected.field(k) == "conductanceWK"
        peer = find(names == selected.peer(k), 1);
        calibrated.conductanceWK(node, peer) = values(k);
        calibrated.conductanceWK(peer, node) = values(k);
    else
        calibrated.(field)(node) = values(k);
    end
end
leotherm.validateNetwork(calibrated);
end
