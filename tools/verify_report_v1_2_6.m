function verify_report_v1_2_6(mode)
%VERIFY_REPORT_V1_2_6 Test synthesis and regenerate bilingual reference reports.
root=fileparts(fileparts(mfilename('fullpath')));
cd(root); addpath('src'); set(groot,'DefaultFigureVisible','off');
switch mode
    case 'test'
        files={'src/+leotherm/buildThermalReportSynthesis.m', ...
            'src/+leotherm/writeThermalReport.m','src/+leotherm/writeThermalPdfReport.m', ...
            'tests/test_report_synthesis.m','tools/verify_report_v1_2_6.m'};
        for k=1:numel(files)
            findings=checkcode(files{k},'-id');
            if ~isempty(findings), disp(files{k}); disp(findings); end
            assert(isempty(findings));
        end
        r=runtests({'tests/test_report_synthesis.m','tests/test_report_details.m', ...
            'tests/test_report_metadata.m','tests/test_report_pdf_merge.m'});
        disp(table(r)); assert(all([r.Passed]));
        fprintf('SYNTHESIS_TESTS_PASSED=%d\n',numel(r));
    case 'report'
        saved=load('results/report_v1_2_5_release/thermal_report_data.mat','bundle');
        bundle=saved.bundle;
        report=leotherm.writeThermalReport(bundle,'results/report_v1_2_6_release','both');
        disp(report.synthesis.overview.linesZh'); disp(report.synthesis.conclusion.linesZh');
        disp(report.pdfPageCounts);
        assert(~isempty(report.synthesis.evidence));
        fprintf('SYNTHESIS_REPORT_COMPLETE\n');
    otherwise
        error('Unknown verification mode.');
end
close all force;
end
