function notifyProgress(callback, stage, completed, total, messageZh, messageEn)
%NOTIFYPROGRESS Deliver observational progress and honor cooperative stopping.
if isempty(callback), return; end
if ~isa(callback,'function_handle')
    error('leotherm:InvalidProgress','Progress must be empty or a function handle.');
end
event=struct('stage',stage,'completed',completed,'total',total, ...
    'messageZh',messageZh,'messageEn',messageEn);
cancelled=callback(event);
if ~islogical(cancelled) || ~isscalar(cancelled)
    error('leotherm:InvalidProgress','Progress callback must return a scalar logical cancellation flag.');
end
if cancelled
    error('leotherm:OperationCancelled','Operation stopped at a progress checkpoint.');
end
end
