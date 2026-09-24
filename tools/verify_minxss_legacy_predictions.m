function summary = verify_minxss_legacy_predictions(previousRun, outputDirectory)
%VERIFY_MINXSS_LEGACY_PREDICTIONS Replay frozen old inputs without refitting.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'src'),fullfile(root,'studies','minxss'));
assert(~isfolder(outputDirectory),'Use a new regression output directory.');
path=fullfile(previousRun,'results.mat');
before=minxss_hash_file(path);
s=load(path,'records','predictions','frozen');
rows=cell(numel(s.records)*2,3); count=0;
for k=1:numel(s.records)
    for kind={'one_node','two_node'}
        field='one'; if strcmp(kind{1},'two_node'),field='two';end
        actual=minxss_panel_predict(s.records(k).input,s.frozen.(field).parameters, ...
            kind{1},s.frozen.protocol);
        delta=max(abs(actual-s.predictions(k).(kind{1})),[],'all');
        count=count+1; rows(count,:)={s.records(k).id,kind{1},delta};
    end
end
summary=cell2table(rows,'VariableNames',{'arc','model','maximum_difference_K'});
assert(strcmp(before,minxss_hash_file(path)),'The original result changed.');
assert(all(summary.maximum_difference_K<1e-10),'Legacy trajectories changed.');
mkdir(outputDirectory);
writetable(summary,fullfile(outputDirectory,'legacy_prediction_regression.csv'));
save(fullfile(outputDirectory,'regression.mat'),'summary','before','previousRun');
fprintf('LEGACY_REPLAY_CASES=%d MAX_DELTA_K=%.12g ORIGINAL_SHA256=%s\n', ...
    height(summary),max(summary.maximum_difference_K),before);
end
