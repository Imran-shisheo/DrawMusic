#!/usr/bin/env python3
"""Restore the reviewed project tree from the checksum-verified bootstrap bundle."""
from pathlib import Path
import hashlib,json,subprocess,tempfile
root=Path(__file__).resolve().parent
manifest=json.loads((root/'bootstrap-manifest.json').read_text())
allowed={'README.md','PRD.md','AGENTS.md','.fvmrc','BOOTSTRAP.md','restore_bootstrap.py','bootstrap-manifest.json',*(p['name'] for p in manifest['parts'])}
tracked=set(subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')[:-1])
if tracked-allowed:raise SystemExit('Unexpected tracked files; inspect instead of replacing: '+str(sorted(tracked-allowed)))
if subprocess.check_output(['git','status','--porcelain'],cwd=root).strip():raise SystemExit('Working tree must be clean before restoring the reviewed project.')
with tempfile.TemporaryDirectory(prefix='drawmusic-bootstrap-') as temp:
 bundle=Path(temp)/'source.bundle'
 with bundle.open('wb') as output:
  for item in manifest['parts']:
   data=(root/item['name']).read_bytes()
   if len(data)!=item['bytes'] or hashlib.sha256(data).hexdigest()!=item['sha256']:raise SystemExit('Part verification failed: '+item['name'])
   output.write(data)
 if bundle.stat().st_size!=manifest['bundle_bytes'] or hashlib.sha256(bundle.read_bytes()).hexdigest()!=manifest['bundle_sha256']:raise SystemExit('Bundle verification failed')
 subprocess.run(['git','bundle','verify',str(bundle)],cwd=root,check=True)
 subprocess.run(['git','fetch',str(bundle),'main:refs/remotes/research-bootstrap/main'],cwd=root,check=True)
 source=subprocess.check_output(['git','rev-parse','refs/remotes/research-bootstrap/main'],cwd=root,text=True).strip()
 if not source.startswith(manifest['source_commit']):raise SystemExit('Unexpected source commit')
 subprocess.run(['git','restore','--source=refs/remotes/research-bootstrap/main','--staged','--worktree','--','.'],cwd=root,check=True)
 print('Restored reviewed project:',source)
 print('Bootstrap transport files are removed from the new tree. Review, commit and push the restored setup before implementing the app.')
