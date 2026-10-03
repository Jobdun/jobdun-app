# Android Production Bug Audit and Test Plan

> **For agentic workers:** Use `superpowers:executing-plans` to execute this plan task by task. Track each checkbox and attach evidence. This request authorizes planning first; execution and fixes are separate stages. Do not commit or push unless asked.

**Goal:** Systematically discover, reproduce, and prioritize defects across every existing Jobdun Android feature, using the connected Samsung phone, Android emulators, automated tests, and backend checks.

**Architecture:** Combine source and configuration review with automated regression tests and real multi-account journeys. Verify persisted backend state as well as visible UI. Keep simulated screen tests, live integration tests, and release-device results clearly distinguished.

**Tech stack:** Flutter/Dart, Riverpod, GoRouter, Supabase Auth/Postgres/RLS/Storage/Realtime/Edge Functions, FCM, Android/ADB.

## Scope and current evidence

**Execution follow-up (2026-10-01):** The user subsequently authorized testing and fixes. Eight confirmed application findings have been remediated and signed build 1.0.3 (13) installed on the Samsung. Full local validation and the documented Android smoke/synthetic suites passed. This plan is **not fully complete**: paired-account, live backend authorization/write, auth-provider, push and resilience/performance coverage remains blocked or not run. See [the current report and feature coverage ledger](../../verification/2026-10-01-android-audit/report.md) for exact evidence, environment blockers and historical-versus-current build distinctions. Unchecked tasks below must not be treated as passed.

Plan prepared on 2026-10-01. This is a test strategy, not a claim that the app has passed an audit or that every possible bug can be found. Completion means documented coverage, reproducible findings, and explicit remaining risks.

- Observed branch: `feat/ui-refresh-figma-2026-08-28`; HEAD `271b45b`. The worktree contains substantial existing modified and untracked code, including apprenticeship changes. Test that exact working snapshot; a commit hash alone cannot identify it.
- `docs/ARCHITECTURE.md` contains older clean-worktree/main statements that disagree with observed state. Its September release notes are historical, not current release certification.
- Source package: `au.com.jobdun.app`. Android minimum SDK is `maxOf(flutter.minSdkVersion, 23)`; resolve the actual merged-manifest minimum/target before selecting oldest-device coverage.
- Release builds enable R8/resource shrinking and can fall back to debug signing if `android/key.properties` is absent. Verify the artifact certificate; do not assume a release filename proves correct signing.
- The connected Samsung is now authorized: model **SM_A266B**, Android **16 / API 36**. Read-only package inspection reports installed Jobdun **1.0.1 (7)**, minSdk **24**, targetSdk **36**. This differs from the later source/release notes, so installed-build and current-source results must be kept separate. One UI version and signing identity remain to be verified. No installation or phone-data changes were performed during planning.
- Existing `integration_test/` contains four files: `guest_browse_flow_test.dart`, `apprenticeship_live_browse_test.dart`, `apprenticeship_screens_test.dart`, and `apprentice_applicant_screen_test.dart`. The latter screen suites contain synthetic inputs/provider overrides and do not establish full live backend correctness.
- `scripts/validate.sh` runs formatting checks, architecture/design checks, analysis, and `flutter test`. Its current implementation does not collect coverage automatically or explicitly run device integration tests. `FULL=1` adds a debug APK build, not release certification.
- `scripts/capture_app_screenshots.sh` uses unqualified ADB calls, reuses an existing APK, and pre-grants notifications. Select the emulator explicitly, rebuild the intended APK, and test real permission prompts separately.
- `docs/CLAUDE_SKILLS.md`, referenced by project guidance, is absent. Use `CLAUDE.md` and installed skills for this run.

Primary references: `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/ANDROID_SCREENSHOTS.md`, `lib/app/router/app_router.dart`, `lib/app/router/router_redirect.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `scripts/validate.sh`, `supabase/schema.sql`, and `supabase/tests/`.

## Approach and boundaries

Recommended: automated baseline, then high-risk live journeys, then exhaustive feature and Android resilience coverage. A phone-only sweep is quick but misses authorization and concurrency defects. An automation-only sweep is repeatable but misses native permission dialogs, Samsung behavior, and release signing differences.

Use staging/local Supabase with production-equivalent schema and functions for writes, race conditions, failure injection, and destructive cases. Production-level means release-quality testing; it does not mean generating public test vacancies or contacting real users. Production smoke checks should be read-only until dedicated production test accounts and permitted actions are identified. Never send messages, OTPs, emails, push events, or reviews to unrelated users. Account deletion applies only to disposable QA accounts. Do not migrate, deploy, publish, clear the Samsung app's data, or uninstall its existing app as part of planning.

## Deliverables during execution

- `docs/verification/2026-10-01-android-audit/baseline.md`: source snapshot, toolchain, environment, artifact hashes/certificates, devices, and fixture IDs. If execution occurs later, use that day's dated folder consistently.
- `docs/verification/2026-10-01-android-audit/cases.csv`: one row per case and variant, with ID, feature, priority, role, preconditions, steps, expected result, environment, device/build, status, evidence, and bug ID.
- `docs/verification/2026-10-01-android-audit/bugs.md`: reproducible findings grouped by severity, including suspected findings separately.
- `docs/verification/2026-10-01-android-audit/report.md`: boss-ready counts, affected workflows, release blockers, coverage gaps, and recommended fix order.
- Redacted screenshots and short videos for failures; sanitized logs and test reports. Keep raw logs outside version control. Do not put credentials, access tokens, personal documents, or device serials in shared reports.

Status values: **Not run / Pass / Fail / Blocked / Not applicable**. A skipped or simulated check must never count as a live pass. Each matrix row below expands into separate results for its individual scenarios.

## Task 1: Establish the exact test target

- [ ] Record `git status --short`, `git rev-parse HEAD`, branch, relevant file hashes, `pubspec.yaml` version, lockfile, SDK versions, and build configuration. Preserve all existing changes.
- [ ] Identify whether the boss wants the currently installed/store build, the current worktree build, or both. Default to comparing both when available; label results independently.
- [ ] Confirm the Samsung USB debugging prompt, then inspect `adb devices -l`. Use an explicit device selector for every device command.
- [ ] Record Samsung model/OS/One UI, screen size, density, refresh rate, free storage, navigation mode, battery mode, and installed package version. Do not overwrite a store-signed installation with an incompatible debug build.
- [ ] Inspect environment identity without printing secret values. Confirm staging and production endpoints, required configuration presence, OAuth callbacks, Firebase package association, and observability configuration.
- [ ] Inventory every production route, modal, action, provider, repository operation, RPC, Edge Function, and corresponding test. Add unlisted functionality to the case sheet. Check debug-only routes are unavailable in release.

Read-only device commands after selecting the connected phone:

```bash
adb devices -l
adb -s "$QA_DEVICE_SERIAL" shell getprop ro.product.model
adb -s "$QA_DEVICE_SERIAL" shell getprop ro.build.version.release
adb -s "$QA_DEVICE_SERIAL" shell getprop ro.build.version.sdk
adb -s "$QA_DEVICE_SERIAL" shell dumpsys package au.com.jobdun.app
```

Set `QA_DEVICE_SERIAL` to the authorized serial from device discovery before these commands. Record only relevant package fields, not a full personal-device inventory.

## Task 2: Prepare accounts, data, and devices

- [ ] Prepare Builder A and Builder B, Trade A and Trade B, Apprentice A, and an unrelated User C. Include incomplete, complete, unverified, pending, approved, rejected, and expired verification states. Use distinct sessions/devices for concurrency.
- [ ] Prepare normal trade jobs, trade jobs accepting apprentices, and dedicated apprenticeships. Include each lifecycle state, no applicants, multiple applicants, missing optional values, and enough records to cross three feed pages.
- [ ] Prepare valid/invalid/oversized image and document files with known non-personal contents. Inventory actual file-size/type limits from implementation before setting boundary cases.
- [ ] Prepare bookings, quote requests, timesheets, review-eligible completed jobs, conversations, notification preferences, and expired links. Record creation and cleanup ownership.
- [ ] Confirm email/SMS/OAuth access for QA identities and permitted admin assistance for verification decisions. Mark unavailable services as blocked, not passed.
- [ ] Use the Samsung for native flows, release smoke tests, and performance. Use `jobdun_test` ARM64 emulator for repeatable screenshots, clean installs, resets, and destructive cases on this Apple Silicon host.
- [ ] Add emulator coverage at the resolved minimum supported API, Android 13 permission boundary if supported, and resolved target API. Add narrow-screen and large-font configurations. Record unavailable configurations as coverage gaps.

## Task 3: Run baseline automation and configuration review

- [ ] Run `bash scripts/validate.sh`; retain all failure output. Classify environment failures separately from product failures. Do not silently alter source or golden files to make the baseline pass.
- [ ] Run `flutter test --coverage` and map meaningful feature/branch coverage. Identify missing scenarios rather than using a percentage as proof of readiness.
- [ ] Run `FULL=1 bash scripts/validate.sh` when preparing device builds. Ensure the APK used later includes the intended environment configuration.
- [ ] Review and run each existing device suite on the designated emulator. Inspect fixture/environment requirements first; do not run them blindly on the user's installed Samsung app.
- [ ] Review `supabase/tests/guest_apprentice_browse.sql`, `public_apprentice_profile.sql`, `apprenticeship_deployment.sql`, and `application_hiring.sql`; run against the designated test database after confirming setup/rollback behavior.
- [ ] Review and run the `supabase/functions/jobs-feed/feed_test.ts` suite using the repository's Deno configuration. Record function version versus deployed version.
- [ ] Audit release configuration: merged permissions/components, signing certificate, package/version, callback routing, Firebase config, min/target SDK, native libraries, backup/extraction rules, cleartext/network settings, shrinking, and packaged secrets.

Example emulator integration invocation after setting `QA_EMULATOR_SERIAL` to the discovered emulator serial:

```bash
flutter test integration_test/guest_browse_flow_test.dart -d "$QA_EMULATOR_SERIAL" --dart-define-from-file=.env
flutter test integration_test/apprenticeship_live_browse_test.dart -d "$QA_EMULATOR_SERIAL" --dart-define-from-file=.env
flutter test integration_test/apprenticeship_screens_test.dart -d "$QA_EMULATOR_SERIAL"
flutter test integration_test/apprentice_applicant_screen_test.dart -d "$QA_EMULATOR_SERIAL"
```

The `.env` target must be checked before using these commands. Existing live tests may depend on particular fixtures. Fixture absence is a test precondition failure, not automatically an app defect.

## Task 4: Execute critical paired-user journeys first

- [ ] **J01, trade hiring:** Builder A creates/publishes a trade job; Trade A discovers it, opens details, quotes/applies; builder reviews, shortlists, and hires; trade observes the result, follows supported acceptance/start/completion actions, and eligible users review. Verify job/application state and actor permissions at every transition.
- [ ] **J02, apprenticeship:** Builder A creates a dedicated apprenticeship with positive hourly pay; Apprentice A finds it, applies with profile/resume, and appears correctly in applicant review. Verify no trade quote is demanded and the resume is visible only to permitted viewers.
- [ ] **J03, mixed eligibility:** Apprentice A applies to an ordinary trade job inviting apprentices; Trade A applies to a trade job with a quote. Verify eligibility restrictions and the distinction between an invitation and a dedicated apprenticeship across filters, cards, details, and application forms.
- [ ] **J04, competing hires:** Two builder sessions attempt to hire different applicants for one vacancy simultaneously in staging. Exactly one permitted hire succeeds; the losing session refreshes with a useful conflict result. Confirm rejected/withdrawn/declined cases cannot leave an impossible assignment and the documented hired-trade decline reopens the vacancy.
- [ ] **J05, communication:** Builder A and Trade A exchange messages and supported attachments; confirm notification delivery/routing, read state, reconnect recovery, and account switching without cross-account content.
- [ ] **J06, interruption:** Interrupt apply/post/upload/hire at the server-response boundary. Retry/relaunch and verify the operation is neither lost nor duplicated and visible state agrees with persisted state.

## Task 5: Complete the feature matrix

For every feature, test a happy path, invalid input, empty data, server error, timeout/offline recovery, cancellation/back navigation, persistence after relaunch, and wrong-role/wrong-owner access where applicable.

| IDs | Feature and source | Concrete cases | Expected outcome |
|---|---|---|---|
| F01 | `lib/features/ftue/` | Fresh install, all slides, skip/login/create-account/guest paths, interrupted onboarding, returning install | Correct entry and return destination; no loops or repeated onboarding after completion |
| F02 | `lib/features/auth/` | Builder/trade registration; required fields, invalid/duplicate email, password boundaries, terms; verify/resend/expired link; login/wrong password; reset/expired/reused reset; phone formatting, wrong/expired OTP and resend cooldown; Google cancellation/success; Apple if exposed on Android; revoked/expired session; sign out | One correct identity/profile; safe errors; callback handles cold/warm launch; denied/cancelled auth recovers; protected routes stay protected |
| F03 | `lib/features/home/` and router | Both roles' dashboard counts/actions, guest gate, tabs/back-stack, invalid/deleted IDs, cold/warm deep links, pending return after login, logged-out notification tap | Correct route and role-specific content; counts reconcile; no stale-account content or inaccessible dead ends |
| F04 | `lib/features/jobs/` browsing | Search, every filter and combinations, clear, sorting, pagination, refresh, saved/unsaved if exposed, map/list parity, no matches, removed job, location denied | Correct dataset and labels; no duplicates/missing pages; recoverable load failure; no private fields in guest results |
| F05 | `lib/features/jobs/` creation/lifecycle | Draft/create/edit/publish, required fields, whitespace, long text, rates at zero/negative/precision/large boundaries, dates, location, urgency, cancel/close/reopen where supported, double submit | Valid lifecycle only; persisted values match; one write per action; non-owner cannot mutate |
| F06 | Apprenticeships across jobs/profile/applications | Dedicated job kind versus invitation, positive finite hourly pay, profile completeness, optional stage/tickets, resume replacement, apprentice filter, public projections, legacy jobs | All surfaces agree; intended applicant form; optional fields do not block; old records still load |
| F07 | `lib/features/applications/` | Apply once/duplicate, quote/note validation, withdraw, shortlist/reject/accept, all tabs/counts, applicant detail/resume, vacancy closed during apply, competing updates | Legal role-gated transitions; server rejection never appears as success; no double hire or leaked applicant data |
| F08 | `lib/features/discovery/` | Trade/apprentice search, trade/suburb/radius/availability/verification filters, map clustering, recenter, denied/approximate location, public profiles | Search/list/map agree; empty and failure states work; private address/documents remain private |
| F09 | `lib/features/profile/` | Both role profiles, edit each available field/sheet, ABN/contact/location/rates/about, avatar/logo crop, portfolio add/remove/view, availability dates, apprentice switch/stage/tickets/resume, public versus owner view | Saves survive relaunch; cancel does not save; errors preserve input; completeness and public visibility follow rules |
| F10 | `lib/features/verification/` | Every offered document/credential type, camera/gallery/file picker/crop cancellation, invalid/large files, expiry boundaries, submit/pending/approved/rejected/re-upload | No picker/native crash; correct progress and retry; badges reflect real approval and expiry; documents stay private |
| F11 | `lib/features/messaging/` | New/existing thread, text/emoji/long input, attachment upload/view, retry, pagination/order, realtime after reconnect, unread/read, archive/mute/block/report if exposed | Single ordered messages; correct unread state; preferences persist; block/report semantics enforced; outsiders denied |
| F12 | `lib/features/notifications/` and profile preferences | In-app list/read/all-read, each event type, permission allow/deny/re-enable, foreground/background/terminated taps, preference opt-out, token refresh, logout/login | Correct recipient, one event, correct route; no notifications belonging to previous account; honest handling when OS blocks delivery |
| F13 | `lib/features/quotes/` | Request/receive/respond and every exposed terminal action, duplicate request, bad price/text, stale/unauthorized request, cross-device refresh | Only intended participants act; visible status and stored state agree; retries do not duplicate |
| F14 | `lib/features/scheduling/` | Create/respond/change/cancel as exposed, overlaps, midnight, past dates, local timezone versus Australian job timezone, DST boundary, refresh | Correct participants and dates; consistent conflict rules; no timezone shift or stale status |
| F15 | `lib/features/timesheets/` | Enter/edit/submit/approve/reject as exposed, zero/negative/long duration, overnight work, breaks, rounding, duplicate tap, other user's entry | Totals reconcile; only allowed actors change state; submitted/approved records respect locking rules |
| F16 | `lib/features/reviews/` | Eligible completed job review, rating boundaries, comment limits, duplicate/self/unrelated review, refresh aggregates | Eligibility enforced by backend; no duplicates; rating/count agree across profile and reviews |
| F17 | Settings, legal, account lifecycle | Theme and notification settings persistence, terms/privacy links, browser return, sign out, account deletion/re-auth/cancel/failure on disposable account | Settings persist; links load; session/cache removed correctly; deleted account cannot regain access |

Before scoring UI, read `design-system/jobdun/MASTER.md` and the relevant page override in `design-system/jobdun/pages/`. Resolve stale examples using current canonical tokens and `CLAUDE.md`; do not file intentional current design as a bug based on an obsolete snippet.

## Task 6: Android and Samsung resilience matrix

- [ ] **A01 install/update:** Fresh installation on emulator; upgrade from the prior signed build using a compatible certificate; offline first launch; retained session/cache/schema after update. Use an approved Play test build for Play-signing/OAuth behavior if available. Mark store distribution untested otherwise.
- [ ] **A02 native permissions:** Location precise/approximate/denied/permanently denied, notifications allow/deny, camera/media/document picker cancellation and limited access where supported. Revoke in Android settings mid-session and reopen. App remains usable with a clear recovery path.
- [ ] **A03 lifecycle:** Home/resume, lock/unlock, rotation where supported, split-screen if supported, process death and relaunch during each critical form/upload/auth callback. Differentiate ordinary background termination from Android force-stop behavior.
- [ ] **A04 Samsung interaction:** Samsung keyboard/autofill/password manager, OTP paste, keyboard hiding bottom buttons, gesture and three-button navigation, system Back, edge-to-edge insets/cutouts, photo picker and crop activity.
- [ ] **A05 connectivity:** Offline before launch and during every write; slow/drop/reconnect; Wi-Fi/mobile switch; server 401/403/429/500 and storage/realtime failures in controlled staging. No endless spinner, false success, data loss, duplicate write, or unbounded retry.
- [ ] **A06 power/storage:** Battery saver and Samsung background restrictions, delayed push and foreground recovery, low disk during cache/upload, large feed/thread/portfolio. Restore changed phone settings after testing; perform invasive conditions on emulator first.
- [ ] **A07 accessibility:** TalkBack labels/order/actions; 48dp targets; 4.5:1 normal-text and 3:1 large-text/control contrast; light/dark themes; large OS font/display settings including behavior beyond the app's scaler clamp; reduced motion; long names and validation messages. Record clipped or unreachable controls as functional defects.
- [ ] **A08 performance:** On Samsung profile mode, measure 10 cold and 10 warm launches, long-feed/map/thread scroll, attachment processing, memory across 20 navigation cycles, and a 30-minute paired-user session. Report median/p95 and device/network conditions; investigate repeatable stalls and sustained memory growth. Debug timing is not a release benchmark.
- [ ] **A09 release parity:** Repeat J01–J05 and auth/upload/push smoke tests on the signed, shrunk release build. Check Android native crashes, missing assets/fonts, callback/OAuth certificate differences, and absent debug routes.

## Task 7: Backend correctness and security

- [ ] Inspect migrations/functions actually deployed to the selected environment against local schema. Treat deployment drift as a separate finding with affected workflows.
- [ ] Exercise each sensitive operation as anonymous, owner, intended participant, unrelated same-role user, and wrong-role user using user-scoped credentials. Never use service-role access to prove RLS works.
- [ ] Attempt guessed IDs on profiles, applications, messages, jobs, quote requests, bookings, timesheets, reviews, documents, and resumes. Check RPCs/views/Edge Functions as well as table policies.
- [ ] Verify `public-media`, `private-docs`, and `chat-attachments` access: ownership, path rules, signed-link expiry, replacement/deletion, and relationship-gated resume access. Ensure public projections exclude contact/address/document data that should remain private.
- [ ] Test stale JWT/session expiry, role spoofing, invalid transition calls, concurrency, retry idempotency, and rate limiting in staging. Reconcile before/after rows and event counts, not only response codes.
- [ ] Confirm account switch/logout purges account-scoped cached data and realtime subscriptions; previous messages/documents/notifications must not flash for the next user.
- [ ] Inspect sanitized logs/crash reporting for secrets and personal information. Confirm crash observability configuration; do not deliberately crash or load-test production.

## Task 8: Evidence collection and defect triage

- [ ] Reproduce each failure twice when possible, record frequency, isolate device/build/backend/network factors, and minimize the reproduction. Intermittent one-off failures remain recorded with their uncertainty.
- [ ] Use `superpowers:systematic-debugging` for diagnosis. Separate **confirmed defect**, **suspected defect**, **environment blocker**, and **test gap**. A source suspicion or failing mock alone is not a confirmed production bug.
- [ ] Assign severity: **P0** data exposure/loss or widespread unusability; **P1** core journey blocked or materially incorrect hiring/auth; **P2** partial failure with a workable alternative; **P3** cosmetic/copy issue. Record release priority separately where impact differs.
- [ ] Each bug includes ID/title, severity, affected roles/build/device/environment, preconditions, numbered steps, expected/actual result, frequency, screenshot/video/log reference, persisted-state evidence, likely source location if established, and recommended regression case. Do not claim a root cause without evidence.
- [ ] Capture live Samsung failures and emulator representative states. Use `adb -s "$QA_DEVICE_SERIAL" exec-out screencap -p` with a case-specific output file. Restrict logcat collection to the app/relevant crash events; sanitize before sharing.
- [ ] For canonical emulator capture, boot the existing ARM64 `jobdun_test` first and run:

```bash
ANDROID_SERIAL="$QA_EMULATOR_SERIAL" ANDROID_SDK=/Users/kuya/Library/Android/sdk bash scripts/capture_app_screenshots.sh
```

This script writes website assets as well as verification images and does not cover all authenticated screens. Review resulting changes; do not deploy or commit them automatically. Its notification pre-grant is not permission-flow evidence. UI fixes in a later phase require this canonical capture plus screenshots of the changed screens.

## Task 9: Report, retest boundaries, and exit criteria

- [ ] Produce counts by feature, role, device/build, severity, and case status. Include every blocked/not-run variant and its effect on confidence.
- [ ] Give the boss a short summary: build tested, journeys tested, confirmed bugs, highest-impact examples, recommended fix order, and release recommendation with evidence links.
- [ ] Stop audit execution at findings/reporting unless fixes are requested. For subsequent fixes, add the smallest meaningful failing regression test, implement, verify it passes, and repeat affected live journeys plus shared-component regression checks.
- [ ] Re-run required validation after code fixes and capture emulator screenshots for UI changes. Retest release artifacts when configuration/native code/shrinking is affected.
- [ ] Audit completion requires all inventoried functionality to have an explicit result, all high-risk J01–J06 scenarios attempted, all failures triaged, and remaining blockers documented. A **release-ready** recommendation additionally requires no open P0/P1 issues, passing critical live journeys and automation on the identified artifact, and no unresolved security/data-integrity gap. Otherwise recommend hold or a clearly limited evaluation.

No promise of “zero bugs”: this process produces evidence of tested behavior and a transparent list of untested risks.

## Execution order and effort

1. Baseline, fixtures, and device setup: approximately half a working day if accounts/environments are available.
2. Critical paired-user journeys and complete feature sweep: approximately 1–2 working days.
3. Android/release/security/performance checks: approximately 1–2 working days.
4. Consolidation and reproducibility review: approximately half a working day.

Plan for roughly 3–5 working days for a thorough first pass, excluding fixes, unavailable environments, account provisioning, store distribution, and extended soak tests. Deliver high-severity findings as they are confirmed rather than waiting for the whole sweep.

## Documentation verification

Context7 was used to check official Flutter testing guidance. Its available Flutter documentation was main-branch documentation, not a version-pinned 3.41.7 API snapshot; verify commands against the installed SDK at execution time.

- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests): device tests complement unit/widget tests.
- [Flutter integration test introduction](https://docs.flutter.dev/cookbook/testing/integration/introduction): `integration_test` cannot operate native permission/notification UI; cover those manually/through Android controls in this plan.
- [Flutter performance guidance](https://docs.flutter.dev/perf/ui-performance): assess performance on physical hardware in profile mode.

The ui-ux-pro-max and impeccable audit guidance informed accessibility, theme, layout, and error-state coverage. This plan does not introduce a new UI design or testing framework.
