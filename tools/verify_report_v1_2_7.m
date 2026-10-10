function verify_report_v1_2_7
%VERIFY_REPORT_V1_2_7 Verify report layout and regenerate reference artifacts.
root=fileparts(fileparts(mfilename('fullpath')));
cd(root); addpath('src'); set(groot,'DefaultFigureVisible','off');
files={'src/+leotherm/drawReportBodyLine.m','src/+leotherm/writeThermalPdfReport.m', ...
    'src/+leotherm/writeThermalReport.m','tests/test_report_body_layout.m', ...
    'tools/verify_report_v1_2_7.m'};
for k=1:numel(files)
    findings=checkcode(files{k},'-id');
    if ~isempty(findings), disp(files{k}); disp(findings); end
    assert(isempty(findings));
end
r=runtests({'tests/test_report_body_layout.m','tests/test_report_synthesis.m', ...
    'tests/test_report_pdf_merge.m'});
disp(table(r)); assert(all([r.Passed]));
fprintf('REPORT_LAYOUT_TESTS_PASSED=%d\n',numel(r));
saved=load('results/report_v1_2_6_release/thermal_report_data.mat','bundle');
report=leotherm.writeThermalReport(saved.bundle,'results/report_v1_2_7_final','both');
assert(~isempty(report.synthesis.evidence));
disp(report.pdfPageCounts);
addpath('examples'); create_example_projects;
fprintf('REPORT_LAYOUT_COMPLETE\n');
close all force;
end
