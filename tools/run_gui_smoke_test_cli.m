try
    run_gui_smoke_test;
    exit(0);
catch exception
    root = fileparts(fileparts(mfilename('fullpath')));
    versionTag = strrep(strtrim(fileread(fullfile(root, 'VERSION'))), '.', '_');
    failureDir = fullfile(root, 'results', ['gui_smoke_v' versionTag]);
    if ~exist(failureDir, 'dir')
        mkdir(failureDir);
    end
    file = fopen(fullfile(failureDir, 'gui_smoke_failure.txt'), 'w');
    if file >= 0
        fprintf(file, '%s\n', getReport(exception, 'extended'));
        fclose(file);
    end
    exit(1);
end
