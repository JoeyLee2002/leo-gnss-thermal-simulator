"""English introduction from production captures, reports and local narration."""
import argparse
import concurrent.futures
import json
import math
import re
import subprocess
import wave
from pathlib import Path

import fitz
import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont, ImageOps

HERE = Path(__file__).resolve().parent
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS = 1920, 1080, 20


def font(size, bold=False):
    return ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf' if bold
                              else 'C:/Windows/Fonts/arial.ttf', size)


def wrap(text, size, width):
    lines, current = [], ''
    for word in text.split():
        candidate = f'{current} {word}'.strip()
        if font(size).getlength(candidate) > width and current:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def stamp(seconds, ass=False):
    precision = 100 if ass else 1000
    t = round(seconds * precision)
    hh, t = divmod(t, 3600 * precision)
    mm, t = divmod(t, 60 * precision)
    ss, frac = divmod(t, precision)
    return (f'{hh}:{mm:02}:{ss:02}.{frac:02}' if ass
            else f'{hh:02}:{mm:02}:{ss:02},{frac:03}')


def frame(source, title, chapter, index, total):
    image = Image.new('RGB', (W, H), '#ffffff')
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, W, 94), fill='#263d47')
    lines = wrap(title, 35, 1650)
    assert len(lines) == 1, title
    draw.text((32, 17), title, font=font(35, True), fill='white')
    draw.text((33, 61), chapter, font=font(21), fill='#dae8eb')
    draw.text((1750, 35), f'{index:02} / {total:02}', font=font(25), fill='white')
    picture = Image.open(source).convert('RGB')
    picture = ImageOps.contain(picture, (1856, 832), Image.Resampling.LANCZOS)
    image.paste(picture, ((W-picture.width)//2, 106+(832-picture.height)//2))
    draw.rectangle((0, 956, W, H), fill='#263d47')
    return image


def run(command, cwd=None):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True,
                            encoding='utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(result.stderr[-4000:])


def prepare_reports(capture):
    for task, name, keyword in [
            ('base_run', 'report_base.png', ''),
            ('sweep_run', 'report_sweep.png', 'Parameter sweep'),
            ('geometry_run', 'report_geometry.png', 'Three-dimensional temperature'),
            ('telemetry_run', 'report_telemetry.png', 'Telemetry'),
            ('sweep_run', 'report_acceptance.png', 'Acceptance')]:
        doc = fitz.open(capture/task/'report/thermal_report_en.pdf')
        # Use the stage-analysis page, not a stage name mentioned on the title page.
        if not keyword:
            page_index = 0
        elif keyword == 'Acceptance':
            page_index = len(doc)-1
        else:
            matches = [i for i in range(2, len(doc))
                       if keyword.lower() in doc[i].get_text().lower()]
            page_index = matches[0] if matches else min(2, len(doc)-1)
        page = doc[page_index]
        blocks = page.get_text('dict')['blocks']
        charts = [b for b in blocks if b['type'] == 1
                  and b['bbox'][2]-b['bbox'][0] > 200]
        if charts:
            # Enlarge genuine report excerpts: findings at left, chart at right.
            chart = fitz.Rect(charts[0]['bbox'])
            layout = Image.new('RGB', (1800, 832), 'white')
            for clip, area, position in [
                    (fitz.Rect(40,65,580,chart.y0-16), (820,780), (12,24)),
                    (chart+(-8,-8,8,8), (930,780), (858,24))]:
                pix = page.get_pixmap(matrix=fitz.Matrix(2,2), clip=clip, alpha=False)
                excerpt = Image.frombytes('RGB', (pix.width,pix.height), pix.samples)
                excerpt = ImageOps.contain(excerpt, area, Image.Resampling.LANCZOS)
                layout.paste(excerpt, position)
            layout.save(capture/'frames'/name)
        else:
            content = [b for b in blocks if b['type']==0 and 55<b['bbox'][1]<720]
            bottom = min(720, max(b['bbox'][3] for b in content)+15)
            clip = fitz.Rect(40,65,580,bottom)
            page.get_pixmap(matrix=fitz.Matrix(2,2), clip=clip, alpha=False).save(
                capture/'frames'/name)


ASS_HEADER = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Arial,34,&H00FFFFFF,&H00FFFFFF,&H00273D47,&H00273D47,0,0,0,0,100,100,0,0,1,0,0,2,100,100,30,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--encode-scenes', nargs='+', type=int)
    args = parser.parse_args()
    capture = args.capture.resolve()
    prepare_reports(capture)
    scenes = json.loads((HERE/'scenes.json').read_text('utf-8'))
    parts = HERE/'video_parts'; parts.mkdir(exist_ok=True)
    durations, timeline, subtitles, chapters = [], [], [], []
    elapsed = 0
    for i, scene in enumerate(scenes, 1):
        with wave.open(str(HERE/'audio'/f'{i:02}.wav')) as wav:
            speech = wav.getnframes()/wav.getframerate()
        duration = math.ceil((speech+0.6)*FPS)/FPS
        durations.append(duration)
        part = parts/f'{i:02}'; part.mkdir(exist_ok=True)
        for name, key in [('first', 'image'), ('second', 'secondImage')]:
            frame(capture/'frames'/scene.get(key, scene['image']), scene['title'],
                  scene['chapter'], i, len(scenes)).save(part/f'{name}.png')
        if i == 1:
            Image.open(part/'first.png').save(HERE/'preview.jpg', quality=95)
        chunks = []
        for sentence in re.split(r'(?<=[.!?])\s+', scene['text']):
            words = sentence.split()
            while words:
                chunks.append(' '.join(words[:17]))
                words = words[17:]
        weights = [len(chunk.split()) for chunk in chunks]
        start, ass = 0, ASS_HEADER
        for chunk, weight in zip(chunks, weights):
            end = start+speech*weight/sum(weights)
            lines = wrap(chunk, 34, 1700)
            assert len(lines) <= 2
            content = '\\N'.join(lines)
            ass += (f'Dialogue: 0,{stamp(start,True)},{stamp(end,True)},'
                    f'Default,,0,0,0,,{content}\n')
            subtitles.extend([str(len(subtitles)//4+1),
                              f'{stamp(elapsed+start)} --> {stamp(elapsed+end)}',
                              chunk, ''])
            start = end
        (part/'captions.ass').write_text(ass, encoding='utf-8-sig')
        timeline.append(dict(index=i, start=elapsed, duration=duration, **scene))
        if not chapters or chapters[-1]['title'] != scene['chapter']:
            chapters.append(dict(start=elapsed, title=scene['chapter']))
        elapsed += duration
    (HERE/'timeline.json').write_text(json.dumps(timeline, indent=2), 'utf-8')
    (HERE/'introduction_en.srt').write_text('\n'.join(subtitles), 'utf-8')
    (HERE/'chapters.txt').write_text('\n'.join(
        f"{int(c['start']//60):02}:{int(c['start']%60):02} {c['title']}"
        for c in chapters), 'utf-8')
    if args.prepare_only:
        print(f'PREPARED scenes={len(scenes)} duration={elapsed:.2f}')
        return

    def encode(i):
        part = parts/f'{i+1:02}'
        if args.encode_scenes is not None and i+1 not in args.encode_scenes:
            assert (part/'clip.mp4').is_file(), 'A reused clip must already exist.'
            return
        filt = (f"[0:v][1:v]overlay=enable='gte(t,{durations[i]*0.50:.3f})',"
                'ass=captions.ass,format=yuv420p[v];[2:a]apad[a]')
        run([FFMPEG, '-hide_banner','-loglevel','error','-y',
             '-loop','1','-framerate',str(FPS),'-i','first.png',
             '-loop','1','-framerate',str(FPS),'-i','second.png',
             '-i',str(HERE/'audio'/f'{i+1:02}.wav'), '-filter_complex',filt,
             '-map','[v]','-map','[a]','-t',str(durations[i]),
             '-c:v','libx264','-preset','veryfast','-crf','18','-threads','2',
             '-c:a','aac','-b:a','160k','-ar','48000','-movflags','+faststart',
             'clip.mp4'], part)
        print(f'ENCODED={i+1:02}/{len(scenes)}', flush=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(encode, range(len(scenes))))
    (parts/'concat.txt').write_text('\n'.join(
        f"file '{i+1:02}/clip.mp4'" for i in range(len(scenes))), 'utf-8')
    metadata = ';FFMETADATA1\ntitle=LEOTherm English Introduction\nlanguage=eng\n'
    for i, chapter in enumerate(chapters):
        end = chapters[i+1]['start'] if i+1<len(chapters) else elapsed
        metadata += (f"[CHAPTER]\nTIMEBASE=1/1000\nSTART={round(chapter['start']*1000)}\n"
                     f"END={round(end*1000)}\ntitle={chapter['title']}\n")
    (parts/'chapters.ffmeta').write_text(metadata, 'utf-8')
    final = HERE/'LEOTherm_English_Introduction.mp4'
    run([FFMPEG,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0',
         '-i','concat.txt','-i','chapters.ffmeta','-map_metadata','1',
         '-map_chapters','1','-metadata:s:a:0','language=eng','-c','copy',
         '-movflags','+faststart',str(final)], parts)
    print(json.dumps(dict(video=str(final), durationSeconds=elapsed,
                          scenes=len(scenes), chapters=len(chapters))), flush=True)


if __name__ == '__main__':
    main()
