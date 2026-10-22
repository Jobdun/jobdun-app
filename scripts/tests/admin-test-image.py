#!/usr/bin/env python3
"""Infrastructure retries must preserve image identity and never skip SQL tests."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory() as folder:
 p=Path(folder)
 (p/'docker').write_text('''#!/usr/bin/env python3
import os,sys,pathlib
p=pathlib.Path(os.environ['FAKE_PULL_COUNT']);n=int(p.read_text())+1 if p.exists() else 1;p.write_text(str(n))
mode=os.environ['FAKE_PULL_MODE']
sys.exit(0 if (mode=='retry' and n==3) or (mode=='fallback' and 'public.ecr.aws/' in sys.argv[-1]) else 1)
''')
 (p/'sleep').write_text('#!/bin/sh\nexit 0\n')
 for name in ['docker','sleep']:(p/name).chmod(0o700)
 for mode,success,registry in [('retry',True,'ghcr.io'),('fallback',True,'public.ecr.aws'),('fail',False,None)]:
  target=p/'env';counter=p/'counter'
  for f in [target,counter]:
   if f.exists():f.unlink()
  env=dict(os.environ,PATH=str(p)+os.pathsep+os.environ['PATH'],FAKE_PULL_MODE=mode,FAKE_PULL_COUNT=str(counter),GITHUB_ENV=str(target))
  result=subprocess.run(['bash',str(root/'scripts/prepare-admin-test-image.sh')],env=env,capture_output=True,text=True)
  assert (result.returncode==0)==success,(mode,result.stderr)
  if success:assert registry in target.read_text() and '@sha256:dda62da900896d4a8f1cf687cd9912c8d3ea4ad442c9273c27848fa8f42da6cc' in target.read_text()
  else:assert not target.exists(),'Failed downloads must not export a usable image'
print('3 image preparation regression scenarios passed')
