# Admin user management

New Edge endpoint and migration only; no Next.js service credential is needed.
Auth roles are `builder`, `trade`, `admin`. Apprentice remains Trade profile data.

## HTTP contract

Requests carry the signed-in session's `Authorization: Bearer <access_token>`.
The handler calls Auth `getUser(token)`, then the service-only readiness RPC,
which checks the **current** role is admin and profile status is active.

- `GET` → `200 {ready:true, invitationConfigured:boolean}`. Readiness confirms
  the database authorization RPC is installed; configuration confirms a valid
  server redirect, not SMTP delivery or callback availability.
- `POST {action:"invite", email, displayName, role}` →
  `200 {userId, invited:true, roleApplied:true}`.
- If Auth sent the invitation but role assignment fails:
  `200 {userId, invited:true, roleApplied:false, error:"role_assignment_failed"}`.
  Keep this outcome visible, refresh the directory and repair the role with
  `set-role`. **Do not automatically resend.** There is no cross-service
  transaction between Auth email delivery and PostgreSQL role assignment.
- `POST {action:"set-role", userId, role, expectedRole, reason}` →
  `200 {userId, role}`. `expectedRole:null` means no role was observed; it is
  **not** a wildcard. A current non-null role then returns `409 role_conflict`.

Input is strict: name 2–100 characters after trimming; reason 5–500; valid UUID;
email at most 254; no control characters; no client actor or redirect fields.
Email is trimmed/lowercased. Request body limit is 16 KiB. Responses are no-store.

Errors are `{error:code}`, with no raw SQL/Auth error or PII:

| Status | Codes |
| --- | --- |
| 400 | `invalid_request` |
| 401 | `unauthorized` |
| 403 | `not_authorized` |
| 404 | `user_not_found` |
| 409 | `role_conflict`, `self_role_change`, `last_admin`, `user_exists` |
| 413 | `request_too_large` |
| 429 | `rate_limited` (Retry-After header) |
| 503 | `invitation_not_configured`, `unavailable` |

Rate limits reuse `verification_rate_limits`: invites 5/actor/hour and 20/IP/hour;
role edits 30/actor/hour and 90/IP/hour, independent buckets. A transaction lock
and UPSERT prevent lost increments. Database failures fail closed. Minute
bucketing is conservative by up to one minute (Retry-After 3660 seconds).
GET does not consume write quota. Existing verification endpoints are unchanged.

## Database contract and security

Migration: `supabase/migrations/20261007000001_admin_user_management.sql`.
Only service_role can execute:

- `admin_user_management_ready(p_actor_id uuid) -> boolean`
- `admin_user_invitation_preflight(p_actor_id uuid,p_email text) -> void`
- `admin_user_management_rate_limit(p_actor_id uuid,p_ip text,p_action text) -> jsonb`
- `admin_set_user_role(p_actor_id uuid,p_user_id uuid,p_role text,p_expected_role text,p_reason text) -> jsonb`

Every RPC checks the fresh active admin actor. Role changes serialize through
an advisory transaction lock and lock actor rows; self changes are forbidden,
and last-admin demotion has an additional guard. Compare-and-swap detects stale
UI state. Missing profile/role-profile stubs are created with defaults; existing
profiles and historical role data are preserved. The role trigger and
`admin_actions` record the verified real actor/reason in the same transaction.
Audit failure rolls back the role and stubs. Transaction audit settings are
restored immediately after mutation; normal signup audit behavior is preserved.

`user_roles_admin_read` now uses a fresh-role/status definer helper, preventing
stale admin JWT claims from retaining directory access. Own-role reads and
builder/trade self-signup are preserved. Client metadata still cannot create
admins. Existing-email invitations are rejected before Auth's mail API; the
subsequent role CAS protects against overwriting a concurrently assigned role.

## Coordinator deployment steps (not executed by this change)

Use the isolated main worktree containing only the new backend files. Do not
merge unrelated mobile branch commits or apply unrelated pending migrations.

1. Confirm the selected linked project and inspect pending migrations:
   `supabase migration list --linked`, then `supabase db push --linked --dry-run`.
   Only the intended admin-management migration should be pending. If remote
   history contains newer mobile migrations absent from main, do not repair or
   discard history to force a push; use the reviewed migration through the
   coordinator's established migration process while preserving that history.
2. Apply `20261007000001_admin_user_management.sql` through that process. When
   CLI history is consistent, the command is `supabase db push --linked`.
   It changes functions/policy and extends a rate-limit check constraint; it
   does not create accounts, send mail, or rewrite existing user roles.
3. Deploy the frontend invitation acceptance callback first. Choose its exact
   HTTPS URL: `https://admin.jobdun.com.au/accept-invitation`. Add exactly that
   URL to Supabase Auth's redirect allowlist after the route is deployed.
   Verify the Invite User email template and SMTP configuration. Built-in
   invitations send real email immediately; no separate notification API is used.
   The callback must handle Supabase's invite flow for all three roles, rather
   than reject Builder/Trade behind an admin gate. PKCE invitation flow is not
   supported by `inviteUserByEmail`; coordinate the template/callback accordingly.
4. Configure Edge secret `ADMIN_INVITE_REDIRECT_URL` to that exact URL using
   `supabase secrets set --project-ref <project-ref> --env-file <protected-env-file>`.
   The protected file contains only `ADMIN_INVITE_REDIRECT_URL=<approved-url>`;
   never put service credentials in Next.js. Hosted Edge already provides
   `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
5. Deploy only this function:
   `supabase functions deploy admin-users --project-ref <project-ref> --use-api --no-verify-jwt`.
   Manual Auth `getUser` verification is mandatory in the handler; disabling
   the legacy gateway JWT check allows current signing keys and does not make
   GET/POST public. OPTIONS is the only unauthenticated success. `--use-api`
   avoids Docker. Do not use `--prune`.
6. Smoke-test GET with an active-admin session (ready/configured true), no
   session (401), and a non-admin session (403). A real invitation, acceptance,
   and role mutation are separate production writes; perform only within the
   coordinator's approved verification scope. Do not auto-retry invitation POST
   after a timeout: check the directory first because delivery may have happened.

Approved HTTPS origins: `https://admin.jobdun.com.au`, `https://jobdun.com.au`,
`https://www.jobdun.com.au`. No credentials, fragment, or unapproved port/origin.
HTTP loopback callbacks are accepted only when SUPABASE_URL is also a local
HTTP loopback or the local Supabase `http://kong` host. A hosted project will
not accept localhost invitations. Missing/invalid redirect disables invites
while role editing remains available. To disable invitations operationally,
remove that one Edge secret; existing-role editing can continue.

Production configuration inspected on 2026-10-07 has **no custom SMTP sender**.
Supabase's default delivery only permits project-team addresses. Keep the
invitation secret unset (invitation UI disabled) until a production SMTP sender
is connected. Do not report general email invitation delivery as verified.

## Local evidence and limits

```sh
npx --yes deno@2 test --allow-read supabase/functions/admin-users/
npx --yes deno@2 check supabase/functions/admin-users/index.ts
npx --yes deno@2 lint supabase/functions/admin-users/
# Optional origin/main compatibility fixture (no checkout or production DB):
git show origin/main:supabase/schema.sql > /tmp/jobdun-admin-users-main-schema.sql
npx --yes deno@2 test --allow-read supabase/functions/admin-users/database_test.ts -- /tmp/jobdun-admin-users-main-schema.sql
```

Handler tests were run red before implementation. SQL regressions first failed
against the existing schema, including stale-claim RLS behavior. The SDK adapter
uses the real pinned Supabase client with mocked HTTP transport and checks that
the session bearer used for Auth does not replace service authorization for RPCs.

SQL tests run the actual migration in isolated PGlite PostgreSQL 18.3, with
relevant table/function/trigger/policy/constraint definitions extracted from the
repo schema. They also pass against origin/main's older schema. A test-only
`ADD COLUMN IF NOT EXISTS is_apprentice` simulates preservation of future profile
columns; the production migration neither requires nor creates that column.
The shared rate table and its primary key/check constraint exist on both branches.

Docker was unavailable. Full Supabase/PostgreSQL 17 migration-chain execution,
multiple database connection contention, hosted Edge bundling, real SMTP/email,
and browser invitation acceptance have not been tested here. No production
account/email writes, backend deployment, Next build, or frontend edits were made.
