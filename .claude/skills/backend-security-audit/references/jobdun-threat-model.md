# Jobdun backend threat model

Read this FIRST in the Discover step. It's the map the OWASP gates are graded against. Regenerate the facts with `scripts/discover.sh` — this file records intent; the scripts record reality.

## Trust hierarchy (who can do what)

| Principal | Trust | How enforced |
|---|---|---|
| `anon` | unauthenticated public | RLS; the **anon key is PUBLIC by design** (bundled in the app) — all protection is RLS, never key secrecy |
| `authenticated` | a logged-in user, scoped to their own data | RLS policies keyed on `(select auth.uid())` |
| `service_role` | full bypass of RLS | **server-only** (Edge Functions, admin SQL); MUST NEVER reach the client |
| `admin` | privileged app-level role | `user_roles` table + `user_role` claim injected into the JWT by `custom_access_token_hook`; **non-self-assignable** (DB-enforced) |

**The cardinal rule:** the mobile client authenticates as `authenticated` with the anon key. Every read/write it makes is subject to RLS. If RLS is wrong, the anon key being public means the door is open. RLS is the whole game.

## Surface inventory (verify with discover.sh — names drift)

**Edge Functions** (`supabase/functions/`):
- `jobs-feed` — read-through Upstash Redis cache over the jobs feed. External fetch = the Upstash REST URL (from env, constant host).
- `push-send` — sends FCM pushes. External fetch = `fcm.googleapis.com` (constant host, `projectId` from config). Check invocation auth + rate limiting.
- `verify-abn` — calls `abr.business.gov.au` (constant host; `abn`/`guid` are `encodeURIComponent`'d query params, NOT the host → not SSRF). Check response validation (API10) + `regulator_circuit_state` breaker.
- `verify-licence` — external licence registry lookup. Same checks as verify-abn.
- `_shared/` — shared helpers incl. `cors.ts` (currently wildcard — see API8).

**Storage buckets** (from migrations — verify with `discover.sh --buckets`):
- `public-media` — `public = true` (avatars / logos / portfolio). Public by intent.
- `chat-attachments` — `public = false`. Message attachments — must stay relationship-scoped.
- `private-docs` — `public = false`. Verification documents — must stay owner/admin-scoped. **Never make public.**

**Core tables** (32 total; all have RLS enabled — verify FORCE separately):
- Identity/profile: `profiles`, `builder_profiles`, `trade_profiles`, `user_roles`.
- Marketplace: `jobs`, `applications`, `quote_requests`, `bookings`, `timesheets`, `saved_jobs`, `hidden_jobs`.
- Messaging: `conversations`, `messages`, `message_reactions`, `blocks`.
- Trust/verification: `verifications`, `verification_documents`, `verification_events`, `verification_funnel_events`, `verification_rate_limits`, `manual_verification_requests`, `builder_unverified_acknowledgements`, `regulator_circuit_state`.
- Moderation/audit: `admin_actions`, `reports`, `user_role_events`.
- Comms/legal: `notifications`, `notification_preferences`, `device_tokens`, `legal_acceptances`, `trade_categories`.

## Trust boundaries that matter most

1. **Trust/verification columns are system-managed.** A user must NOT be able to set their own `verified` / trust / rating / role fields. Legitimate writes come only from an admin RPC or a `SECURITY DEFINER` verification path. (This is the historically-open **API3 P0** — confirm every run.)
2. **PII gating.** Phone, exact coordinates, and rates are PII. Counterparty-facing reads go through minimized `SECURITY DEFINER` projections (`get_builder_public_verification`, `get_trade_public_credentials`) and public views (coords rounded, rates gated) — never the raw row.
3. **Verification documents** (`private-docs`, `verification_documents`) are the most sensitive data (licences, insurance). Owner + admin only.
4. **Admin actions are logged** (`admin_actions`, `user_role_events`, `verification_events`) and the audit trail must not be user-writable.

## Known-open / watch-list baseline (confirm, don't rediscover)

- **API3** — self-grantable trust flags (historically "narrowed but OPEN"). Verify the current policy/trigger state on `trade_profiles` / `builder_profiles` / `verifications`.
- **A02** — service-role + Twilio creds were bundled in old builds; **rotation status is not file-verifiable** → flag for dashboard confirmation.
- **API8** — `_shared/cors.ts` wildcard `Access-Control-Allow-Origin: *`.
- **API1 (hardening)** — RLS enabled on all tables but **FORCE not set** on any.
- **API9** — Dart-model ↔ schema phantom columns (see `docs/BACKEND_FULL_AUDIT_2026-06-11.md`).
- **Scalability** — unindexed foreign keys (pair `discover.sh --fks` REFERENCES vs INDEXES).

## Verified-solid (don't re-litigate unless changed)

- RLS enabled on all 32 tables.
- All 39 `SECURITY DEFINER` functions pin `search_path`.
- Verification has rate limiting (`verification_rate_limits`) + a regulator circuit breaker (`regulator_circuit_state`).
- `.env` split done: bundled `.env` = anon key + public config only; secrets in gitignored `.env.server`.
- Private buckets (`chat-attachments`, `private-docs`) are `public = false`.
