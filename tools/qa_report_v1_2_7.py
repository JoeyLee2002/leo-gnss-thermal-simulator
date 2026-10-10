"""Render both reports and verify the requested reading order and footers."""
import json
import runpy
import sys
from pathlib import Path

import fitz

root = Path(sys.argv[1])
runpy.run_path(str(Path(__file__).with_name('qa_report_v1_2_5.py')), run_name='__main__')
checks = []
for language in ('zh', 'en'):
    with fitz.open(root / f'thermal_report_{language}.pdf') as doc:
        text = ''.join(page.get_text() for page in doc)
        compact = ''.join(text.split())
        assert '关键发现与解读' not in compact
        assert 'Keyfindingsandinterpretation' not in compact
        assert '研究级结果' not in compact
        assert 'Researchresult|' not in compact
        final = ''.join(doc[-1].get_text().split())
        assert ('任务总结' if language == 'zh' else 'Taskconclusions') in final
        errors = []
        for index, page in enumerate(doc):
            footer = [word for word in page.get_text('words') if word[1] > page.rect.height * 0.93]
            assert len(footer) == 1, (language, index + 1, footer)
            word = footer[0]
            assert word[4] == str(index + 1)
            offset = abs((word[0] + word[2]) / 2 - page.rect.width / 2)
            assert offset < 1.0, (language, index + 1, offset)
            errors.append(offset)
        markdown = (root / f'thermal_report_{language}.md').read_text(encoding='utf-8')
        assert '关键发现与解读' not in markdown
        assert 'Key findings and interpretation' not in markdown
        checks.append({'language': language, 'pages': len(doc),
                       'max_page_number_center_error_pt': max(errors),
                       'opening_synthesis_removed': True, 'conclusions_retained': True})
(root / 'qa' / 'layout_checks.json').write_text(json.dumps(checks, indent=2), encoding='utf-8')
print(json.dumps(checks))
