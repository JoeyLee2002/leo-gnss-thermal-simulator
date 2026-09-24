function fit = minxss_fit_bounded(objective,bounds,settings,checkpointPrefix)
%MINXSS_FIT_BOUNDED Use the shared bounded, convergence-audited calibrator.
if nargin < 4, checkpointPrefix = ''; end
fit = leotherm.fitThermalParameters(objective,bounds,settings,checkpointPrefix);
end
