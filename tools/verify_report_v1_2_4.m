function verify_report_v1_2_4(mode)
%VERIFY_REPORT_V1_2_4 Reproducible report and numerical regression checks.
root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath('src');
if strcmp(mode,'test')
    files={'tests/test_report_pdf_merge.m','tests/test_orbital_harmonic_response.m','tests/test_report_details.m', ...
        'tests/test_report_result_audit.m','tests/test_hardening.m','tests/test_model_extensions.m'};
    r=runtests(files); disp(table(r)); assert(all([r.Passed]));
    save('results/report_v1_2_4_tests.mat','r');
    fprintf('TARGETED_TESTS_PASSED=%d\n',numel(r));
elseif strcmp(mode,'report')
    s=load('results/report_v1_2_3_release/thermal_report_data.mat','bundle');
    bundle=s.bundle;
    report=leotherm.writeThermalReport(bundle,'results/report_v1_2_4_release','both');
    disp(report.pdfPageCounts); disp(report.harmonicResponse.phaseDelayS);
    disp(report.harmonicResponse.halfWindowDifferenceS);
    close all force; clear s bundle report; drawnow; pause(2);
else
    error('Unknown verification mode.');
end
end
