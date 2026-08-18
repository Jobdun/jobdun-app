# Staging backend (Jobdun Staging)

Created 2026-08-14 when production was cleaned for launch. All QA / test fixtures
now live **here**, not in production. Production (`zethpanvkfyijislxesn`) holds only
real data plus the App Review demo account and one demo job.

| | Production | Staging |
|---|---|---|
| Project ref | `zethpanvkfyijislxesn` | `kqpsceobwtavcxhatxww` |
| URL | `https://zethpanvkfyijislxesn.supabase.co` | `https://kqpsceobwtavcxhatxww.supabase.co` |
| Org / region | Jobdun's Org / Sydney | Jobdun's Org / Sydney |
| Plan | Free | Free |

Staging anon key (client-safe, like any anon key):

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtxcHNjZW9id3RhdmN4aGF0eHd3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2ODUzNzcsImV4cCI6MjEwMjI2MTM3N30.X5CUBP219F0PaI6egdl3wobV5P1QqLA1yWIToLt2uuc
```

The staging **DB password** and project ref are in the gitignored `.env.server`
(`SUPABASE_STAGING_*` keys). Service-role key: Supabase dashboard → Staging → API keys.

## Run the app against staging

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kqpsceobwtavcxhatxww.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging anon key above>
```

Screenshot-capture and QA builds should use staging — the `jam@jobdun.com.au`
account the scripts log in with now only exists here.

## Fixture accounts (permanent — do not delete)

| Email | Role | Password |
|---|---|---|
| `jam@jobdun.com.au` | builder | `123Jobdun!` |
| `qa.builder.test@jobdun.com.au` | builder | `123Jobdun!` |
| `qa.trade.test@jobdun.com.au` | trade | `123Jobdun!` |
| `appreview@jobdun.com.au` | trade | same as production (see App Store docs) |

Seed data: the `[QA TEST]` job (owned by qa.builder.test), all 18 trade categories.
Accounts were copied from production with their original UUIDs, so prod-era IDs in
old test notes still resolve.

## What's configured

- Full schema (tables, RLS policies, functions, triggers) cloned from live prod
  schema on 2026-08-14, including `contact_enquiries` (was missing from
  `supabase/schema.sql`), both `auth.users` triggers, the 3 storage buckets with
  prod-identical RLS policies, and the `custom_access_token` JWT hook (verified:
  login returns `user_role` claim).
- **Signup autoconfirm is ON** (unlike prod) so QA account creation never waits on
  email delivery.

- **Edge Functions deployed** (2026-08-14): `jobs-feed`, `push-send`, `verify-abn`,
  `verify-licence` — all ACTIVE, smoke-tested (jobs-feed returns the QA job with
  `source: origin-no-cache`). Secrets set: `ABR_GUID`, `ABR_DEV_MODE`,
  `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT` (same Firebase project as
  prod, so staging can send real pushes to staging-registered devices).
  **Upstash secrets deliberately NOT set** — staging must not share prod's feed
  cache; jobs-feed falls back to direct Postgres reads by design.

## What's NOT configured (set up when first needed)

- **`contact-send` function** — prod-only; its source lives in the marketing-site
  work, not this repo.
- **Google / Apple sign-in** — providers not configured; use the email/password
  fixtures.
- **Custom SMTP / Twilio** — defaults only.
- **Migration history** — staging was cloned from the live schema, not by replaying
  `supabase/migrations/`, so `supabase migration list` is empty here. Apply future
  schema changes to both projects (the 2026-08-14 advisor-hardening migration was
  applied to both by hand).

## Ops (2026-08-14 "proper prod" pass)

- **Advisor hardening** — `supabase/migrations/20260814000001_advisor_hardening.sql`
  applied to BOTH projects: client EXECUTE revoked on 20 trigger/cron/internal
  SECURITY DEFINER functions, `anon` revoked on 12 authenticated-only RPCs,
  `search_path` pinned on 7 functions. Verified live: signup still works,
  `get_inbox` works authenticated and is denied for anon. Remaining advisor
  findings are deliberate (sanitized definer storefront views/functions) or
  plan-gated (leaked-password protection is Pro-only; `pg_net` can't leave
  `public`).
- **Automated daily prod backups** — free plan has none, so
  `scripts/backup-prod.sh` (all tables incl. auth password hashes + all storage
  files) runs daily at 10:00 via launchd (`au.com.jobdun.db-backup`), writing to
  `~/Documents/Jobdun-backups/auto/<date>/`, 14-day retention. Log:
  `~/Documents/Jobdun-backups/auto/backup.log`.
- **Known Pro-plan gaps on prod** (upgrade when revenue justifies ~US$25/mo):
  real daily backups + PITR, leaked-password protection, no 7-day pause risk,
  Supabase branching.

## 2026-08-14 production cleanup record

Removed from prod (full JSON + storage backup at
`~/Documents/Jobdun-backups/2026-08-14-prod-cleanup/`, restorable incl. password
hashes): 8 test accounts (screenshots@, jam@, qa.builder.test@, 2 Apple-relay
signups, ken@romega-solutions.com, kgarcia.a62240916@umak.edu.ph,
garciakenpatrick3@gmail.com) and all their cascaded data; all test
applications/conversations/messages/notifications; 5 stale manual verification
requests; 2 QA contact enquiries; 4 chat-attachment files. Two remaining test jobs
were **soft-deleted** (`deleted_at` set, rows kept). Added one professional demo
job ("Licensed plumber — bathroom reno rough-in", Parramatta) owned by the
Garcia Plumbing & Co builder account so the feed isn't empty for App Review and
first users.

Kept in prod: `ken@jobdun.com.au` (admin), `appreview@jobdun.com.au` (Apple demo),
`kenpatrickgarcia123@gmail.com` (trade, verified), `kenpatrickag21@gmail.com`
(builder, demo-job owner), `sam.s@goldenviewcleaning.com.au` (**confirmed real user**
2026-08-18 — never touch in cleanups).
