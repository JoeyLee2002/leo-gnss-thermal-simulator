"""Build a documentation-only release; preserve the tested EXE byte-for-byte."""
from pathlib import Path
import hashlib
import json
import shutil
import zipfile
import re
from urllib.parse import urlsplit, unquote

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'results/release_staging_v1_5_release'
STAGE = ROOT/'results/release_staging_v1_5_illustrated'
ARCHIVE = ROOT/'results/LEOTherm_1.5_windows_release_illustrated.zip'
EXPECTED_EXE = 'CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE'
MAP = {
    'usage_v1.5_zh':'USAGE_CN', 'quickstart_v1.5':'USAGE_EN',
    'reproduce_paper_v1.5_zh':'PAPER_REPRODUCTION_CN',
    'reproduce_paper_v1.5':'PAPER_REPRODUCTION_EN',
    'verification_v1.5_release':'REPORT_AUDIT_CN', 'tutorials_v1.5':'TUTORIALS',
    'report_v1.5_zh':'REPORT_GUIDE_CN', 'plotting_v1.5_zh':'PLOTTING_CN',
    '术语与指标':'METRICS_CN',
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def stage_files():
    assert sha(BASE/'LEOTherm.exe') == EXPECTED_EXE
    if STAGE.exists():
        raise FileExistsError('Use a new staging directory; do not overwrite a release.')
    shutil.copytree(BASE, STAGE)
    for src, dst in list(MAP.items())[:4]:
        text = (ROOT/'docs'/f'{src}.md').read_text(encoding='utf-8')
        for old, new in MAP.items():
            text = text.replace(old+'.md', new+'.md')
        (STAGE/f'{dst}.md').write_text(text, encoding='utf-8')
    shutil.copytree(ROOT/'docs/manual_images', STAGE/'manual_images')
    for relative in ['examples/assets/example_coupled_surface.obj',
                     'examples/assets/example_two_tetrahedra.msh',
                     'examples/projects/06_engineering_model_exchange.json']:
        target = STAGE/relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT/relative, target)
    shutil.copy2(ROOT/'patches/PATCH_v1.5_illustrated_manuals.md', STAGE/'PATCH_v1.5_illustrated_manuals.md')
    shutil.copy2(ROOT/'docs/illustrated_release_readme_v1.5.md', STAGE/'README.md')
    index='''<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><title>LEOTherm 1.5 Illustrated Manuals</title><style>body{font:18px/1.7 Arial,"Microsoft YaHei",sans-serif;max-width:900px;margin:50px auto;padding:24px;color:#182a33}a{color:#005e85}li{margin:16px 0}h1{font-size:30px}small{font-size:15px}</style></head><body><h1>LEOTherm 1.5 图解手册 / Illustrated Manuals</h1><p>先完整解压，再双击 LEOTherm.exe。需要免费的 MATLAB Runtime R2021b。</p><p>Extract the entire package, then launch LEOTherm.exe with free MATLAB Runtime R2021b.</p><ul><li><a href="USAGE_CN.html">中文用户手册：设置、运行、导出</a> · <a href="USAGE_CN.pdf">PDF</a></li><li><a href="USAGE_EN.html">English User Manual</a> · <a href="USAGE_EN.pdf">PDF</a></li><li><a href="PAPER_REPRODUCTION_CN.html">中文论文复现：40个求解任务、36个工况和结果核对</a> · <a href="PAPER_REPRODUCTION_CN.pdf">PDF</a></li><li><a href="PAPER_REPRODUCTION_EN.html">English Paper Reproduction</a> · <a href="PAPER_REPRODUCTION_EN.pdf">PDF</a></li></ul><p><small>HTML可点击图片放大；所有图片本地随包，无需联网。HTML images can be opened at full size; all assets are local.</small></p></body></html>'''
    (STAGE/'START_HERE.html').write_text(index, encoding='utf-8')
    print('MANUAL_STAGE_OK', STAGE)

def archive_files():
    assert sha(STAGE/'LEOTherm.exe') == EXPECTED_EXE
    assert not ARCHIVE.exists(), 'Preserve existing archives.'
    render = json.loads((STAGE/'manual_render_audit.json').read_text(encoding='utf-8'))
    assert len(render)==4 and all(row['images']==row['validImages'] for row in render)
    manifest = {
        'version':'1.5','build':'release_illustrated','changeScope':'Documentation and small example inputs only',
        'exeSha256':EXPECTED_EXE,'exeUnchanged':True,
        'baseArchiveSha256':sha(ROOT/'results/LEOTherm_1.5_windows_release.zip'),
        'manualRenderAudit':render,
        'files':{p.relative_to(STAGE).as_posix():sha(p) for p in sorted(STAGE.rglob('*')) if p.is_file()}
    }
    (STAGE/'illustrated_package_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    with zipfile.ZipFile(ARCHIVE, 'w', zipfile.ZIP_DEFLATED, compresslevel=8) as z:
        for file in sorted(STAGE.rglob('*')):
            if file.is_file():
                z.write(file, file.relative_to(STAGE).as_posix())
    with zipfile.ZipFile(ARCHIVE) as z:
        assert z.testzip() is None
        assert hashlib.sha256(z.read('LEOTherm.exe')).hexdigest().upper()==EXPECTED_EXE
        assert all(not any(ord(c)>127 for c in name) for name in z.namelist())
    verify_archive_links()
    summary={'archive':str(ARCHIVE),'bytes':ARCHIVE.stat().st_size,'sha256':sha(ARCHIVE),'exeSha256':EXPECTED_EXE,'exeUnchanged':True}
    (ROOT/'results/illustrated_manuals_v1_5_package_audit.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
    print(json.dumps(summary,indent=2))

def verify_archive_links():
    checked=0
    with zipfile.ZipFile(ARCHIVE) as z:
        entries=set(z.namelist())
        for name in ['USAGE_CN.html','USAGE_EN.html','PAPER_REPRODUCTION_CN.html','PAPER_REPRODUCTION_EN.html','START_HERE.html']:
            html=z.read(name).decode('utf-8')
            for url in re.findall(r'(?:href|src)="([^"]+)"',html):
                parts=urlsplit(url)
                if parts.scheme or not parts.path: continue
                assert unquote(parts.path) in entries, (name,url)
                checked+=1
    print('ZIP_LINKS_OK',checked)

if __name__ == '__main__':
    import sys
    if '--verify' in sys.argv:
        verify_archive_links()
    elif '--archive' in sys.argv:
        archive_files()
    else:
        stage_files()
