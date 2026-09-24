function boundary = normalizeCouplingOptions(options, volumeMesh)
%NORMALIZECOUPLINGOPTIONS Fill only missing explicit boundary-option fields.
if nargin < 1 || isempty(options), options = struct; end
if nargin < 2, volumeMesh = []; end
if ~isstruct(options) || ~isscalar(options)
    error('leotherm:InvalidCouplingOptions', 'Coupling options must be a scalar structure.');
end
boundary = leotherm.defaultCouplingOptions;
if isfield(options, 'contacts'), boundary.contacts = options.contacts; end
if isfield(options, 'volumeThermal') && ~isempty(options.volumeThermal)
    if ~isstruct(options.volumeThermal) || ~isscalar(options.volumeThermal)
        error('leotherm:InvalidCouplingOptions', 'volumeThermal must be a scalar structure.');
    end
    names = fieldnames(options.volumeThermal);
    for k = 1:numel(names)
        boundary.volumeThermal.(names{k}) = options.volumeThermal.(names{k});
    end
end
leotherm.validateCouplingOptions(boundary, volumeMesh);
end
