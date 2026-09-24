function requireCalibrationConvergence(fit)
%REQUIRECALIBRATIONCONVERGENCE Prevent incomplete fits from being frozen.
if ~isstruct(fit) || ~isfield(fit,'converged') || ~isequal(fit.converged,true) ...
        || ~isfield(fit,'objective') || ~isscalar(fit.objective) || ~isfinite(fit.objective)
    error('leotherm:CalibrationNotConverged', ...
        'The best calibration has not converged. Retain diagnostics; do not freeze or claim validation.');
end
end
