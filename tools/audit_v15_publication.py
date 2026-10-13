"""Check the curated source checkout against the frozen release records."""
from pathlib import Path
from urllib.parse import urlsplit, unquote
import csv
import hashlib
import json
import re
import sys
import subprocess

root=Path(sys.argv[1]).resolve()
record=root/'docs/verification/v1.5'
manifest=json.loads((record/'publication_source_manifest.json').read_text(encoding='utf-8'))
assert (root/'VERSION').read_text().strip()=='1.5'
assert manifest['sourceFileCount']==185
for name, hashes in manifest['files'].items():
    data=(root/name).read_bytes()
    assert hashlib.sha256(data).hexdigest().upper()==hashes['sha256'], name
    assert hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest().upper()==hashes['normalizedLfSha256'],name

with (record/'paper_results.csv').open(encoding='utf-8-sig',newline='') as f:
    cases=list(csv.DictReader(f))
with (record/'audit.csv').open(encoding='utf-8-sig',newline='') as f:
    audit=next(csv.DictReader(f))
assert len(cases)==36 and float(audit['case_count'])==36
for key in ['unique_factorial_design','periodic_initialization_passed','only_target_link_changed','forcing_invariant_across_conductance']:
    assert float(audit[key])==1
status=json.loads((record/'paper_study_status.json').read_text(encoding='utf-8-sig'))
assert status['status']=='complete' and status['solveJobsCompleted']==40

checked=0
bad=[]
docs=['README.md','README_CN.md','docs/standalone_en.md','docs/quickstart_v1.5.md',
      'docs/usage_v1.5_zh.md','docs/reproduce_paper_v1.5.md','docs/reproduce_paper_v1.5_zh.md']
for name in docs:
    file=root/name
    for url in re.findall(r'\[[^\]]*\]\(([^)]+)\)',file.read_text(encoding='utf-8')):
        parts=urlsplit(url)
        if parts.scheme or not parts.path: continue
        checked+=1
        if not (file.parent/unquote(parts.path)).exists():bad.append((name,url))
assert not bad,bad

secret=re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN (?:RSA |OPENSSH )?PRIVATE KEY-----)')
for folder in ['src','tests','docs','tools']:
    for file in (root/folder).rglob('*'):
        if file.suffix not in {'.md','.txt','.json','.m','.py','.ps1','.mjs'}:continue
        assert not secret.search(file.read_text(encoding='utf-8-sig',errors='replace')),file

result={'sourceFilesMatched':185,'cases':36,'solveJobs':40,'checkedLocalLinks':checked,'brokenLinks':bad,'credentialPatternsFound':0}
if '--committed' in sys.argv:
    command=['git','-c',f'safe.directory={root.as_posix()}','cat-file','--batch']
    names=list(manifest['files'])
    refs=''.join(f'HEAD:{name}\n' for name in names).encode('utf-8')
    data=subprocess.run(command,input=refs,capture_output=True,check=True,cwd=root).stdout
    cursor=0
    for name in names:
        end=data.index(b'\n',cursor)
        header=data[cursor:end].split()
        assert len(header)==3 and header[1]==b'blob',(name,header)
        size=int(header[2])
        content=data[end+1:end+1+size]
        assert hashlib.sha256(content.replace(b'\r\n',b'\n')).hexdigest().upper()==manifest['files'][name]['normalizedLfSha256'],name
        cursor=end+1+size+1
    result['committedSourceFilesMatched']=len(names)
(record/'publication_checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
