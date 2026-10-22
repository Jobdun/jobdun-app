#!/usr/bin/env bash
# Creates ONLY a separate, disposable local Supabase project. Never links or pushes.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
local_root="${STAFF_FILES_LOCAL_ROOT:-/tmp/jobdun-staff-files-local}"
case "$local_root" in /tmp/jobdun-staff-files-*) ;; *) echo 'Use an isolated /tmp/jobdun-staff-files-* directory' >&2; exit 1;; esac
umask 077
if [[ -e "$local_root/supabase/config.toml" ]]; then
 echo "Existing isolated project: $local_root (refusing to overwrite)." >&2
 exit 1
fi
mkdir -p "$local_root/supabase"
python3 - "$repo_root" "$local_root" <<'PY'
import sys
from pathlib import Path
repo, root = map(Path, sys.argv[1:])
s = (repo/'supabase/config.toml').read_text().replace('project_id = "Jobdun"','project_id = "jobdun-staff-files-local"')
for a,b in [('54321','55321'),('54322','55322'),('54320','55320'),('54323','55323'),('54324','55324'),('54327','55327'),('8083','8183')]: s=s.replace(a,b)
s=s.replace('enabled = true\n# Specifies an ordered list of seed','enabled = false\n# Specifies an ordered list of seed')
s=s.replace('[auth.email.template.confirmation]\nsubject = "Confirm your Jobdun account — your first job\'s one tap away"\ncontent_path = "./supabase/email-templates/confirm-signup.html"','')
(root/'supabase/config.toml').write_text(s)
PY
supabase start --workdir "$local_root" --exclude studio,vector,logflare,supavisor > "$local_root/start.log" 2>&1
supabase status --workdir "$local_root" -o env > "$local_root/status.env"
python3 - "$repo_root" "$local_root" <<'PY'
import json, secrets, shutil, subprocess, sys, urllib.request
from pathlib import Path
repo,root=map(Path,sys.argv[1:])
container='supabase_db_jobdun-staff-files-local'
def sql(source):
 subprocess.run(['docker','exec','-e','PGPASSWORD=postgres','-i',container,'psql','-X','-U','supabase_admin','-d','postgres','-q','-v','ON_ERROR_STOP=1'],input=source,text=True,check=True,capture_output=True)
files=['supabase/tests/company_admin_pre_migration_schema.sql','supabase/migrations/20260527000001_verification_documents_admin_review.sql','supabase/rollbacks/20261011000001_admin_safety_down.sql','supabase/migrations/20261007000001_admin_user_management.sql','supabase/migrations/20261011000001_admin_safety.sql','supabase/migrations/20261014000001_company_admin.sql','supabase/migrations/20261021000001_staff_chat.sql','supabase/migrations/20261023000001_staff_chat_attachments.sql']
for file in files:
 sql((repo/file).read_text())
 if '20260527000001' in file: sql('DROP POLICY verification_documents_admin_update ON public.verification_documents;')
d={k:v.strip('"') for k,v in [x.split('=',1) for x in (root/'status.env').read_text().splitlines() if '=' in x]}
(root/'admin.env.local').write_text('NEXT_PUBLIC_SUPABASE_URL='+d['API_URL']+'\nNEXT_PUBLIC_SUPABASE_ANON_KEY='+d['ANON_KEY']+'\n')
users=[]
for n in range(1,4):
 email=f'local.attachment.staff{n}@jobdun.com.au';password=secrets.token_urlsafe(24)
 req=urllib.request.Request(d['API_URL']+'/auth/v1/admin/users',data=json.dumps({'email':email,'password':password,'email_confirm':True}).encode(),headers={'apikey':d['SERVICE_ROLE_KEY'],'Authorization':'Bearer '+d['SERVICE_ROLE_KEY'],'Content-Type':'application/json'})
 u=json.load(urllib.request.urlopen(req));users.append({'id':u['id'],'email':email,'password':password})
 sql("SELECT set_config('request.jwt.claim.role','service_role',false);"+f"INSERT INTO public.profiles(id,display_name) VALUES ('{u['id']}','Local Attachment Staff {n}') ON CONFLICT(id) DO UPDATE SET display_name=excluded.display_name; INSERT INTO public.user_roles(user_id,role) VALUES ('{u['id']}','admin') ON CONFLICT(user_id) DO UPDATE SET role='admin'; INSERT INTO public.admin_staff(user_id,staff_role) VALUES ('{u['id']}','owner');")
(root/'users.json').write_text(json.dumps(users))
(root/'supabase/functions').mkdir()
for name in ['admin-chat-files', '_shared']:
 if (repo/'supabase/functions'/name).exists():
  shutil.copytree(repo/'supabase/functions'/name,root/'supabase/functions'/name)
PY
printf 'Local project ready at %s; run functions serve in a separate terminal.\n' "$local_root"
printf 'supabase functions serve admin-chat-files --no-verify-jwt --workdir %s\n' "$local_root"
