# Observability & Ops Audit — Jobdun Backend

**Auditor:** observability-ops-auditor
**Scope:** Crash/error reporting (Sentry in Flutter — SDK, DSN, release tagging, source maps/debug symbols, user context, breadcrumbs, performance tracing); Edge Function structured logging (none exist); structured logging schema; alert thresholds & routing; metrics dashboard / SQL views; solo-engineer on-call runbooks (auth down, verification backlog, mass message-send failure, suspected breach → Notifiable Data Breaches scheme); public status page; backup restore testing/documentation; feature-flag infrastructure for risky launches; App Store / Play Store deployment process.
**Files reviewed:**
- `pubspec.yaml` (lines 30–121 — full dependency tree)
- `lib/main.dart` (whole file — bootstrap path)
- `lib/core/config/supabase_config.dart` (referenced — init path)
- `lib/core/services/ftue_analytics.dart` (whole file)
- `lib/core/services/auth_analytics.dart` (whole file)
- `lib/core/services/profile_analytics.dart` (referenced)
- `.github/workflows/ci.yml` (whole file)
- `.github/workflows/` (directory listing — only `ci.yml` present; **no `cd.yml`**)
- `scripts/validate.sh`, `scripts/install-hooks.sh` (directory listing)
- `docs/` and `docs/audit/` (directory listings — **no `docs/runbooks/`**)
- `supabase/functions/` (does not exist — **0 Edge Functions**)
- `grep -rli "sentry|posthog|crashlytics|firebase_crash|datadog|logging|logger|analytics" lib/` (only the no-op `*_analytics.dart` debugPrint shims)
- `find … -iname "*fastlane*" -o -iname "Fastfile"` (0 hits)

**Date:** 2026-05-16

---

## Summary

| Severity | Count |
|---|---|
| **P0** | 3 |
| **P1** | 5 |
| **P2** | 4 |
| **P3** | 2 |

**Overall posture: RED.**

Jobdun's backend is **observability-blind and ops-undocumented**. There is no crash/error reporting (no Sentry, no Crashlytics, no any error SDK), no structured logging, no metrics view, no alerting, no on-call runbook, no tested backup/restore, no feature-flag kill switch, and no documented store-release process. The analytics shims (`FtueAnalytics`, `AuthAnalytics`, `ProfileAnalytics`) are deliberate no-ops (`debugPrint` in debug, nothing in release) with `TODO(analytics): forward to PostHog once the SDK is wired`. At 25,000 AU accounts with a single on-call engineer on Supabase Pro, a production incident today is **invisible until a user complains**, and a data breach has **no assessment/notification process** despite the Privacy Act 1988 Notifiable Data Breaches scheme imposing a hard 30-day clock. This is the lowest-maturity domain in the audit and must be closed before any real user load.

### Direct answers to the brief

| # | Question | Answer |
|---|---|---|
| 1 | Sentry in pubspec + initialised in `main.dart` w/ env + release tag? | **NO.** No `sentry_flutter` (or any error SDK) in `pubspec.yaml`. `main.dart` has no error/zone guard, no `runZonedGuarded`, no `FlutterError.onError` override. |
| 2 | Edge Functions structured JSON logs? | **N/A — MISSING.** `supabase/functions/` does not exist. Zero Edge Functions, therefore zero edge logging. |
| 3 | ANY metrics dashboard / SQL view? | **NO.** Only the `profile_completeness` view exists (product, not ops). No DAU/jobs-per-day/queue-depth/p95 view; no Grafana/Metabase/dashboard config in repo. |
| 4 | On-call runbook in repo? | **NO.** `docs/runbooks/` does not exist. No incident/auth-down/breach playbook anywhere in `docs/`. |
| 5 | DB restore tested / documented? | **NO.** No restore doc, no PITR test record, no backup policy. Supabase Pro provides daily backups + PITR but **an untested backup is not a backup**. |
| 6 | `feature_flags` table or PostHog flags for risky launches? | **NO.** No `feature_flags` table in the 17 migrations, no remote-config, no PostHog SDK. Risky launches (e.g. geo personalisation, social auth) ship with no kill switch. |
| 7 | App/Play Store deploy process documented (Fastlane/manual)? | **NO.** No Fastlane (`find` → 0 hits), no `cd.yml` (scope & CLAUDE.md claim one exists — **it does not**), no `fastlane/`, no documented manual release steps. |

---

## Findings

### F-OPS-01 — No crash / error reporting SDK anywhere in the app
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** `pubspec.yaml` lines 30–121 — no `sentry_flutter`, `sentry_dart_plugin`, `firebase_crashlytics`, `bugsnag`, or equivalent. `lib/main.dart` (whole file) — `main()` does `dotenv.load` → `SupabaseConfig.initialize()` → `runApp()` with **no `runZonedGuarded`, no `FlutterError.onError`, no `PlatformDispatcher.instance.onError`**. `grep -rli sentry|crashlytics lib/` → 0 production hits.
- **Why it matters at 25k AU users:** With 5,000 MAU on rural-AU 3G and a solo engineer, an unhandled exception (null deref in the jobs feed, a Supabase 500 in the apply flow, an OOM on a low-end Android) is **completely invisible**. You learn about it from a 1-star review or a support DM, days later, with no stack trace, no device/OS breakdown, no affected-user count, and no way to know if it's 1 user or 5,000. Crash-free rate cannot be measured, so the "crash-free < 99%" alert in the brief is impossible to even define. This is the single highest-leverage gap in the entire backend audit.
- **Fix (concrete):**
  - `pubspec.yaml`:
    ```yaml
    dependencies:
      sentry_flutter: ^8.10.0
    dev_dependencies:
      sentry_dart_plugin: ^2.4.1   # uploads debug symbols / source maps on release build
    ```
  - `lib/main.dart` — wrap bootstrap:
    ```dart
    import 'package:sentry_flutter/sentry_flutter.dart';

    Future<void> main() async {
      await SentryFlutter.init(
        (o) {
          o.dsn = dotenv.env['SENTRY_DSN'] ?? '';
          o.environment = const String.fromEnvironment('ENV', defaultValue: 'production');
          o.release = 'jobdun@1.0.0+1'; // wire to package_info_plus at build time
          o.tracesSampleRate = 0.2;          // perf: 20% of txns
          o.profilesSampleRate = 0.2;
          o.attachScreenshot = false;        // privacy: docs/IDs in private-docs
          o.sendDefaultPii = false;          // Privacy Act 1988 — no PII by default
          o.enableAutoSessionTracking = true; // gives crash-free sessions metric
        },
        appRunner: () => runZonedGuarded(() {
          WidgetsFlutterBinding.ensureInitialized();
          // dotenv must load before reading SENTRY_DSN — see note below
          runApp(ProviderScope(/* … existing … */));
        }, (e, s) => Sentry.captureException(e, stackTrace: s)),
      );
    }
    ```
    > Ordering caveat: `dotenv.load()` must run *before* `SentryFlutter.init` reads the DSN. Either inject `SENTRY_DSN` via `--dart-define` (preferred — keeps it out of the `.env` asset bundled into the APK) or `await dotenv.load()` before `SentryFlutter.init`.
  - Add `pubspec.yaml` plugin block for symbol upload:
    ```yaml
    sentry:
      upload_debug_symbols: true
      upload_source_maps: true
      project: jobdun
      org: <your-sentry-org>
    ```
  - Add `SENTRY_DSN` to GitHub Secrets and to the `.env`/`--dart-define` matrix.
- **Effort:** S
- **Phase:** 0
- **Layman's:** The app has no smoke detector — if it crashes for users, nobody is told.

---

### F-OPS-02 — No on-call runbooks for the solo AU engineer (incl. no Notifiable Data Breach process)
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** `docs/runbooks/` does not exist (`ls` → "No such file or directory"). `grep -rli "breach|incident|on-call|runbook|recovery" docs/` matches only audit files, never an operational playbook. No reference anywhere to the OAIC / Notifiable Data Breaches (NDB) scheme.
- **Why it matters at 25k AU users:** Jobdun holds licence documents, contact details and location data for AU tradies — clearly "personal information" under the Privacy Act 1988, and licence/ID docs are arguably sensitive. The NDB scheme requires: assess a suspected eligible data breach **within 30 days**, and if confirmed, **notify the OAIC and affected individuals as soon as practicable**. With one engineer and no playbook, at 3am during an auth outage or after a leaked signed URL, decisions are improvised under stress — exactly when legal exposure is highest. "Auth down", "verification backlog", and "mass message-send failure" similarly have no triage steps, so MTTR is unbounded.
- **Fix (concrete):** Create `docs/runbooks/` with the four templates below (full markdown provided in **Cross-cutting recommendations §A–D**): `00_oncall_index.md`, `auth_down.md`, `verification_backlog.md`, `message_send_failure.md`, `suspected_data_breach.md`. The breach runbook must encode the 30-day assessment clock, OAIC notification path (`https://www.oaic.gov.au/privacy/notifiable-data-breaches`), and an affected-user comms template.
- **Effort:** M
- **Phase:** 0
- **Layman's:** When something goes badly wrong, the one engineer has no checklist — including for a legally-mandated 30-day breach-notification deadline.

---

### F-OPS-03 — Backup/restore never tested or documented (recovery is unproven)
- **Severity:** P0
- **Status:** RISKY
- **Evidence:** No restore/backup/PITR/disaster-recovery document in `docs/` (grep matches only audit files). No `supabase db dump` schedule, no restore-drill log. Supabase Pro provides daily backups + PITR, but nothing in the repo proves a restore has ever succeeded or records RTO/RPO targets.
- **Why it matters at 25k AU users:** A bad migration, an accidental `DELETE` without a `WHERE`, or table corruption at 50k applications / 200k messages is a business-ending event if restore fails. Supabase PITR is a *capability*, not a *guarantee* — schema-only-vs-full, RLS/role re-creation, storage-object orphaning, and time-to-restore are all unknowns until rehearsed. RPO/RTO are undefined, so you can't even tell the business how much data a failure would cost.
- **Fix (concrete):** Add `docs/runbooks/db_restore.md` (template in §E). Perform one restore drill to a scratch Supabase project: PITR to T-1h, verify row counts on `profiles`/`jobs`/`applications`/`messages`, verify RLS policies + `custom_access_token` hook survive, verify `private-docs` objects resolve. Record actual RTO and set RPO target (Supabase Pro PITR ≈ 2-min granularity). Re-drill quarterly (cron in §F).
- **Effort:** M
- **Phase:** 0
- **Layman's:** There's a backup button but nobody has ever pressed restore — so we don't actually know it works.

---

### F-OPS-04 — No metrics dashboard or ops SQL views (DAU, jobs/day, queue depth, p95 all unmeasurable)
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** 17 migrations; only the `profile_completeness` view exists (product feature, `supabase/migrations/20260514000001_profile_completeness.sql`). No ops view (`v_ops_*`), no Metabase/Grafana/dashboard config, no scheduled metric snapshot. `fl_chart` is in `pubspec.yaml` but only for in-app earnings UI, not ops.
- **Why it matters at 25k AU users:** The brief asks for DAU, jobs/day, applications/day, message success, verification queue depth and p95 — none of these are computable today without ad-hoc SQL the on-call engineer writes from memory mid-incident. You cannot detect a slow regression (e.g. signups quietly halving after an auth change) without a baseline trend.
- **Fix (concrete):** Ship the `v_ops_daily` + `v_ops_verification_queue` + `v_ops_realtime_health` views in **Cross-cutting §G** (single migration `20260516000001_ops_metrics_views.sql`). Point a free Metabase (or Supabase dashboard SQL snippets) at them. p95 query latency comes from `pg_stat_statements` (enable in Supabase dashboard) — query template included in §G.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Nobody can answer "how many people used the app today and is it healthy?" without writing SQL by hand.

---

### F-OPS-05 — No alerting: no thresholds, no routing, no paging
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** No alert config in repo (no `alerts.yml`, no Supabase alert config exportable from repo, no Sentry — so no crash/issue alerts possible per F-OPS-01). Brief-specified thresholds (auth-failure spike >5×, verification queue age >48h, message send failure >1%, DB CPU >70%/5min, p95 query >500ms hot paths, Edge p95 >2s, crash-free <99%) have no implementation.
- **Why it matters at 25k AU users:** Detection is currently "a user emails Ken". For a solo on-call, the only sustainable model is *push alerts on a small number of high-signal thresholds*. Without them, a 5× auth-failure spike (credential-stuffing or a broken JWT hook deploy) runs for hours unnoticed.
- **Fix (concrete):** After F-OPS-01, configure in Sentry: crash-free-sessions < 99% → alert; issue spike rule on `auth.*` exceptions. In Supabase dashboard → Reports/Alerts: DB CPU > 70% 5-min, disk > 80%. For the data-derived thresholds (queue age >48h, message-send failure >1%) add a `pg_cron` job that queries the §G views and posts to a webhook — config in **Cross-cutting §H**. Route everything to one channel (Discord/Slack webhook + email) that pages the solo engineer. Full threshold→action table in §H.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Even if a metric goes bad, no alarm rings — there are no alarms configured.

---

### F-OPS-06 — Analytics layer is a permanent no-op (zero product/funnel telemetry in production)
- **Severity:** P1
- **Status:** BROKEN
- **Evidence:** `lib/core/services/ftue_analytics.dart` lines ~60–66 — `_emit` does `if (kDebugMode) debugPrint(...)` then `// TODO(analytics): forward to PostHog once the SDK is wired into main().` Same pattern in `auth_analytics.dart` and `profile_analytics.dart`. No PostHog/Segment/Amplitude/Firebase-Analytics SDK in `pubspec.yaml`.
- **Why it matters at 25k AU users:** Significant engineering effort was spent instrumenting funnels (FTUE, auth, profile, geo-personalisation A/B variant) but **every event is discarded in release builds**. Decisions like "is the geo personalisation wow actually lifting signup?" or "did the missing-signup-link fix recover referral signups?" — the explicit rationale in `auth_analytics.dart` — are unanswerable. This also means there is no behavioural signal to corroborate an ops incident (e.g. signup conversion cratering).
- **Fix (concrete):** Add `posthog_flutter: ^4.7.0` to `pubspec.yaml`; init in `main()` after `dotenv.load`; replace the body of each `_emit` with `Posthog().capture(eventName: event, properties: props)`. Keep PII out of `props` (Privacy Act 1988). PostHog also unlocks F-OPS-08 (feature flags) and self-serve funnel dashboards (partially covers F-OPS-04 for product metrics).
- **Effort:** S
- **Phase:** 1
- **Layman's:** All the usage-tracking code that was written is throwing every event in the bin.

---

### F-OPS-07 — No structured logging schema (Dart side is `debugPrint`, no correlation IDs)
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** No `logging`/`logger` package in `pubspec.yaml`. Only diagnostic output is `debugPrint` inside the analytics shims (`kDebugMode`-gated, release no-op). No request/correlation ID, no severity levels, no JSON log shape. Edge Function logs are N/A (no Edge Functions exist — `supabase/functions/` absent).
- **Why it matters at 25k AU users:** When Sentry shows an exception, there's no breadcrumb trail or correlation ID to tie it to a Supabase Postgres log line or a specific user action. Debugging a rural-3G timeout vs an RLS denial vs a server 500 becomes guesswork.
- **Fix (concrete):** Adopt a thin structured logger (`logging: ^1.3.0`) emitting JSON `{ts, level, event, userId?(hashed), correlationId, ctx}`; pipe `WARNING+` into Sentry breadcrumbs (`Sentry.addBreadcrumb`). Define the canonical schema in `docs/runbooks/logging_schema.md` (skeleton in §I). When Edge Functions are eventually built (per edge-functions-auditor), reuse the same JSON shape with `console.log(JSON.stringify({...}))` so logs are queryable.
- **Effort:** S
- **Phase:** 2
- **Layman's:** There's no consistent log format, so tracing one user's bad experience across the system is hard.

---

### F-OPS-08 — No feature-flag / kill-switch infrastructure for risky launches
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** No `feature_flags` table in the 17 migrations; no remote-config; no PostHog (so no PostHog flags). Risky recently-shipped features (IP-geo personalisation `ftue_geo_provider.dart`, social auth, portfolio array RPCs) have no remote disable.
- **Why it matters at 25k AU users:** If the geo personalisation calls a third-party IP API that goes down or starts returning garbage, or social auth breaks after a provider change, the only mitigation is a full app-store release cycle (days, especially iOS review). A flag turns a P0 into a 1-minute config toggle.
- **Fix (concrete):** Cheapest path: use PostHog feature flags (free, comes with F-OPS-06). Alternatively a `feature_flags` table:
  ```sql
  -- migration 20260516000002_feature_flags.sql
  create table public.feature_flags (
    key text primary key,
    enabled boolean not null default false,
    rollout_pct int not null default 0 check (rollout_pct between 0 and 100),
    updated_at timestamptz not null default now()
  );
  alter table public.feature_flags enable row level security;
  create policy ff_read on public.feature_flags for select to authenticated using (true);
  -- writes: dashboard / service-role only (no client policy)
  ```
  Gate geo-personalisation and social-auth entry behind `ff('geo_wow')` / `ff('social_auth')`.
- **Effort:** S
- **Phase:** 2
- **Layman's:** If a new feature misbehaves, there's no off-switch short of shipping a new app version.

---

### F-OPS-09 — No store-release pipeline or documented deploy process; `cd.yml` referenced but absent
- **Severity:** P2
- **Status:** BROKEN
- **Evidence:** `.github/workflows/` contains **only `ci.yml`** (analyze + `flutter test test/features/`). `cd.yml` does **not** exist, yet `CLAUDE.md` ("CD | `.github/workflows/cd.yml` | Push to `main`") and `00_SCOPE.md` line 41 both assert it does — documentation/repo drift. No Fastlane (`find … Fastfile` → 0 hits), no `fastlane/`, no documented manual App Store / Play Store steps, no signing-key handling doc.
- **Why it matters at 25k AU users:** Releases (including the urgent hotfix you'll need the first time F-OPS-01 surfaces a P0 crash) are an undocumented manual ritual in one person's head. If Ken is unavailable, nobody can ship a fix. The doc-vs-reality drift also means CLAUDE.md cannot be trusted as ops ground truth.
- **Fix (concrete):** (1) Correct `CLAUDE.md` + `00_SCOPE.md` to state CD does not exist. (2) Add `docs/runbooks/release.md` documenting the manual `flutter build appbundle` / `flutter build ipa`, signing config location, store-listing checklist, and rollback (store phased release / halt rollout). (3) Optional Phase-3: Fastlane `Fastfile` with `supply` (Play) and `deliver` (App Store) lanes + `match` for signing.
- **Effort:** M
- **Phase:** 2
- **Layman's:** Nobody has written down how to actually publish the app, and the docs claim an automation that doesn't exist.

---

### F-OPS-10 — No public/internal status page
- **Severity:** P3
- **Status:** MISSING
- **Evidence:** No status-page config/repo (`statuspage`, `upptime`, `cstate`) anywhere; no health endpoint (no Edge Functions to host one).
- **Why it matters at 25k AU users:** During an outage, support volume spikes and the solo engineer fields duplicate "is it down?" messages instead of fixing it. A status page deflects load and signals professionalism to builders deciding whether to trust the platform with hiring.
- **Fix (concrete):** Phase-3: free [Upptime](https://upptime.js.org/) (GitHub-Actions-based) pinging the Supabase REST health URL + app store links, or a hosted Better Uptime free tier. Link it from the app's error/empty states.
- **Effort:** S
- **Phase:** 3
- **Layman's:** When the app is down there's no page telling users "we know, we're on it".

---

### F-OPS-11 — Unencrypted secrets in repo working tree (local-disk / accidental-share exposure)
- **Severity:** P3
- **Status:** RISKY
- **Evidence:** Per `00_SCOPE.md` §3 (pre-verified): `.env` plus three `client_secret_*.json` / `client_*.plist` Google OAuth files sit unencrypted in the repo root. Git-ignored and **not tracked** (`git ls-files` clean), so this is *not* a git-history leak. Confirmed in scope as flag-at-auditor-discretion for observability-ops. Also relevant: `pubspec.yaml` line 134 bundles `.env` as a Flutter **asset** — meaning anything in `.env` is shipped inside the APK/IPA and trivially extractable.
- **Why it matters at 25k AU users:** Two distinct risks. (a) Local: laptop loss/theft or an accidental `zip -r project` shared with a contractor leaks the Google OAuth client secret with no rotation runbook. (b) Bundling `.env` as an asset means the **Sentry DSN, Supabase anon key, and any other `.env` value are extractable from the shipped app** — the Supabase anon key is designed to be public (RLS-gated) so that's acceptable, but a Sentry DSN there enables event spoofing, and any future secret in `.env` would be fully exposed.
- **Fix (concrete):** (1) Add a "secret rotation" section to `docs/runbooks/suspected_data_breach.md` (Google OAuth client, Supabase keys, Sentry DSN). (2) Prefer `--dart-define` over the bundled `.env` asset for anything sensitive; keep only non-secret runtime config in the bundled `.env`. (3) Recommend full-disk encryption (FileVault) on the dev machine — note in `00_oncall_index.md`.
- **Effort:** XS
- **Phase:** 2
- **Layman's:** The app's secrets sit in plain files on the laptop and some get baked into the shipped app.

---

### F-OPS-12 — CI does not build a release artifact or run the full test suite
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `.github/workflows/ci.yml` runs `flutter analyze --no-fatal-infos` and `flutter test test/features/` only — no `flutter build`, no `dart format --set-exit-if-changed`, and tests scoped to `test/features/` (skips `test/` root tests). `scripts/validate.sh` (the local pre-push hook) is more thorough than CI.
- **Why it matters at 25k AU users:** A change that breaks the release build (e.g. an iOS plugin conflict after adding `sentry_flutter`) passes CI and is only caught when Ken manually builds to ship — exactly when speed matters during an incident. Format drift also isn't enforced server-side.
- **Fix (concrete):** Add to `ci.yml`: `dart format --output=none --set-exit-if-changed .` and a `flutter build apk --debug --no-pub` job; broaden test to `flutter test` (all). This mirrors `scripts/validate.sh FULL=1`.
- **Effort:** XS
- **Phase:** 2
- **Layman's:** CI checks the code lints and some tests pass, but never confirms the app still builds.

---

## Cross-cutting recommendations

Concrete artifacts to create. All runbooks go in a new `docs/runbooks/` directory.

### §A — `docs/runbooks/00_oncall_index.md` (template)
```markdown
# Jobdun On-Call Index (Solo Engineer)

**On-call:** Ken Garcia | **TZ:** Australia | **Backend:** Supabase Pro (ref `zethpanvkfyijislxesn`, Postgres 17.6)
**Paging channel:** <Discord/Slack webhook> + email
**Dashboards:** <Metabase URL> · Sentry: <org/jobdun> · Supabase: dashboard → Reports

## Severity ladder
- **SEV1** prod down / data loss / suspected breach → drop everything, see specific runbook
- **SEV2** degraded (slow, partial) → triage within 1h
- **SEV3** minor / cosmetic → next business day

## Runbooks
| Symptom | Runbook |
|---|---|
| Logins failing / spike in auth errors | `auth_down.md` |
| Verification queue not clearing | `verification_backlog.md` |
| Messages not sending for many users | `message_send_failure.md` |
| Suspected data breach / leaked docs | `suspected_data_breach.md` (NDB 30-day clock) |
| DB restore needed | `db_restore.md` |
| Shipping a release / hotfix | `release.md` |

## First 5 minutes of ANY incident
1. Check Sentry issue stream + Supabase dashboard (DB CPU, connections, errors).
2. Run the `v_ops_realtime_health` view (§G) — is it data-wide or one user?
3. Post "investigating <symptom>" to status page (`F-OPS-10`) + paging channel.
4. Note start time (for RTO + any NDB clock).
5. Open the matching runbook.

## Secret rotation quick-ref
Google OAuth client · Supabase anon/JWT · Sentry DSN — see `suspected_data_breach.md §Rotation`.
Dev machine: FileVault MUST be on (secrets live unencrypted in repo root — F-OPS-11).
```

### §B — `docs/runbooks/auth_down.md` (template)
```markdown
# Runbook: Auth Down / Auth-Failure Spike  (SEV1)
**Trigger:** Sentry `auth.*` exception spike >5× 1h baseline, OR users report can't log in.

## Triage
1. Supabase dashboard → Auth → Logs. Pattern? (rate-limited / provider error / JWT hook error)
2. Did `custom_access_token` hook change recently? `supabase/migrations/*token_hook*`. A broken
   JWT hook blocks ALL logins — highest-probability self-inflicted cause.
3. Google/Apple SSO only, or email/password too? SSO-only → provider/credential issue (F-OPS-11
   rotation may be implicated). All → Supabase Auth or JWT hook.
4. Check DB CPU/connections (a saturated DB fails token issuance).

## Mitigate
- Broken JWT hook → revert hook via dashboard SQL to last-good `custom_access_token` body.
- SSO creds invalid → rotate (see suspected_data_breach.md §Rotation), redeploy config.
- Rate-limited → raise Supabase auth rate limits (dashboard) if legit traffic.

## Verify & close
- New test account can sign up + log in (email + each SSO).
- Sentry auth error rate back to baseline.
- Record cause + RTO in incident log.
```

### §C — `docs/runbooks/verification_backlog.md` (template)
```markdown
# Runbook: Verification Backlog  (SEV2)
**Trigger:** `v_ops_verification_queue.oldest_pending_hours > 48`.
Context: there is NO admin Edge Function — verification approval is manual via the
separate admin web app. This runbook is about *detecting & clearing*, not automating.

## Triage
1. `select * from v_ops_verification_queue;` — depth + oldest age.
2. Is it a volume spike (marketing push) or a process stall (admin not reviewing)?

## Mitigate
- Process stall → review the queue in the admin web app now; prioritise oldest.
- Volume spike → batch-review; consider temporary auto-acknowledge messaging to users
  so trades aren't blocked from applying while waiting.

## Prevent
- Add the >48h alert (F-OPS-05 / §H). Long-term: `admin-approve-verification` Edge
  Function with audit log (see edge-functions-auditor).
```

### §D — `docs/runbooks/message_send_failure.md` (template)
```markdown
# Runbook: Mass Message-Send Failure  (SEV1)
**Trigger:** message send failure rate >1% (Sentry messaging exceptions / user reports).

## Triage
1. RLS denial vs server error vs realtime? Sentry breadcrumb + Supabase Postgres logs
   filtered to `messages`/`conversations`.
2. Did a migration touch `messages`/RLS/`update_conversation_last_message` trigger?
3. DB CPU / connection pool saturated? (200k+ messages — check slow queries via
   pg_stat_statements, §G).

## Mitigate
- RLS regression → revert offending policy migration.
- Trigger error → disable/fix `update_conversation_last_message`.
- DB saturation → kill long-running queries; scale compute (Supabase Pro).

## Verify & close
- Two test users exchange messages successfully; failure rate < 1%; record RTO.
```

### §E — `docs/runbooks/db_restore.md` (template, satisfies F-OPS-03)
```markdown
# Runbook: Database Restore  (SEV1)  — RPO target: ≤2 min · RTO target: <set after first drill>

## When
Data corruption, accidental destructive SQL, failed migration with data loss.

## Procedure (Supabase Pro PITR)
1. STOP writes — put app in maintenance (feature flag `kill_switch`, F-OPS-08) / disable client keys.
2. Supabase dashboard → Database → Backups → Point in Time → choose timestamp just
   BEFORE the bad event.
3. Restore to a NEW project first if unsure (non-destructive validation).
4. Validate on restored DB:
   - Row counts: profiles / jobs / applications / messages vs expected.
   - RLS policies present (`select * from pg_policies;`).
   - `custom_access_token` hook + `handle_new_user` trigger present & correct.
   - `private-docs` storage objects resolve (signed URL test).
5. Cut over; re-enable writes; announce on status page.
6. Record actual RTO; post-incident review.

## Quarterly drill (REQUIRED — an untested backup is not a backup)
Restore latest PITR to scratch project, run step-4 checks, log result + RTO here.
Automated reminder: pg_cron / GitHub Action (see §F).
```

### §F — pg_cron reminders + data-derived alerts
```sql
-- migration 20260516000003_ops_cron.sql  (requires pg_cron extension — enable in dashboard)
-- Quarterly restore-drill reminder (writes a notification row the engineer sees)
select cron.schedule('restore-drill-reminder','0 0 1 */3 *', $$
  insert into public.notifications(user_id, type, title, body)
  select id, 'ops', 'Quarterly DB restore drill due',
         'Run docs/runbooks/db_restore.md quarterly drill.'
  from public.profiles where /* admin/owner predicate */ true limit 1;
$$);
```

### §G — Ops metrics views (satisfies F-OPS-04)
```sql
-- migration 20260516000001_ops_metrics_views.sql
create or replace view public.v_ops_daily as
select
  d::date as day,
  (select count(*) from public.profiles  p where p.created_at::date = d::date) as new_accounts,
  (select count(*) from public.jobs      j where j.created_at::date = d::date) as jobs_created,
  (select count(*) from public.applications a where a.created_at::date = d::date) as applications_created,
  (select count(*) from public.messages  m where m.created_at::date = d::date) as messages_sent,
  (select count(distinct sender_id) from public.messages m where m.created_at::date = d::date) as dau_msg
from generate_series(now() - interval '30 days', now(), interval '1 day') d;

create or replace view public.v_ops_verification_queue as
select
  count(*) filter (where status = 'pending')                                   as pending_count,
  coalesce(extract(epoch from now() - min(created_at)
           filter (where status = 'pending'))/3600, 0)                          as oldest_pending_hours
from public.verification_documents;

create or replace view public.v_ops_realtime_health as
select
  (select count(*) from public.messages where created_at > now() - interval '5 min')      as msgs_last_5m,
  (select count(*) from public.applications where created_at > now() - interval '1 hour')  as apps_last_1h,
  (select count(*) from public.profiles where created_at > now() - interval '1 hour')      as signups_last_1h;

-- p95 hot-path latency (enable pg_stat_statements in Supabase dashboard first):
-- select query, calls, mean_exec_time,
--        (total_exec_time / nullif(calls,0)) as avg_ms
-- from pg_stat_statements order by mean_exec_time desc limit 20;
```
> RLS: these views aggregate across all rows — restrict to a dashboard/service-role connection only; do **not** grant to `authenticated`. (Use `security_invoker=off` deliberately here, queried via service role from Metabase — never exposed to the mobile client.)

### §H — Alert thresholds & routing (satisfies F-OPS-05)
| Metric | Threshold | Source | Action / Route |
|---|---|---|---|
| Crash-free sessions | < 99% | Sentry | Sentry alert → paging channel (SEV1) |
| Auth-failure spike | > 5× 1h baseline | Sentry issue rule on `auth.*` | paging channel (SEV1) → `auth_down.md` |
| Verification queue age | > 48h | pg_cron on `v_ops_verification_queue` → webhook | paging channel (SEV2) → `verification_backlog.md` |
| Message send failure | > 1% | Sentry messaging issue rate | paging channel (SEV1) → `message_send_failure.md` |
| DB CPU | > 70% for 5 min | Supabase dashboard alerts | paging channel (SEV2) |
| DB disk | > 80% | Supabase dashboard alerts | paging channel (SEV2) |
| p95 hot query | > 500ms | pg_stat_statements weekly review | backlog ticket (SEV3) |
| Edge p95 | > 2s | N/A — no Edge Functions yet | revisit when edge functions ship |
```sql
-- pg_cron data-derived alert (post to webhook via pg_net / http extension)
select cron.schedule('verif-queue-alert','*/30 * * * *', $$
  select net.http_post(
    url := '<PAGING_WEBHOOK_URL>',
    body := json_build_object('text',
      'ALERT verification queue oldest pending hours=' || oldest_pending_hours)::jsonb)
  from public.v_ops_verification_queue where oldest_pending_hours > 48;
$$);
```

### §I — `docs/runbooks/logging_schema.md` (skeleton, satisfies F-OPS-07)
```markdown
# Jobdun Structured Log Schema
Every log line is one JSON object:
{ "ts": ISO8601, "level": "DEBUG|INFO|WARNING|ERROR",
  "event": "domain.action",         // e.g. "auth.login_failed"
  "userId": "<sha256(uid)>|null",   // hashed — Privacy Act 1988, never raw PII
  "correlationId": "<uuid per user action>",
  "ctx": { ...non-PII key/values } }

Rules: WARNING+ → Sentry breadcrumb; ERROR → Sentry.captureException.
No emails/phones/licence numbers/coords in `ctx`. Reuse identical shape in
future Edge Functions: console.log(JSON.stringify({...})).
```

### §J — Sequencing for the solo engineer (do not boil the ocean)
- **Phase 0 (this week, P0s):** F-OPS-01 (Sentry, ~½ day), F-OPS-02 (runbooks §A–E, ~1 day), F-OPS-03 (one restore drill, ~½ day).
- **Phase 1 (pre-load, P1s):** F-OPS-04 (views §G), F-OPS-05 (alerts §H), F-OPS-06 (PostHog).
- **Phase 2 (tech debt):** F-OPS-07, F-OPS-08, F-OPS-09, F-OPS-11, F-OPS-12.
- **Phase 3 (polish):** F-OPS-10 status page.

---

## Open questions for Ken

1. **Sentry vs alternative?** Recommendation is `sentry_flutter` (best Flutter crash + perf + release tracking). Confirm, or do you already have a Sentry/Crashlytics org? **NEEDS HUMAN INPUT.**
2. **`cd.yml` discrepancy:** `CLAUDE.md` and `00_SCOPE.md` claim a CD workflow exists; the repo has only `ci.yml`. Was a CD workflow deleted, or was it never created? This determines whether F-OPS-09 is "fix drift" or "build from scratch".
3. **Supabase region** (also raised by storage-privacy-auditor): is the project in `ap-southeast-2` (Sydney)? Affects the breach runbook's cross-border disclosure section (APP 8). **NEEDS HUMAN INPUT.**
4. **Paging channel:** what should alerts route to for a solo on-call — Discord webhook, Slack, email, SMS (Twilio)? Drives §H wiring.
5. **PostHog vs other analytics:** the code's TODOs all say PostHog. Confirm PostHog (cheap, includes feature flags → also closes F-OPS-08) or another vendor.
6. **Acceptable RTO/RPO?** No targets defined. Proposed RPO ≤2 min (Supabase PITR), RTO TBD after first drill — what downtime is tolerable to the business?
7. **Store accounts:** do Apple Developer + Google Play Console accounts exist and who holds the signing keys? Required to write a complete `release.md`.
