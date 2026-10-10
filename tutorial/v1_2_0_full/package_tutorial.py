"""Package only tutorial outputs; exclude temporary desktop recording material."""
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path

source=Path(sys.argv[1]).resolve()
target=Path(__file__).resolve().parent
video='LEOTherm_v1.2.0_中文完整教程.mp4'
for name in [video,'tutorial_zh.srt','chapters.txt']:
    shutil.copy2(source/name,target/name)
shutil.copy2(source/'review/qa.json',target/'验收记录.json')
shutil.copy2(source/'review/scene_10_0.75.jpg',target/'视频预览.jpg')
package=target/'教学案例与报告.zip'
with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED) as archive:
    for name in ['base_project.mat','scan_project.mat','physical_scan_setup.mat','geometry_project.mat',
                 'geometry_completed.mat','telemetry_completed.mat','calibration_completed.mat']:
        archive.write(source/name,Path('projects')/name)
    for name in ['base_run','sweep_run','geometry_run','telemetry_run','calibration_fit']:
        for path in (source/name).rglob('*'):
            if path.is_file():
                archive.write(path,path.relative_to(source))
    archive.write(target/'README_CN.md','README_CN.md')
    for path in (source/'frames/calibration_chart.png').glob('*'):
        if path.is_file():
            archive.write(path,Path('calibration_figures')/path.name)
with zipfile.ZipFile(package) as archive:
    assert archive.testzip() is None
    assert not any('wizard_live' in x for x in archive.namelist())
manifest={}
for path in [target/video,package,target/'tutorial_zh.srt',target/'chapters.txt']:
    manifest[path.name]={'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(target/'交付文件校验.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
