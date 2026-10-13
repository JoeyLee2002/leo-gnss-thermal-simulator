"""Validate local guide assets, PDF content and unchanged release code."""
from pathlib import Path
from urllib.parse import unquote, urlsplit
import hashlib
import json
import re
import subprocess
import zipfile
from PIL import Image, ImageDraw, ImageFont
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'results/release_staging_v1_5_illustrated'
QA=ROOT/'results/manual_qa_v1_5'
QA.mkdir(exist_ok=True)
POPPLER=Path('C:/Users/30698/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin/pdftoppm.exe')
NAMES=['USAGE_CN','USAGE_EN','PAPER_REPRODUCTION_CN','PAPER_REPRODUCTION_EN']
face=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)

def digest(data): return hashlib.sha256(data).hexdigest()

def contact_sheet(files, output, thumb=(255,360), columns=4):
    rows=(len(files)+columns-1)//columns
    image=Image.new('RGB',(columns*(thumb[0]+18),rows*(thumb[1]+48)),'#e5ebee')
    draw=ImageDraw.Draw(image)
    for i,file in enumerate(files):
        page=Image.open(file).convert('RGB')
        page.thumbnail(thumb)
        x=(i%columns)*(thumb[0]+18)+9
        y=(i//columns)*(thumb[1]+48)+34
        image.paste(page,(x+(thumb[0]-page.width)//2,y))
        draw.text((x,y-28),file.stem,font=face,fill='#182A33')
    image.save(output)

report=[]
for name in NAMES:
    html=(STAGE/f'{name}.html').read_text(encoding='utf-8')
    bad=[]
    for url in re.findall(r'(?:href|src)="([^"]+)"',html):
        parts=urlsplit(url)
        if parts.scheme or not parts.path: continue
        if not (STAGE/unquote(parts.path)).exists(): bad.append(url)
    assert not bad, (name,bad)
    pdf=STAGE/f'{name}.pdf'
    reader=PdfReader(pdf)
    empty=[]
    for i,page in enumerate(reader.pages,1):
        text=page.extract_text() or ''
        if len(text.strip())<20 and not page.images: empty.append(i)
    assert not empty,(name,'empty PDF pages',empty)
    prefix=QA/name
    subprocess.run([str(POPPLER),'-scale-to','850','-png',str(pdf),str(prefix)],check=True,capture_output=True)
    digits=len(str(len(reader.pages)))
    pages=[QA/f'{name}-{i:0{digits}d}.png' for i in range(1,len(reader.pages)+1)]
    assert all(p.exists() for p in pages)
    contact_sheet(pages,QA/f'{name}_contact.png')
    report.append({'guide':name,'pages':len(reader.pages),'brokenLinks':bad,'emptyPages':empty})

snapshot=Path('H:/paper/leo-gnss-thermal-simulator_versions/LEOTherm_1.5_before_illustrated_manuals_20261013.zip')
with zipfile.ZipFile(snapshot) as z:
    source_names=[n for n in z.namelist() if n.startswith('src/')]
    for name in source_names:
        assert digest(z.read(name))==digest((ROOT/name).read_bytes()), f'Release source changed: {name}'

report.append({'releaseSrcFilesUnchanged':len(source_names),'exeUnchanged':digest((STAGE/'LEOTherm.exe').read_bytes()).upper()=='CAEB39ECC63D81479E6356F7BBD6DC1FA691BA1EE618C20B9F52CE0DD3928BDE'})
(ROOT/'results/illustrated_manuals_v1_5_qa.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
