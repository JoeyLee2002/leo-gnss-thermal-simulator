"""Generate a transparent instructional layer for the Jianying project.

Pointer cues identify controls in genuine application captures. They are not
claimed to be recorded input events or newly executed simulation results.
"""
import json
import math
import subprocess
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / 'click_guide'
W, H, FPS = 1920, 1080, 10
SCALE = 832 / 900
LEFT = (1920 - round(1500 * SCALE)) // 2


def event(start, end, action, label, rect=None):
    return dict(start=start, end=end, action=action, label=label, rect=rect)


EVENTS = [
    event(3, 9, 'ACTION GUIDE', 'Pointer cues show where to click. Values are examples.'),
    event(24, 30, 'SELECT', 'First simulation', [215,270,575,315]),
    event(30, 37, 'CLICK', 'Task wizard\nName: My first run\nDuration: 2 h\nTime step: 60 s', [265,326,415,442]),
    event(38, 45, 'ALTERNATIVE', 'Open existing project\nUse a saved MAT project', [425,326,575,442]),
    event(47, 50.5, 'CLICK', 'Simulation\nSingle scenario', [92,88,181,112]),
    event(50.5, 54.5, 'ENTER', 'Start date (UTC)\n2024-03-20\nTime: 12:00:00', [214,316,387,374]),
    event(54.5, 58.5, 'ENTER', 'Duration (hours): 2\nTime step (s): 60\nWarmup orbits: 1', [214,380,387,470]),
    event(58.5, 63, 'ENTER', 'Altitude (km): 600\nInclination (deg): 97.6\nRAAN (deg): 20', [214,477,387,567]),
    event(63, 68, 'SELECT', 'Attitude\nNadir pointing', [214,605,387,631]),
    event(68, 74, 'REVIEW', 'Enable the heat sources needed by your study.', [18,763,388,843]),
    event(77, 83, 'CLICK', 'Thermal network', [253,272,376,296]),
    event(83, 90, 'REVIEW', 'Node properties\nUse documented device values', [15,365,914,643]),
    event(91, 99, 'REVIEW', 'Thermal links\nCheck units and connected nodes', [924,365,1485,643]),
    event(101, 105.5, 'CLICK', 'Check task\nResolve errors first', [15,223,160,256]),
    event(105.5, 110, 'CLICK', 'Run task\nWait for completion', [170,223,330,256]),
    event(111, 114.9, 'INSPECT', 'Temperature and illumination plots', [442,330,1473,826]),
    event(116, 122, 'CLICK', 'Results and export', [183,88,320,112]),
    event(122, 128.8, 'CLICK', 'Open this run PDF\nRead checks and limits', [25,813,245,846]),
    event(130.5, 133.7, 'OPTIONAL: ENABLE', 'Parameter sweep', [15,145,176,170]),
    event(133.7, 136.7, 'CLICK', 'Parameter sweep tab', [120,272,252,296]),
    event(136.7, 139.5, 'ENTER', 'Altitude (km)\n500,600', [184,354,374,384]),
    event(139.5, 143, 'ENTER', 'Target beta angle (deg)\n0,15,30\n2 x 3 = 6 cases', [184,392,374,422]),
    event(145, 151, 'INSPECT', 'Check all six case statuses before comparing.', [405,636,1476,842]),
    event(157.5, 161.3, 'OPTIONAL: ENABLE', '3-D coupling', [192,145,325,170]),
    event(161.3, 165, 'CLICK', '3-D geometry tab', [377,272,485,296]),
    event(166, 171, 'REVIEW', 'Declare mesh units, materials and boundary mapping.'),
    event(187.5, 192, 'CLICK', 'Engineering thermal model', [486,272,670,296]),
    event(192, 198, 'CLICK', 'Import thermal model\nSupported exchange file', [15,310,195,358]),
    event(198, 204, 'CLICK', 'Load explicit mapping\nMap external nodes', [15,368,185,412]),
    event(205, 213, 'NEXT', 'Preview mapping, then Confirm and apply\nOnly after valid mapping', [395,368,706,412]),
    event(216.7, 220, 'OPTIONAL: ENABLE', 'Telemetry comparison', [374,145,545,170]),
    event(220, 224, 'CLICK', 'Import CSV\nUse traceable measurements', [14,301,119,339]),
    event(224, 230, 'CLICK', 'Preflight\nCheck time, units and node mapping', [129,301,234,339]),
    event(245.8, 250, 'CLICK', 'Device calibration tab', [843,272,980,296]),
    event(250, 256, 'CLICK', 'Prepare calibration\nConfiguration only in this video', [14,305,159,340]),
    event(256, 262, 'REVIEW', 'Nominal values, Lower, Upper and Prior sigma', [495,409,915,435]),
    event(263, 270, 'REVIEW', 'Split whole days into training, validation and test.', [14,478,259,741]),
    event(301, 306, 'CLICK', 'Save project\nKeep the task configuration', [1228,8,1360,50]),
    event(306, 312, 'CLICK', 'Open this run PDF\nKeep data and run records too', [25,813,245,846]),
]


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf' if bold
                             else 'C:/Windows/Fonts/arial.ttf', size)


def wrapped(text, width=202):
    lines = []
    for paragraph in text.split('\n'):
        line = ''
        for word in paragraph.split():
            candidate = (line + ' ' + word).strip()
            if font(28).getlength(candidate) > width and line:
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
    return lines


def overlay(e, number, elapsed):
    im = Image.new('RGBA', (W,H), (0,0,0,0))
    d = ImageDraw.Draw(im)
    lines = wrapped(e['label'])
    title = wrapped(e['action'])
    x, y, width = 14, 350, 236
    height = 42 + len(title)*35 + len(lines)*36
    assert y + height < 940
    d.rounded_rectangle((x,y,x+width,y+height), radius=6,
                        fill=(28,48,58,248), outline='#ffbc42', width=3)
    d.text((x+15,y+12), f'{number:02}  ACTION', font=font(22,True), fill='#ffbc42')
    ty = y+45
    for line in title:
        d.text((x+15,ty),line,font=font(28,True),fill='#ffbc42'); ty += 35
    for line in lines:
        d.text((x+15,ty),line,font=font(28),fill='white'); ty += 36
    if e['rect']:
        a,b,c,f = e['rect']
        rect = tuple(round(v) for v in (LEFT+a*SCALE,106+b*SCALE,
                                        LEFT+c*SCALE,106+f*SCALE))
        d.rectangle(rect,outline='#ffad19',width=5)
        tx,ty = rect[0]+min(24,(rect[2]-rect[0])/2), (rect[1]+rect[3])/2
        # A short animated arrival and two click pulses, followed by a held cue.
        progress = min(1, elapsed/.45)
        px = x+width+(tx-x-width)*progress
        py = y+height/2+(ty-y-height/2)*progress
        d.line((x+width,y+height/2,tx,ty),fill=(255,173,25,190),width=3)
        phase = (elapsed-.45) % .7
        if .45 <= elapsed <= 1.85:
            radius = 9+phase*37
            d.ellipse((tx-radius,ty-radius,tx+radius,ty+radius),
                      outline='#ff6b35',width=5)
        points=[(px,py),(px+4,py+34),(px+12,py+25),(px+23,py+40),
                (px+30,py+35),(px+20,py+20),(px+33,py+19)]
        d.polygon(points,fill='white',outline='#192b33',width=3)
    return im


def main():
    OUT.mkdir(exist_ok=True)
    (OUT/'actions.json').write_text(json.dumps(EVENTS,indent=2),encoding='utf-8')
    timeline = json.loads((HERE/'timeline.json').read_text('utf-8'))
    duration = timeline[-1]['start'] + timeline[-1]['duration']
    # Use a transparent animation as an independently editable overlay track.
    command = [imageio_ffmpeg.get_ffmpeg_exe(),'-y','-hide_banner','-loglevel','error',
               '-f','rawvideo','-pixel_format','rgba','-video_size','1920x1080',
               '-framerate',str(FPS),'-i','pipe:0','-an','-c:v','qtrle',
               '-pix_fmt','argb',str(OUT/'LEOTherm_Click_Overlay.mov')]
    process = subprocess.Popen(command,stdin=subprocess.PIPE)
    clear = bytes(W*H*4)
    cached = {}
    for k in range(math.ceil(duration*FPS)):
        t = k/FPS
        found = next(((i,e) for i,e in enumerate(EVENTS,1)
                      if e['start'] <= t < e['end']),None)
        if found:
            i,e = found
            elapsed = t-e['start']
            if elapsed > 1.9:
                if i not in cached: cached[i] = overlay(e,i,2).tobytes()
                frame = cached[i]
            else: frame = overlay(e,i,elapsed).tobytes()
            if abs(elapsed-2) < .051:
                base = Image.open(HERE/'video_parts'/f"{next(s['index'] for s in timeline if s['start'] <= t < s['start']+s['duration']):02}"/'first.png').convert('RGBA')
                # Save representative first-image previews only before midscene.
                scene = next(s for s in timeline if s['start'] <= t < s['start']+s['duration'])
                name = 'second.png' if t-scene['start'] >= scene['duration']/2 else 'first.png'
                base = Image.open(HERE/'video_parts'/f"{scene['index']:02}"/name).convert('RGBA')
                base.alpha_composite(overlay(e,i,2))
                base.convert('RGB').save(OUT/f'preview_{i:02}.jpg',quality=93)
        else: frame = clear
        process.stdin.write(frame)
        if k % 300 == 0: print(f'OVERLAY={t:.1f}/{duration:.2f}',flush=True)
    process.stdin.close()
    if process.wait(): raise RuntimeError('Overlay encoding failed')
    print(f'COMPLETE actions={len(EVENTS)} duration={duration}',flush=True)


if __name__ == '__main__':
    main()
