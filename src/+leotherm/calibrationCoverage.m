function coverage = calibrationCoverage(reports,split,settings)
%CALIBRATIONCOVERAGE Audit actual scored intervals; gaps never add duration.
roles = ["train","validation","test"]; parts = {};
for k = 1:3
    samples = reports{k}.samples;
    days = split.day_utc(split.role == roles(k));
    epochs = samples.epoch_utc; epochs.TimeZone = 'UTC';
    key = dateshift(epochs,'start','day'); key.Format = 'yyyy-MM-dd'; key = string(key);
    for d = 1:numel(days)
        for node = reports{k}.metrics.node'
            s = samples(samples.used & key == days(d) & samples.node == node,:);
            duration = 0; longest = 0; span = 0; count = height(s);
            if count > 0
                span = max(s.observed_k)-min(s.observed_k);
                elapsed = seconds(diff(s.epoch_utc));
                connected = diff(s.source_row) == 1 & diff(s.segment_id) == 0 ...
                    & elapsed > 0 & elapsed <= settings.telemetryOptions.maxGapS;
                duration = sum(elapsed(connected));
                accumulated = 0;
                for j = 1:numel(elapsed)
                    if connected(j), accumulated = accumulated+elapsed(j); else, accumulated = 0; end
                    longest = max(longest,accumulated);
                end
            end
            enough = count >= settings.minimumScoredSamples ...
                && duration >= settings.minimumCoverageS && longest >= settings.minimumContinuousS ...
                && span >= settings.minimumTemperatureSpanK;
            parts{end+1,1} = table(roles(k),days(d),node,count,duration,longest,span,enough, ...
                'VariableNames',{'role','day_utc','node','scored_samples', ...
                'scored_duration_s','longest_continuous_s','temperature_span_k','sufficient'}); %#ok<AGROW>
        end
    end
end
coverage = vertcat(parts{:});
end
