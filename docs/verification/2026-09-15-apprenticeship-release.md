# Apprenticeship release — 2026-09-15

## Scope and release status

Android `1.0.3 (9)`, package `au.com.jobdun.app`. Apprenticeship vacancies are
implemented across posting, discovery, application and builder review. Ordinary
trade work can separately invite apprentices. Dedicated vacancies use positive
finite employer-set hourly pay; apprentice profile applications do not ask for a
contractor quote. Qualified trades retain quotes for invited trade jobs.

**Backend deployed; Play Store upload/publication not performed.** This record
must not be read as confirmation that an installed Play Store version includes
these changes. No production test vacancies, applications or hiring records
were created. No commits or pushes were made.

## Production backend

- Project: `zethpanvkfyijislxesn`.
- Migrations `20260915000001_apprenticeship_jobs`,
  `20260915000002_application_hiring`, and
  `20260915000003_apprentice_completeness` applied successfully after a dry run
  and schema backup (`/private/tmp/jobdun-before-apprenticeship-20260915.sql`).
- `jobs-feed` Edge Function redeployed; shared cache key bumped to v2.
- `supabase/schema.sql` refreshed from production.
- Read-only deployment SQL passed. Guest REST returned HTTP 200 with all new
  projection fields. Filtered apprenticeship REST returned HTTP 200 and zero
  rows at verification time: the feature is available, but no dedicated live
  apprenticeship vacancies were present.
- Rollback notes/scripts are under `supabase/rollbacks/`. The additive job-kind
  schema is retained when rolling back an app binary.

## Verification

- Disposable local Postgres restored from the production public schema, then
  all three migrations applied. `supabase/tests/application_hiring.sql` passed:
  application identity/state enforcement, employer hire, job assignment,
  second-hire rejection, valid vacancy constraints, public projection and
  apprentice completeness.
- Two concurrent local SQL sessions confirmed exactly one hire commits for the
  same vacancy; the other rejects. Fixtures were cleaned afterward.
- SQL mutation tests ran only in the disposable database. Production checks
  were read-only.
- Focused Flutter tests cover JSON/cache round trips, cents, vacancy validation,
  query-before-pagination filters, cold applicant-profile loading/failure,
  application retry/write confirmation, apprentice completeness, creation and
  builder applicant review. Deno feed/projection suite: 3 passed.
- A controlled pending-request regression reproduced stale results after filter
  refresh. The fix invalidates old paged/nonpaged/account requests immediately
  and starts a replacement even when the pagination controller is already in
  its initial loading state. The regression and guest cap tests pass (4 tests).
- `FULL=1 bash scripts/validate.sh`: exit 0, all checks passed (design,
  architecture, formatting, analysis, all Flutter tests and normal debug APK).
  Summary: `2026-09-15-apprenticeship-validation.txt`.
- All three Android integration drivers passed, including the final live guest
  browsing run after the refresh fixes. Independent final code review found no
  material blockers.

## Real Android screenshots

The following are actual emulator renders, not design mockups:

- `2026-09-15-emulator-apprenticeship-01-details.png`: creation details.
- `2026-09-15-emulator-apprenticeship-02-pay.png`: employer hourly pay.
- `2026-09-15-emulator-apprenticeship-03-application.png`: profile application.
- `2026-09-15-emulator-apprenticeship-04-applicant.png`: builder applicant review.

Those four use labelled synthetic inputs/repository fixtures with production
widgets. They verify rendering and form behavior; database transactions are
verified separately by SQL and repository tests.

`apprenticeship_live_browse_test.dart` uses the actual `JobdunApp`, router and
production Supabase reads with an asserted guest session. Its screenshots are
`2026-09-15-emulator-live-01-jobs.png`, `02-apprenticeships.png`, and
`03-job-detail.png`. The test initializes the app without Sentry's global error
handler so Flutter's integration-test error handling remains intact.

The mandatory `scripts/capture_app_screenshots.sh` pipeline also completed
(exit 0) against the normal debug app: launch, login, role selection and create
account. Screenshots were inspected and the website-consumed
`assets/website/screenshots/create-account.png` was refreshed. The marketing
site was not redeployed.

## Reproduce the checks

```bash
FULL=1 bash scripts/validate.sh
flutter test --no-pub test/features/jobs/apprentice_filter_test.dart
flutter drive --no-pub --driver=test_driver/integration_driver.dart \
  --target=integration_test/apprenticeship_screens_test.dart -d emulator-5554
flutter drive --no-pub --driver=test_driver/integration_driver.dart \
  --target=integration_test/apprentice_applicant_screen_test.dart -d emulator-5554
flutter drive --no-pub --driver=test_driver/integration_driver.dart \
  --target=integration_test/apprenticeship_live_browse_test.dart \
  --dart-define-from-file=.env -d emulator-5554
```

Run Flutter builds/drivers sequentially in this checkout: they share generated
Android plugin-registration files. Do not use `--no-pub` when switching from
debug to release: Flutter 3.41.7 only regenerates the release plugin registrant
when pub is enabled; stale debug-only plugin references fail Java compilation.
After integration drivers, rebuild the normal
`lib/main.dart` debug APK before running `scripts/capture_app_screenshots.sh`.
The live smoke test depends on backend availability and at least one open job.


## Signed Android artifact

Build command (exit 0):

```bash
flutter build appbundle --release --dart-define-from-file=.env \
  --dart-define=SENTRY_ENVIRONMENT=production
```

- Artifact: `build/app/outputs/bundle/release/app-release.aab` (60,539,778 bytes).
- Bundletool manifest verified: `au.com.jobdun.app`, version `1.0.3`, code `9`.
- JAR signature verified; certificate matches the configured upload keystore.
- AAB SHA-256: `e8ced1cd840f12a53449b2bd3c2b8eef0ed6f8399f4a20615ba79f5e7a31ecd4`.
- Upload certificate SHA-256: `2B:73:B1:6F:37:10:E3:5E:77:E6:A6:0F:C0:05:76:6C:13:5D:37:C3:E9:86:48:DF:07:D8:90:3E:F0:39:C5:80`.

The normal debug APK also reports `1.0.3 (9)` and remains installed in the
Android emulator. The local SQL test container was stopped after verification.
A subsequent user-authorized store-submission task produced the signed iOS
`1.0.3 (9)` IPA. See `2026-09-15-store-submission.md` for current upload and
review status on both platforms.
