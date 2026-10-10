function verify_report_v1_2_9(sourceFile,outputDirectory)
%VERIFY_REPORT_V1_2_9 Check scalar reporting without changing thermal results.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath('src');
set(groot,'DefaultFigureVisible','off');
files={'buildThermalReportDetails','reportLagExplanation','writeThermalPublicationFigures'};
for k=1:numel(files)
    findings=checkcode(fullfile('src','+leotherm',[files{k} '.m']),'-id');
    if ~isempty(findings), disp(findings); end
    assert(isempty(findings));
end
tests=runtests({'tests/test_report_scalar_lag.m','tests/test_report_figure_style.m', ...
    'tests/test_report_details.m','tests/test_report_synthesis.m', ...
    'tests/test_report_body_layout.m','tests/test_report_result_audit.m', ...
    'tests/test_report_pdf_merge.m'});
disp(table(tests)); assert(all([tests.Passed]));
fprintf('REPORT_REGRESSION_PASSED=%d\n',numel(tests));
saved=load(sourceFile,'bundle');
report=leotherm.writeThermalReport(saved.bundle,outputDirectory,'both');
after=load(fullfile(outputDirectory,'thermal_report_data.mat'),'bundle');
assert(isequaln(saved.bundle,after.bundle));
assert(report.phaseDiagnostics.identifiablePeakCycles==1);
assert(~any(strcmp({report.details.stage},'lag_detail')));
assert(~isfile(fullfile(outputDirectory,'detail_lag_detail_en.png')));
disp(report.pdfPageCounts);
fprintf('SCALAR_REPORT_COMPLETE\n'); close all force;
end
