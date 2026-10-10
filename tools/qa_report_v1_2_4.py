"""Render every report page and record text/layout checks."""
import json
import sys
from pathlib import Path

import fitz
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
qa = root / 'qa'
qa.mkdir(exist_ok=True)
checks = []
for lang in ('zh', 'en'):
    doc = fitz.open(root / f'thermal_report_{lang}.pdf')
    texts = []
    thumbs = []
    outside = []
    for index, page in enumerate(doc):
        texts.append(page.get_text())
        for block in page.get_text('blocks'):
            if not (page.rect + (-1, -1, 1, 1)).contains(fitz.Rect(block[:4])):
                outside.append({'page': index + 1, 'box': list(block[:4])})
        target = qa / f'{lang}_{index+1:02}.png'
        page.get_pixmap(matrix=fitz.Matrix(1.5, 1.5)).save(target)
        im = Image.open(target).convert('RGB')
        im.thumbnail((300, 410))
        tile = Image.new('RGB', (320, 440), 'white')
        tile.paste(im, ((320-im.width)//2, 20))
        ImageDraw.Draw(tile).text((10, 420), f'{lang} / {index+1}', fill='black')
        thumbs.append(tile)
    for first in range(0, len(thumbs), 9):
        sheet = Image.new('RGB', (960, 1320), '#d0d0d0')
        for j, tile in enumerate(thumbs[first:first+9]):
            sheet.paste(tile, ((j % 3)*320, (j//3)*440))
        sheet.save(qa / f'contact_{lang}_{first//9+1}.png')
    combined = '\n'.join(texts)
    banned = ['未提供 s', 'NaN s', '阅读结论', '不确定', '不正确', '不完整', '不完善']
    found = [word for word in banned if word in combined]
    checks.append({'language': lang, 'pages': len(doc), 'outside': outside, 'unwanted_text': found})
    (qa / f'text_{lang}.txt').write_text(combined, encoding='utf-8')
(qa / 'checks.json').write_text(json.dumps(checks, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(checks, ensure_ascii=False))
assert not any(row['outside'] or row['unwanted_text'] for row in checks)
