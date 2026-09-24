function biasM = temperatureCodeBias(temperatureK, biasConfig)
%TEMPERATURECODEBIAS Map node temperature anomalies to synthetic code bias.

reference = median(temperatureK, 1);
anomaly = temperatureK - reference;
biasM = anomaly * biasConfig.linearMPerK(:);
if biasConfig.quadraticMPerK2 ~= 0
    node = biasConfig.quadraticNode;
    squared = anomaly(:, node).^2;
    biasM = biasM + biasConfig.quadraticMPerK2 .* (squared - median(squared));
end
biasM = biasM - median(biasM);
end

