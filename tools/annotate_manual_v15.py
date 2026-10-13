"""Numbered callouts on real MATLAB UI captures; no UI or result fabrication."""
import json
import csv
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / 'results/manual_capture_v1_5'
OUT = ROOT / 'docs/manual_images/v1_5'
FONT = 'C:/Windows/Fonts/msyh.ttc'

def font(size):
    return ImageFont.truetype(FONT, size)

def target(entries, key):
    kind, value = key.split(':', 1)
    matches = [e for e in entries if e.get(kind) == value and e['position'][2] > 0 and e['position'][3] > 0]
    if not matches:
        raise ValueError(f'Missing real UI target: {key}')
    return matches[0]['position']

# Crops retain the exact captured pixels. Numbered legends explain the targets.
CONFIG = [
    ('01_start', 'start', (0, 0, 1600, 605), [
        ('tag:QuickStartTemplate', '选择 First simulation（第一次仿真）', 'Select First simulation'),
        ('tag:QuickStartRunButton', '按模板运行并生成任务报告', 'Run the template and produce a task report'),
        ('tag:QuickStartAdvancedButton', '只做单场景：从这里进入参数页', 'For a local single scenario, open Advanced simulation'),
        ('tag:QuickStartWizardButton', '选择 JSON 模板并修改少量参数', 'Choose a JSON template and edit its few inputs'),
    ]),
    ('02_paper', 'paper', (0, 220, 950, 540), [
        ('tag:QuickStartTemplate', '选择 Paper: reference task and 36 cases', 'Select Paper: reference task and 36 cases'),
        ('tag:QuickStartRunButton', '点击 Reproduce paper and report；随后选择保存父目录', 'Click Reproduce paper and report; then choose a parent folder'),
    ]),
    ('03_scenario', 'scenario', (0, 270, 430, 1000), [
        ('text:Analysis duration (h)', '演示值：2 h；不是论文 36 工况的设置', 'Tutorial value: 2 h, not the 36-case paper protocol'),
        ('text:Time step (s)', '填写 60：表示每 60 s 输出一个采样点', 'Enter 60: one output sample every 60 s'),
        ('text:Orbit altitude (km)', '演示轨道高度：600 km', 'Tutorial orbit altitude: 600 km'),
        ('tag:RunScenarioButton', '只计算当前单场景，不自动生成 PDF', 'Run only this scenario; do not generate a PDF automatically'),
    ]),
    ('03_scenario', 'complete_task', (0, 105, 1600, 290), [
        ('tag:PipelineSweepCheck', '按需勾选四个阶段；本次不需要的保持未勾选', 'Select only the optional stages needed for this task'),
        ('tag:TaskCheckButton', '先检查完整任务的输入是否就绪', 'Check whether the complete-task inputs are ready'),
        ('tag:TaskRunButton', '这里运行所选流水线，并自动生成 PDF', 'Run the selected pipeline and generate the PDF'),
    ]),
    ('04_results', 'results', (0, 105, 1600, 1000), [
        ('tag:ResultConclusionLabel', '先确认展示的是本次结果', 'Confirm that the displayed result is current'),
        ('tag:GenerateReportButton', '手动导出已有结果的 PDF 和配套数据', 'Export existing results as a PDF and companion data'),
    ]),
    ('05_sweep', 'sweep', (0, 270, 430, 1000), [
        ('text:Sweep mode', '选择扫描模式：高度与目标 beta 角', 'Choose the altitude / target-beta sweep mode'),
        ('text:Altitude (km)', '练习输入 600；按逗号分隔可填写多档高度', 'Practice with 600; use commas for several altitudes'),
        ('text:Target beta angle (deg)', '练习输入 0,30；本图的小扫描只有两组工况', 'Practice with 0,30; this tutorial has only two cases'),
        ('tag:RunSweepButton', '只运行本页扫描；与论文 36 工况复现入口不同', 'Run this page only, not the paper reproduction protocol'),
    ]),
    ('06_network', 'network', (0, 270, 1600, 1000), [
        ('tag:NetworkNodeTable', '在节点表设置热容、功耗等物理参数', 'Set heat capacity, power and other node parameters'),
        ('text:Apply roles and bias settings', '修改响应节点或偏差设置后，点击应用', 'Apply edited response roles and bias settings'),
    ]),
    ('07_geometry', 'geometry', (0, 270, 1600, 520), [
        ('text:Import STL/OBJ', '先选正确的长度单位，再导入表面网格', 'Select the length unit, then import a surface mesh'),
        ('text:Import Gmsh volume mesh', '需要体导热时再导入 Gmsh 体网格', 'Import a Gmsh volume mesh for volume conduction'),
        ('tag:RunSurfaceButton', '仅面片热仿真：点击这个按钮', 'Surface-only thermal run: use this button'),
        ('tag:RunVolumeButton', '仅体导热：点击这个按钮', 'Volume-only conduction: use this button'),
        ('tag:CoupledRunButton', '表面与体耦合：配置边界后再运行', 'For surface-volume coupling, configure boundaries first'),
    ]),
    ('08_model', 'model', (0, 270, 1600, 690), [
        ('tag:ThermalModelImportButton', '载入符合 schema 的 MAT/JSON 热模型', 'Import a schema-compatible MAT/JSON thermal model'),
        ('tag:ThermalModelMappingTemplateButton', '生成映射模板：明确外部节点对应关系', 'Generate a mapping template for external node IDs'),
        ('tag:ThermalModelMappingPreviewButton', '预览映射及单位，再决定是否应用', 'Preview the mapping and units before applying'),
        ('tag:ThermalModelMappingApplyButton', '确认应用后，单场景才使用映射后的网络', 'Confirm and apply so the scenario uses the mapped network'),
    ]),
    ('09_telemetry', 'telemetry', (0, 270, 500, 1000), [
        ('text:Import CSV', '导入自己的 CSV；也可从 More actions 导出空模板', 'Import your CSV; More actions offers a CSV template'),
        ('text:Workflow', '选择轨道驱动、热载荷驱动或已有场景比较', 'Choose orbit, heat-load or current-scenario comparison'),
        ('text:Preflight', '设置列映射、节点与单位后，做数据预检', 'Set column mapping, nodes and units, then run Preflight'),
        ('tag:RunTelemetryButton', '只执行本页仿真或比较', 'Run only this telemetry simulation or comparison'),
    ]),
    ('10_calibration', 'calibration', (0, 270, 1600, 1000), [
        ('text:Prepare calibration', '先准备设备档案和遥测数据', 'Prepare the device profile and telemetry data'),
        ('tag:CalibrationProfileTable', '依据设备参数设置先验、上下界及估计开关', 'Set justified priors, bounds and estimation switches'),
        ('tag:CalibrationDayTable', '按完整 UTC 日期区分训练日与留出日', 'Assign whole UTC days to training and holdout roles'),
        ('tag:RunCalibrationButton', '准备完成后，标定并保存至新运行目录', 'When ready, calibrate and save to a new run directory'),
    ]),
    ('11_progress', 'progress', (430, 365, 1170, 780), [
        ('tag:OperationProgressMessage', '这里显示真实阶段、工况和进度；本截图来自已停止的演示任务', 'Actual stage/case progress; capture from a cancelled tutorial run'),
        ('tag:OperationStopButton', '停止计算：保留已保存工况；不是暂停或自动续跑', 'Stop computation retains saved cases; it is not pause/resume'),
    ]),
    ('12_wizard_inputs', 'wizard_inputs', (0, 0, 840, 421), [
        ('tag:InputValue_1', '任务名：my_first_run（建议英文基础名）', 'Task name: my_first_run'),
        ('tag:InputValue_2', '时长：2 小时；JSON 模板中对应 7200 秒', 'Duration: 2 hours; the JSON equivalent is 7200 seconds'),
        ('tag:InputValue_3', '输出采样间隔：60 秒', 'Output sampling interval: 60 seconds'),
        ('tag:InputAcceptButton', '点 OK 校验；下一步可选只载入或立即运行', 'Click OK to validate; next choose Load only or Run now'),
    ]),
    ('01_start', 'projects', (1180, 0, 1600, 90), [
        ('text:Save project', '保存整个工作区，建议改参数前保存一份', 'Save the workspace before editing its inputs'),
        ('text:Open project', '恢复项目及保存时的语言设置', 'Restore a project and its recorded language'),
    ]),
]

def wrap(draw, text, width, face):
    lines, line = [], ''
    # Character wrapping works for both CJK and long file names.
    for char in text:
        if draw.textlength(line + char, font=face) > width and line:
            lines.append(line.rstrip())
            line = char
        else:
            line += char
    if line:
        lines.append(line.rstrip())
    return lines

def annotated(frame, name, crop, notes, manifest, lang):
    source = Image.open(RAW / f'{frame}.png').convert('RGB')
    entries = manifest['frame_' + frame]
    crop = (crop[0], crop[1], min(crop[2], source.width), min(crop[3], source.height))
    shot = source.crop(crop)
    width = max(shot.width, 900)
    face = font(24)
    probe = ImageDraw.Draw(shot)
    legends = [wrap(probe, n[1 if lang == 'zh' else 2], width - 112, face) for n in notes]
    height = shot.height + 28 + sum(36 * len(ls) + 18 for ls in legends)
    canvas = Image.new('RGB', (width, height), 'white')
    canvas.paste(shot, (0, 0))
    draw = ImageDraw.Draw(canvas)
    for index, (key, _, _) in enumerate(notes, 1):
        x, y, w, h = target(entries, key)
        if frame == '12_wizard_inputs':
            # getframe returns physical pixels for this classic dialog at 150% DPI.
            sx, sy = source.width/560, source.height/281
            x, w, y, h = x*sx, w*sx, y*sy, h*sy
        if name in ('scenario', 'sweep', 'telemetry') and key.startswith('text:') and 'label' in next(e['type'].lower() for e in entries if e.get('text') == key[5:]):
            w = (405 if name == 'scenario' else 378 if name == 'sweep' else 445) - x
        top = source.height - y - h
        rect = [x - crop[0], top - crop[1], x + w - crop[0], top + h - crop[1]]
        if rect[2] < 0 or rect[0] > shot.width or rect[3] < 0 or rect[1] > shot.height:
            raise ValueError(f'Annotation target outside crop: {name} {key} {rect}')
        rect = [max(2, rect[0]-3), max(2, rect[1]-3), min(shot.width-2, rect[2]+3), min(shot.height-2, rect[3]+3)]
        draw.rounded_rectangle(rect, radius=3, outline='#D65324', width=4)
        if name in ('scenario', 'sweep', 'telemetry', 'wizard_inputs'):
            cx, cy = min(width-22, rect[2]+28), (rect[1]+rect[3])/2
            draw.line((cx-16, cy, rect[2], cy), fill='#D65324', width=3)
        elif name == 'projects':
            cx, cy = (rect[0]+rect[2])/2, shot.height-20
            draw.line((cx, cy-15, cx, rect[3]), fill='#D65324', width=3)
        else:
            cx, cy = max(20, rect[0]+8), max(21, rect[1]-16)
            draw.line((cx, cy+13, rect[0]+14, rect[1]+3), fill='#D65324', width=3)
        draw.ellipse((cx-17, cy-17, cx+17, cy+17), fill='#005E85', outline='white', width=2)
        draw.text((cx, cy), str(index), fill='white', font=font(22), anchor='mm')
    draw.line((0, shot.height+8, width, shot.height+8), fill='#CDD9DD', width=2)
    y = shot.height + 26
    for index, lines in enumerate(legends, 1):
        draw.ellipse((22, y, 56, y+34), fill='#005E85')
        draw.text((39, y+17), str(index), fill='white', font=font(22), anchor='mm')
        for j, line in enumerate(lines):
            draw.text((72, y+j*36), line, font=face, fill='#182A33')
        y += len(lines)*36+18
    path = OUT / f'{name}_{lang}.png'
    canvas.save(path, optimize=True)
    return path

def output_map(lang):
    run = Path('C:/LEOTherm_Paper_Test_v1_5_release/paper_result')
    status = json.loads((run/'paper_study_status.json').read_text(encoding='utf-8-sig'))
    assert status['status'] == 'complete' and status['solveJobsCompleted'] == 40
    descriptions = [
        ('paper_study_status.json', '先看 status=complete、40/40', 'First check status=complete and 40/40'),
        ('paper_results.csv', '36 行工况指标，不是 40 行', '36 rows of case metrics, not 40 rows'),
        ('audit.csv', '设计、初始化、热导和驱动的检查', 'Design, initialization, link and forcing checks'),
        ('sweep36/time_refinement.csv', '工况 2、20、36 的时间采样加密比较', 'Sampling refinements for cases 2, 20 and 36'),
        ('open_data/', '39 份工况/加密时序 CSV', '39 case/refinement history CSV files'),
        ('report/thermal_report_en.pdf', '打开英文分析报告', 'Open the English analysis report'),
        ('report/thermal_report_zh.pdf', '打开中文分析报告', 'Open the Chinese analysis report'),
    ]
    for filename, _, _ in descriptions:
        assert (run/filename).exists(), filename
    im = Image.new('RGB', (1100, 1080), 'white')
    d = ImageDraw.Draw(im)
    title = '论文复现结果文件导览（基于实际验证输出）' if lang=='zh' else 'Paper-study output guide (verified run)'
    d.text((30, 22), title, font=font(30), fill='#182A33')
    d.text((30, 78), 'status = complete    |    solveJobsCompleted = 40 / 40', font=font(25), fill='#005E85')
    y = 136
    for i, (filename, cn, en) in enumerate(descriptions, 1):
        d.rectangle((26, y, 1070, y+110), outline='#C3D0D4', width=2)
        d.ellipse((42,y+18,80,y+56), fill='#005E85')
        d.text((61,y+37),str(i),fill='white',font=font(22),anchor='mm')
        d.text((104,y+13),filename,font=font(27),fill='#182A33')
        d.text((104,y+59),cn if lang=='zh' else en,font=font(23),fill='#43545D')
        y += 126
    im.save(OUT/f'output_map_{lang}.png', optimize=True)

def result_checks(lang):
    run = Path('C:/LEOTherm_Paper_Test_v1_5_release/paper_result')
    with (run/'paper_results.csv').open(encoding='utf-8-sig', newline='') as f:
        cases = list(csv.DictReader(f))
    with (run/'audit.csv').open(encoding='utf-8-sig', newline='') as f:
        audit = next(csv.DictReader(f))
    assert len(cases) == 36 and float(audit['case_count']) == 36
    im = Image.new('RGB', (1160, 1100), 'white')
    d = ImageDraw.Draw(im)
    cn = lang == 'zh'
    d.text((28,20), '结果核对导览：来自已完成的 v1.5 输出' if cn else 'Reading a completed v1.5 output', font=font(30), fill='#182A33')
    d.text((28,78), '① paper_results.csv：36行；以下是前3行示例' if cn else '1  paper_results.csv: 36 data rows; first 3 shown',font=font(25),fill='#005E85')
    columns = ['case_id','altitude_km','target_beta_deg','effective_thermal_conductance_w_per_k','rf_temperature_p95_p5_k']
    heads = ['工况','高度 / km','beta / deg','热导 / W/K','RF P95-P5 / K'] if cn else ['Case','Altitude / km','Beta / deg','G / W/K','RF P95-P5 / K']
    xs=[28,155,367,585,826,1132]
    for r in range(4):
        y=126+r*58
        d.rectangle((28,y,1132,y+58),fill='#E7EFF3' if r==0 else 'white',outline='#C8D4D9',width=1)
        for j in range(5):
            text=heads[j] if r==0 else f"{float(cases[r-1][columns[j]]):.3f}" if j>=3 else cases[r-1][columns[j]]
            d.text((xs[j]+12,y+15),text,font=font(23),fill='#182A33')
    spans=[float(row['rf_temperature_p95_p5_k']) for row in cases]
    d.text((28,390), f'RF P95-P5: {min(spans):.3f}–{max(spans):.3f} K',font=font(25),fill='#182A33')
    d.text((28,450), '② audit.csv：四个协议标记均为1' if cn else '2  audit.csv: all four protocol flags equal 1',font=font(25),fill='#005E85')
    flags=['unique_factorial_design','periodic_initialization_passed','only_target_link_changed','forcing_invariant_across_conductance']
    y=507
    for name in flags:
        assert float(audit[name])==1
        d.rectangle((28,y,1132,y+57),outline='#C8D4D9',width=1)
        d.text((42,y+14),name,font=font(23),fill='#182A33')
        d.text((1070,y+14),audit[name],font=font(23),fill='#005E85')
        y+=57
    d.text((28,778),f"max_energy_closure_j = {float(audit['max_energy_closure_j']):.3e} J",font=font(24),fill='#182A33')
    d.text((28,823),f"max_endpoint_difference_k = {float(audit['max_endpoint_difference_k']):.3e} K",font=font(24),fill='#182A33')
    d.text((28,896),'③ 核对自己的结果，不用示例图代替本次验收' if cn else '3  Check your own run, not this example image',font=font(25),fill='#005E85')
    d.text((28,950),'加密表 case_id：2、20、36；PDF在report目录' if cn else 'Refinement case_id: 2, 20, 36; PDFs are under report/',font=font(23),fill='#182A33')
    d.text((28,1000),'数据导览图（非桌面截图）' if cn else 'Data guide, not a desktop screenshot',font=font(22),fill='#43545D')
    im.save(OUT/f'paper_checks_{lang}.png', optimize=True)

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((RAW/'capture_manifest.json').read_text(encoding='utf-8-sig'))
    for spec in CONFIG:
        for lang in ['en','zh']:
            annotated(*spec, manifest, lang)
    for lang in ['en','zh']:
        output_map(lang)
        result_checks(lang)
    print('ANNOTATED_IMAGES_OK', len(CONFIG)*2+4)
