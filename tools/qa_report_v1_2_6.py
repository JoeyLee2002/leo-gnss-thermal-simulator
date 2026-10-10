"""Verify rendered synthesis pages and their machine-readable evidence."""
import csv
import json
import runpy
import sys
from pathlib import Path

import fitz

root=Path(sys.argv[1])
runpy.run_path(str(Path(__file__).with_name('qa_report_v1_2_5.py')),run_name='__main__')
with (root/'thermal_interpretation_evidence.csv').open(encoding='utf-8-sig',newline='') as source:
    rows=list(csv.DictReader(source))
values={row['metric']:float(row['value']) for row in rows}
shares=[values['external_share_'+key] for key in ('directSolarW','albedoW','earthIRW')]
assert abs(sum(shares)-100)<1e-8
assert 0<=values['response_to_largest_nodal_range']<=100
checks=[]
for language in ('zh','en'):
    with fitz.open(root/f'thermal_report_{language}.pdf') as doc:
        pages=[page.get_text() for page in doc]
    heading='关键发现与解读' if language=='zh' else 'Key findings and interpretation'
    closing='任务总结' if language=='zh' else 'Task conclusions'
    assert any(heading in page for page in pages)
    assert closing in pages[-1]
    assert ('平均净' if language=='zh' else 'mean net') in '\n'.join(pages)
    checks.append({'language':language,'pages':len(pages),'findings_and_conclusions':'passed'})
(root/'qa'/'synthesis_checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print(json.dumps({'checks':checks,'evidence_metrics':len(values),'external_heat_shares':shares}))
