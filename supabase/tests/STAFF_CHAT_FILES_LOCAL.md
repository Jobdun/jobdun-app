# Isolated staff attachment HTTP integration

This fixture uses real local Supabase Auth, PostgreSQL, PostgREST, Storage and
Edge Runtime. It never links, pushes migrations or modifies hosted data. The
production-linked repository config and `admin-web/.env.local` are unchanged.

Prerequisites: Docker, Supabase CLI, Python 3 with Pillow. Start from the repo root:

```sh
bash supabase/tests/start_staff_chat_files_local.sh
supabase functions serve admin-chat-files --no-verify-jwt --workdir /tmp/jobdun-staff-files-local
```

The second command stays running in its terminal. JWT verification at the gateway
is disabled because the handler validates the bearer with Auth itself and checks
fresh staff eligibility, MFA policy and thread membership in PostgreSQL.

After refreshing Edge source, copy it again into the temporary function folder.

In another terminal:

```sh
python3 supabase/tests/staff_chat_files_http.py
```

API is `http://127.0.0.1:55321`; PostgreSQL is on port 55322. A separate project ID,
`jobdun-staff-files-local`, keeps its containers apart from the linked project.
The setup reconstructs the fixed pre-company schema fixture plus the reviewed safety,
company staff, chat and attachments migrations on a fresh managed local schema;
it does not replay historical migrations against an incompatible snapshot.

The mode-600 files under `/tmp/jobdun-staff-files-local` are private local fixtures:

- `status.env`: CLI connection settings including service secrets. Use only in
  Edge/test processes; never load this into Next.js.
- `admin.env.local`: public localhost URL and anon key for a separate preview.
- `users.json`: three fictional confirmed `jobdun.com.au` staff accounts.
- `http-evidence.json`: credential-free result summary written only after success.

For a Next preview, use a separate source directory/port/build output and load
only `admin.env.local`. Keep the existing port-3000 process and env untouched.
No service key is needed by Next or the browser.

The HTTP runner authenticates through the real password endpoint and verifies
JPEG, PNG, WebP, PDF and UTF-8 text upload/download, upload/message retry identity,
pending-owner privacy, participant access, unrelated/anonymous denial, byte
roundtrips, disposition/cache/nosniff headers, invalid/empty/oversize files and
an exact 3 MiB upload. It also verifies direct authenticated Storage listing,
MFA-policy enforcement and revoked-staff access with local policy restoration.
It is repeatable: each execution uses fresh client tags and existing synthetic
staff accounts. Rapid repeated executions may hit deliberate server rate limits.

Stop only this project when finished:

```sh
supabase stop --workdir /tmp/jobdun-staff-files-local
```

The setup refuses to overwrite an existing temporary project. To reconstruct
from scratch, stop this named project, remove its disposable temporary directory
and use a fresh local stack. Do not run root-project reset or hosted commands.

Local execution on 23 October 2026 passed **62 real HTTP assertions** using this
runner against port 55321. This establishes the direct Edge/backend transport;
Next proxy, browser interaction and visual evidence are separate checks.

The fixture copies only `admin-chat-files` and `_shared` into its temporary
functions folder. After changing Edge source, refresh that copy before rerunning;
external source symlinks cannot resolve inside the runtime's Docker mount.
