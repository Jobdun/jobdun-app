# Apprentice production release — 2026-09-07

## Production backend: deployed and verified

- Project: `zethpanvkfyijislxesn` (the backend configured in `.env`).
- Applied exactly migrations `20260831000001`–`20260831000005` using
  `supabase db push --linked --yes` after verifying the dry run.
- Pre-change public/storage schema backup:
  `/private/tmp/jobdun-before-apprentice-schema.sql` (local, schema only).
- All five `trade_profiles` columns and `jobs.open_to_apprentices` exist.
- `site_tickets` contains nine rows; RLS is enabled.
- Resume storage policy checks the applicant/builder relationship.
- `search_trades`: authenticated execute allowed; anonymous execute denied.
  Both legacy and apprentice signatures execute under the authenticated role.
- App-facing REST projections return 200; anonymous search RPC returns 401.
- Live emulator verification exposed two further missing view projections:
  `20260907000001_guest_browse_apprentices.sql` and
  `20260907000002_public_apprentice_profiles.sql` were subsequently deployed.
  Guest jobs now include the invitation flag; public trade profiles now include
  apprentice identity/stage/tickets, with private documents still withheld.
- Redeployed `jobs-feed` with `open_to_apprentices`. A temporary session for the
  existing review account confirmed the live Edge Function returns the boolean,
  the public profile projection is readable, and all nine tickets are available.
  The temporary session was revoked. No password was changed or email sent.
- Both read-only SQL regression tests failed before their respective fixes and
  passed afterwards:
  `supabase/tests/guest_apprentice_browse.sql` and
  `supabase/tests/public_apprentice_profile.sql`. They also check location/rate
  masking and document/directory privacy.
- Final `scripts/schema-diff.sh` check passed after both follow-up migrations.
- `supabase/schema.sql` refreshed from the live public schema. This also records
  the pre-existing `verifications_user_kind_unique` constraint that the old
  snapshot omitted; that constraint was not changed in this deployment.

`apprenticeship_started_at` and `trade_tickets` were inaccurate checks in the
earlier handoff. The implementation does not use either. Staging remains
listed in the authenticated Supabase account but its project hostname does not
resolve; this does not establish that the project was deleted.

## Validation and artifacts

- `bash scripts/validate.sh`: all checks passed, including all test suites.
- Existing uncommitted changes expanded validation beyond `test/features/` and
  corrected the two stale navigation/header assertions. Retained and verified.
- Inspected the builder-profile golden mismatch and refreshed its stale spacing.
- All three Deno feed tests pass. The projection guard reads the actual Dart
  source, so an app/backend mismatch now fails the test. Run:
  `npx --yes deno test --allow-read=lib/features/jobs/data/datasources/job_remote_datasource.dart supabase/functions/jobs-feed/feed_test.ts`.
- Signed Android AAB: `build/app/outputs/bundle/release/app-release.aab`.
  Version `1.0.2`, versionCode `8`, package `au.com.jobdun.app`, target API 36.
  SHA-256: `e1f6931c00dffbad653e7b86a9845329b2396e8252d354a815d47871ea8789ed`.
- Signed iOS IPA: `build/ios/ipa/Jobdun.ipa`. Version `1.0.2 (8)`, bundle
  `au.com.jobdun.app`, iOS 26.5 SDK via Xcode 26.6, arm64.
  SHA-256: `a1ef3d72481c026efc19ef5c80e03be9dd47e9531c8dbfdde0a8fbd5ac895c4f`.
  Cloud Managed Apple Distribution signing; production push entitlement,
  Sign in with Apple, and privacy manifest verified in the exported artifact.
- Both builds used `--dart-define-from-file=.env` and
  `--dart-define=SENTRY_ENVIRONMENT=production`. The explicit override matters:
  `.env` contains `SENTRY_ENVIRONMENT=development`.
- Fresh debug APK built for emulator verification. Removed only regenerable
  Jobdun Android intermediates, old iOS simulator output, and its Xcode derived
  data to free space for the test emulator. Release artifacts/archive retained.
- Android API 36 emulator: captured launch, login, role selection, registration,
  guest feed and job detail. Visually inspected the captures. Guest feed loads
  a real production job after the follow-up view migration. The website's
  `assets/website/screenshots/create-account.png` now contains the actual form.
- Fixed the screenshot workflow's obsolete SKIP tap, role-selection omission,
  and Bash 4-only associative array; the workflow passes on macOS Bash 3.2.

No app-source changes were needed for the additional backend fixes, so the
signed artifacts and uploaded iOS build already consume them.

## Store status

**iOS upload succeeded.** Xcode reported `Upload succeeded`, `Uploaded Runner`,
and `EXPORT SUCCEEDED`; App Store Connect accepted the package for processing.
This is not an App Review submission or public release.

**Android upload is pending.** Brave has an authenticated Jobdun Play Console
tab, but JavaScript from Apple Events is disabled. Native UI automation is also
blocked because osascript lacks macOS Accessibility access. App Store Connect's
Brave tab remains at login. The user was asked to enable the browser automation
setting and sign into App Store Connect; no store review was bypassed.

Remaining: upload the AAB to Play, inspect its pre-launch report, prepare the
release details and submit; attach the processed iOS build to version 1.0.2 and
submit it for App Review. Confirm approval/rollout separately. Store console
metadata, current questionnaires, and iOS physical-device interaction checks
were not verified in this session. No commits or pushes were made.

Public privacy, support, and account-deletion pages returned HTTP 200 at
`https://jobdun.com.au/privacy`, `/contact`, and `/delete-account/`.

### Store audit gates

| Platform / gate | Result and evidence |
| --- | --- |
| Play 1 — package identity | PASS — `au.com.jobdun.app` in release manifest |
| Play 2 — target SDK | PASS — API 36 in release manifest |
| Play 3 — adaptive icon | PASS — foreground/background/monochrome configured |
| Play 4 — permissions | PASS in code — network/location plus plugin permissions; Console declarations unverified |
| Play 5 — edge-to-edge | PASS on inspected API 36 onboarding/guest screens; not an exhaustive screen audit |
| Play 6 — deletion | PASS in code — in-app deletion RPC flow and live deletion URL |
| Play 7 — Data safety | BLOCKER — Console questionnaire not verified |
| Play 8 — artifact | PASS — upload-key-signed AAB, R8 and resource shrinking enabled |
| Play 9 — core quality | PASS automated checks and limited emulator smoke test; broader device checks pending |
| Play 10 — pre-launch report | BLOCKER — AAB not yet uploaded to Play |
| Apple 1 — bundle identity | PASS — `au.com.jobdun.app` in exported IPA |
| Apple 2 — SDK | PASS — Xcode 26.6 / iOS 26.5 SDK; upload accepted |
| Apple 3 — purpose strings | PASS — camera, photos, optional location descriptions present |
| Apple 4 — privacy manifest | PASS — bundled in exported IPA |
| Apple 5 — Apple sign-in | PASS entitlement/code; live iOS sign-in interaction not tested |
| Apple 6 — deletion | PASS in code — shared in-app deletion flow |
| Apple 7 — encryption | PASS — non-exempt-encryption declaration configured; upload accepted |
| Apple 8 — icon | PASS upload validation — AppIcon set contains 21 PNGs |
| Apple 9 — signing | PASS — Cloud Managed Apple Distribution; upload succeeded |
| Apple 10 — metadata | BLOCKER — App Store Connect browser sign-in and submission details pending |

Suggested release notes:

> Apprentice profiles now support apprenticeship stage, site tickets and resume
> uploads. Builders can find apprentices and mark jobs as open to apprentices.
> This update also refreshes key screens and fixes guest job browsing.

Store policy references checked for this release:
[Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/)
and [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878).
