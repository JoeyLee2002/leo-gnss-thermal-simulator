function run = paper_example_v1_2_9(outputDirectory)
%PAPER_EXAMPLE_V1_2_9 Reproduce the six-case SoftwareX reference task.
if nargin<1 || isempty(outputDirectory)
    outputDirectory=fullfile(pwd,'paper_run_v1_2_9');
end
assert(isfolder('src') && isfile('VERSION'), ...
    'Start MATLAB in the root of the LEOTherm source release.');
addpath('src');
assert(strcmp(leotherm.version,'1.2.9'),'This example targets LEOTherm 1.2.9.');
task=leotherm.createThermalPipelineTask;
task.language='en';
task.scenario.name='reference_network_report_demo';
task.scenario.durationS=7200;
task.scenario.timeStepS=60;
task.scenario.warmupOrbits=0;
task.scenario.convergence.enabled=false;
task.sweep.enabled=true;
task.sweep.mode='beta_altitude';
task.sweep.altitudeKm=[500 600];
task.sweep.betaDeg=[0 15 30];
task.sweep.branch=1;
audit=leotherm.preflightThermalPipeline(task);
assert(audit.ready,strjoin(cellstr(audit.errors),newline));
run=leotherm.runThermalPipeline(task,outputDirectory);
assert(strcmp(run.status,'complete'));
assert(height(run.sweep)==6 && all(strcmp(run.sweep.status,'complete')));
fprintf('PAPER_TASK_COMPLETE=%s\n',outputDirectory);
end
