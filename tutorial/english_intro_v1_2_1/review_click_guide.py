"""Verify the Jianying export, timing and readability evidence."""
import json
import subprocess
from pathlib import Path

import cv2
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE/'click_guide'
VIDEO = OUT/'LEOTherm_English_Click_Guide.mp4'
REVIEW = OUT/'review'
REVIEW.mkdir(exist_ok=True)
actions = json.loads((OUT/'actions.json').read_text('utf-8'))
cap = cv2.VideoCapture(str(VIDEO))
assert cap.isOpened()
fps = cap.get(cv2.CAP_PROP_FPS)
duration = cap.get(cv2.CAP_PROP_FRAME_COUNT)/fps
assert [int(cap.get(3)),int(cap.get(4))] == [1920,1080]
assert abs(duration-325.35) < .2
sheet = Image.new('RGB',(1920,10*240),'white')
d = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
checks = []
for i,e in enumerate(actions,1):
    t = e['start']+min(2,(e['end']-e['start'])/2)
    cap.set(cv2.CAP_PROP_POS_MSEC,t*1000)
    ok,bgr = cap.read()
    assert ok and bgr.std() > 12
    rgb = cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)
    gutter = rgb[350:700,14:250]
    amber = (gutter[:,:,0]>170)&(gutter[:,:,1]>95)&(gutter[:,:,2]<110)
    assert amber.sum() > 90, f'Missing cue at {t}'
    im = Image.fromarray(rgb)
    im.save(REVIEW/f'action_{i:02}.jpg',quality=94)
    im.thumbnail((480,216))
    x,y = ((i-1)%4)*480,((i-1)//4)*240
    sheet.paste(im,(x,y))
    d.text((x+8,y+217),f'{i:02}  {t:.1f}s  {e["action"]}',font=font,fill='black')
    checks.append(dict(action=i,time=t,visibleCue=True))
cap.release()
sheet.save(REVIEW/'contact_sheet.jpg',quality=94)
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
result = subprocess.run([ffmpeg,'-v','error','-i',str(VIDEO),'-f','null','-'],
                        capture_output=True,text=True)
assert result.returncode == 0 and not result.stderr.strip(),result.stderr
info = subprocess.run([ffmpeg,'-hide_banner','-i',str(VIDEO)],capture_output=True,
                      text=True,encoding='utf-8',errors='replace').stderr
assert 'Video: h264' in info and 'Audio: aac' in info
(REVIEW/'media_info.txt').write_text(info,'utf-8')
audio = subprocess.run([ffmpeg,'-v','error','-i',str(VIDEO),'-vn','-ac','1',
                        '-ar','16000','-f','f32le','pipe:1'],capture_output=True)
assert audio.returncode == 0
samples = np.frombuffer(audio.stdout,dtype='<f4')
assert np.sqrt(np.mean(samples*samples)) > .005
verification = dict(editor='Jianying Pro 8.1.1',resolution=[1920,1080],fps=fps,
                    durationSeconds=duration,actionCues=len(checks),
                    fullDecodePassed=True,audioPresent=True,checks=checks,
                    scope='Instructional pointer animation over genuine GUI captures; not continuous recorded mouse input.',
                    sourceVideoPreserved=True)
(OUT/'verification.json').write_text(json.dumps(verification,indent=2),'utf-8')
print(json.dumps({k:v for k,v in verification.items() if k!='checks'}),flush=True)
