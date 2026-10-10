function verify_report_v1_2_5(mode)
%VERIFY_REPORT_V1_2_5 Metadata regression and reference report reproduction.
root = fileparts(fileparts(mfilename('fullpath')));
cd(root); addpath('src'); set(groot, 'DefaultFigureVisible', 'off');
switch mode
    case 'test'
        files = {'src/+leotherm/propagateCircularOrbit.m', ...
            'src/+leotherm/reportMetadataText.m','src/+leotherm/writeThermalReport.m', ...
            'src/+leotherm/writeThermalPdfReport.m','tests/test_report_metadata.m', ...
            'tests/test_unified_report.m','tools/verify_report_v1_2_5.m'};
        total = 0;
        for k = 1:numel(files)
            findings = checkcode(files{k}, '-id');
            total = total + numel(findings);
            if ~isempty(findings), disp(files{k}); disp(findings); end
        end
        fprintf('CODE_ANALYZER_FINDINGS=%d\n', total);
        assert(total == 0);
        r = runtests({'tests/test_report_metadata.m','tests/test_unified_report.m', ...
            'tests/test_report_pdf_merge.m','tests/test_model_extensions.m'});
        disp(table(r)); assert(all([r.Passed]));
        fprintf('METADATA_TESTS_PASSED=%d\n', numel(r));
    case 'report'
        saved = load('results/report_v1_2_4_release/thermal_report_data.mat', 'bundle');
        bundle = saved.bundle;
        old = bundle.scenario;
        bundle.scenario = leotherm.simulateScenario(old.scenario, old.network);
        delta = max(abs(bundle.scenario.temperatureK(:) - old.temperatureK(:)));
        assert(delta < 1e-9, 'Thermal history changed in a metadata-only patch.');
        report = leotherm.writeThermalReport(bundle, 'results/report_v1_2_5_release', 'both');
        fprintf('REFERENCE_MAX_TEMPERATURE_CHANGE_K=%.16g\n', delta);
        disp(report.pdfPageCounts);
    otherwise
        error('Unknown verification mode.');
end
close all force;
end
