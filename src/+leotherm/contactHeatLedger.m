function ledger = contactHeatLedger(contact, temperatureK)
%CONTACTHEATLEDGER Evaluate signed contact heat flows and cancellation.
if ~isstruct(contact) || ~isfield(contact,'nodeCount') || ~isfield(contact,'interfaces')
    error('leotherm:InvalidContactInterface','Invalid assembled contact object.');
end
if ~isnumeric(temperatureK) || ~isvector(temperatureK) || numel(temperatureK) ~= contact.nodeCount || any(~isfinite(temperatureK(:)))
    error('leotherm:InvalidContactInterface','temperatureK must be a finite node vector.');
end
temperatureK = temperatureK(:);
n = numel(contact.interfaces);
entries = repmat(struct('name','','heatFlowW',0,'leftTemperatureK',0,'rightTemperatureK',0),n,1);
nodePower = zeros(contact.nodeCount,1);
for k = 1:n
    it = contact.interfaces(k); left = it.leftNodes(:); right = it.rightNodes(:); g = it.conductanceWK;
    Tl = temperatureK(left); Tr = temperatureK(right);
    q = sum(sum(g .* (Tl - Tr')));
    entries(k).name = it.name; entries(k).heatFlowW = q;
    entries(k).leftTemperatureK = mean(Tl); entries(k).rightTemperatureK = mean(Tr);
    for a=1:numel(left), nodePower(left(a)) = nodePower(left(a)) - sum(g(a,:) .* (Tl(a)-Tr')); end
    for b=1:numel(right), nodePower(right(b)) = nodePower(right(b)) + sum(g(:,b) .* (Tl-Tr(b))); end
end
ledger = struct('interfaces',entries,'nodePowerW',nodePower, ...
    'totalInternalPowerW',sum(nodePower),'maxCancellationResidualW',abs(sum(nodePower)));
end
