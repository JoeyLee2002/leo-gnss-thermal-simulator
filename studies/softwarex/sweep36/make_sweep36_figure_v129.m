function make_sweep36_figure_v129(dataDirectory, figureDirectory)
%MAKE_SWEEP36_FIGURE_V129 Compatibility entry using the production renderer.
[~,~,defaultOutput]=sweep36_paths;
if nargin<1 || isempty(dataDirectory), dataDirectory=defaultOutput; end
if nargin<2 || isempty(figureDirectory), figureDirectory=fullfile(defaultOutput,'figures'); end
figureDirectory=sweep36_safe_output(figureDirectory);
if ~isfolder(figureDirectory), mkdir(figureDirectory); end
data=readtable(fullfile(dataDirectory,'sweep36_summary.csv'));
p=struct('summary',table2struct(data));
refinement=fullfile(dataDirectory,'time_refinement.csv');
if isfile(refinement), p.refinement=table2struct(readtable(refinement)); end
item=leotherm.buildPaperStudyReport(struct('metadata',struct('paperStudy',p)));
for language={'en','zh'}
    lang=language{1}; file=['Figure_5_sweep36_' lang '.png'];
    leotherm.plotThermalReportDetail(item,fullfile(figureDirectory,file),lang);
end
save(fullfile(figureDirectory,'Figure_5_sweep36_source.mat'),'data','item');
end
