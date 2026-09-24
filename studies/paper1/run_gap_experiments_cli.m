try
    diary(fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
        'results', 'paper1_gap_v0_5_1_paper', 'matlab_diary.txt'));
    fprintf('gap CLI started\n');
    addpath(fileparts(mfilename('fullpath')));
    run_gap_experiments('paper');
    fprintf('gap CLI completed\n');
    diary off;
    exit(0);
catch exception
    fprintf(2, '%s\n', getReport(exception, 'extended'));
    diary off;
    exit(1);
end
