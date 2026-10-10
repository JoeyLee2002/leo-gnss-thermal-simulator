"""Decode the final file, inspect all scene samples and check source evidence."""
import json
import subprocess
import sys
import wave
from pathlib import Path

import cv2
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFont

root=Path(sys.argv[1])
video=root/'LEOTherm_v1.2.0_中文完整教程.mp4'
out=root/'review'; out.mkdir(exist_ok=True)
timeline=json.loads((root/'timeline.json').read_text('utf-8'))
capture=cv2.VideoCapture(str(video))
assert capture.isOpened()
fps=capture.get(cv2.CAP_PROP_FPS)
frames=capture.get(cv2.CAP_PROP_FRAME_COUNT)
duration=frames/fps
width,height=int(capture.get(3)),int(capture.get(4))
assert (width,height)==(1920,1080) and duration<600
assert abs(duration-(timeline[-1]['start']+timeline[-1]['duration']))<0.3
samples=[]
for scene in timeline:
    for fraction in [0.2,0.75]:
        t=scene['start']+scene['duration']*fraction
        capture.set(cv2.CAP_PROP_POS_MSEC,t*1000)
        ok,bgr=capture.read(); assert ok, (scene['index'],t)
        rgb=cv2.cvtColor(bgr,cv2.COLOR_BGR2RGB)
        assert np.std(rgb)>12
        im=Image.fromarray(rgb)
        name=f"scene_{scene['index']:02}_{fraction:.2f}.jpg"
        im.save(out/name,quality=92)
        samples.append((scene['index'],t,name))
capture.release()
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
for half in [0,1]:
    selected=samples[half*33:(half+1)*33]
    sheet=Image.new('RGB',(5*384,7*238),'white'); draw=ImageDraw.Draw(sheet)
    for k,(index,t,name) in enumerate(selected):
        x,y=(k%5)*384,(k//5)*238
        im=Image.open(out/name); im.thumbnail((384,216))
        sheet.paste(im,(x,y)); draw.text((x+8,y+217),f'{index:02} | {int(t//60):02}:{int(t%60):02}',fill='black',font=font)
    sheet.save(out/f'contact_sheet_{half+1}.jpg',quality=93)
audio=[]
for path in sorted((root/'audio').glob('*.wav')):
    with wave.open(str(path)) as wav:
        assert wav.getsampwidth()==2
        values=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(float)/32768
        peak=float(np.max(np.abs(values)))
        rms=float(np.sqrt(np.mean(values*values)))
        assert rms>0.005 and peak<1
        audio.append({'scene':path.stem,'peak':peak,'rms':rms})
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
decoded=subprocess.run([ffmpeg,'-v','error','-i',str(video),'-f','null','-'],capture_output=True,text=True)
assert decoded.returncode==0 and not decoded.stderr.strip(), decoded.stderr
info=subprocess.run([ffmpeg,'-hide_banner','-i',str(video)],capture_output=True,text=True,encoding='utf-8',errors='replace').stderr
assert 'Audio: aac' in info and 'Video: h264' in info and 'Chapter #0:8' in info
(out/'media_info.txt').write_text(info,encoding='utf-8')
tasks={p.parent.name:json.loads(p.read_text('utf-8'))['status'] for p in root.glob('*/pipeline_status.json')}
assert len(tasks)==4 and all(v=='complete' for v in tasks.values())
report={'durationSeconds':duration,'resolution':[width,height],'fps':fps,'frames':frames,
        'chapters':9,'scenes':len(timeline),'sampledFrames':len(samples),'fullDecodePassed':True,
        'audioCodec':'AAC','videoCodec':'H.264','audioChecks':audio,'tasks':tasks,
        'scope':'Production GUI captures, actual reports, 3-D view rotation and labelled explanatory cards; not a continuous mouse recording.'}
(out/'qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='audioChecks'},ensure_ascii=False))
