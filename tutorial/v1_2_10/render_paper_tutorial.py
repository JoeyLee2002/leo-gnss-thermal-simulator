"""Bilingual reviewer guides built from production GUI and new run evidence."""
import argparse
import json
import subprocess
import wave
from pathlib import Path

import os
import shutil
import re
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageFont, ImageOps

FFMPEG = os.environ.get('LEOTHERM_FFMPEG') or shutil.which('ffmpeg')
if not FFMPEG:
    try:
        import imageio_ffmpeg
        FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        raise RuntimeError('Install FFmpeg or set LEOTHERM_FFMPEG to its executable.')
PYTHON_FONT = 'C:/Windows/Fonts/msyh.ttc'
W, H = 1920, 1080


def font(size):
    return ImageFont.truetype(PYTHON_FONT, size)


def wrap(text, size, width):
    if not re.search(r'[\u4e00-\u9fff]',text):
        lines=[]
        for paragraph in text.split('\n'):
            line=''
            for word in paragraph.split():
                candidate=(line+' '+word).strip()
                if line and font(size).getlength(candidate)>width:
                    lines.append(line); line=word
                else:
                    line=candidate
            lines.append(line)
        return lines
    lines, current = [], ''
    for char in text:
        if char == '\n' or font(size).getlength(current + char) > width:
            lines.append(current)
            current = '' if char == '\n' else char
        else:
            current += char
    if current:
        lines.append(current)
    return lines


def card(path, title, paragraphs):
    out = Image.new('RGB', (1500, 900), 'white')
    d = ImageDraw.Draw(out)
    d.text((55, 40), title, font=font(38), fill='#1b393c')
    y = 130
    for p in paragraphs:
        for line in wrap(p, 29, 1380):
            d.text((55, y), line, font=font(29), fill='#263538')
            y += 49
        y += 33
    assert y < 860, (title, y)
    out.save(path)


def prepare(output, study):
    summary = json.loads((study/'paper_study_status.json').read_text())
    assert summary['status'] == 'complete' and summary['caseCount'] == 36
    for lang in ['zh', 'en']:
        zh = lang == 'zh'
        folder = output/lang
        captures = {r['image']: r for r in json.loads((folder/'captures.json').read_text())}
        titles = [
            ('启动软件', 'Launch the software'),
            ('选择论文复现任务', 'Select the paper study'),
            ('点击运行并选择保存位置', 'Run and select the output location'),
            ('确认固定实验配置', 'Review the fixed experiment protocol'),
            ('查看11节点热网络', 'Inspect the 11-node thermal network'),
            ('打开本次任务报告', 'Open the study report'),
            ('核对36工况与论文结果', 'Check the 36-case results'),
            ('检查完整性和步长加密', 'Check completeness and time refinement'),
            ('源码和Runtime复现入口', 'Source and Runtime entry points')]
        texts = [
            ('这是 LEOTherm 一点二点十版。打开软件后进入快速开始。中文和英文使用相同的模型与求解器，语言只改变界面、图表和报告。',
             'This is LEOTherm version one point two point ten. Start in Quick start. Chinese and English use the same model and solver; language only changes the interface, plots and report.'),
            ('在我要做什么下拉框中，选择复现论文，参考任务与三十六工况。无需逐项填写模型参数。这个入口使用论文的固定配置，自动运行参考任务、三十六工况和三个步长加密算例。',
             'In the goal dropdown, select Paper: reference task and 36 cases. You do not need to enter model parameters individually. This entry uses the fixed paper protocol and runs the reference task, all 36 conditions and three time-refinement cases.'),
            ('点击复现论文并生成报告。选择一个用于保存结果的父目录，软件会创建新的任务子目录，不覆盖旧结果。然后等待全部计算和报告完成。这里省略计算等待时间。完成后，软件会自动打开当前语言的报告。',
             'Click Reproduce paper and report. Choose a parent folder for the outputs. The software creates a new task subfolder without overwriting previous results. Wait for the computations and report export to finish. Computation time is omitted here. On completion, the report opens in the current language.'),
            ('参考任务计算两小时，输出间隔六十秒，不预热。三十六工况是三个轨道高度、四个目标贝塔角与三档结构到射频前端的等效热导组合。每个工况先达到周期初始化条件，再分析六个轨道周期。不要把参考任务的初始瞬态与周期工况混为一谈。',
             'The reference task covers two hours with a 60-second output interval and no warmup. The 36-case study combines three orbital altitudes, four target beta angles and three effective thermal conductances between the structure and RF front end. Each case is initialized periodically before six orbits are analyzed. Keep this separate from the reference-task initial transient.'),
            ('十一节点网络区分六个外表面、主体结构、天线以及接收机电子部件。矩阵记录节点间的等效热导，单位瓦每开尔文。工况扫描只改变结构与射频前端之间的一条连接，其余设备参数保持不变。',
             'The eleven-node network distinguishes six exterior faces, the structure, antenna and receiver electronics. The matrix records effective thermal conductance in watts per kelvin. The study changes only the structure-to-RF link; all other equipment parameters stay fixed.'),
            ('本次任务的总报告位于任务目录下面的 report 文件夹。报告包含参考任务温度、环境吸收功率、导热关系、三十六工况曲线和配对分析。中文和英文报告来自同一批结果，不需要另跑仿真。',
             'The combined study report is in the report folder of the new task directory. It includes reference temperatures, absorbed external power, conductive paths, 36-case curves and paired comparisons. Both language reports come from the same results; a separate simulation is not needed.'),
            ('图的上排比较射频前端温度第九十五与第五百分位数之差，下排比较相对于总外部吸收功率的轨道基频相位时延。温度百分位差范围约零点九九五到六点零四八开尔文。增强热导在入影工况下增大波动，在持续光照下减小波动，十二组配对的相位时延都缩短。',
             'The upper panels compare RF temperature P95 minus P5; the lower panels compare orbital-frequency phase delay relative to total absorbed external power. The temperature difference ranges from about 0.995 to 6.048 kelvin. Increasing conductance increases fluctuations in eclipsing cases, reduces them under continuous sunlight, and shortens phase delay in all twelve orbital pairs.'),
            ('先查看任务状态是否为 complete，工况数是否为三十六。再查看审计表和时间步长加密表。第二、二十和三十六工况使用两倍输出分辨率独立重算。报告给出本次实际差值，完整温度时间序列保存在 open data 目录，可自行复核。',
             'Check that the task status is complete and the case count is 36. Then inspect the audit and time-refinement tables. Cases two, twenty and thirty-six are independently recomputed at twice the output resolution. The report shows the measured differences. Full temperature histories are retained in open_data for independent checking.'),
            ('有 MATLAB 时，可调用这里显示的源码命令。没有 MATLAB 许可证时，安装免费的二零二一年 b 版 Runtime，使用新版可执行程序的 paper study 参数。结果目录必须是新目录。遇到中断，先看状态文件中的阶段和错误信息，再选择新目录重跑。',
             'With MATLAB, use the source command shown here. Without a MATLAB license, install the free R2021b Runtime and use the paper-study argument of the new executable. The output directory must be new. If execution stops, inspect the stage and error in the status file before rerunning into a fresh directory.')]
        image_names = ['01_start.png', '02_paper.png', '03_run.png', 'protocol.png', '05_network.png', 'report.png', 'study.png', 'checks.png', 'commands.png']
        card(folder/'protocol.png', titles[3][0 if zh else 1], [
            'Reference: 7200 s; 60 s output; warmup = 0',
            'Altitude: 400 / 600 / 800 km', 'Target beta: 0 / 30 / 60 / 75 deg',
            'Effective thermal conductance: 0.31 / 0.62 / 1.24 W/K',
            'Periodic initialization: 0.001 K; analysis: 6 orbits',
            '360 output intervals/orbit; refined cases 2 / 20 / 36: 720'] if not zh else [
            '参考任务：7200 s；60 s 输出间隔；预热圈数 0',
            '高度：400 / 600 / 800 km；目标 β 角：0° / 30° / 60° / 75°',
            '结构—射频前端等效热导：0.31 / 0.62 / 1.24 W/K',
            '周期初始化条件：0.001 K；分析：6 圈',
            '每圈 360 个输出间隔；第 2 / 20 / 36 工况加密为 720'])
        pdf=pdfium.PdfDocument(str(study/'report'/f'thermal_report_{lang}.pdf'))
        pdf[0].render(scale=1.7).to_pil().save(folder/'report.png')
        pdf.close()
        Image.open(study/'report'/f'publication_paper_study_{lang}.png').save(folder/'study.png')
        import csv
        refinement=list(csv.DictReader((study/'sweep36/time_refinement.csv').open()))
        rows=[(f"工况 {r['case_id']}：P95-P5 差值 {float(r['rf_span_difference_k']):.6f} K；相位时延差值 {float(r['harmonic_delay_difference_s']):.4f} s" if zh else f"Case {r['case_id']}: P95-P5 difference {float(r['rf_span_difference_k']):.6f} K; phase-delay difference {float(r['harmonic_delay_difference_s']):.4f} s") for r in refinement]
        card(folder/'checks.png', titles[7][0 if zh else 1], [
            'paper_study_status.json: status = complete; caseCount = 36',
            'audit.csv：36 个独立工况；周期初始化通过；只改变一条连接' if zh else 'audit.csv: 36 unique cases; periodic initialization; one link changed',
            *rows, 'open_data/：全部36工况温度及外部吸收功率时间序列' if zh else 'open_data/: all 36 temperature and absorbed-power histories'])
        card(folder/'commands.png', titles[8][0 if zh else 1], [
            "MATLAB:\naddpath('src');\nstudy=leotherm.runPaperStudy('C:/LEOThermResults/run_01','both');",
            'Windows Runtime R2021b:\n.\\LEOTherm.exe --paper-study "C:\\LEOThermResults\\run_01" both',
            'docs/reproduce_paper_v1.2.10.md\ndocs/论文结果复现_v1.2.10.md'])
        scenes=[]
        for i, (title, narration, image) in enumerate(zip(titles,texts,image_names)):
            rect=captures.get(image,{}).get('rect',[])
            scenes.append({'title':title[0 if zh else 1], 'narration':narration[0 if zh else 1], 'image':image,'rect':rect})
        (folder/'scenes.json').write_text(json.dumps(scenes,ensure_ascii=False,indent=2),encoding='utf-8')


def stamp(seconds, ass=False):
    p=100 if ass else 1000
    t=round(seconds*p); hh,t=divmod(t,3600*p); mm,t=divmod(t,60*p); ss,frac=divmod(t,p)
    return f'{hh}:{mm:02}:{ss:02}.{frac:02}' if ass else f'{hh:02}:{mm:02}:{ss:02},{frac:03}'


def render(output):
    for lang in ['zh','en']:
        folder=output/lang; scenes=json.loads((folder/'scenes.json').read_text(encoding='utf-8'))
        parts=folder/'parts'; parts.mkdir(exist_ok=True)
        timeline=[]; subtitles=[]; elapsed=0
        for i,s in enumerate(scenes):
            image=Image.open(folder/s['image']).convert('RGB')
            base=Image.new('RGB',(W,H),'#f2f5f5'); d=ImageDraw.Draw(base)
            d.rectangle((0,0,W,78),fill='#183d42'); d.text((30,16),s['title'],font=font(34),fill='white')
            d.text((1730,25),f'{i+1:02} / {len(scenes):02}',font=font(23),fill='white')
            view=ImageOps.contain(image,(1810,810),Image.Resampling.LANCZOS)
            x=(W-view.width)//2; y=95+(810-view.height)//2
            base.paste(view,(x,y)); d.rectangle((0,945,W,H),fill='#142d31')
            label='LEOTherm v1.2.10 | 实际界面与本次结果 | 操作位置高亮' if lang=='zh' else 'LEOTherm v1.2.10 | Production GUI and new run results | Highlighted control locations'
            d.text((35,918),label,font=font(18),fill='#496269')
            file=parts/f'{i:02}.png'; base.save(file)
            audio=folder/'audio'/f'{i+1:02}.wav'
            with wave.open(str(audio)) as wav:
                duration=wav.getnframes()/wav.getframerate()+0.8
            caption_lines=wrap(s['narration'],31,1780)
            chunks=['\\N'.join(caption_lines[k:k+2]) for k in range(0,len(caption_lines),2)]
            events=[]
            for j,c in enumerate(chunks):
                start=j*duration/len(chunks); end=(j+1)*duration/len(chunks)
                events.append(f'Dialogue: 0,{stamp(start,True)},{stamp(end,True)},Default,,0,0,0,,{c}')
                subtitles.append((elapsed+start,elapsed+end,c.replace('\\N','\n')))
            ass=parts/f'{i:02}.ass'
            ass.write_text('[Script Info]\nScriptType: v4.00+\nPlayResX: 1920\nPlayResY: 1080\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Microsoft YaHei,31,&H00FFFFFF,&H00FFFFFF,&H00142D31,&H00142D31,0,0,0,0,100,100,0,0,1,0,0,2,70,70,25,1\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n'+'\n'.join(events),encoding='utf-8-sig')
            vf=f"subtitles={ass.name}"
            if s['rect']:
                a,b,c,e=s['rect']; scale=view.width/image.width
                box=[round(x+a*scale),round(y+b*scale),round(c*scale),round(e*scale)]
                vf+=f",drawbox=x={box[0]-4}:y={box[1]-4}:w={box[2]+8}:h={box[3]+8}:color=0xE67C20:t=4:enable='lt(mod(t,2),1.4)'"
            cmd=[FFMPEG,'-y','-loop','1','-i',file.name,'-i',str(audio.resolve()),'-vf',vf,'-t',str(duration),'-r','15','-c:v','libx264','-preset','veryfast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k',f'{i:02}.mp4']
            completed=subprocess.run(cmd,cwd=parts,capture_output=True)
            if completed.returncode: raise RuntimeError(completed.stderr.decode(errors='replace')[-4000:])
            timeline.append({'chapter':s['title'],'start':elapsed,'duration':duration,'source':s['image'],'control':s['rect']})
            elapsed+=duration
        concat=parts/'concat.txt'; concat.write_text('\n'.join(f"file '{i:02}.mp4'" for i in range(len(scenes))),encoding='ascii')
        video=output/f'LEOTherm_v1.2.10_paper_tutorial_{lang}.mp4'
        subprocess.run([FFMPEG,'-y','-f','concat','-safe','0','-i',str(concat),'-c','copy','-movflags','+faststart',str(video)],check=True,capture_output=True)
        (output/f'LEOTherm_v1.2.10_paper_tutorial_{lang}.srt').write_text('\n\n'.join(f'{i+1}\n{stamp(a)} --> {stamp(b)}\n{c}' for i,(a,b,c) in enumerate(subtitles)),encoding='utf-8')
        (output/f'timeline_{lang}.json').write_text(json.dumps(timeline,ensure_ascii=False,indent=2),encoding='utf-8')
        print(f'{lang}: {elapsed:.1f} s; {video}')


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('output',type=Path); parser.add_argument('--study',type=Path); parser.add_argument('--prepare',action='store_true'); args=parser.parse_args()
    if args.prepare: prepare(args.output.resolve(),args.study.resolve())
    else: render(args.output.resolve())
