function out = reportHarmonicResponse(result)
%REPORTHARMONICRESPONSE Derive the same metric used by the simulation engine.
out=[];
if ~isstruct(result) || ~all(isfield(result,{'timeS','loads','network','orbit','temperatureK'})), return; end
n=result.network; response=[];
if isfield(n,'roles') && isfield(n.roles,'response'), response=n.roles.response; end
if isempty(response), response=find(strcmp(n.nodeNames,'gnss_rf_frontend'),1); end
if isempty(response), return; end
out=leotherm.orbitalHarmonicResponse(result.timeS,sum(result.loads.totalExternalW,2), ...
    result.temperatureK(:,response),result.orbit.periodS);
end
