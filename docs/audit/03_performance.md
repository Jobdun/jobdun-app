# Performance & Indexing Audit — Jobdun Backend

**Auditor:** performance-auditor
**Date:** 2026-05-16
**Supabase project ref:** `zethpanvkfyijislxesn` — Postgres 17.6, Supabase Pro

## Scope

Every query path the Flutter app issues against Supabase/PostgREST, and the
indexes (or absence of them) supporting each. B-tree vs GIN vs GiST vs BRIN
selection; `pg_trgm` / FTS for keyword search; pagination strategy (keyset vs
offset vs unbounded); N+1 risk; Realtime subscription cost; PgBouncer
transaction-mode compatibility. No live DB available — every finding ships a
`CREATE INDEX` statement and the **expected EXPLAIN plan shape** (cost class)
it should produce.

## Files reviewed

Migrations (17): `supabase/migrations/20260511000002_jobs.sql`,
`…000003_applications.sql`, `…000004_messaging.sql`, `…000005_social.sql`,
`…000006_rls.sql`, `…20260514000001_profile_completeness.sql`,
`…20260514000003_portfolio_array_helpers.sql` (+ remaining 10 reviewed for
index/trigger content).

Dart query sites (15 files, 101 call sites). Primary:
`lib/features/jobs/data/datasources/job_remote_datasource.dart`,
`lib/features/applications/data/datasources/application_remote_datasource.dart`,
`lib/features/messaging/data/datasources/message_remote_datasource.dart`,
`lib/features/messaging/presentation/providers/messaging_provider.dart`,
`lib/features/notifications/data/datasources/notification_remote_datasource.dart`,
`lib/features/verification/data/datasources/verification_remote_datasource.dart`,
`lib/features/reviews/data/datasources/review_remote_datasource.dart`,
`lib/features/profile/data/datasources/profile_remote_datasource.dart`,
`lib/features/legal/data/legal_acceptance_repository.dart`,
`lib/features/profile/presentation/providers/trade_categories_provider.dart`,
plus auth/profile providers.

**Indexes that exist (all plain B-tree, plus one partial):**
`jobs(builder_id)`, `jobs(status)`, `jobs(trade_type_required)`;
`applications(job_id)`, `applications(trade_id)`, `applications(builder_id)`,
`UNIQUE(applications.job_id, trade_id)`;
`conversations(builder_id)`, `conversations(trade_id)`,
`UNIQUE(conversations.job_id, builder_id, trade_id)`;
`messages(conversation_id)`, `messages(sender_id)`;
`notifications(user_id)`, **partial** `notifications(user_id, read_at) WHERE read_at IS NULL`;
`verification_documents(trade_id)`; `reviews(reviewee_id)`,
`UNIQUE(reviews.job_id, reviewer_id)`.

**Index types absent entirely:** GIN, GiST, BRIN, `pg_trgm`, `tsvector`/FTS,
any composite covering `(…, created_at DESC)`, any keyset-pagination support.
No `LIMIT`/`.range()` is used **anywhere** in the codebase (verified:
`grep -rn '\.range(\|\.limit(' lib/` → 0 hits).

---

## Summary

| Severity | Count |
|---|---|
| P0 | 1 |
| P1 | 7 |
| P2 | 4 |
| P3 | 1 |

**Overall: RED.** Every list-returning query in the app is **unbounded** (no
`LIMIT`) and **offset-free but also keyset-free** — it fetches the entire
matching set every time. The job feed's keyword search calls `.textSearch()`
against a `search_vector` column **that does not exist in any migration** (the
feature is broken on day one, not just slow). The job-browse path has no
`published_at` index despite ordering by it on every load, no geo index for
"jobs near me", and no FTS/trgm index for keyword search. At 10k jobs / 50k
applications / 200k messages these become sequential scans + full sorts on the
hot path for 500 DAU on rural-AU 3G. The single engineer on call will see
Supabase Pro CPU saturate well before 25k accounts.

---

## Findings

### F-PERF-01 — Job keyword search targets a non-existent `search_vector` column (feature broken, not slow)
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `lib/features/jobs/data/datasources/job_remote_datasource.dart:41-46` —
  `query.textSearch('search_vector', filter.searchQuery!, type: TextSearchType.websearch)`.
  No `search_vector` column, no `tsvector` column, no GIN index exists in any
  migration (`grep -rn 'search_vector\|tsvector' supabase/migrations/` → only
  the Dart-side reference, zero schema). `jobs` columns are listed in
  `supabase/migrations/20260511000002_jobs.sql:24-66`; there is no FTS column.
- **Why it matters at 25k AU users:** Job keyword search is a primary discovery
  path for trades. Every search request returns a PostgREST error
  (`column jobs.search_vector does not exist`, 42703) — the feature has never
  worked, it is not a perf regression. Even once the column exists, without a
  GIN index a `to_tsvector` match is a full seq scan + per-row tsvector
  recomputation across 10k+ rows on every keystroke-debounced search.
- **Fix (concrete):** Add a generated `tsvector` column + GIN index, plus a
  `pg_trgm` GIN for fuzzy/typo-tolerant suburb/title matching (tradies
  mistype "electricain"). New migration
  `supabase/migrations/20260516000001_jobs_fts.sql`:
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_trgm;

  ALTER TABLE public.jobs
    ADD COLUMN IF NOT EXISTS search_vector tsvector
    GENERATED ALWAYS AS (
      setweight(to_tsvector('english', coalesce(title,'')), 'A') ||
      setweight(to_tsvector('english', coalesce(trade_type_required,'')), 'B') ||
      setweight(to_tsvector('english', coalesce(description,'')), 'C') ||
      setweight(to_tsvector('english', coalesce(suburb,'')), 'B')
    ) STORED;

  CREATE INDEX IF NOT EXISTS jobs_search_vector_gin
    ON public.jobs USING gin (search_vector);

  -- typo-tolerant title/suburb search (ILIKE '%term%')
  CREATE INDEX IF NOT EXISTS jobs_title_trgm
    ON public.jobs USING gin (title gin_trgm_ops);
  CREATE INDEX IF NOT EXISTS jobs_suburb_trgm
    ON public.jobs USING gin (suburb gin_trgm_ops);
  ```
  Generated column means no trigger to maintain and PgBouncer-safe (no
  prepared-statement / session state issue). Expected plan once added:
  `Bitmap Heap Scan on jobs → Bitmap Index Scan on jobs_search_vector_gin`,
  cost class **O(log n + matches)** vs the current broken / future seq-scan
  **O(n)**.
- **Effort:** S
- **Phase:** 0
- **Layman's:** The search box is wired to a database column that was never
  created — it errors out today, and even after we add it, it'll be slow
  without a search index.

---

### F-PERF-02 — Every list query is unbounded — no LIMIT / keyset / offset anywhere in the app
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `grep -rn '\.range(\|\.limit(' lib/` → **0 hits**. Affected
  hot paths: `job_remote_datasource.dart:50-52` (`getJobs` — full `jobs`
  scan), `application_remote_datasource.dart:58-74` `getMyApplications` and
  `:76-94` `getApplicationsForMyJobs`, `message_remote_datasource.dart:45-60`
  `getMessages` (entire conversation history), `:28-43` `getConversations`,
  `notification_remote_datasource.dart:17-31` `getNotifications`,
  `review_remote_datasource.dart:28-42` `getReviewsForUser`.
- **Why it matters at 25k AU users:** With 10k+ jobs, 50k+ applications,
  200k+ messages, a single `getJobs()` ships the entire open-jobs result set
  to a phone on rural 3G — multi-MB payloads, client OOM risk, and a full
  Postgres sort every call. A popular conversation with thousands of messages
  loads in one round trip. There is no pagination primitive (keyset cursor
  column ordering) anywhere, so this can't even be patched client-side without
  a query-layer change. This is the single biggest scale cliff in the app.
- **Fix (concrete):** Adopt **keyset pagination** (not offset — offset over
  50k rows re-scans+discards and is itself a P1). Add a stable sort key and
  `.limit(n)` to every list datasource. Example for the job feed
  (`job_remote_datasource.dart`):
  ```dart
  // page 1
  query = query.order('published_at', ascending: false)
               .order('id', ascending: false)   // tiebreaker, stable
               .limit(20);
  // page n: pass last row's (published_at, id)
  query = query
    .or('published_at.lt.$lastPublishedAt,'
        'and(published_at.eq.$lastPublishedAt,id.lt.$lastId)')
    .order('published_at', ascending: false)
    .order('id', ascending: false)
    .limit(20);
  ```
  Pair with the composite indexes in F-PERF-03/04/05/06. Use the
  `infinite_scroll_pagination` package already in `pubspec.yaml`. Messages
  should load **newest 30** then page backwards on scroll. Expected plan:
  `Index Scan … Limit 20` — cost class **O(log n + page)** vs current
  **O(n) + full sort**.
- **Effort:** L (touches 6 datasources + their providers/UI)
- **Phase:** 1
- **Layman's:** Every screen downloads the entire table instead of one page,
  so the app gets slower for everyone as the database grows.

---

### F-PERF-03 — Job browse: no index supports `WHERE deleted_at IS NULL [AND status='open'] ORDER BY published_at DESC`
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `job_remote_datasource.dart:25-52` — `getJobs` filters
  `.isFilter('deleted_at', null)`, optionally `.eq('status', …)` and
  `.eq('trade_type_required', …)`, then `.order('published_at', ascending: false)`.
  Indexes present (`supabase/migrations/20260511000002_jobs.sql:67-69`):
  `jobs(builder_id)`, `jobs(status)`, `jobs(trade_type_required)` — **none on
  `published_at`, none partial on `deleted_at IS NULL`, none composite**.
- **Why it matters at 25k AU users:** The job feed is the most-hit query in
  the product (every trade, every session). With no `published_at` index,
  Postgres seq-scans `jobs`, filters `deleted_at`, then does an external sort
  on `published_at` for every load. The standalone `jobs(status)` index is
  near-useless (low cardinality, ~5 enum values; planner will ignore it for a
  10k-row table and seq-scan anyway). On Supabase Pro shared CPU this sort
  dominates the feed latency for 500 DAU.
- **Fix (concrete):** Partial composite index matching the exact predicate +
  sort. New migration `supabase/migrations/20260516000002_jobs_feed_idx.sql`:
  ```sql
  -- Open-jobs feed: status filter + recency sort, excluding soft-deleted.
  CREATE INDEX IF NOT EXISTS jobs_feed_open_idx
    ON public.jobs (published_at DESC, id DESC)
    WHERE deleted_at IS NULL AND status = 'open';

  -- Trade-filtered feed variant.
  CREATE INDEX IF NOT EXISTS jobs_feed_trade_idx
    ON public.jobs (trade_type_required, published_at DESC, id DESC)
    WHERE deleted_at IS NULL AND status = 'open';

  -- Builder's own jobs (watchBuilderJobs streams by builder_id, created_at).
  CREATE INDEX IF NOT EXISTS jobs_builder_recent_idx
    ON public.jobs (builder_id, created_at DESC)
    WHERE deleted_at IS NULL;
  ```
  A partial index on `status='open'` is correct here (the feed only ever
  shows open jobs; draft/closed/cancelled never appear) and keeps the index
  small. Expected plan: `Index Scan Backward using jobs_feed_open_idx
  (… LIMIT 20)` — no Sort node — cost class **O(log n + page)** vs current
  `Seq Scan + Sort` **O(n log n)**.
- **Effort:** S
- **Phase:** 1
- **Layman's:** The main jobs list has no index for "newest open jobs", so
  the database reads and re-sorts every job on every visit.

---

### F-PERF-04 — Builder/Trade applications list: no `(builder_id|trade_id, created_at DESC)` composite; N+1 join risk
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `application_remote_datasource.dart:58-94` —
  `getMyApplications` does `.eq('trade_id', …).order('created_at', desc)`
  with embedded `jobs(...)`, `builder_profiles(...)`;
  `getApplicationsForMyJobs` does `.eq('builder_id', …).order('created_at', desc)`
  with embedded `trade_profiles(...)`, `jobs(...)`. Indexes present
  (`…000003_applications.sql:44-46`): single-column `applications(job_id)`,
  `(trade_id)`, `(builder_id)` — **no `(builder_id, created_at)` or
  `(trade_id, created_at)` composite**. The spec specifically asks for
  `(job_id, status, created_at DESC)` for the builder applicant view — also
  absent.
- **Why it matters at 25k AU users:** A builder with many postings can
  accumulate hundreds–thousands of applications (50k+ total in system). The
  single-column `applications(builder_id)` index returns the match set but
  Postgres must then sort all of them by `created_at` every load (no
  composite). The PostgREST embed (`jobs(...)`, `trade_profiles(...)`) is
  resolved as a batched join, not a true N+1, but with no index on the join
  it amplifies the seq-scan cost. Unbounded (F-PERF-02) makes it worse.
- **Fix (concrete):** New migration
  `supabase/migrations/20260516000003_applications_idx.sql`:
  ```sql
  -- Trade's "my applications" list.
  CREATE INDEX IF NOT EXISTS applications_trade_recent_idx
    ON public.applications (trade_id, created_at DESC, id DESC);

  -- Builder's incoming applications list.
  CREATE INDEX IF NOT EXISTS applications_builder_recent_idx
    ON public.applications (builder_id, created_at DESC, id DESC);

  -- Per-job applicant review screen, filtered by status (spec-requested).
  CREATE INDEX IF NOT EXISTS applications_job_status_idx
    ON public.applications (job_id, status, created_at DESC);
  ```
  Expected plan: `Index Scan using applications_trade_recent_idx … Limit 20`,
  no Sort node — cost class **O(log n + page)** vs current
  `Index Scan + Sort` **O(k log k)** where k = applications for that user.
- **Effort:** S
- **Phase:** 1
- **Layman's:** A builder's applicant list isn't indexed for sorting by date,
  so the database re-sorts all their applications each time.

---

### F-PERF-05 — Inbox: no keyset pagination, no `messages(conversation_id, created_at)` composite; conversation list scan
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `message_remote_datasource.dart:45-60` `getMessages` —
  `.eq('conversation_id', …).isFilter('deleted_at', null).order('created_at')`
  loads the **entire** thread; `:28-43` `getConversations` —
  `.or('builder_id.eq.$userId,trade_id.eq.$userId').neq('status','blocked')
  .order('last_message_at', desc)`. Indexes present
  (`…000004_messaging.sql:24-25`): single-column `messages(conversation_id)`,
  `messages(sender_id)`; `conversations(builder_id)`, `(trade_id)`. **No
  `messages(conversation_id, created_at DESC)`; no index on
  `conversations.last_message_at`; the `OR(builder_id, trade_id)` predicate
  can't use either single-column index efficiently.**
- **Why it matters at 25k AU users:** 200k+ messages. Opening a busy
  conversation seq-orders the whole thread (no composite, no LIMIT). The
  conversation-list `OR` across two FK columns plus a sort on the
  un-indexed `last_message_at` is a seq scan of `conversations` per inbox
  open. Messaging is realtime-backed (F-PERF-08) so this fires often.
- **Fix (concrete):** New migration
  `supabase/migrations/20260516000004_messaging_idx.sql`:
  ```sql
  -- Thread fetch: newest-first, paged.
  CREATE INDEX IF NOT EXISTS messages_conv_recent_idx
    ON public.messages (conversation_id, created_at DESC, id DESC);

  -- Inbox sort. last_message_at is maintained by the
  -- update_conversation_last_message() trigger.
  CREATE INDEX IF NOT EXISTS conversations_builder_recent_idx
    ON public.conversations (builder_id, last_message_at DESC);
  CREATE INDEX IF NOT EXISTS conversations_trade_recent_idx
    ON public.conversations (trade_id, last_message_at DESC);
  ```
  Replace the `.or(builder_id,trade_id)` round trip with **two indexed queries
  unioned client-side** (PostgREST `or` across distinct columns defeats both
  indexes), or expose an `inbox` RPC `WHERE builder_id = auth.uid() OR
  trade_id = auth.uid()` with the two partial indexes. Add keyset paging to
  `getMessages` (load newest 30, page up). Expected plan:
  `Index Scan Backward using messages_conv_recent_idx … Limit 30` —
  cost class **O(log n + page)** vs current full-thread **O(n) + Sort**.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Opening a chat loads every message ever sent in it, and the
  inbox isn't indexed for "most recent conversations first".

---

### F-PERF-06 — Admin verification queue & licence-expiry have no supporting index AND no data model
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `verification_documents` indexes
  (`…000005_social.sql:39`): only `verification_documents(trade_id)`. The
  app writes/reads `status='pending'`
  (`profile_remote_datasource.dart:159-170`,
  `verification_remote_datasource.dart:82-101`) but there is **no partial
  index `WHERE status='pending'`** for the (separate web) admin review queue,
  and **no `expires_at` / `expiry_date` column exists** despite the Dart
  upload path sending `expiry_date`
  (`verification_remote_datasource.dart:97-98`) and `submitted_at` /
  `deleted_at` / `doc_type` / `file_path` — none of these columns exist in
  `…000005_social.sql:26-37` (table has `type`, `url`, `created_at`,
  `updated_at`). The licence-expiry notification path the spec asks about has
  no data model at all (confirmed by 00_SCOPE §2).
- **Why it matters at 25k AU users:** The admin verification queue (separate
  web app) will scan all `verification_documents` filtering `status='pending'`
  — at 25k trades that's a growing seq scan with no partial index. Worse, the
  expiry-reminder job ("white card expires in 30 days") cannot exist:
  there's no `expires_at` column to index. Insurance/licence expiry is a
  compliance-relevant gap for AU construction (a trade with a lapsed white
  card is unlawful on site) — silent expiry is a trust/safety + legal issue.
- **Fix (concrete):** Schema-auditor owns the column additions; from a perf
  standpoint, once `expires_at` exists, add partial indexes. New migration
  `supabase/migrations/20260516000005_verification_idx.sql`:
  ```sql
  -- (depends on schema-auditor adding status mapping + expires_at + deleted_at)
  ALTER TABLE public.verification_documents
    ADD COLUMN IF NOT EXISTS expires_at date,
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

  -- Admin review queue: only pending rows, oldest first (FIFO triage).
  CREATE INDEX IF NOT EXISTS verif_pending_queue_idx
    ON public.verification_documents (created_at)
    WHERE status = 'pending';

  -- Licence-expiry sweep: approved docs expiring soon.
  CREATE INDEX IF NOT EXISTS verif_expiry_idx
    ON public.verification_documents (expires_at)
    WHERE status = 'approved' AND expires_at IS NOT NULL;
  ```
  The expiry sweep belongs in a scheduled Edge Function (edge-functions-auditor
  scope). Expected plan for the queue: `Index Scan using verif_pending_queue_idx`
  touching only pending rows — cost class **O(pending)** vs **O(all docs)**.
- **Effort:** S (index) / blocked on M (schema columns + Edge Function)
- **Phase:** 2
- **Layman's:** There's no fast way to find documents waiting for review, and
  no field at all to track when a licence expires — so no expiry reminders
  are possible.

---

### F-PERF-07 — Realtime streams over-fetch and filter client-side; `watchConversations` subscribes to the whole table
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `message_remote_datasource.dart:99-113` `watchConversations`
  — `.from('conversations').stream(primaryKey: ['id']).order('last_message_at')`
  with **no `.eq()` server filter**, then `.where((r) => r['builder_id'] ==
  userId || r['trade_id'] == userId)` filtered **in Dart**. Same shape risk in
  `:116-128` `watchMessages` (filtered server-side by `conversation_id`, OK)
  and `job_remote_datasource.dart:128-140` `watchBuilderJobs` (server-filtered
  by `builder_id`, OK, but `deleted_at` filtered client-side). The
  conversations stream has no per-row RLS-equivalent server filter on the
  realtime channel.
- **Why it matters at 25k AU users:** Supabase Realtime on the
  `conversations` table with no filter means every connected client receives
  **every conversation change for every user in the system** and discards
  99.99% client-side. At 500 DAU that's 500 sockets each receiving the full
  firehose of 25k users' conversation updates — Realtime quota burn, battery
  drain on rural 3G, and a privacy smell (other users' row payloads transit
  the client even if RLS hides columns). This will hit Supabase Pro Realtime
  limits long before 25k accounts.
- **Fix (concrete):** Server-filter the stream. PostgREST realtime supports a
  single `eq` filter per stream; since the predicate is an `OR` across two
  columns, run **two filtered streams and merge**, or denormalise a
  `participant_ids uuid[]` and filter `cs` (contains). Minimal fix:
  ```dart
  // two streams, merged — each is server-filtered, RLS-scoped
  final asBuilder = _client.from('conversations')
      .stream(primaryKey: ['id']).eq('builder_id', userId);
  final asTrade = _client.from('conversations')
      .stream(primaryKey: ['id']).eq('trade_id', userId);
  // merge in Dart with rxdart Rx.combineLatest2 / StreamGroup
  ```
  Confirm RLS policies on `conversations`/`messages` are enabled (rls-auditor
  scope) so Realtime respects them. Effort/cost class: turns an O(all_rows)
  broadcast into O(user's_rows).
- **Effort:** M
- **Phase:** 1
- **Layman's:** The inbox live-updates by listening to *everyone's*
  conversations and throwing away all but yours — wasteful and a privacy
  smell.

---

### F-PERF-08 — Per-conversation realtime subscriptions never time-bounded; subscription accumulation
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `messaging_provider.dart:77-90` `_subscribeToMessages` adds a
  `StreamSubscription` per opened conversation into `_messageSubs` and only
  removes via explicit `unsubscribeMessages` (`:88-90`) or
  `_cancelAllSubscriptions` on dispose (`:125-131`). There is no LRU cap; a
  user who opens 50 conversations in a session holds 50 live Realtime
  channels simultaneously. `watchMessages` (`message_remote_datasource.dart:116`)
  also re-streams the **entire** thread on every change (no incremental
  cursor).
- **Why it matters at 25k AU users:** Each open channel is a server-side
  Realtime subscription. A power-user builder triaging applicants across many
  threads silently accumulates channels; multiplied across 500 DAU this is
  unnecessary Realtime concurrency against the Pro plan ceiling. Re-streaming
  full threads on each new message is O(thread) bandwidth per message on 3G.
- **Fix (concrete):** Cap concurrent message subscriptions (LRU, e.g. keep
  the 3 most-recently-viewed; cancel the rest):
  ```dart
  static const _maxLiveThreads = 3;
  void _subscribeToMessages(String id) {
    if (_messageSubs.containsKey(id)) return;
    if (_messageSubs.length >= _maxLiveThreads) {
      final oldest = _messageSubs.keys.first;
      _messageSubs.remove(oldest)?.cancel();
    }
    /* … existing listen … */
  }
  ```
  Combine with keyset message paging (F-PERF-05) so the stream only carries
  new rows, not the whole thread.
- **Effort:** S
- **Phase:** 2
- **Layman's:** Opening many chats keeps all of them live in the background
  forever, quietly using up server connections.

---

### F-PERF-09 — App queries reference ~8 columns that don't exist in any migration (queries error or are silently mis-shaped)
- **Severity:** P2
- **Status:** BROKEN
- **Evidence:** Beyond F-PERF-01's `search_vector`:
  `application_remote_datasource.dart:106,121` writes `status_changed_at` —
  not in `…000003_applications.sql`.
  `message_remote_datasource.dart:35` filters `conversations.status`,
  `:52,124` filter `messages.deleted_at`, `:86-92` write
  `builder_last_read_at`/`trade_last_read_at`/`builder_unread_count`/`trade_unread_count`
  — none in `…000004_messaging.sql` (table has no `status`, no
  `deleted_at`, no read/unread columns).
  `verification_remote_datasource.dart:40,127` order by `submitted_at`,
  `:86-87` write `doc_type`/`file_path`, `:97-98` write
  `expiry_date`/`issued_date`/`state`/`issuer`/`document_number`,
  `:39` filter `deleted_at` — `…000005_social.sql` has only `type`, `url`,
  `status`, `created_at`, `updated_at`.
- **Why it matters at 25k AU users:** These are correctness-before-performance
  defects that an indexing audit surfaces because they sit on the same hot
  paths. PostgREST returns 42703 (`column … does not exist`) for the read
  filters/orders, and silently drops unknown keys on some writes — meaning
  application status-change timestamps, message soft-delete, and unread
  counters are not actually persisted. No amount of indexing helps a column
  that isn't there. Flagged here so the schema-auditor's migration list is
  complete and the eventual indexes (F-PERF-04/05/06) target real columns.
- **Fix (concrete):** Schema-auditor to add the missing columns in a
  reconciliation migration; this audit's index migrations
  (F-PERF-04/05/06) **depend on** it. Cross-referenced as
  **NEEDS HUMAN INPUT** on which side is canonical (schema vs Dart) per
  column — recommend Dart is the product intent, migrate the schema up.
- **Effort:** M (schema-auditor owns)
- **Phase:** 1
- **Layman's:** Several queries point at database columns that were never
  created, so they error or quietly lose data — indexes can't fix a missing
  column.

---

### F-PERF-10 — `getConversations` `OR` predicate + un-indexed `last_message_at` sort = seq scan
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `message_remote_datasource.dart:28-43` —
  `.or('builder_id.eq.$userId,trade_id.eq.$userId')
  .order('last_message_at', ascending: false, nullsFirst: false)`. No index
  on `conversations(last_message_at)`; the disjunction across two
  single-column indexes (`conversations_builder_id_idx`,
  `conversations_trade_id_idx`) is typically planned as a seq scan + sort,
  not a BitmapOr, because the trailing sort can't be satisfied by either.
- **Why it matters at 25k AU users:** Inbox open is frequent. At 25k users
  with many conversations each, a seq scan of `conversations` + sort on
  every inbox refresh adds up under Realtime-driven refresh churn. Subsumed
  by the F-PERF-05 / F-PERF-07 fixes (split into two indexed, server-filtered
  streams) but called out distinctly because it also affects the non-realtime
  initial `getConversations` fetch.
- **Fix (concrete):** Covered by the
  `conversations_builder_recent_idx` / `conversations_trade_recent_idx`
  composites in `20260516000004_messaging_idx.sql` (F-PERF-05) **plus**
  rewriting the `.or()` into two indexed queries merged client-side, or an
  `inbox()` RPC. Expected plan post-fix: two `Index Scan using
  conversations_*_recent_idx` (no Sort) merged — cost **O(log n + k)** vs
  `Seq Scan + Sort` **O(n log n)**.
- **Effort:** S (folds into F-PERF-05)
- **Phase:** 1
- **Layman's:** The inbox query can't use an index because of how it's
  written, so it scans the whole conversations table.

---

### F-PERF-11 — Reference & per-user lookups are fine but `trade_categories` / `legal_acceptances` lack the exact-ordering index
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `trade_categories_provider.dart:13-17` —
  `.order('category').order('sort_order')`, no index on
  `(category, sort_order)` (table is 19 seeded rows per 00_SCOPE §2 — a
  seq scan + sort here is **fine forever**, do not index).
  `legal_acceptance_repository.dart:40-44` —
  `.eq('user_id', …).order('accepted_at', desc)`; `reviews` reads
  (`review_remote_datasource.dart:28-42`) use the existing
  `reviews(reviewee_id)` index but then sort by `created_at` un-indexed.
  `notifications` reads are well-covered (the partial
  `notifications(user_id, read_at) WHERE read_at IS NULL` in
  `…000005_social.sql:14-15` is a genuinely good index; the
  `getNotifications` full list still benefits from a
  `(user_id, created_at DESC)` composite).
- **Why it matters at 25k AU users:** `trade_categories` is a tiny static
  reference table — **no action, indexing it would be cargo-culting**.
  `legal_acceptances` and per-user `reviews`/`notifications` lists grow
  slowly per user; the missing `(user_id, created_at DESC)` composites are
  minor and only matter once a user has hundreds of rows. Documented for
  completeness, not urgent.
- **Fix (concrete):** Optional, low priority, fold into a later migration:
  ```sql
  CREATE INDEX IF NOT EXISTS notifications_user_recent_idx
    ON public.notifications (user_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS reviews_reviewee_recent_idx
    ON public.reviews (reviewee_id, created_at DESC);
  CREATE INDEX IF NOT EXISTS legal_acceptances_user_idx
    ON public.legal_acceptances (user_id, accepted_at DESC);
  -- DO NOT index trade_categories (19 rows).
  ```
- **Effort:** XS
- **Phase:** 3
- **Layman's:** A few small per-user lists could use a sort index eventually,
  but they're tiny today and the reference table needs nothing.

---

### F-PERF-12 — `jobs(status)` standalone index is dead weight; `view_count`/`application_count` counter writes are hot-row contention at scale
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `…000002_jobs.sql:68` `jobs_status_idx ON jobs(status)` —
  a 5-value enum on a 10k+ row table; the planner will not use it (selectivity
  too low) and it costs write amplification on every job update. Counters
  `application_count`/`view_count` (`…000002_jobs.sql:56-57`, comment says
  "maintained by triggers / edge functions" — **no such trigger exists in any
  migration**, and 00_SCOPE §2 confirms zero Edge Functions). If/when a
  per-application trigger increments `jobs.application_count`, every applicant
  to a popular job `UPDATE`s the same `jobs` row → row-lock contention.
- **Why it matters at 25k AU users:** A hot job (urgent, metro, 50k apps
  system-wide) funnels concurrent applicants into serialised updates of one
  `jobs` row — lock waits, bloat, and the standalone status index just adds
  write cost without read benefit. The partial indexes in F-PERF-03 already
  encode `status='open'` where it's actually selective.
- **Fix (concrete):**
  ```sql
  DROP INDEX IF EXISTS public.jobs_status_idx;  -- superseded by partials
  ```
  For counters, when the trigger is built (edge-functions/schema scope),
  prefer derived `COUNT(*)` from `applications` via the
  `applications_job_status_idx` (F-PERF-04) or a periodic refresh rather than
  per-insert hot-row `UPDATE` on `jobs`. Document as NEEDS HUMAN INPUT:
  confirm the counter-maintenance strategy before 25k.
- **Effort:** XS (drop) / M (counter strategy, deferred)
- **Phase:** 2
- **Layman's:** One index is never used but slows writes, and the
  "applications count" design will jam up popular jobs unless changed.

---

## Cross-cutting recommendations

1. **Ship the index migrations in dependency order:** F-PERF-09 schema
   reconciliation (schema-auditor) **first**, then
   `20260516000001…000005` index migrations, then the Dart keyset/limit
   refactor (F-PERF-02). Indexes on missing columns are no-ops.
2. **Adopt keyset pagination as a codebase-wide convention.** Every
   list datasource gets `(sort_col DESC, id DESC)` ordering + `.limit(n)` +
   a cursor parameter. Use `infinite_scroll_pagination` (already in
   `pubspec.yaml`). Ban offset pagination in code review — offset over 50k
   rows is itself a P1.
3. **Realtime hygiene:** every `.stream()` must carry a server-side `.eq()`
   filter (never client-side `.where()` over an unfiltered stream — F-PERF-07).
   Cap concurrent message channels (F-PERF-08). Verify RLS is enforced on
   realtime channels with the rls-auth-auditor.
4. **PgBouncer / pooling:** all current access is stateless PostgREST +
   single-statement RPCs — **transaction-mode safe**. The proposed
   `search_vector` is a *generated column* (no trigger, no session state) and
   the portfolio RPCs are single-statement SECURITY DEFINER — all
   PgBouncer-transaction-mode compatible. No `LISTEN/NOTIFY`, no client-side
   prepared statements, no advisory locks found. **No pooling change needed**;
   keep it that way (flag any future `LISTEN`/session-state RPC in review).
5. **No PostGIS / geo index — confirmed and intentional gap.** `jobs.latitude`
   /`jobs.longitude` are `double precision` with no GiST index and no
   `ST_DWithin` path (no "jobs within 50km" query exists in the app today —
   `job_filter` has no radius). When geo search ships, it needs PostGIS
   `geography` + `CREATE INDEX … USING gist(geog)`; a naive
   `lat BETWEEN … AND lng BETWEEN …` bounding-box on the double columns is a
   stopgap that still needs a `(latitude, longitude)` btree and is wrong near
   poles/dateline (irrelevant for AU but the radius math is still off). Track
   as a Phase 2 design item, not a today-bug.
6. **`ANALYZE` after backfill:** the generated `search_vector` and any
   schema-reconciliation columns need `ANALYZE public.jobs;` etc. so the
   planner has stats before the new indexes are chosen. Add to each migration.
7. **Add a query-perf smoke test:** a CI step that runs `EXPLAIN (ANALYZE,
   BUFFERS)` against seeded data for the 6 hot queries and fails if a
   `Seq Scan` on `jobs`/`applications`/`messages` appears — cheap insurance
   for a solo on-call engineer.

## Open questions for Ken

1. **Schema vs Dart canonicality (F-PERF-09):** ~8 columns
   (`search_vector`, `status_changed_at`, `conversations.status`,
   `messages.deleted_at`, conversation read/unread counters,
   `verification_documents.doc_type/file_path/expiry_date/submitted_at/deleted_at`)
   are used by the app but absent from migrations. Confirm the Dart side is
   the intended product shape so the schema can be migrated up to match.
2. **Counter maintenance (F-PERF-12):** `jobs.application_count` /
   `view_count` have no trigger and no Edge Function. What's the intended
   maintenance strategy — DB trigger (hot-row risk), derived count, or
   periodic rollup?
3. **Geo search roadmap:** Is "jobs within X km" a planned feature? If yes,
   PostGIS + GiST should be designed before the schema ossifies (Phase 2).
4. **Job feed default ordering:** `getJobs` orders by `published_at DESC`
   but unpublished/draft rows have `published_at = NULL`. Confirm the feed
   should be `status='open'`-only (the F-PERF-03 partial index assumes this).
5. **Region / Realtime quota:** Supabase Pro Realtime concurrency ceiling vs
   projected 500 DAU × multiple channels — confirm the plan tier headroom
   once F-PERF-07/08 land.
