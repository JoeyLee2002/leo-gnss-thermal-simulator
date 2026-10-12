"""Render every report page and sample every tutorial chapter for review."""
from pathlib import Path
import argparse
import json
import subprocess
import re
import wave
import csv
import numpy as np
import pypdfium2 as pdfium
from PIL import Image, ImageDraw, ImageOps

def sheets(images, destination, columns=3, rows=3):
    for first in range(0,len(images),columns*rows):
        subset=images[first:first+columns*rows]
        out=Image.new('RGB',(columns*480,rows*660),'#e9eded')
        for i,path in enumerate(subset):
            image=Image.open(path).convert('RGB'); image=ImageOps.contain(image,(460,625))
            x=(i%columns)*480; y=(i//columns)*660
            out.paste(image,(x+(480-image.width)//2,y+22))
            ImageDraw.Draw(out).text((x+10,y+5),path.stem,fill='black')
        out.save(destination/f'sheet_{first//(columns*rows)+1:02}.jpg')

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('study',type=Path); parser.add_argument('tutorial',type=Path); parser.add_argument('output',type=Path); parser.add_argument('--ffmpeg',required=True); parser.add_argument('--runtime',type=Path); args=parser.parse_args()
    args.output.mkdir(exist_ok=True); records={}
    if args.runtime:
        with (args.study/'paper_results.csv').open(newline='',encoding='utf-8-sig') as file: source=list(csv.DictReader(file))
        with (args.runtime/'paper_results.csv').open(newline='',encoding='utf-8-sig') as file: runtime=list(csv.DictReader(file))
        assert len(source)==len(runtime)==36
        differences=[]; matching_missing=0
        for a,b in zip(source,runtime):
            assert a.keys()==b.keys()
            for key in a:
                if key=='elapsed_wall_s': continue
                try: left=float(a[key]); right=float(b[key])
                except ValueError: assert a[key]==b[key]; continue
                if np.isnan(left) and np.isnan(right): matching_missing+=1; continue
                difference=abs(left-right)
                assert np.isfinite(difference)
                differences.append(difference)
        assert max(differences)==0
        records['source_runtime']={'caseCount':36,'numericValuesCompared':len(differences),'matchingUnavailableOptionalValues':matching_missing,'maximumAbsoluteDifference':max(differences),'excludedColumns':['elapsed_wall_s']}
    for lang in ['zh','en']:
        folder=args.output/f'report_{lang}'; folder.mkdir(exist_ok=True)
        pdf=pdfium.PdfDocument(str(args.study/'report'/f'thermal_report_{lang}.pdf'))
        images=[]; content=[]
        for i in range(len(pdf)):
            page=pdf[i]; path=folder/f'page_{i+1:02}.png'
            page.render(scale=1.5).to_pil().save(path); images.append(path)
            text=page.get_textpage(); content.append(text.get_text_range()); text.close(); page.close()
        records[f'report_{lang}']={'pages':len(pdf),'nonemptyPages':all(content)}
        pdf.close(); (folder/'text.txt').write_text('\n\n'.join(content),encoding='utf-8'); sheets(images,folder)
        video=args.tutorial/f'LEOTherm_v1.2.10_paper_tutorial_{lang}.mp4'
        metadata=subprocess.run([args.ffmpeg,'-i',str(video)],capture_output=True).stderr.decode(errors='replace')
        assert '1920x1080' in metadata and 'Audio: aac' in metadata
        decoded=subprocess.run([args.ffmpeg,'-v','error','-i',str(video),'-f','null','-'],capture_output=True)
        assert decoded.returncode==0,decoded.stderr
        timeline=json.loads((args.tutorial/f'timeline_{lang}.json').read_text(encoding='utf-8'))
        folder=args.output/f'video_{lang}'; folder.mkdir(exist_ok=True); images=[]; levels=[]
        for i,scene in enumerate(timeline):
            path=folder/f'chapter_{i+1:02}.png'
            subprocess.run([args.ffmpeg,'-y','-ss',str(scene['start']+0.7),'-i',str(video),'-frames:v','1',str(path)],check=True,capture_output=True)
            images.append(path)
            with wave.open(str(args.tutorial/lang/'audio'/f'{i+1:02}.wav')) as wav:
                data=np.frombuffer(wav.readframes(wav.getnframes()),dtype='<i2').astype(float)
                levels.append(float(np.sqrt(np.mean(data*data))))
        assert min(levels)>10
        sheets(images,folder,3,3)
        records[f'video_{lang}']={'chapters':len(timeline),'seconds':sum(r['duration'] for r in timeline),'decodePassed':True,'minimumNarrationRms':min(levels),'videoStream':'1920x1080 H.264 / AAC'}
    (args.output/'checks.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
    print(json.dumps(records,indent=2))

if __name__=='__main__': main()
