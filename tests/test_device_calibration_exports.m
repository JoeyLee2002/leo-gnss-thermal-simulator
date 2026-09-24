function tests = test_device_calibration_exports
tests = functiontests(localfunctions);
end

function testRelativeExportRoundTripUtcPlotsAndNoOverwrites(testCase)
originalFolder = pwd;
originalPath = path;
originalVisible = get(groot, 'DefaultFigureVisible');
originalClose = get(groot, 'DefaultFigureCloseRequestFcn');
root = tempname;
mkdir(root);
testCase.addTeardown(@restoreEnvironment, originalFolder, originalPath, ...
    originalVisible, originalClose, root);
snapshots = {};
captureErrors = {};
testFolder = fileparts(mfilename('fullpath'));
addpath(testFolder, fullfile(fileparts(testFolder), 'src'));
cd(root);
set(groot, 'DefaultFigureVisible', 'off', ...
    'DefaultFigureCloseRequestFcn', @captureClosingFigure);

f = deviceCalibrationFixture(3);
gapRows = (20:f.samplesPerDay:height(f.raw))';
drivers = f.data;
drivers.accepted(gapRows) = false;
truth = leotherm.simulateTelemetry(drivers, f.scenario, f.trueNetwork, ...
    f.settings.telemetryOptions);
assertTrue(testCase, all(truth.segments.status == "complete"));
f.raw.temperature_k_device = truth.temperatureK + f.noiseK;
f.raw.temperature_k_device(gapRows) = NaN;
f.raw.quality(gapRows) = 0; % A rejected driving record must break every plotted prediction.
f.data = leotherm.readTelemetry(f.raw, [], f.network);
f.data.epoch.TimeZone = 'Asia/Shanghai';
utcSplit = leotherm.calibrationDaySplit(f.data);
assertEqual(testCase, utcSplit.day_utc, f.split.day_utc);

% Harmless formula-shaped text is evidence data, never executable test input.
evidence = ["=1+1"; "+SUM(1,2)"; "-1+2"; "@SUM(1,2)"; ...
    string(sprintf('\t=1+1')); "Plain synthetic assumption only."];
assertEqual(testCase, height(f.profile.parameters), numel(evidence));
f.profile.parameters.evidence = evidence;
relativeOutput = fullfile('relative exports', 'calibration run');
output = canonicalPath(fullfile(root, relativeOutput));
% Fail before writing if Java and MATLAB disagree about the current folder.
assertEqual(testCase, canonicalPath(relativeOutput), output, ...
    'Relative export paths must resolve inside the temporary working folder.');
r = leotherm.calibrateTelemetry(f.data, f.scenario, f.network, ...
    f.profile, f.split, f.settings, relativeOutput);
assertEqual(testCase, r.outputDirectory, output);
assertTrue(testCase, r.fit.converged);
verifyFalse(testCase, r.passed);
verifyTrue(testCase, all(r.parameterReport.within_bounds));
verifyFalse(testCase, any(ismember(r.samples.source_row, gapRows)));
verifyEmpty(testCase, captureErrors);
assertEqual(testCase, numel(snapshots), 8);

verifyMatRoundTrip(testCase, output, f, r, evidence);
verifyCsvRoundTrip(testCase, output, r, evidence);
verifyFigureFiles(testCase, output, f.split);
verifyFigureData(testCase, snapshots, r, f, gapRows);
manifest = verifyManifest(testCase, output);
manifestPath = fullfile(output, 'artifact_manifest.csv');
manifestBytes = fileBytes(manifestPath);

verifyError(testCase, @() leotherm.calibrateTelemetry(f.data, f.scenario, ...
    f.network, f.profile, f.split, f.settings, relativeOutput), ...
    'leotherm:DeviceCalibrationExport');
verifyError(testCase, @() leotherm.writeDeviceCalibrationResults(r, relativeOutput), ...
    'leotherm:DeviceCalibrationExport');
for language = {'zh', 'en'}
    verifyError(testCase, @() leotherm.plotDeviceCalibration(r, ...
        fullfile(output, ['figures_' language{1}]), language{1}), ...
        'leotherm:DeviceCalibrationExport');
end
verifyError(testCase, @() leotherm.plotDeviceCalibration(r, ...
    fullfile(output, 'report_en.md'), 'en'), 'leotherm:DeviceCalibrationExport');
verifyEqual(testCase, fileBytes(manifestPath), manifestBytes);
verifyEqual(testCase, verifyManifest(testCase, output), manifest);
verifyEqual(testCase, numel(snapshots), 8);
verifyEmpty(testCase, captureErrors);

    function captureClosingFigure(fig, ~)
        % close(fig) invokes this before deletion, after both real exports.
        closeCleanup = onCleanup(@() deleteIfValid(fig));
        try
            snapshots{end + 1} = figureSnapshot(fig);
        catch exception
            captureErrors{end + 1} = exception.message;
        end
    end

end

function verifyMatRoundTrip(testCase, output, f, r, evidence)
original = load(fullfile(output, 'original_device.mat'));
calibrated = load(fullfile(output, 'calibrated_device.mat'));
protocol = load(fullfile(output, 'protocol_before_fit.mat'), 'protocol');
frozen = load(fullfile(output, 'frozen_before_checks.mat'), 'frozen');
saved = load(fullfile(output, 'calibration_result.mat'), 'result');
input = load(fullfile(output, 'input_snapshot.mat'), 'data');
profiles = {original.profile, calibrated.profile, protocol.protocol.profile, ...
    frozen.frozen.profileBefore, frozen.frozen.profileAfter, ...
    saved.result.profileBefore, saved.result.profileAfter};
for k = 1:numel(profiles)
    verifyEqual(testCase, profiles{k}.parameters.evidence, evidence);
    verifyEqual(testCase, profiles{k}.parameters, f.profile.parameters);
    verifyEqual(testCase, profiles{k}.referenceNetwork, f.network);
end
verifyEqual(testCase, original.network, f.network);
verifyEqual(testCase, original.scenario, f.scenario);
verifyEqual(testCase, calibrated.network, r.profileAfter.calibratedNetwork);
verifyEqual(testCase, calibrated.scenario, f.scenario);
verifyEqual(testCase, calibrated.calibrationStatus, r.status);
verifyEqual(testCase, saved.result.parameterReport, r.parameterReport);
verifyEqual(testCase, saved.result.outputDirectory, output);
verifyTrue(testCase, isequaln(input.data, f.data));
for k = 1:3
    verifyTrue(testCase, isequaln(saved.result.prediction{k}.temperatureK, ...
        r.prediction{k}.temperatureK));
end
verifyTrue(testCase, contains(fileread(fullfile(output, 'report_en.md')), ...
    'Synthetic data are not flight validation'));
verifyGreaterThan(testCase, numel(fileBytes(fullfile(output, 'report_zh.md'))), 100);
end

function verifyCsvRoundTrip(testCase, output, r, evidence)
t = readtable(fullfile(output, 'parameter_changes.csv'), 'TextType', 'string');
expected = evidence;
expected(1:5) = "'" + expected(1:5);
verifyEqual(testCase, t.evidence, expected);
verifyEqual(testCase, t.field, r.parameterReport.field);
verifyEqual(testCase, t.node, r.parameterReport.node);
for name = {'nominal', 'lower', 'upper', 'priorSigma', 'calibrated'}
    verifyEqual(testCase, t.(name{1}), r.parameterReport.(name{1}), 'AbsTol', 1e-10);
end
stages = readtable(fullfile(output, 'stage_metrics.csv'), 'TextType', 'string');
daily = readtable(fullfile(output, 'day_metrics.csv'), 'TextType', 'string');
samples = readtable(fullfile(output, 'scored_samples.csv'), 'TextType', 'string');
audit = readtable(fullfile(output, 'row_audit.csv'), 'TextType', 'string');
verifyEqual(testCase, stages.role, r.stageMetrics.role);
verifyEqual(testCase, daily.role, r.dayMetrics.role);
verifyEqual(testCase, stages.calibrated_rmse_k, r.stageMetrics.calibrated_rmse_k, ...
    'AbsTol', 1e-10);
verifyEqual(testCase, daily.calibrated_rmse_k, r.dayMetrics.calibrated_rmse_k, ...
    'AbsTol', 1e-10);
verifyEqual(testCase, samples.source_row, r.samples.source_row);
verifyEqual(testCase, samples.role, r.samples.role);
verifyEqual(testCase, audit.source_row, r.rowAudit.source_row);
verifyEqual(testCase, audit.calibration_role, r.rowAudit.calibration_role);
end

function verifyFigureFiles(testCase, output, split)
stems = strings(height(split)+1,1);
stems(1) = "Fig_C1_node_01_daily_errors";
for k = 1:height(split)
    stems(k + 1) = "Fig_C2_node_01_" + split.role(k) + "_" ...
        + erase(split.day_utc(k), '-');
end
for language = {'zh', 'en'}
    directory = fullfile(output, ['figures_' language{1}]);
    files = dir(directory);
    files = files(~[files.isdir]);
    expected = sort([stems + ".png"; stems + ".pdf"]);
    names = string({files.name});
    verifyEqual(testCase, sort(names(:)), expected);
    for k = 1:numel(stems)
        pixels = imread(fullfile(directory, char(stems(k) + ".png")));
        verifyGreaterThan(testCase, size(pixels, 1), 100);
        verifyGreaterThan(testCase, size(pixels, 2), 100);
        verifyGreaterThan(testCase, std(double(pixels(:))), 1);
        bytes = fileBytes(fullfile(directory, char(stems(k) + ".pdf")));
        assertGreaterThan(testCase, numel(bytes), 100);
        verifyEqual(testCase, char(bytes(1:5)'), '%PDF-');
    end
end
end

function snapshot = figureSnapshot(fig)
ax = findall(fig, 'Type', 'axes');
assert(isscalar(ax), 'Expected exactly one data axes per calibration figure.');
lines = flipud(findall(ax, 'Type', 'line'));
snapshot.title = string(ax.Title.String);
snapshot.visible = char(fig.Visible);
snapshot.xlim = ax.XLim;
snapshot.ylim = ax.YLim;
snapshot.tickPositions = ax.XTick(:);
snapshot.tickLabels = string(ax.XTickLabel);
snapshot.series = cell(numel(lines), 1);
for k = 1:numel(lines)
    snapshot.series{k} = struct('x', lines(k).XData(:), 'y', lines(k).YData(:));
end
legendHandle = findall(fig, 'Type', 'legend');
assert(isscalar(legendHandle), 'Expected one legend per calibration figure.');
snapshot.legend = string(legendHandle.String);
end

function verifyFigureData(testCase, snapshots, r, f, gapRows)
titles = strings(numel(snapshots), 1);
counts = zeros(numel(snapshots), 1);
for k = 1:numel(snapshots)
    snap = snapshots{k};
    titles(k) = snap.title;
    counts(k) = numel(snap.series);
    verifyEqual(testCase, snap.visible, 'off');
    verifyEqual(testCase, numel(snap.legend), counts(k));
    for j = 1:counts(k)
        line = snap.series{j};
        finite = isfinite(line.x) & isfinite(line.y);
        assertTrue(testCase, any(finite), 'Exported series must not be blank.');
        verifyGreaterThanOrEqual(testCase, min(line.x(finite)), snap.xlim(1)-1e-9);
        verifyLessThanOrEqual(testCase, max(line.x(finite)), snap.xlim(2)+1e-9);
        verifyGreaterThanOrEqual(testCase, min(line.y(finite)), snap.ylim(1)-1e-9);
        verifyLessThanOrEqual(testCase, max(line.y(finite)), snap.ylim(2)+1e-9);
    end
end
verifyEqual(testCase, sum(counts == 2), 2);
verifyEqual(testCase, sum(counts == 3), 6);
for k = find(counts == 2)'
    snap = snapshots{k};
    verifyEqual(testCase,snap.tickLabels(:),r.dayMetrics.day_utc(snap.tickPositions));
    for j = 1:2
        verifyEqual(testCase, snap.series{j}.x, (1:height(r.dayMetrics))');
    end
    verifyEqual(testCase, snap.series{1}.y, r.dayMetrics.baseline_rmse_k);
    verifyEqual(testCase, snap.series{2}.y, r.dayMetrics.calibrated_rmse_k);
end

epoch = f.data.epoch;
epoch.TimeZone = 'UTC';
day = dateshift(epoch, 'start', 'day');
day.Format = 'yyyy-MM-dd';
for role = 1:3
    at = string(day) == f.split.day_utc(role);
    expectedX = seconds(epoch(at)-epoch(find(at, 1)))/60;
    report = r.reports{role}.samples;
    observed = report.observed_k(at);
    observed(~report.used(at)) = NaN;
    expectedY = [observed, r.baseline{role}.temperatureK(at, 1), ...
        r.prediction{role}.temperatureK(at, 1)] - 273.15;
    matches = find(counts == 3 & contains(titles, f.split.day_utc(role)));
    assertEqual(testCase, numel(matches), 2);
    gapTime = seconds(epoch(gapRows(role))-epoch(find(at, 1)))/60;
    for k = matches'
        for j = 1:3
            line = snapshots{k}.series{j};
            sourcePoints = isfinite(line.x);
            verifyEqual(testCase, line.x(sourcePoints), expectedX, 'AbsTol', 1e-12);
            actualY = line.y(sourcePoints);
            verifyEqual(testCase, isnan(actualY), isnan(expectedY(:, j)));
            finite = isfinite(expectedY(:, j));
            verifyEqual(testCase, actualY(finite), expectedY(finite, j), 'AbsTol', 1e-10);
            gap = abs(line.x-gapTime) < 1e-12;
            assertEqual(testCase, sum(gap), 1);
            verifyTrue(testCase, isnan(line.y(gap)));
            verifyGreaterThanOrEqual(testCase, sum(isnan(line.x)), 2);
            % No pair of adjacent drawable vertices may span the missing row.
            bridgesGap = line.x(1:end-1) < gapTime & line.x(2:end) > gapTime ...
                & isfinite(line.y(1:end-1)) & isfinite(line.y(2:end));
            verifyFalse(testCase, any(bridgesGap));
        end
    end
end
end

function manifest = verifyManifest(testCase, output)
manifest = readtable(fullfile(output, 'artifact_manifest.csv'), 'Delimiter', ',', ...
    'ReadVariableNames', true, 'TextType', 'string');
verifyEqual(testCase, manifest.Properties.VariableNames, {'file', 'bytes', 'sha256'});
assertFalse(testCase, any(ismissing(manifest.file)));
verifyEqual(testCase, numel(unique(manifest.file)), height(manifest));
verifyFalse(testCase, any(manifest.file == "artifact_manifest.csv"));
files = dir(fullfile(output, '**', '*'));
files = files(~[files.isdir]);
prefix = [output filesep];
inventory = strings(0, 1);
for k = 1:numel(files)
    absolute = fullfile(files(k).folder, files(k).name);
    assertTrue(testCase, startsWith(absolute, prefix, 'IgnoreCase', ispc));
    relative = string(absolute(numel(prefix)+1:end));
    if relative ~= "artifact_manifest.csv"
        inventory(end + 1, 1) = relative; %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(manifest.file), sort(inventory));
for k = 1:height(manifest)
    relative = char(manifest.file(k));
    unsafe = regexp(relative, '(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))', 'once');
    assertEmpty(testCase, unsafe, 'Manifest entries must be contained relative paths.');
    bytes = fileBytes(fullfile(output, relative));
    verifyEqual(testCase, numel(bytes), manifest.bytes(k));
    digest = java.security.MessageDigest.getInstance('SHA-256');
    digest.update(typecast(bytes, 'int8'));
    expectedHash = string(lower(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2)', 1, [])));
    verifyEqual(testCase, manifest.sha256(k), expectedHash);
end
end

function bytes = fileBytes(file)
fid = fopen(file, 'rb');
assert(fid ~= -1, 'Cannot read exported artifact.');
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
end

function value = canonicalPath(input)
file = java.io.File(char(input));
if ~file.isAbsolute(), file = java.io.File(fullfile(pwd,char(input))); end
value = char(file.getCanonicalPath());
end

function deleteIfValid(fig)
if isgraphics(fig), delete(fig); end
end

function restoreEnvironment(folder, searchPath, visible, closeCallback, root)
set(groot, 'DefaultFigureVisible', visible, ...
    'DefaultFigureCloseRequestFcn', closeCallback);
cd(folder);
path(searchPath);
removeTemporaryRoot(root);
end

function removeTemporaryRoot(root)
if ~isfolder(root), return; end
absolute = canonicalPath(root);
parent = canonicalPath(tempdir);
assert(strcmpi(fileparts(absolute), parent), ...
    'Refusing to delete outside the direct temporary test directory.');
rmdir(absolute, 's');
end
