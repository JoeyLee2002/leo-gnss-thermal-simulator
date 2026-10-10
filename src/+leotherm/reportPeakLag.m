function phase = reportPeakLag(result)
%REPORTPEAKLAG Recompute phase diagnostics instead of trusting cached metrics.
phase = [];
if ~isstruct(result) || ~all(isfield(result,{'timeS','loads','network','orbit','temperatureK'}))
    return
end
n = result.network; response = [];
if isfield(n,'roles') && isfield(n.roles,'response'), response = n.roles.response; end
if isempty(response), response = find(strcmp(n.nodeNames,'gnss_rf_frontend'),1); end
if isempty(response), return; end
phase = leotherm.orbitalPeakLagMetrics(result.timeS,sum(result.loads.totalExternalW,2), ...
    result.temperatureK(:,response),result.orbit.periodS);
end
