function [arcs, segmentId] = minxss_segments(timeS, jd, accepted, p)
%MINXSS_SEGMENTS A rejected row is always a discontinuity, even at short gaps.
rows = find(accepted);
segmentId = zeros(numel(timeS),1);
arcs = struct('rows',{},'split',{},'day',{},'durationS',{},'id',{});
if isempty(rows), return; end
starts = [1; find(diff(rows)~=1 | diff(timeS(rows))>p.maximumGapS ...
    | diff(timeS(rows))<=0)+1];
ends = [starts(2:end)-1; numel(rows)];
for k = 1:numel(starts)
    r = rows(starts(k):ends(k));
    segmentId(r) = k;
    if timeS(r(end))-timeS(r(1)) < p.minimumArcS, continue; end
    startDay = floor(jd(r(1))-0.5)+0.5;
    endDay = floor(jd(r(end))-0.5)+0.5;
    if startDay < p.trainBeforeJD && endDay < p.trainBeforeJD
        split = 'train';
    elseif startDay >= p.trainBeforeJD && endDay < p.testFromJD
        split = 'validation';
    elseif startDay >= p.testFromJD
        split = 'test';
    else
        continue
    end
    item.rows = r;
    item.split = split;
    item.day = char(datetime(startDay,'ConvertFrom','juliandate','Format','yyyy-MM-dd'));
    item.durationS = timeS(r(end))-timeS(r(1));
    item.id = sprintf('arc_%06d',r(1));
    arcs(end+1) = item; %#ok<AGROW>
end
end
