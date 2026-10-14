# Company admin source release — 14 October 2026

The company admin website is maintained in the separate
[jobdun-admin-web repository](https://github.com/KpG782/jobdun-admin-web).
Its company expansion adds scoped staff roles, MFA, marketplace records,
report/support operations, platform settings, verification assignment/expiry,
analytics and audited communications. Finance remains unavailable by decision.

This backend release provides the matching company migration, rollback, isolated
PostgreSQL regression suite and owner-authorized admin-users Edge handler.
The company migration and matching admin-users Edge function were deployed to
production on 14 October 2026. The admin website was deployed separately.

## Verification

The integrated development checkout passed `bash scripts/validate.sh` normally;
a separate Flutter run recorded 1,047 passes and six existing opt-in integration
skips. Admin checks recorded 770 unit/component passes, 41 public browser passes,
74 isolated operational browser passes, TypeScript, lint and production build.
Operational browser writes use synthetic fixtures and mocked actions. SQL checks
independently exercise real database mutations in network-disabled containers.

The exact isolated `origin/main` backend checkout passed
`bash supabase/tests/run_company_admin.sh` (exit 0) and
`npx --yes deno@2 test --allow-read supabase/functions/admin-users/`
(23 tests, 50 steps, 0 failures). The SQL runner checks migration application,
scope/reason/version/audit guards, concurrent final-owner protection, exact
rollback restoration and reapplication.
The final unrestricted exact-main `bash scripts/validate.sh` completed with exit
0: design, architecture, Dart format, Flutter analyze and feature tests passed.
An earlier sandbox attempt could not write the Flutter SDK cache; the final run
resolved that environment limitation. No mobile source is changed in this commit.

## Deployment boundary

The admin repository's `docs/COMPANY_ADMIN.md` records the reviewed deployment
sequence and post-deploy checks. Preserve existing remote migration history;
do not repair or discard it merely to force a push. Native clients do not yet
consume the public settings RPC. General invitations require configured SMTP.
Notification creation is not evidence of delivery. MFA recovery requires an
independent authorized operator; no public reset bypass is included.

User authorization covered publication to both repositories' `main` branches.
Unrelated mobile work is excluded from this backend commit.

## Schema snapshot and security audit

After production deployment, `supabase/schema.sql` was synchronized from the live
public schema. The migration regression runner uses a fixed pre-company schema
fixture, with the historical public anon token replaced by an inert test value.
This preserves apply/rollback/reapply coverage after the current-state snapshot
already contains the company migration. Remote migration history is unchanged.

A redacted Gitleaks audit of both repositories’ new commits and reachable main
history found only SHA-256 manifest hashes, dependency checksums and historical
public Supabase anon keys. No private credential was identified; no key rotation
or history rewrite was performed. Private backup/auth artifacts remain outside Git.
