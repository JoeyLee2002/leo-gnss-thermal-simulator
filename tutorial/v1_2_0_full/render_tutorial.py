"""Build a bounded Chinese tutorial from genuine GUI captures and run reports."""
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
ROOT = HERE.parents[1]
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS = 1920, 1080, 15


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


def wrap(text, f, width):
    lines, line = [], ''
    for char in text:
        if char == '\n' or f.getlength(line + char) > width:
            lines.append(line)
            line = '' if char == '\n' else char
        else:
            line += char
    if line:
        lines.append(line)
    return lines


def card(path, title, sections, footer):
    im = Image.new('RGB', (1500, 900), 'white')
    d = ImageDraw.Draw(im)
    d.text((65, 42), title, font=font(42, True), fill='#174f51')
    d.line((65, 115, 1435, 115), fill='#bccbcc', width=2)
    y = 152
    for label, body in sections:
        d.text((65, y), label, font=font(29, True), fill='#202a2b')
        y += 52
        for line in wrap(body, font(26), 1350):
            d.text((65, y), line, font=font(26), fill='#34464b')
            y += 39
        y += 30
    assert y < 815, (path, y)
    d.text((65, 842), footer, font=font(20), fill='#637477')
    im.save(path)


def prepare(capture):
    frames = capture / 'frames'
    card(frames/'installation.png', '两种启动方式', [
        ('Windows 独立版', '解压 LEOTherm_1.2.0_windows.zip\n安装免费的 MATLAB Runtime R2021b → 启动 LEOTherm.exe'),
        ('MATLAB 源码版', "cd('项目目录')\nlaunch_gui"),
        ('第一次运行', '确认界面版本 → 从“第一次仿真”开始 → 保存新任务')
    ], '启动步骤说明；不是安装过程录屏。来源：docs/独立版使用_v1.2.0.md')
    template = json.loads((ROOT/'templates/01_first_simulation.json').read_text(encoding='utf-8-sig'))
    card(frames/'template.png', '任务模板：复制后修改少量字段', [
        ('实际模板', 'templates/01_first_simulation.json'),
        ('本例的原始配置', '\n'.join(f'"{key}": {json.dumps(value, ensure_ascii=False)}' for key,value in template['scenario'].items())),
        ('载入方式', '快速开始 → 任务向导 → 选择其他 JSON 模板')
    ], '字段节选来自软件内置模板；秒是 durationS 和 timeStepS 的单位。')
    card(frames/'extension.png', '扩展入口：规范化交换与外部求解器', [
        ('已有热模型', '官方导出器 / 明确交换文件 → 模型校验 → 节点映射 → 当前任务'),
        ('MATLAB 开发接口', 'leotherm.adapter.register\nleotherm.adapter.execute\nleotherm.io.runExternalThermalSolver'),
        ('需要另外提供', '外部软件及许可、求解器路径、输入输出约定、自定义处理函数')
    ], '开发接口说明；未演示外部商业软件运行。详见 docs/适配器开发指南.md。')
    card(frames/'outputs.png', '一个任务，一套可以复查的交付物', [
        ('报告与图表', 'report/thermal_report_zh.pdf\n各阶段分析图、指标表格、报告数据'),
        ('模型与运行记录', 'input_snapshot.mat      frozen_model.mat\npipeline_run.mat           pipeline_status.json'),
        ('继续下一次工作', '打开保存的项目 → 修改参数 → 检查 → 在新目录运行 → 比较报告')
    ], '目录说明基于本次实际运行；教程案例均保留在同目录配套文件中。')
    reports = [
        ('base_run', 0, 'report_base.png'),
        ('sweep_run', 2, 'report_sweep.png'),
        ('geometry_run', 2, 'report_geometry.png'),
        ('telemetry_run', 2, 'report_telemetry.png'),
        ('sweep_run', -1, 'report_acceptance.png')]
    for run, page, name in reports:
        doc = fitz.open(capture/run/'report/thermal_report_zh.pdf')
        doc[page].get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False).save(frames/name)
    charts = list((frames/'calibration_chart.png').glob('*test*.png'))
    assert charts, 'Calibration test-day chart is missing'
    Image.open(charts[0]).save(frames/'calibration_plot.png')


def stamp(seconds, ass=False):
    precision = 100 if ass else 1000
    t = round(seconds * precision)
    hh, t = divmod(t, 3600 * precision)
    mm, t = divmod(t, 60 * precision)
    ss, frac = divmod(t, precision)
    return f'{hh}:{mm:02}:{ss:02}.{frac:02}' if ass else f'{hh:02}:{mm:02}:{ss:02},{frac:03}'


ASS_HEADER = '''[Script Info]
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
WrapStyle: 2
[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,Microsoft YaHei,33,&H00FFFFFF,&H00FFFFFF,&H00182020,&H00182020,0,0,0,0,100,100,0,0,1,0,0,2,80,80,19,1
[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''


def make_frame(scene, number, image_path, total, crop=None):
    out = Image.new('RGB', (W, H), '#edf1f2')
    d = ImageDraw.Draw(out)
    d.rectangle((0, 0, W, 76), fill='#174f51')
    d.text((28, 16), scene['title'], font=font(34, True), fill='white')
    d.text((1710, 24), f'{number:02} / {total:02}', font=font(24), fill='#d0e7e4')
    source = Image.open(image_path).convert('RGB')
    if crop:
        source = source.crop(tuple(crop))
    view = ImageOps.contain(source, (1490, 886), Image.Resampling.LANCZOS)
    out.paste(view, (18+(1490-view.width)//2, 88+(886-view.height)//2))
    d.line((1532, 100, 1532, 956), fill='#b7c9cc', width=2)
    d.text((1558, 104), scene['chapter'], font=font(25, True), fill='#174f51')
    y = 175
    for i, tip in enumerate(scene['tips']):
        d.text((1558, y), f'{i+1:02}', font=font(25, True), fill='#b4682e')
        for j, line in enumerate(wrap(tip, font(25), 275)):
            d.text((1606, y+j*39), line, font=font(25), fill='#223538')
        y += max(108, 42*len(wrap(tip, font(25), 275))+38)
    d.text((1558, 829), 'LEOTherm v1.2.0', font=font(24, True), fill='#174f51')
    d.text((1558, 872), '中文教程 · 真实界面剪辑', font=font(21), fill='#5a7073')
    d.text((1558, 910), '软件截图 / 报告 / 操作说明', font=font(18), fill='#5a7073')
    d.rectangle((0, 985, W, H), fill='#182020')
    return out


def run(cmd, cwd=None):
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding='utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(result.stderr[-5000:])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('capture', type=Path)
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args()
    capture = args.capture.resolve()
    prepare(capture)
    if args.prepare_only:
        return
    scenes = json.loads((HERE/'scenes.json').read_text(encoding='utf-8'))
    parts = capture/'video_parts'; parts.mkdir(exist_ok=True)
    durations = []
    for k in range(len(scenes)):
        with wave.open(str(capture/'audio'/f'{k+1:02}.wav')) as audio:
            durations.append(math.ceil((audio.getnframes()/audio.getframerate()+0.4)*FPS)/FPS)
    assert sum(durations) < 590, f'Duration exceeds target: {sum(durations)}'
    elapsed = 0
    srt, timeline, chapters = [], [], []
    for k, (scene, duration) in enumerate(zip(scenes, durations)):
        number = k+1
        part = parts/f'{number:02}'; part.mkdir(exist_ok=True)
        source = capture/'frames'/scene['image']
        assert source.is_file(), source
        make_frame(scene,number,source,len(scenes)).save(part/'full.png')
        detail_path = capture/'frames'/scene.get('secondImage',scene['image'])
        make_frame(scene,number,detail_path,len(scenes),scene.get('crop')).save(part/'detail.png')
        if scene.get('rotation'):
            rotation = sorted((capture/'rotation').glob('*.png'))
            assert len(rotation) == 36
            (part/'rotation').mkdir(exist_ok=True)
            for frame_number, frame in enumerate(rotation, 1):
                make_frame(scene,number,frame,len(scenes)).save(part/'rotation'/f'{frame_number:03}.png')
        # Divide subtitles into short phrases; duration is weighted by spoken text length.
        phrases = [p for p in re.split(r'(?<=[，。；：])',scene['text']) if p]
        weights = [len(p) for p in phrases]
        speech_duration = duration-0.4
        start=0; ass=ASS_HEADER
        for phrase, weight in zip(phrases,weights):
            end=start+speech_duration*weight/sum(weights)
            lines=wrap(phrase,font(33),1730)
            assert len(lines)<=2
            content='\\N'.join(lines)
            ass+=f'Dialogue: 0,{stamp(start,True)},{stamp(end,True)},Default,,0,0,0,,{content}\n'
            srt.extend([str(len(srt)//4+1),f'{stamp(elapsed+start)} --> {stamp(elapsed+end)}',phrase,''])
            start=end
        (part/'captions.ass').write_text(ass,encoding='utf-8-sig')
        timeline.append(dict(index=number,start=round(elapsed,3),duration=duration,**scene))
        if not chapters or chapters[-1]['title']!=scene['chapter']:
            chapters.append({'start':elapsed,'title':scene['chapter']})
        elapsed+=duration
    (capture/'timeline.json').write_text(json.dumps(timeline,ensure_ascii=False,indent=2),encoding='utf-8')
    (capture/'tutorial_zh.srt').write_text('\n'.join(srt),encoding='utf-8-sig')
    (capture/'chapters.txt').write_text('\n'.join(f"{int(c['start']//60):02}:{int(c['start']%60):02} {c['title']}" for c in chapters),encoding='utf-8')
    metadata=';FFMETADATA1\ntitle=LEOTherm v1.2.0 中文完整教程\n'
    for i,c in enumerate(chapters):
        end=chapters[i+1]['start'] if i+1<len(chapters) else elapsed
        metadata+=f"[CHAPTER]\nTIMEBASE=1/1000\nSTART={round(c['start']*1000)}\nEND={round(end*1000)}\ntitle={c['title']}\n"
    (parts/'chapters.ffmeta').write_text(metadata,encoding='utf-8')
    def encode(k):
        part=parts/f'{k+1:02}'; dur=durations[k]
        # Cut once to a close-up where useful. Subtitles stay outside the software image.
        filt=(f"[0:v][1:v]overlay=enable='gte(t,{dur*.40:.3f})'[v];"
              "[v]ass=captions.ass,format=yuv420p[out];[2:a]apad[a]")
        first_input = (['-stream_loop','-1','-framerate','3','-i','rotation/%03d.png']
                       if scenes[k].get('rotation') else ['-loop','1','-framerate',str(FPS),'-i','full.png'])
        run([FFMPEG,'-hide_banner','-loglevel','error','-y',*first_input,
             '-loop','1','-framerate',str(FPS),'-i','detail.png',
             '-i',str(capture/'audio'/f'{k+1:02}.wav'),'-filter_complex',filt,
             '-map','[out]','-map','[a]','-t',f'{dur:.6f}',
             '-c:v','libx264','-preset','veryfast','-crf','20','-threads','2','-r',str(FPS),
             '-c:a','aac','-b:a','128k','-ar','48000','-movflags','+faststart','clip.mp4'],part)
        print(f'ENCODED={k+1:02}/{len(scenes)}',flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(encode,range(len(scenes))))
    (parts/'concat.txt').write_text('\n'.join(f"file '{k+1:02}/clip.mp4'" for k in range(len(scenes))),encoding='utf-8')
    final=capture/'LEOTherm_v1.2.0_中文完整教程.mp4'
    run([FFMPEG,'-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i','concat.txt',
         '-i','chapters.ffmeta','-map_metadata','1','-map_chapters','1','-c','copy','-movflags','+faststart',str(final)],parts)
    print(json.dumps({'video':str(final),'durationSeconds':elapsed,'chapters':len(chapters),'scenes':len(scenes)},ensure_ascii=False),flush=True)


if __name__=='__main__':
    main()
