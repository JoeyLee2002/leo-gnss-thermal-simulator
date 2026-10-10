"""Render the report and verify the two repaired metadata fields."""
import csv
import json
import runpy
import sys
from pathlib import Path

import fitz

root = Path(sys.argv[1])
runpy.run_path(str(Path(__file__).with_name('qa_report_v1_2_4.py')), run_name='__main__')
with (root / 'thermal_sections.csv').open(encoding='utf-8-sig', newline='') as source:
    rows = list(csv.DictReader(source))
frame = next(row for row in rows if row['field'] == 'trajectory_frame')
telemetry = next(row for row in rows if row['field'] == 'telemetry_status')
assert frame['value'] == 'approximate_geocentric_equatorial'
assert frame['status'] == 'available'
assert telemetry['value'] == 'not_run_no_data'
assert telemetry['status'] == 'available'
checks = []
for lang in ('zh', 'en'):
    with fitz.open(root / f'thermal_report_{lang}.pdf') as doc:
        text = ''.join(page.get_text() for page in doc)
    compact = ''.join(text.split())
    if lang == 'zh':
        assert '轨道坐标系:地心赤道坐标系（内置近似轨道模型）' in compact
        assert '遥测比较:未执行（本次未导入遥测数据）' in compact
        assert '轨道坐标系:未提供' not in compact
        assert '状态:未提供' not in compact
    else:
        assert 'Trajectorycoordinatesystem:Geocentricequatorialaxes' in compact
        assert 'Telemetrycomparison:Notrun(notelemetrydataimportedforthistask)' in compact
    checks.append({'language': lang, 'coordinate_and_telemetry_labels': 'passed'})
(root / 'qa' / 'metadata_checks.json').write_text(
    json.dumps(checks, indent=2), encoding='utf-8')
print(json.dumps(checks))
