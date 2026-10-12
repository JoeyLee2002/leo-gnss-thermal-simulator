function run = paper_example_revision4(outputDirectory)
%PAPER_EXAMPLE_REVISION4 Compatibility entry for the current paper workflow.
if nargin<1 || isempty(outputDirectory)
    outputDirectory=fullfile(leotherm.installRoot,'results','softwarex_paper');
end
study=leotherm.runPaperStudy(outputDirectory,'both');
run=study.reference;
end
