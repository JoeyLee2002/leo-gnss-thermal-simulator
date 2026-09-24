function split = calibrationDaySplit(data)
%CALIBRATIONDAYSPLIT Whole UTC days; no automatically chosen test data.
if ~isfield(data,'epoch') || ~isdatetime(data.epoch) || isempty(data.epoch.TimeZone)
    error('leotherm:DeviceCalibrationSplit','Telemetry needs explicitly zoned epochs.');
end
epoch = data.epoch; epoch.TimeZone = 'UTC';
day = dateshift(epoch(~isnat(epoch)),'start','day');
day.Format = 'yyyy-MM-dd';
day_utc = string(unique(day));
split = table(day_utc,repmat("exclude",numel(day_utc),1),'VariableNames',{'day_utc','role'});
end
