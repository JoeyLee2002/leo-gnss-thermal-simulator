function verify_report_v1_2_8(sourceFile, outputDirectory)
%VERIFY_REPORT_V1_2_8 Exercise publication-style plots and unchanged results.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath('src');
if nargin<1
    sourceFile=fullfile(root,'results','report_v1_2_6_release','thermal_report_data.mat');
end
if nargin<2, outputDirectory=fullfile(root,'results',['report_v1_2_8_' datestr(now,'yyyymmdd_HHMMSS')]); end
set(groot,'DefaultFigureVisible','off');
files={'thermalFigureStyle','thermalFigureLabels','styleThermalFigure','exportThermalFigure', ...
    'plotThermalReportDetail','plotThermalReportStage','plotScenario','plotSweep', ...
    'writeThermalPublicationFigures','writeThermalReport'};
for k=1:numel(files)
    findings=checkcode(fullfile('src','+leotherm',[files{k} '.m']),'-id');
    if ~isempty(findings), disp(files{k}); disp(findings); end
    assert(isempty(findings));
end
r=runtests({'tests/test_report_figure_style.m','tests/test_report_details.m', ...
    'tests/test_report_synthesis.m','tests/test_report_body_layout.m', ...
    'tests/test_report_result_audit.m','tests/test_report_pdf_merge.m'});
disp(table(r)); assert(all([r.Passed]));
fprintf('FIGURE_REGRESSION_PASSED=%d\n',numel(r));
saved=load(sourceFile,'bundle');
report=leotherm.writeThermalReport(saved.bundle,outputDirectory,'both');
after=load(fullfile(outputDirectory,'thermal_report_data.mat'),'bundle');
assert(isequaln(saved.bundle,after.bundle));
disp(report.pdfPageCounts);
fprintf('REPORT_FIGURES_COMPLETE\n'); close all force;
end
