function artifact = render_v1_1_0_video(captureDirectory)
%RENDER_V1_1_0_VIDEO Assemble captured GUI/PDF frames with Chinese narration.
root = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(captureDirectory)
    captureDirectory = fullfile(root, 'results', 'tutorial_v1_1_0_capture_final');
end
manifest = jsondecode(fileread(fullfile(captureDirectory, 'video_scenes.json')));
scenes = manifest.Scenes;
videoPath = fullfile(captureDirectory, 'silent_video.mp4');
audioPath = fullfile(captureDirectory, 'narration.wav');
subtitlePath = fullfile(captureDirectory, 'tutorial_zh.srt');
if isfile(videoPath) || isfile(audioPath) || isfile(subtitlePath)
    error('leotherm:TutorialOutput', 'Tutorial render outputs already exist.');
end

fps = 10;
video = VideoWriter(videoPath, 'MPEG-4');
video.FrameRate = fps;
video.Quality = 92;
open(video);
videoCleanup = onCleanup(@() close(video));
subtitle = fopen(subtitlePath, 'w', 'n', 'UTF-8');
if subtitle < 0, error('leotherm:TutorialOutput', 'Cannot create subtitles.'); end
subtitleCleanup = onCleanup(@() fclose(subtitle));
audioChunks = cell(numel(scenes), 1);
previousFrame = [];
elapsed = 0;
sampleRate = [];
for k = 1:numel(scenes)
    imagePath = fullfile(captureDirectory, 'frames', scenes(k).Image);
    voicePath = fullfile(captureDirectory, 'audio', scenes(k).Audio);
    frame = composeFrame(imread(imagePath), char(scenes(k).Caption));
    [voice, rate] = audioread(voicePath);
    if isempty(sampleRate), sampleRate = rate; end
    if rate ~= sampleRate || size(voice, 2) ~= 1
        error('leotherm:TutorialAudio', 'Narration format differs between scenes.');
    end
    speechSeconds = numel(voice) / rate;
    frameCount = ceil((speechSeconds + 0.6) * fps);
    transitionCount = min(5, frameCount);
    for j = 1:frameCount
        if ~isempty(previousFrame) && j <= transitionCount
            weight = j / transitionCount;
            current = uint8((1 - weight) * double(previousFrame) ...
                + weight * double(frame));
        else
            current = frame;
        end
        writeVideo(video, current);
    end
    audioChunks{k} = [voice; zeros(max(0, round(frameCount / fps * rate) ...
        - numel(voice)), 1)];
    fprintf(subtitle, '%d\n%s --> %s\n%s\n\n', k, ...
        subtitleTime(elapsed), subtitleTime(elapsed + speechSeconds), ...
        char(scenes(k).Narration));
    elapsed = elapsed + frameCount / fps;
    previousFrame = frame;
    fprintf('SCENE_%02d_SECONDS=%.1f\n', k, frameCount / fps);
end
clear subtitleCleanup
clear videoCleanup
audio = vertcat(audioChunks{:});
audiowrite(audioPath, audio, sampleRate);
artifact = struct('video', videoPath, 'audio', audioPath, ...
    'subtitles', subtitlePath, 'durationSeconds', elapsed, ...
    'sceneCount', numel(scenes));
fprintf('SILENT_VIDEO=%s\nDURATION=%.1f\n', videoPath, elapsed);
end

function frame = composeFrame(image, caption)
frame = uint8(245 * ones(960, 1380, 3));
if size(image, 3) > 3, image = image(:, :, 1:3); end
if size(image, 1) == 860 && size(image, 2) == 1380
    frame(1:860, :, :) = image;
else
    scale = min(860 / size(image, 1), 1380 / size(image, 2));
    page = imresize(image, scale);
    top = floor((860 - size(page, 1)) / 2) + 1;
    left = floor((1380 - size(page, 2)) / 2) + 1;
    frame(top:top+size(page,1)-1, left:left+size(page,2)-1, :) = page;
end
frame(861:960, :, :) = 24;
frame = insertText(frame, [35 884], caption, ...
    'Font', 'Microsoft YaHei', 'FontSize', 30, ...
    'TextColor', 'white', 'BoxOpacity', 0);
end

function value = subtitleTime(secondsValue)
milliseconds = round(secondsValue * 1000);
hours = floor(milliseconds / 3600000);
milliseconds = mod(milliseconds, 3600000);
minutes = floor(milliseconds / 60000);
milliseconds = mod(milliseconds, 60000);
secondsPart = floor(milliseconds / 1000);
milliseconds = mod(milliseconds, 1000);
value = sprintf('%02d:%02d:%02d,%03d', ...
    hours, minutes, secondsPart, milliseconds);
end
