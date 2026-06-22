# Jobs-Feed Shared Cache (Upstash Redis + Edge Function)

> **Status (2026-06-22):** Phases 0–5 done & **DEPLOYED to Sydney**
> (`zethpanvkfyijislxesn`): `jobs-feed` function ACTIVE (v2), Upstash secrets set,
> index `20260622000001` applied. Code on `feat/jobs-feed-cache` (commits
> `c6a53e4`→`9e167ca`) — Deno tests + 11 Dart repo tests green, analyze +
> architecture clean. **Remaining:** read the live hit ratio after real feed
> traffic (counters `jobs:feed:v1:stats:hit|miss`); branch not yet `git push`ed.
> **Companion:** [`CACHING_ARCHITECTURE.md`](CACHING_ARCHITECTURE.md) — this is the
> implementation of its **Phase 4** (shared server-side cache for the public feed).

## Context

Jobdun is Flutter → Supabase (BaaS, no app server). The goal is Redis/Upstash caching "so
there are no bottlenecks when there are a lot of users." Reality-check first: the big
read-scaling win (per-user client cache) is **already shipped** (`lib/core/cache/`, Hive
stale-while-revalidate). The remaining lever is the **shared hot read** — the public jobs
feed. Its RLS policy `jobs_select_open` is `status IN ('open','filled') AND deleted_at IS
NULL` for **every** authenticated user, so the default, unfiltered first page is provably
identical for all users and safe to cache in a shared layer.

Because the app reads Postgres directly, a shared cache must sit **behind an Edge Function**
(the app can't hold Redis creds). This adds one `jobs-feed` Deno function backed by Upstash
Redis — chosen over the no-infra Postgres-matview alternative after explicit discussion,
because it actually *offloads* Postgres rather than just softening per-query cost.

**Outcome:** thousands of concurrent feed-opens in the same ~45s collapse to ~1 Postgres
query, with graceful fallback to the existing direct path if Redis/the function is down.

## Goal & Non-Goals

**Goal:** Cache the default, unfiltered jobs-feed **first page** (offset 0, limit 20) in
Upstash Redis behind a new `jobs-feed` Edge Function, read-through with a 45s TTL and
best-effort invalidation on write, degrading safely to direct Postgres.

**Non-goals (v1 — fall through to direct Postgres, unchanged):**
- Filtered feeds (trade-type / status), open-ended search, "Your listings" (`builder_id`) — per-user or low-shareability.
- Deeper pages (offset ≥ 20). Page 0 is the overwhelming hot path and matches the existing client-cache scope.
- Offline writes / outbox (explicitly out of scope per `CACHING_ARCHITECTURE.md`).
- Moving the existing Postgres rate-limit / circuit-breaker to Redis (separate, lower-value).

## Architecture

```
Flutter feed (default, page 0)
  → Hive client cache (per-user, EXISTS today)
  → JobRepositoryImpl.getJobs()  [isFirstPage block]
       └─ try JobFeedCacheDataSource.getFirstPage()  →  invoke('jobs-feed', {action:'read'})
              Edge Function (JWT-gated, service-role):
                GET  jobs:feed:v1:open:p0
                  ├─ HIT  → return rows            (Postgres untouched)
                  └─ MISS → SELECT <feedColumns> WHERE status IN ('open','filled')
                            AND deleted_at IS NULL ORDER BY published_at DESC LIMIT 20
                          → SET key EX 45 → return rows
       └─ on success: write-through to Hive (offline last-known) → return
       └─ on ANY failure (fn down / network): fall through to existing
          _datasource.getJobs() direct path (which itself has offline disk fallback)

Writes (createJob / updateJob / softDeleteJob):
  → after success: unawaited invalidate → invoke('jobs-feed', {action:'invalidate'})
       Edge Function: debounce-lock (SET NX EX 5) → DEL jobs:feed:v1:open:p0
```

## Key Design Decisions

- **Cache key:** `jobs:feed:v1:open:p0` (single key for v1). `v1` lets a `feedColumns` change bust everything.
- **TTL:** 45s (a new job appears within ≤45s even with zero invalidation — the safety net).
- **Safety invariant (non-negotiable):** the function uses service-role (bypasses RLS), so its
  SELECT **hard-codes** the public predicate and ignores all client params except a clamped
  `limit ≤ 20`. It can only ever return the public open/filled set — exactly what RLS grants
  every authenticated user. No per-user data flows through it.
- **Projection parity:** the function's SELECT must mirror Dart `feedColumns`
  (`job_remote_datasource.dart`). A Deno test asserts the column list (drift guard, mirroring
  the existing geo-columns regression comment).
- **Graceful degradation:** app falls back to direct Postgres on function failure; if Upstash
  env is missing the function serves uncached from Postgres (`source:'origin-no-cache'`).
- **Kill switch:** app-side `kFeedServerCacheEnabled` const (default true; `--dart-define`
  overridable). False → repo bypasses the function entirely → exact pre-change behavior.
- **Invalidation abuse cap:** invalidate is debounced server-side (one DEL per ≤5s via a Redis
  `SET NX EX 5` lock), so a malicious authenticated user can't amplify cache-miss load beyond
  today's uncached baseline.

## Upstash setup (one-time, done by the project owner)

1. Sign up at **upstash.com** (free tier, no card).
2. Create a **Redis** database → **Regional**, region **AWS `ap-southeast-2` (Sydney)** to
   co-locate with the Supabase project (Sydney, ref `zethpanvkfyijislxesn`).
3. Copy the **REST** credentials `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN`
   (HTTP/REST pair — not the `redis://` connection string).
4. Local: add both to `supabase/functions/.env` (gitignored). Deploy: `supabase secrets set
   UPSTASH_REDIS_REST_URL=... UPSTASH_REDIS_REST_TOKEN=...`.

## Phases (each independently shippable & reviewable)

### Phase 0 — Plan doc ✅
This document. **Review checkpoint:** the plan itself.

### Phase 1 — Feed index (DB prerequisite, zero app risk)
- Migration `supabase/migrations/20260622000001_jobs_feed_index.sql`:
  partial index `jobs_feed_published_idx ON jobs (published_at DESC) WHERE deleted_at IS NULL
  AND status IN ('open','filled')`.
- Rollback `supabase/rollbacks/20260622000001_jobs_feed_index_down.sql`.
- **Verify:** `EXPLAIN (ANALYZE, BUFFERS)` on the feed query shows an index scan (no in-memory
  sort) before vs. after. Confirm target project ref before `db push` (mobile = `zethpanvkfyijislxesn`).
- **Review checkpoint:** migration SQL + EXPLAIN before/after.

### Phase 2 — `jobs-feed` Edge Function (read path) + Upstash
- `supabase/functions/jobs-feed/index.ts` — mirror `verify-abn` house style: `preflight` →
  `getUserFromRequest` (401 if none) → parse `{action,limit}` → branch read/invalidate →
  `jsonResponse`. `serviceClient()` for the miss-path query. Upstash import confirmed via Context7.
- Stats: `INCR jobs:feed:v1:stats:{hit|miss}`.
- Bootstrap minimal Deno test infra (`supabase/functions/deno.json` + `…/index_test.ts`):
  limit-clamp invariant, projection-parity vs `feedColumns`, miss→set→hit (mocked).
- Secrets added to `supabase/functions/.env.example`.
- **No app changes yet** — function dormant until Phase 3.
- **Verify:** `supabase functions serve`; `curl` read ×2 → `source:cache` on 2nd; invalidate resets it.
- **Review checkpoint:** function code + Deno test green + curl hit/miss transcript.

### Phase 3 — App read integration (TDD)
- `lib/features/jobs/data/datasources/job_feed_cache_datasource.dart` mirroring
  `verifications_remote_datasource.dart`'s `_invoke`.
- `jobs_provider.dart`: public `jobFeedCacheDataSourceProvider`, injected into `jobRepositoryProvider`.
- `job_repository_impl.dart`: inside the existing `isFirstPage` block (gated by
  `kFeedServerCacheEnabled`), try cache datasource first; keep Hive write-through on success;
  on `ServerException` fall through to the existing direct path.
- **TDD:** hit returns + writes through; throw → falls back to direct; flag off → never called.
- **Verify:** `scripts/validate.sh` + `scripts/check-architecture.sh` green; emulator feed
  screenshot (CLAUDE.md UI rule — visually identical, new path).
- **Review checkpoint:** Dart diff + tests green + emulator screenshot.

### Phase 4 — Invalidation on write (TDD)
- Function `invalidate` action: debounce-lock (`SET NX EX 5`) + `DEL`.
- `job_repository_impl.dart`: `unawaited(cacheDatasource.invalidate())` after successful
  create/update/softDelete (closes the existing no-invalidation gap on update/delete).
- **TDD:** each write fires invalidate once; invalidate failure never fails the write.
- **Verify:** post a job → appears in another account's feed within seconds.
- **Review checkpoint:** post-a-job demo + tests green.

### Phase 5 — Measurement, docs & hardening (fold-in)
- Record observed hit ratio from `stats:hit|miss`; advance `CACHING_ARCHITECTURE.md` Phase 4 status.
- Noted (not built): trade-type variants via generation-counter key; `checkUserAndIp` reuse if needed.
- **Review checkpoint:** hit-ratio numbers + doc updates.

## Files Touched (by phase)

| Phase | Create | Modify |
|---|---|---|
| 0 | `docs/JOBS_FEED_CACHE_PLAN.md` | — |
| 1 | `supabase/migrations/20260622000001_jobs_feed_index.sql`, `supabase/rollbacks/…_down.sql` | — |
| 2 | `supabase/functions/jobs-feed/index.ts`, `…/index_test.ts`, `supabase/functions/deno.json` | `supabase/functions/.env.example` |
| 3 | `lib/features/jobs/data/datasources/job_feed_cache_datasource.dart`, repo+datasource tests | `jobs_provider.dart`, `job_repository_impl.dart` |
| 4 | invalidation tests | `jobs-feed/index.ts`, `job_repository_impl.dart` |
| 5 | — | `CACHING_ARCHITECTURE.md` |

## Risks & Mitigations
- **Shared-cache data leak** → function hard-codes the public predicate + clamps params; Deno test guards it.
- **Stale feed for the poster** → 45s TTL + Phase 4 invalidation; builder's own "Your listings" (uncached) shows their job immediately regardless.
- **Redis/function outage** → app falls back to direct Postgres; disk cache covers full offline.
- **Projection drift (TS vs Dart)** → projection-parity Deno test + comment cross-link.
- **Premature optimization** → honest note retained; kill switch + index make the change net-positive even at low load; measurement gate in Phase 5.

## Go-live (remaining steps — outward, run with care)

Confirm the target project first (mobile = `zethpanvkfyijislxesn`, Sydney; two
projects are linked).

1. **Deploy the function** (JWT-gated by default — no `--no-verify-jwt`):
   ```bash
   supabase functions deploy jobs-feed
   ```
2. **Set the Upstash secrets in prod** (service-role + SUPABASE_URL are
   auto-injected by Supabase for edge functions — only Upstash needs setting):
   ```bash
   supabase secrets set \
     UPSTASH_REDIS_REST_URL="https://<your-db>.upstash.io" \
     UPSTASH_REDIS_REST_TOKEN="<token>"
   ```
3. **Apply the feed index** (after confirming the project):
   ```bash
   supabase db push
   ```
4. **Verify live**: open the app (emulator/device) → Jobs feed → confirm it
   renders; post a job from another account → it appears within seconds. Then
   read the counters to confirm caching is working:
   ```bash
   # hits should climb on repeated feed opens
   curl -s "$UPSTASH_REDIS_REST_URL" -H "Authorization: Bearer $UPSTASH_REDIS_REST_TOKEN" \
     -d '["MGET","jobs:feed:v1:stats:hit","jobs:feed:v1:stats:miss"]'
   ```
5. **Record** the observed hit ratio back into this doc + `CACHING_ARCHITECTURE.md`.

If anything misbehaves: remove the Upstash secrets (function serves uncached) or
`supabase functions delete jobs-feed` (app falls back to direct Postgres).

## End-to-End Verification
1. `EXPLAIN (ANALYZE)` feed query → index scan, no sort (Phase 1).
2. `deno test` green; `curl` read×2 shows cache hit; invalidate resets it (Phase 2).
3. `flutter test` repo/datasource suites green incl. fallback + kill-switch (Phase 3/4).
4. `scripts/validate.sh` + `scripts/check-architecture.sh` green every phase.
5. Emulator: feed renders via cache path (screenshot); posting a job surfaces it fast (Phase 3/4).
6. `stats:hit|miss` counters show a climbing hit ratio under repeated opens (Phase 5).

## Rollback
- App: set `kFeedServerCacheEnabled=false` (or `--dart-define`) → instant pre-change behavior.
- Function: remove Upstash secrets → serves uncached; or `supabase functions delete jobs-feed`.
- DB: apply `supabase/rollbacks/20260622000001_jobs_feed_index_down.sql`.
