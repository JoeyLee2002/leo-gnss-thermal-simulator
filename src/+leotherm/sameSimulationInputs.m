function same = sameSimulationInputs(leftScenario,leftNetwork,rightScenario,rightNetwork,leftGeometry,rightGeometry)
%SAMESIMULATIONINPUTS Labels do not affect physics; every physical field does.
same = isequaln(normalizeScenario(leftScenario),normalizeScenario(rightScenario)) ...
    && isequaln(withoutName(leftNetwork),withoutName(rightNetwork));
if nargin >= 6
    same = same && isequaln(leftGeometry, rightGeometry);
end
end

function s = normalizeScenario(s)
s = withoutName(s);
if ~isfield(s.environment,'earthIRModel'), s.environment.earthIRModel = 'legacy_cosine'; end
if isempty(s.startEpoch.TimeZone), s.startEpoch.TimeZone = 'UTC'; end
s.startEpoch.TimeZone = 'UTC';
end

function s = withoutName(s)
if isfield(s,'name'), s = rmfield(s,'name'); end
end
