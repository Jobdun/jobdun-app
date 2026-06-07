# Jobdun Caching Architecture

> **Status:** planning / design doc · **Branch:** `feat/offline-cache-hardening` · **Last updated:** 2026-06-07
>
> This document explains — in plain English *and* in engineering terms — where
> caching belongs in Jobdun, why "add Redis" is only one small piece of the
> answer, and a safe, phased rollout. **No application code is changed by this
> document.** Each phase below is approved and built separately.
>
> **Scope:** offline is **read-only by design** — mutations (apply, shortlist,
> send a message) still require connectivity. A client-side offline-**write** /
> outbox layer is deliberately **out of scope** of this document and would be
> designed separately. What this doc *does* commit to is making offline **reads**
> correct and safe (see §3.3).

---

## 1. Why we're doing this

Jobdun today has **almost no caching**, and it shows:

- Every time you open a screen, the app **re-fetches everything from scratch**.
  Riverpod providers are `autoDispose` — they throw their data away the moment you
  navigate away.
- Nothing survives an app restart. Cold start = blank skeletons every time. Only
  `shared_preferences` flags and the Supabase login session persist; there is no
  local data store (no Hive/SQLite/Drift).
- Offline = mostly empty/error states. The only "show cached data offline" today
  is the map pins on the discovery map.
- The two most expensive backend operations run with **zero caching**:
  - the geospatial **trade search** (`search_trades` RPC — trigonometry across
    many rows), and
  - the **external ABR/ABN lookup** (a slow Australian government API,
    rate-limited, called fresh every single time).

Caching is worth doing. The important correction is **what "Redis" actually buys
you here** — and the honest answer is: *less than you'd think, and not first.*

---

## 2. The one idea to take away

> **Caching is layered. "Redis" is one server-side layer. For a mobile app, the
> biggest, cheapest, lowest-risk win is the *client-side* layer — and Jobdun has
> nothing there yet. Redis is a precision tool you add later, only for work that is
> shared between many users or talks to a slow external service.**

### 2.1 Layman's version — the fridge analogy

- **Postgres (Supabase) = the supermarket.** Always has the freshest, correct
  data, but every trip costs time and effort.
- **Client cache (on the phone) = your fridge.** Keep what *you* personally use a
  lot — your profile, your inbox, the jobs you just scrolled — close by, so you
  don't run to the supermarket every time you get hungry. Private to you.
- **Redis (server-side) = a corner shop shared by the whole street.** Useful when
  *lots of people* keep asking for the *same* thing (e.g. "verify ABN
  51 824 753 556"): the shop fetches it from the far-away supplier once and hands
  out copies. Pointless for things only *you* ever ask for — that belongs in *your*
  fridge, not a shared shop.

The mistake "just add Redis" makes is putting *your* groceries in the shared
corner shop: it adds a server hop and a whole new piece of infrastructure to
manage, for something your own fridge does better and for free.

### 2.2 Why the mobile app can't just "use Redis"

The Flutter app talks **directly** to Postgres today (`.from().select()`,
`.rpc()`). It can't safely talk to Redis directly — you'd have to embed Redis
credentials in the app (insecure) or expose Redis to the internet (don't). Redis
only makes sense **behind an Edge Function**:

```
app  →  Edge Function  →  (check Redis)  →  Postgres / external API
```

Since almost nothing in Jobdun currently goes through an Edge Function for *reads*,
adding Redis to a read path also means **building a new Edge Function in front of
it** — real architectural cost. That's the main reason Redis is a later, surgical
move, not the opener.

---

## 3. The architecture: two layers

### 3.1 Layer 1 — Client-side cache (in the Flutter app) ← start here

Two sub-pieces:

1. **In-memory cache with TTL.** Keep a provider's result alive for a short window
   (e.g. 2–5 min) after you navigate away, so returning is *instant* instead of
   re-fetching. Riverpod 3 pattern: `final link = ref.keepAlive();` plus a `Timer`
   that calls `link.close()` after the TTL — wrapped in **one** small reusable
   helper so every controller uses it identically.
2. **Persistent (disk) cache for stale-while-revalidate.** Save the last-known
   result to a local store with a timestamp. On next open: **show the saved copy
   immediately** (screen is never blank), then quietly refresh in the background
   and swap in fresh data. This gives the offline win for free — offline just means
   "show the saved copy + an OFFLINE chip."

**What goes in Layer 1 (most of the app):**

| Read path | File (today) | Why client-cache |
|---|---|---|
| Jobs feed (first page) | `lib/features/jobs/data/datasources/job_remote_datasource.dart` → `getJobs()` | Hot; re-fetched on every Home/Jobs open; first page is the same for seconds-to-minutes |
| Trade discovery (first page) | `lib/features/discovery/data/datasources/trade_search_remote_datasource.dart` → `searchTrades()` | Same origin+radius+filters between visits; show last results instantly |
| My profile / builder / trade profile | `lib/features/profile/data/datasources/profile_remote_datasource.dart` | Rarely changes; loaded on app start + every profile/card view |
| My / incoming applications | `lib/features/applications/data/datasources/application_remote_datasource.dart` | Embedded job+profile data is stable; show last list while refreshing |
| Avatars / logos / portfolio images | `cached_network_image` (already in use) | Already cached; just tune `stalePeriod` on a shared `CacheManager` |

These cover **3 of the 4 goals** (faster revisits, offline, cut Supabase load)
with **no new external service and no Edge Functions**.

### 3.2 Layer 2 — Server-side cache (shared) ← later, surgical

Only for work that is **shared across users** or **hits a slow external API**.

| Read path | What's expensive | Right tool (vendor-light) |
|---|---|---|
| **ABR / ABN verification** (`supabase/functions/verify-abn/index.ts`) | Slow gov't API, rate-limited (5/hr/user), called fresh every time; same ABN often re-checked | **Postgres cache table first** — `abr_cache(abn pk, payload jsonb, fetched_at)`, served from the existing Edge Function. *Zero new infra.* |
| Rate-limit + circuit-breaker counters (`supabase/functions/_shared/circuit-breaker.ts`) | Currently **in-memory per function instance** → ineffective on serverless (each cold start forgets the count) | **This is where real Redis earns its place** — atomic `INCR`/`EXPIRE` shared across all instances |
| **Trade search** (`search_trades`, `supabase/migrations/20260604000001_trade_search.sql`) | Geospatial trig across many rows, per scroll/filter | **Measure first.** If needed: bucket the query (snap lat/lng to a ~1 km grid + fixed radius), cache the result per bucket+filters for 1–5 min — *requires routing search through a new Edge Function*, so only if metrics justify it |

**Explicitly NOT server-cached:** inbox, notifications, message threads (already
handled by Supabase **Realtime streams**), and any per-user read — those belong in
Layer 1 (your fridge), not the shared shop.

### 3.3 Hardening Layer 1 (required before the client cache is safe)

A persistent client cache is not "save JSON to disk and read it back." Four
properties have to hold or the cache becomes a *liability* — slower, leaky, or a
crash source. These are **not optional polish**; they are the line between a
cache that helps and one that ships bugs.

1. **Schema versioning + purge-on-bump — the one Jobdun cannot skip.** Jobdun has
   a documented history of *schema drift* (`trade_profiles` reading phantom
   columns; `JobModel` with non-null casts that throw on a missing field). A disk
   cache makes that sharper: a payload saved under last week's model shape is read
   back after a model change and **crashes on deserialize**. Defence is two-fold:
   - Stamp every entry (or every namespace) with a `schemaVersion`. On launch, a
     version mismatch **drops that namespace** before any read.
   - Wrap every deserialize **fail-safe**: a parse error evicts the bad entry and
     falls through to the network. A cache read must **never** surface a crash —
     worst case it degrades to "cold cache, fetch fresh."

2. **Eviction bounds.** TTL alone doesn't stop the store growing forever. Each
   namespace gets a max-entry count and a max-age; the store as a whole gets a
   size ceiling; eviction is LRU. Unbounded disk cache is a slow-burn liability on
   long-lived installs.

3. **Encryption at rest.** Layer 1 caches PII — profiles, message previews, ABN
   lookups. On a rooted or shared device an unencrypted store is plaintext on
   disk. The local store is encrypted; the key lives in platform secure storage
   (Keychain / Keystore via `flutter_secure_storage`), never in the app bundle.
   (`hive_ce` ships AES; Drift pairs with SQLCipher — decide alongside the Phase 2
   store choice.)

4. **Honest reachability.** `isOnlineProvider`
   (`lib/core/network/connectivity_provider.dart`) reports **radio state, not real
   reachability** — its own doc comment says so. It reads "online" on a
   captive-portal Wi-Fi or when Supabase itself is down, so the OFFLINE chip lies.
   Extend it with a cheap, debounced reachability probe (short-timeout HEAD
   against Supabase), kept best-effort so it never blocks the UI.

None of these add an external service — bar `flutter_secure_storage` for the key,
a package-list change that needs sign-off. They are the cost of doing Layer 1
*correctly*, and they ship as **Phase 2.5**, immediately after the persistent
cache that creates the need for them.

### 3.4 Where Redis actually lands

After the honest accounting, genuine **Redis (recommended: Upstash — serverless,
HTTP, free tier, pairs cleanly with Deno Edge Functions)** is justified for exactly
**one thing at first**: the **shared rate-limit + circuit-breaker counters** in the
verification functions, where Postgres is awkward and in-memory is broken. The ABR
*result* cache starts as a plain Postgres table; the search cache is "only if
measured." This stays vendor-light and still puts Redis exactly where it's the
correct tool.

---

## 4. The UX dimension (caching is not just backend)

Caching changes what the screen shows, so it is a design concern too. **Reuse what
already exists — don't reinvent:**

- **Stale-while-revalidate UX:** show cached content instantly; if a refresh is in
  flight, show a *quiet* "updating…" affordance, then swap. Returning users should
  rarely see a full skeleton again. Use `JSkeletonList`
  (`lib/core/design/widgets/j_skeleton_list.dart`) **only on a true cold cache**.
- **Freshness signal:** a subtle "Updated 2 min ago" / pull-to-refresh, so cached
  data never feels like a bug. Quiet secondary-text styling (`#94A3B8`), never a
  loud banner.
- **Offline:** show last-known data + the existing OFFLINE chip pattern
  (`isOnlineProvider` in `lib/core/network/connectivity_provider.dart`, already
  wired into the discovery map) instead of empty/error states.
- **Consistency:** the same loading → cached → fresh transition everywhere
  (150–200 ms, no bounce — per `design-system/jobdun/MASTER.md`).

---

## 5. Recommended rollout (phased, each phase independently shippable)

| Phase | What | Goal it serves | New infra? |
|---|---|---|---|
| **0** | This doc (`docs/CACHING_ARCHITECTURE.md`) | shared understanding | none |
| **1** | **Client cache — in-memory TTL.** One reusable `keepAlive + Timer` helper applied to jobs feed, discovery, profiles | Faster revisits | none |
| **2** | **Client cache — persistent stale-while-revalidate.** Thin local `CacheStore` (one small persistence package — *to be confirmed*, leaning `hive_ce` or `drift`) + the SWR provider pattern + offline "show last-known" | Cold-start instant + real offline | one Flutter pkg (needs sign-off — CLAUDE.md package-list change) |
| **2.5** | **Client cache — hardening (§3.3).** Schema versioning + purge-on-bump, fail-safe deserialize, eviction bounds (LRU + size ceiling), encryption at rest, honest reachability probe | Make Layer 1 *safe*: no stale-payload crashes, no unbounded disk, no plaintext PII, truthful OFFLINE chip | one Flutter pkg (`flutter_secure_storage` for the key — needs sign-off) |
| **3** | **ABR result cache in Postgres.** `abr_cache` table + dedup lookup in `verify-abn` | Protect the ABR API | none |
| **4** | **Redis (Upstash), only if warranted.** Move rate-limit/circuit-breaker counters to Redis; optionally bucketed search cache behind a new Edge Function | Cut load at scale | Upstash Redis |

We **measure between phases** (Supabase Dashboard query stats + simple in-app
timing) so we never add infrastructure we can't show is needed.

---

## 6. Files referenced (for whoever implements each phase)

**Client read paths (Layer 1 targets)**
- `lib/features/jobs/data/datasources/job_remote_datasource.dart`
- `lib/features/discovery/data/datasources/trade_search_remote_datasource.dart`
- `lib/features/profile/data/datasources/profile_remote_datasource.dart`
- `lib/features/applications/data/datasources/application_remote_datasource.dart`

**Reuse (do not reinvent)**
- `lib/core/providers/current_user_provider.dart` (user-scoped invalidation)
- `lib/core/providers/account_scoped.dart` (`resetOnAccountChange` — clear cache on logout/switch)
- `lib/core/network/connectivity_provider.dart` (`isOnlineProvider` — offline gating; extend with a reachability probe in Phase 2.5)
- `lib/core/design/widgets/j_skeleton_list.dart` (cold-cache skeleton only)

**To add (Phase 2.5)**
- `flutter_secure_storage` — stores the at-rest encryption key (Keychain / Keystore). CLAUDE.md package-list change — needs sign-off.

**Server paths (Layer 2 targets)**
- `supabase/functions/verify-abn/index.ts`
- `supabase/functions/_shared/circuit-breaker.ts`
- `supabase/migrations/20260604000001_trade_search.sql` (`search_trades`)

---

## 7. Guardrails for future phases

- **Cache invalidation is the hard part.** Every write must invalidate the cache it
  affects (e.g. editing your profile clears the cached profile; posting a job
  clears the cached "Your listings"). Clear all per-user cache on logout/account
  switch via the existing `account_scoped.dart` seam.
- **Never cache across users on the client.** Key every client-cache entry by user
  id so account switching can't leak data.
- **Cache reads are fail-safe.** A stale, unversioned, or unparseable entry is
  **evicted, never deserialized into the app** — on any doubt, drop it and fetch
  fresh. A cache must never be a crash source (see §3.3.1, given Jobdun's
  schema-drift history).
- **Version the cache; purge on bump.** Every entry/namespace carries a
  `schemaVersion`; a mismatch drops the namespace on launch *before* any read.
- **Encrypt at rest.** The local store is encrypted; the key lives in platform
  secure storage (`flutter_secure_storage`), never in the app bundle.
- **Offline is read-only by design.** Writes (apply, shortlist, send) require
  connectivity in this design. An offline-write / outbox layer is explicitly out
  of scope and, if ever needed, is a separately-designed effort — not a quiet
  addition to Layer 1.
- **RLS still applies.** Server-side caching (Layer 2) must respect Row Level
  Security — cache only non-user-specific or already-authorised results, and run
  `supabase db advisors` + an RLS review before committing any migration (per the
  Supabase skill).
- **Measure, don't guess.** Phase 4 (real Redis) only proceeds if dashboard query
  counts / latency show it's needed.
