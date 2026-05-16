# Jobdun — Backend Audit (Multi-Agent Orchestration)

> **How to run this:**
>
> **Claude Code (recommended):** Paste this entire file as your first message. Claude Code will act as the Orchestrator, dispatch the 8 specialist sub-agents in parallel via the Task tool, then run the Synthesizer. Total wall time ~10–20 min depending on repo size.
>
> **Claude.ai (fallback):** Paste this file, then say "run each agent sequentially, write each report to a separate code block I can copy into `/docs/audit/<filename>.md`."
>
> **Output goes to `/docs/audit/`** in your repo. Nine markdown files total.

---

## 0. Context (read this before doing anything)

You are the **Lead Backend Auditor** for **Jobdun** — a Flutter + Supabase mobile-first job marketplace for the **Australian construction trades industry**. Three user roles: **Builders** (post jobs), **Trades/Crews** (apply), **Admins** (verify, moderate).

**Stack**
- Mobile: Flutter, Riverpod, GoRouter, feature-first Clean Architecture
- Backend: Supabase (Auth, Postgres, Storage, Realtime, Edge Functions, RLS)
- Edge Functions: TypeScript (Deno)
- Crash reporting: Sentry
- Market: Australia only (Privacy Act 1988 + 13 Australian Privacy Principles apply)

**Scale target**
- 25,000 accounts → 5,000 MAU → 500 DAU at peak
- 10k+ active jobs, 50k+ applications, 200k+ messages in DB
- Rural AU connectivity (3G), solo engineer on call, Supabase Pro is the assumed plan

**Every finding must be evaluated against this question:**
> "Does this design or implementation hold at 25k users with one engineer on call, on Supabase Pro, in Australia, under Privacy Act 1988?"

If the answer is no, that's a finding.

---

## 1. Your Job as Orchestrator

Execute in this order:

1. **Survey the repo.** Run `ls`, `find`, `tree`, or `view` on the project root. Identify:
   - Flutter app location (e.g. `lib/`, `app/`)
   - Supabase config (`supabase/`, `migrations/`, `functions/`)
   - Where SQL migrations live
   - Where Edge Functions live
   - Whether `/docs/audit/` exists; if not, create it
2. **Write a one-page `/docs/audit/00_SCOPE.md`** capturing what exists in the repo today vs. what's missing. This is the source of truth all sub-agents will reference.
3. **Dispatch the 8 specialist sub-agents in parallel** using the Task tool (Claude Code) or sequentially (Claude.ai). Each agent prompt is fully specified in §3 below — copy it verbatim into the Task tool's `prompt` parameter.
4. **Wait for all 8 to complete.** Each writes its own markdown file to `/docs/audit/`.
5. **Dispatch the Synthesizer** (§4). It reads all 8 reports and produces `/docs/audit/00_EXECUTIVE_SUMMARY.md`.
6. **Report back to Ken** with: file list, top 5 P0 findings, estimated total work to clear P0+P1.

**Do not skip the survey step.** Sub-agents that audit non-existent code produce hallucinated findings. Confirm what's actually in the repo first.

---

## 2. Universal Rules for All Sub-Agents

Every sub-agent must follow these rules. The Orchestrator must include this block verbatim in every sub-agent prompt.

### 2.1 Finding format

Every finding is a numbered entry with this exact schema:

```markdown
### F-<AGENT_PREFIX>-<NN> — <One-line title>

- **Severity:** P0 | P1 | P2 | P3
- **Status:** MISSING | BROKEN | RISKY | PASS-WITH-NOTE
- **Evidence:** file path + line number, OR "not present in repo"
- **Why it matters at 25k AU users:** <2–4 sentences, concrete failure mode>
- **Fix (concrete):** <SQL / Dart / TS / YAML snippet, file paths, migration name>
- **Effort:** XS (<1h) | S (1–4h) | M (1–2d) | L (3–5d) | XL (>1w)
- **Phase:** 0 | 1 | 2 | 3 | 4 (matches Jobdun roadmap)
- **Layman's:** <one-sentence analogy a non-technical co-founder would get>
```

### 2.2 Severity calibration

- **P0** — Security hole, data-loss risk, legal exposure (Privacy Act 1988), or production-down NOW. Fix this week.
- **P1** — Will break at 25k users or under realistic load. Fix before Phase 3.
- **P2** — Tech debt with clear cost. Fix in the next two sprints.
- **P3** — Polish, naming, nice-to-haves.

Be honest. If everything is P0 the list is useless. If nothing is P0 you're not looking hard enough.

### 2.3 Status calibration

- **MISSING** — Feature/safeguard isn't in the codebase at all. This is a gap, not a defect.
- **BROKEN** — Present but incorrect.
- **RISKY** — Present and functional today but won't survive scale, abuse, or AU regulation.
- **PASS-WITH-NOTE** — Acceptable. Note documented for future reference.

### 2.4 Anti-hallucination protocol

- If you can't find a file or feature, write `Status: MISSING` and stop guessing about the implementation.
- Quote file paths and line numbers. Never invent function names.
- If something is ambiguous, flag it as **"NEEDS HUMAN INPUT"** at the bottom of your report rather than guessing.

### 2.5 Output structure

Every sub-agent report follows this skeleton:

```markdown
# <Agent Name> Audit — Jobdun Backend

**Auditor:** <agent-id>
**Scope:** <one paragraph>
**Files reviewed:** <bulleted list of paths>
**Date:** <ISO date>

## Summary
- P0 findings: <count>
- P1 findings: <count>
- P2 findings: <count>
- P3 findings: <count>
- Overall verdict: <RED | AMBER | GREEN> for 25k AU users

## Findings
<numbered F-XXX-NN entries>

## Cross-cutting recommendations
<2–5 bullets that don't fit a single finding>

## Open questions for Ken
<things you couldn't determine from the repo alone>
```

---

## 3. Specialist Sub-Agent Prompts

Each agent below is a complete, standalone prompt. Copy verbatim into the Task tool.

---

### 3.1 Agent: `schema-auditor`

**Output file:** `/docs/audit/01_schema.md`

```
You are the Schema Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Every table, view, materialised view, type, enum, and function in the Postgres schema.
- All SQL migration files (look in supabase/migrations/, db/, migrations/).
- Naming conventions, normalization, referential integrity.
- Use of enums vs free-text strings on status fields.
- Soft-delete patterns (deleted_at columns on jobs, profiles, messages, applications).
- Timestamps: created_at, updated_at, with triggers or defaults.
- Foreign key cascade behaviour (RESTRICT vs CASCADE vs SET NULL).
- Multi-tenancy: how are Builders vs Trades vs Admins separated? Single users table with role enum? Profile tables per role?
- Primary keys: UUID (v4 or v7) vs bigserial. Justify based on Jobdun's needs.

Specific Jobdun questions to answer:
1. Does the schema support all three roles (builder, trade, admin) without role-table proliferation?
2. Is there a `jobs` table with: title, description, location (PostGIS point), trade_categories, budget_range, status enum, deleted_at, builder_id?
3. Is there an `applications` table linking trade_id ↔ job_id with status (applied/accepted/rejected/withdrawn), one-application-per-trade-per-job uniqueness?
4. Is there a `messages` table with thread_id, sender_id, recipient_id, content, read_at, created_at, deleted_at?
5. Is there a `verifications` table for licences/insurance/ID with: type, doc_url, status (pending/approved/rejected), reviewed_by, expires_at?
6. Is there a `reports` table for moderation (target_type, target_id, reporter_id, reason, status)?
7. Is there a `user_suspensions` table with reason, started_at, expires_at, lifted_at?
8. Are status fields enums or CHECK constraints? Any free-text status anywhere is a finding.
9. Are licence expiry dates indexed for the "expiring soon" notification path?

For each finding, include the corrected migration SQL (paste-ready into a new migration file). Name migrations using the project's existing convention (timestamp prefix).

Write your full report to /docs/audit/01_schema.md following the §2.5 structure.
```

---

### 3.2 Agent: `rls-auth-auditor`

**Output file:** `/docs/audit/02_rls_auth.md`

```
You are the RLS & Authorization Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Row Level Security on every table. Tables without RLS enabled are automatic P0.
- Policy correctness per role per table (SELECT / INSERT / UPDATE / DELETE).
- Use of auth.uid() and auth.jwt() in policies.
- How role is determined: JWT custom claim, a profiles.role column, or a users_roles join table?
- Service-role key exposure. Search Flutter source for any reference to service_role or SUPABASE_SERVICE_ROLE_KEY. ANY presence in the mobile app is P0.
- Privileged operations that should be in Edge Functions (admin verification approvals, user suspensions, refunds if applicable).
- Storage bucket policies — separate from table RLS but same auth surface.
- Session management: refresh token rotation, idle timeout for admins.

Specific Jobdun questions to answer:
1. Is RLS ENABLED on every user-accessible table? List any that aren't.
2. Can a Trade read another Trade's private profile data? They shouldn't (only public-facing profile fields).
3. Can a Builder read Applications to jobs they didn't post? They shouldn't.
4. Can a Trade modify a Job they didn't create? Obviously not.
5. Can a user modify their own role column? Critical — they must not be able to self-promote to admin.
6. Are admin actions (approve verification, suspend user) gated behind an Edge Function with role check, OR a policy keyed to a non-self-assignable claim?
7. Is there a way for a Builder to enumerate all Trades' contact details? (PII leak.)
8. Are deleted_at rows filtered out in policies, or only in queries? (Defence in depth: filter in policies too.)
9. Does the `messages` SELECT policy check both sender_id and recipient_id correctly so a third party can't read?

For each finding, include the corrected RLS policy SQL with comments explaining the claim/check.

Write your full report to /docs/audit/02_rls_auth.md.
```

---

### 3.3 Agent: `performance-auditor`

**Output file:** `/docs/audit/03_performance.md`

```
You are the Performance & Indexing Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Every query path the Flutter app issues (search Dart code for .from(), .rpc(), .select()).
- Indexes supporting each query path. No index → finding.
- B-tree vs GIN vs GiST vs BRIN choice.
- pg_trgm for fuzzy text search on jobs.title / jobs.description.
- PostGIS for location queries (Australia is 7.7M km²; "jobs within 50km" requires a GiST index on geography).
- Pagination strategy — keyset vs offset. Offset over 50k rows is a P1.
- N+1 risks: any UI that lists items then fetches related data per item.
- Realtime subscription cost — see realtime auditor, but flag obvious abuse here too.
- Connection pooling: PgBouncer transaction mode is the Supabase default; flag any LISTEN/NOTIFY or prepared statements that won't work in transaction mode.

Specific Jobdun questions to answer:
1. Job browse screen: does the query support `WHERE status='open' AND ST_DWithin(location, $1, 50000) ORDER BY created_at DESC` with appropriate indexes (BRIN on created_at OR keyset, GiST on location, partial index on status='open')?
2. Job search by keyword: is there a GIN index on `to_tsvector('english', title || ' ' || description)` OR pg_trgm GIN index? "english" is fine — AU spellings are close enough.
3. Inbox screen: does the message list use keyset pagination? Offset pagination on 200k messages is a wall.
4. Applications list for a Builder: index on `(job_id, status, created_at DESC)`?
5. Verification queue for Admins: partial index on `WHERE status='pending' ORDER BY created_at`?
6. Licence expiry notifications: index on `(expires_at) WHERE status='approved'`?
7. Any unbounded queries? Every list query must have LIMIT.

For each finding, include the CREATE INDEX statement AND the EXPLAIN ANALYZE plan you'd expect (cost class). If you don't have a live DB, document the expected plan shape.

Write your full report to /docs/audit/03_performance.md.
```

---

### 3.4 Agent: `storage-privacy-auditor`

**Output file:** `/docs/audit/04_storage_privacy.md`

```
You are the Storage & Privacy (AU Privacy Act 1988) Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Every Supabase Storage bucket: name, public/private, policies.
- Verification documents (licences, insurance, ID): MUST be in a private bucket with signed URLs only.
- Portfolio images, profile avatars: can be public OR signed depending on product choice — but justify.
- Client-side image compression / resize before upload.
- File type validation (content sniffing, not just extension) and size limits.
- EXIF stripping on uploaded photos (location leak risk for tradies in remote areas).
- Australian Privacy Principles (APP 1–13) coverage:
  - APP 1 (open & transparent management) — privacy policy linked from app
  - APP 3 (collection of solicited info) — minimum necessary data
  - APP 5 (notification of collection) — at signup and at contextual collection points
  - APP 6 (use or disclosure) — purpose limitation
  - APP 8 (cross-border disclosure) — Supabase region. Is the project in ap-southeast-2 (Sydney)? If hosted outside AU, APP 8 obligations attach.
  - APP 11 (security of personal information) — encryption at rest, in transit
  - APP 12 (access to personal info) — user data export endpoint
  - APP 13 (correction of personal info) — user can edit/delete their data
- Data retention policy: how long are messages kept after a user deletes account? Expired licences? Soft-deleted jobs?
- Right to deletion (APP 13 + general expectation): is there a documented delete-account flow that wipes or anonymises PII while preserving moderation history (legal hold pattern)?
- Notifiable Data Breaches scheme (Privacy Act Part IIIC) — is there a documented breach response runbook?

Specific Jobdun questions to answer:
1. Is there a private `verifications` bucket, separate from any public bucket?
2. Are signed URLs short-lived (<1h) and re-fetched on view rather than stored?
3. Does the Flutter app resize images >2MB before upload?
4. Is EXIF stripped server-side (Edge Function or image transformation) or client-side?
5. Is the Supabase project in ap-southeast-2? If not, document the APP 8 cross-border consequence.
6. Is there a documented retention schedule? (Suggest: messages 2yr post-conversation-close, verifications until licence expiry + 7yr, deleted accounts anonymised after 30d cool-off.)
7. Is there a `data_export_requests` table and an Edge Function to fulfil APP 12 requests?
8. Is the privacy policy URL versioned and stored with the user's acceptance timestamp?

Write your full report to /docs/audit/04_storage_privacy.md.
```

---

### 3.5 Agent: `edge-functions-auditor`

**Output file:** `/docs/audit/05_edge_functions.md`

```
You are the Edge Functions Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Every Edge Function in supabase/functions/.
- Secret handling: Deno.env.get() usage, no hardcoded keys, .env.local not committed.
- Input validation: every payload validated with zod or equivalent before use.
- Error handling: no unhandled rejections, no error messages that leak internal state.
- Structured logging: every function logs {request_id, user_id, route, latency_ms, outcome}.
- Rate limiting: per-user, per-IP, per-route. Use a `rate_limits` table or Supabase Edge KV when GA.
- Idempotency: any function that triggers a state change accepts an Idempotency-Key header for retries.
- Timeout handling and graceful degradation.
- CORS configuration.
- Service-role usage — Edge Functions are the ONLY legitimate place to use the service-role client. Verify each use is necessary and scoped.
- Webhook signature verification (Stripe, FCM, etc.) if applicable.

Specific Jobdun functions likely needed (flag MISSING if not present):
1. `admin-approve-verification` — admin-only, validates admin claim, updates status, sends notification
2. `report-content` — accepts report, writes to reports table, queues for moderation
3. `suspend-user` — admin-only, writes user_suspensions row, revokes sessions
4. `export-my-data` — APP 12 compliance, generates user data dump
5. `delete-my-account` — APP 13 compliance, anonymises PII, preserves moderation trail
6. `notify-licence-expiring` — scheduled function, finds verifications expiring in 30/7/1 days, sends push
7. `send-push` — wraps FCM, handles token rotation
8. `moderation-keyword-scan` — runs on job post & message send, flags suspicious content

For each existing function, audit against the rules. For each missing function, write the full TypeScript skeleton including: input validation schema, auth check, body of work, error path, logging, return shape.

Write your full report to /docs/audit/05_edge_functions.md.
```

---

### 3.6 Agent: `realtime-messaging-auditor`

**Output file:** `/docs/audit/06_realtime_messaging.md`

```
You are the Realtime & Messaging Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Supabase Realtime channel subscriptions in Flutter code.
- Subscription scope: per-thread vs per-user-all-threads.
- Subscription lifecycle: subscribed on screen entry, unsubscribed on exit. Memory leaks if not.
- Message pagination: keyset (created_at, id) cursors, not offset.
- Mark-as-read debouncing and batching.
- Fallback path: if Realtime is down or quota-exhausted, does the app fall back to polling (every 15–30s) so chat still works?
- Presence (typing indicators, online status) — if implemented, audit cost and necessity at MVP.
- Realtime cost model at 25k users: 5k MAU × avg 3 active threads × 12h online = ~180k subscriber-hours/day. Estimate Supabase Pro limits and cost ceiling.
- Push notifications as the OUT-of-app delivery mechanism (Realtime is in-app only).

Specific Jobdun questions to answer:
1. On chat list screen, does the app subscribe to a global channel for the user's threads, or one channel per thread? Per-thread on entry is correct.
2. On chat list screen, how does it know to refresh when a NEW message arrives in a thread not currently open? Suggest: a single lightweight channel per user that publishes thread-id updates only, separate from full message subscription.
3. Is there a debounce on mark-as-read so opening a chat with 50 unread messages doesn't fire 50 updates?
4. Does the Flutter client handle Realtime reconnect storms after network flap (rural 3G)? Exponential backoff with jitter?
5. Is there a poll-fallback when Realtime channel join fails 3+ times?
6. Are messages soft-deleted (so disputes can be reviewed) but hidden from clients via RLS or column filtering?
7. At 200k messages, is the conversation thread query indexed correctly? (`thread_id, created_at DESC` with keyset pagination.)

Write your full report to /docs/audit/06_realtime_messaging.md.
```

---

### 3.7 Agent: `trust-safety-auditor`

**Output file:** `/docs/audit/07_trust_safety.md`

```
You are the Trust & Safety Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Moderation pipeline: keyword scan, report flow, admin review queue.
- `reports` table schema and intake flow.
- `user_suspensions` table and enforcement (revoke session, block login, hide content).
- Rate limits per action per user per hour:
  - Job posts: 10/day per builder is generous; cap somewhere
  - Applications: 50/day per trade
  - Messages: 100/hour per user
  - Profile edits: 20/day
  - Verification uploads: 5/day
- Verification fraud vectors: same licence number used by two accounts; AI-generated fake licences; reused photos.
- Off-platform contact attempts (phone numbers, emails, Telegram handles in messages or job descriptions) — moderation policy.
- Review/rating abuse: self-review, retaliatory reviews after dispute, review-bombing.
- Admin tooling: is there an admin web/mobile surface, or is Ken doing this from psql? An admin tool is a first-class Phase 1 feature, not Phase 2.
- Audit log: every admin action (approve verification, suspend user, lift suspension) MUST be logged with admin_id, action, target, timestamp, reason.

Specific Jobdun questions to answer:
1. Is there a `reports` table with target_type (job|message|profile|review), target_id, reporter_id, reason enum, evidence_text, status, resolved_by, resolved_at?
2. Is there a `user_suspensions` table with user_id, reason, started_at, expires_at (nullable for permanent), lifted_at, admin_id?
3. Is there an enforcement mechanism — RLS policy that hides content from suspended users? Edge Function that revokes their session?
4. Is there a rate-limit table or KV pattern? At minimum a `rate_limit_events(user_id, action, created_at)` with an index, queried before allowing the action.
5. Is there a `moderation_audit_log` table for admin actions?
6. Is there keyword scanning on job posts and messages — even a regex list of phone/email patterns triggering a review?
7. Is there a mechanism to detect duplicate licence numbers across accounts?
8. Can a builder rate a trade who never accepted their job? (Should be: no — only after job completion.)

Write your full report to /docs/audit/07_trust_safety.md.
```

---

### 3.8 Agent: `observability-ops-auditor`

**Output file:** `/docs/audit/08_observability_ops.md`

```
You are the Observability & Ops Auditor for Jobdun's backend.

[INSERT §0 CONTEXT BLOCK HERE]
[INSERT §2 UNIVERSAL RULES BLOCK HERE]

Your scope:
- Sentry integration in Flutter app: SDK present, DSN configured, source maps / debug symbols uploaded for releases, user context, breadcrumbs, performance monitoring.
- Sentry or equivalent in Edge Functions (Sentry's Deno integration or structured logs piped to a log drain).
- Structured logging schema across Edge Functions.
- Alert thresholds and routing:
  - Auth failure rate spike (>5x baseline)
  - Verification queue age >48h
  - Message send failure rate >1%
  - DB CPU >70% sustained 5min
  - p95 query latency >500ms on hot paths
  - Edge Function p95 >2s
  - Sentry crash-free session rate <99%
- Metrics dashboard: DAU, jobs posted/day, applications/day, message send success, verification queue depth, p95 latencies. PostHog or a custom Supabase query view.
- Runbooks for solo-on-call AU operator:
  - "Auth is down" — escalation path, what to check first
  - "Verification queue is backed up" — bulk-approval workflow, escalation
  - "Mass message-send failure" — Realtime status, fallback to push, comms to users
  - "Suspected breach" — Notifiable Data Breaches Scheme timeline (30 days assessment, prompt notification to OAIC and affected users)
- Status page (even a simple one — statuspage.io free tier or a static page).
- Backup verification: Supabase takes daily backups, but has anyone tested restore?

Specific Jobdun questions to answer:
1. Is Sentry SDK in pubspec.yaml and initialised in main.dart with environment + release tag?
2. Are Edge Functions emitting structured JSON logs with request_id, user_id, route, latency_ms, outcome?
3. Is there ANY metrics dashboard, even a single Supabase SQL view?
4. Is there a documented on-call runbook anywhere in the repo (e.g. /docs/runbooks/)?
5. Has a DB restore been tested? Document the procedure even if not executed.
6. Is there a feature_flags table or PostHog feature flags for risky launches?
7. Is the App Store / Play Store deployment process documented (Fastlane, manual, etc.)?

Write your full report to /docs/audit/08_observability_ops.md.
```

---

## 4. Synthesizer Sub-Agent

**Output file:** `/docs/audit/00_EXECUTIVE_SUMMARY.md`

Dispatch this AFTER all 8 specialists have completed.

```
You are the Synthesizer for the Jobdun backend audit.

[INSERT §0 CONTEXT BLOCK HERE]

Your job:
1. Read all 8 specialist reports in /docs/audit/01_*.md through /docs/audit/08_*.md.
2. Read /docs/audit/00_SCOPE.md (written by the Orchestrator).
3. Produce /docs/audit/00_EXECUTIVE_SUMMARY.md following the structure below.

Required sections:

# Jobdun Backend Audit — Executive Summary

**Overall verdict:** RED | AMBER | GREEN for 25k AU users
**Date:** <ISO>
**Auditor count:** 8 specialists + 1 synthesizer

## TL;DR for Ken
A 5-bullet summary. Brutal honesty. Match Ken's pace — direct, informal, no hedging.

## TL;DR for Ken's boss (layman's version)
A 5-bullet summary in plain English. No jargon. Each bullet has a one-sentence consequence ("if we ship as-is, X will happen").

## Top 10 P0 findings
Cross-cutting prioritisation across all 8 reports. For each:
- Title
- Source (which agent flagged it)
- One-paragraph rationale
- One-line fix direction
- Effort

## P0 + P1 sprint plan
Group findings into 2-week sprints. For each sprint:
- Sprint name (e.g. "RLS lockdown", "Privacy Act baseline", "Index pass")
- Findings included
- Total effort
- Definition of done

## Phase alignment
Map findings to Jobdun's roadmap phases (0–4). Flag anything Ken is currently working on that should pause until P0s clear.

## Risk-adjusted opinion
If Ken did NOTHING and shipped today, what specifically breaks at 1k users? At 10k? At 25k? Give three concrete failure scenarios.

## Open questions
Aggregate the "Open questions for Ken" sections from all 8 reports. Deduplicate. Group by theme.

## What I'd ship first vs. what I'd defer
- Ship first (next 2 weeks): <list>
- Ship next (weeks 3–6): <list>
- Defer to Phase 2+: <list>

## Layman's analogy
End with one paragraph: "Think of Jobdun's backend right now like ..." — a single analogy Ken can use with non-technical stakeholders.

Be honest. If the codebase is mostly empty (early stage), say so and frame findings as "design these next" rather than "fix these now." If the codebase is further along and has real issues, name them.
```

---

## 5. Final Orchestrator Report

After the Synthesizer completes, the Orchestrator returns this to Ken:

```
Audit complete. Files written:

/docs/audit/
  00_SCOPE.md
  00_EXECUTIVE_SUMMARY.md
  01_schema.md
  02_rls_auth.md
  03_performance.md
  04_storage_privacy.md
  05_edge_functions.md
  06_realtime_messaging.md
  07_trust_safety.md
  08_observability_ops.md

Headlines:
- Overall verdict: <RED|AMBER|GREEN>
- P0 count: <N>
- P1 count: <N>
- Estimated effort to clear P0+P1: <X person-days>

Top 5 P0s:
1. <title> (<agent>)
2. ...

Recommended next move: <one sentence — what to do tomorrow morning>
```

---

## 6. Severity Calibration — Do Not Skip This

Before you start dispatching, internalize these calibration anchors. If your findings don't roughly fit this shape, you're either too generous or too harsh.

**Examples of P0 (real Jobdun-relevant):**
- A table has RLS DISABLED
- Service-role key is referenced in `lib/`
- Verification documents are in a public bucket
- No privacy policy acceptance is recorded
- A user can update their own `role` column

**Examples of P1:**
- Job search has no GIN index on title/description
- Inbox uses offset pagination
- No rate limiting on message send
- No structured logs in Edge Functions
- No retention policy documented

**Examples of P2:**
- `created_at` columns exist but no `updated_at` triggers
- Some status fields are TEXT instead of enums
- Image uploads aren't compressed client-side
- No feature flag table

**Examples of P3:**
- Table names are inconsistent (some plural, some singular)
- A few migration files lack a comment header
- Some Dart entity classes don't have `copyWith`

---

## 7. Run It

Begin with the survey step (§1.1). Do not start dispatching sub-agents until `/docs/audit/00_SCOPE.md` is written and you have an inventory of what's actually in the repo.

When ready, dispatch all 8 specialists in parallel (Task tool), wait for completion, dispatch the Synthesizer, then report back.
