function [samples, factors] = sampleUncertainty(model, nSamples, seed, ranges)
%SAMPLEUNCERTAINTY Generate reproducible stratified parameter perturbations.
%   SAMPLES is a struct array with fields model, factors and sample. Factors
%   are ordered [capacity conductance power absorptivity emissivity].
if nargin < 2 || isempty(nSamples), nSamples = 1; end
if nargin < 3 || isempty(seed), seed = 0; end
if nargin < 4 || isempty(ranges), ranges = defaultRanges; end
if ~isstruct(model) || ~isscalar(model) || ~isfield(model, 'network')
    model = leotherm.model.normalize(model);
else
    leotherm.model.validate(model);
end
if ~isnumeric(nSamples) || ~isscalar(nSamples) || ~isfinite(nSamples) || nSamples < 1 || nSamples ~= floor(nSamples)
    error('leotherm:modelInvalidUncertainty', 'nSamples must be a positive integer.');
end
if ~isnumeric(seed) || ~isscalar(seed) || ~isfinite(seed) || seed < 0 || seed ~= floor(seed)
    error('leotherm:modelInvalidUncertainty', 'seed must be a nonnegative integer.');
end
ranges = validateRanges(ranges);
stream = RandStream('mt19937ar', 'Seed', seed);
unit = zeros(nSamples, 5);
for k = 1:5
    values = ((0:nSamples-1)' + rand(stream, nSamples, 1)) / nSamples;
    unit(:, k) = values(randperm(stream, nSamples));
end
half = [ranges.capacity, ranges.conductance, ranges.power, ranges.absorptivity, ranges.emissivity];
factors = 1 + (2 * unit - 1) .* half;
samples = repmat(struct('sample', 0, 'seed', seed, 'factors', zeros(1,5), 'model', model), nSamples, 1);
for k = 1:nSamples
    candidate = model;
    candidate.network = perturbNetwork(model.network, factors(k, :));
    candidate.provenance = leotherm.model.parameterProvenance(candidate.network, candidate.geometry, candidate.volumeMesh, ...
        struct('source', 'stratified_uniform_uncertainty', 'status', 'perturbed'));
    candidate.uncertainty.enabled = true;
    candidate.uncertainty.seed = seed;
    candidate.uncertainty.sampleCount = nSamples;
    candidate.uncertainty.halfRanges = ranges;
    candidate.uncertainty.source = 'stratified_uniform_uncertainty';
    leotherm.model.validate(candidate);
    samples(k).sample = k;
    samples(k).factors = factors(k, :);
    samples(k).model = candidate;
end
end

function network = perturbNetwork(base, factors)
network = base;
network.capacityJK = base.capacityJK * factors(1);
network.conductanceWK = base.conductanceWK * factors(2);
network.internalPowerW = base.internalPowerW * factors(3);
network.solarAbsorptivity = min(max(base.solarAbsorptivity * factors(4), 0), 1);
network.irEmissivity = min(max(base.irEmissivity * factors(5), 0), 1);
leotherm.validateNetwork(network);
end

function ranges = defaultRanges
ranges = struct('capacity', 0.20, 'conductance', 0.30, 'power', 0.20, ...
    'absorptivity', 0.12, 'emissivity', 0.08);
end

function ranges = validateRanges(ranges)
fields = {'capacity','conductance','power','absorptivity','emissivity'};
if ~isstruct(ranges) || ~isscalar(ranges), error('leotherm:modelInvalidUncertainty', 'ranges must be a scalar structure.'); end
for k = 1:numel(fields)
    f = fields{k};
    if ~isfield(ranges, f) || ~isnumeric(ranges.(f)) || ~isscalar(ranges.(f)) || ~isfinite(ranges.(f)) || ranges.(f) < 0 || ranges.(f) >= 1
        error('leotherm:modelInvalidUncertainty', 'ranges.%s must lie in [0,1).', f);
    end
end
end
