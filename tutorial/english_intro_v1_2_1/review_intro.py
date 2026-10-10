"""Check the encoded introduction and retain sampled-frame evidence."""
import json
import subprocess
import wave
from pathlib import Path

import cv2
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
video = HERE/'LEOTherm_English_Introduction.mp4'
timeline = json.loads((HERE/'timeline.json').read_text('utf-8'))
out = HERE/'review'; out.mkdir(exist_ok=True)
cap = cv2.VideoCapture(str(video))
assert cap.isOpened()
fps = cap.get(cv2.CAP_PROP_FPS)
duration = cap.get(cv2.CAP_PROP_FRAME_COUNT)/fps
resolution = [int(cap.get(3)), int(cap.get(4))]
assert resolution == [1920, 1080]
assert abs(duration-(timeline[-1]['start']+timeline[-1]['duration'])) < 0.3
sheet = Image.new('RGB', (1920, 6*238), 'white')
draw = ImageDraw.Draw(sheet)
for i, scene in enumerate(timeline):
    for half, fraction in enumerate([0.25, 0.8]):
        t = scene['start']+scene['duration']*fraction
        cap.set(cv2.CAP_PROP_POS_MSEC, t*1000)
        ok, frame = cap.read()
        assert ok and np.std(frame) > 12
        image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        image.save(out/f'scene_{i+1:02}_{half}.jpg', quality=95)
        k = i*2+half
        image.thumbnail((480, 216))
        x, y = (k%4)*480, (k//4)*238
        sheet.paste(image, (x,y))
        draw.text((x+8,y+217), f"{i+1:02} | {int(t//60):02}:{int(t%60):02}",
                  font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18), fill='black')
cap.release()
sheet.save(out/'contact_sheet.jpg', quality=95)
audio_checks = []
for path in sorted((HERE/'audio').glob('*.wav')):
    with wave.open(str(path)) as wav:
        assert wav.getsampwidth() == 2
        data = np.frombuffer(wav.readframes(wav.getnframes()), dtype='<i2')/32768.
        peak, rms = float(np.max(np.abs(data))), float(np.sqrt(np.mean(data**2)))
        assert 0.005 < rms and peak < 1
        audio_checks.append(dict(scene=path.stem, peak=peak, rms=rms))
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
result = subprocess.run([ffmpeg,'-v','error','-i',str(video),'-f','null','-'],
                        capture_output=True, text=True)
assert result.returncode == 0 and not result.stderr.strip(), result.stderr
info = subprocess.run([ffmpeg,'-hide_banner','-i',str(video)], capture_output=True,
                      text=True, encoding='utf-8', errors='replace').stderr
assert 'Video: h264' in info and 'Audio: aac' in info and 'Chapter #0:3' in info
(out/'media_info.txt').write_text(info, 'utf-8')
capture = HERE.parents[1]/'results'/'english_intro_v121_20261004'
tasks = {p.parent.name:json.loads(p.read_text('utf-8'))['status']
         for p in capture.glob('*/pipeline_status.json')}
assert len(tasks) == 4 and all(s == 'complete' for s in tasks.values())
review = dict(version='1.2.1', resolution=resolution, fps=fps,
              durationSeconds=duration, scenes=len(timeline), chapters=4,
              fullDecodePassed=True, sampledFrames=24, audioChecks=audio_checks,
              taskStatus=tasks, voice='Microsoft Zira (English, synthetic)',
              scope='Edited production GUI captures and actual reports. Calibration configuration only. Telemetry is synthetic.')
(HERE/'verification.json').write_text(json.dumps(review,indent=2), 'utf-8')
print(json.dumps({k:v for k,v in review.items() if k!='audioChecks'}))
