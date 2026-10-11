function run = paper_example_revision4(outputDirectory)
%PAPER_EXAMPLE_REVISION4 Run the reference task and the 36-case research study.
if nargin<1, outputDirectory=[]; end
[~,~,root]=sweep36_paths(outputDirectory);
task=leotherm.createThermalPipelineTask;
task.language='en';
task.scenario.name='reference_network_report_demo';
task.scenario.durationS=7200;
task.scenario.timeStepS=60;
task.scenario.warmupOrbits=0;
task.scenario.convergence.enabled=false;
task.sweep.enabled=false;
audit=leotherm.preflightThermalPipeline(task);
assert(audit.ready,strjoin(cellstr(audit.errors),newline));
destination=fullfile(root,'reference');
assert(~isfolder(destination),'Choose a new directory for a new reference run.');
run=leotherm.runThermalPipeline(task,destination);
assert(strcmp(run.status,'complete'));
summary=run_paper_sweep36_v129(fullfile(root,'sweep36'));
assert(height(summary)==36);
make_sweep36_figure_v129(fullfile(root,'sweep36'),fullfile(root,'figures'));
audit_sweep36_v129(fullfile(root,'sweep36'),fullfile(root,'audit.csv'));
fprintf('PAPER_REVISION4_REFERENCE_AND_SWEEP_COMPLETE\n');
end
