# Android installation and smoke-test report

Date: 2026-10-01. Scope: latest local source installation, automated baseline, Android integration tests, Samsung guest and signed-in trade flows, and release-emulator authentication/offline smoke tests. This is an expanding audit, not a production-readiness certification.

Publication note (2026-10-03): raw audit screenshots remain local and are intentionally excluded from GitHub because authenticated screens contain account information. Relative image links below refer to that local evidence archive. Anonymous onboarding and synthetic role-banner screenshots are published separately in the parent verification directory.

## October 3 backend-only follow-up

- Fresh `bash scripts/validate.sh` passed design, architecture, format, analysis and all Flutter tests. No phone was used in this follow-up.
- Cross-platform build verification: `flutter build apk --release --dart-define-from-file=.env` and `flutter build ios --release --no-codesign --dart-define-from-file=.env` passed. Both built artifacts identify as `au.com.jobdun.app`, version `1.0.3 (13)`, from the same shared Flutter source. Android signer SHA-256 remains `2b73b16f3710e35e77e6a60fc005766c135d37c3e98648df07d8903ef039c580`. iOS is unsigned compilation evidence, not an installed/signed IPA or iPhone runtime test. No store upload or production deployment was performed.
- An initial Android `--no-pub` release build failed because generated registration still referenced dev-only plugins after tests. Rebuilding with normal dependency regeneration passed; no application source change was needed.
- Three jobs-feed Deno tests passed. Anonymous REST feed/apprenticeship projections returned HTTP 200; schema-only requests used `limit=0`.
- One sampled guest row showed no observed address/coordinate privacy violation. Anonymous private-table reads returned empty arrays; public trade profile/search access was denied. This limited sample is not a complete RLS audit.
- Authenticated paired-user and write-lifecycle tests remain pending an isolated environment and designated accounts. No production data writes or phone interactions were performed in this follow-up.
- Admin login at `https://admin.jobdun.com.au/login` returned HTTP 200. The Next.js admin lives in its own `admin-web` Git repository, intentionally ignored by the mobile repository; its clean checkout matches remote commit `a5d3f5f`. Live deployment commit identity remains unverified. Older Flutter/Cloudflare admin deployment instructions do not describe the observed Next.js/Vercel site.

## Expanded remediation — installed build 1.0.3 (13)

All eight confirmed application findings in this report have source fixes with regression evidence. The original four shipped locally in build 11; account isolation and image retry fixes were installed in build 12; the final role-copy correction is installed in **build 13**. This does not mean every planned production workflow has been tested. The coverage ledger and blockers below remain authoritative.

### Final verification

| Check | Result |
|---|---|
| Required local validation | **Pass:** `FULL=1 bash scripts/validate.sh` after the final production change: design, file-size ceiling, architecture, formatting, analysis, Flutter test suites and debug APK. Existing over-400-line advisories remain; enforced 500-line ceiling passes. Log: `/private/tmp/jobdun-build13-final-validation.log`. |
| Focused regressions | **Pass:** 93 messaging/notification tests; 15 profile/banner tests. The expanded pass added **53 unit/widget regression cases** (10 notification, 17 messaging isolation, 21 image retry, 5 banner-copy). The earlier baseline had six skipped environment-dependent RBAC cases; those were not converted into live passes. |
| Android integration | **Pass individually during this pass:** real anonymous guest browsing/account gate and live filter/clear/detail; synthetic apprenticeship form, applicant detail, and two-role banner rendering. Synthetic checks do not prove posting/hiring/backend writes. The final banner driver rerun passed with a representative content-sized fixture. |
| Canonical screenshots | **Pass:** normal debug build 13, explicit emulator selection, canonical script completed and create-account website asset refreshed locally. Real screenshots were inspected. Changed banner: [trade fixture](../2026-10-01-emulator-profile-banner-trade.png), [builder fixture](../2026-10-01-emulator-profile-banner-builder.png). |
| Signed release | **Pass:** `flutter build apk --release --dart-define-from-file=.env`; signer matches the installed application. SHA-256: `45a23f59b53a30eaefabdb9ab7d6bab90e20a82229a04db5f6820b555fec41a0`. APK: `build/app/outputs/flutter-apk/app-release.apk`. |
| Samsung update | **Pass:** `adb install -r`, package manager confirms **1.0.3 (13)**. Signed-in session retained; no Samsung data clear/uninstall. [Final Home](expanded-06-build13-samsung-home.png) shows correct worker wording and 80% completeness. Jobdun left on Home. |
| Signed-in load checks | Build 12 loaded the existing [notification](expanded-04-build12-samsung-notifications.png) and [empty inbox](expanded-05-build12-samsung-messages.png). Build 13 changes only banner wording from that application snapshot. These are load checks, not two-account race or real attachment-delivery verification. |
| Crash observation | No entries observed in the current Samsung Jobdun process's crash buffer after the final update. This is not an exhaustive crash guarantee. |

Final logs: `/private/tmp/jobdun-build13-{final-validation,release,screenshots}.log`, `/private/tmp/jobdun-expanded-final-regressions.log`, `/private/tmp/jobdun-banner-copy-{red,green,analyze}.log`, `/private/tmp/jobdun-banner-android-final.log`. No commits, pushes, migrations, backend deployments or store submissions. The UI audit/screenshot workflow exposed AND-008 during final inspection and led to its correction.

Expanded finding priorities: **AND-005 / AND-006: P1** because previous-session content can reach the next local session's state; these tests do not demonstrate bypass of server authorization. **AND-007: P2**, interrupted image-send recovery. QA-001/QA-002 are test-tooling defects, not production application failures. The original four findings were P2.

| Finding | Evidence / current state |
|---|---|
| AND-005 — Notifications can retain/repopulate a previous session's data; signing in after an already-created logged-out controller does not start loading | Ten controller regression cases added; nine failed before the fix. Identity-generation guards, reload on sign-in, stream cancellation and stale rollback suppression implemented. Ten new plus four existing notification-page tests pass; independent spec and quality reviews approved. Device account-switch verification remains pending controlled accounts. |
| AND-006 — Messaging async results can repopulate stale inbox/thread state after logout/account changes or disposal | Seventeen new regressions failed before the fix; all 58 messaging tests pass afterward. Guarded requests, streams, optimistic actions and pagination; account reset clears pagination locks. Independent spec and quality reviews approved. |
| AND-007 — Image-message retry requires unavailable overwrite permission, can fail on duplicate-key conflicts, and can remain pending after a lost acknowledgement | Real-Supabase-client HTTP-boundary regressions reproduce retry failure under the checked-in INSERT/SELECT storage policy contract. Immutable upload now accepts only recognized duplicate conflicts after authenticated exact-byte verification; message insertion is idempotent. Retry performs a scoped authoritative lookup and validates sender/path/MIME before reconciling its pending bubble. Missing/mismatched confirmation stays retryable; stale sessions cannot update state. All 79 messaging tests pass, including 21 new retry cases; independent spec and quality reviews approved. Live paired-account Storage/RLS delivery remains unverified. |
| QA-001 — Guest-flow Android test no longer follows current screens | Reproduced obsolete entry labels, test error-handler replacement and premature animated-card tapping. Test now initializes the real app without Sentry taking the test binding's handler, waits for hittable cards and checks the actual guest gate. One real-backend Android guest-flow test passes. This is a test-harness repair, not an application defect. |
| QA-002 — Other Android suites depend on startup timing and legacy location input | Live browse no longer forces a route while startup can redirect it; waits use a finder that remains valid before any job exists. Synthetic apprenticeship form supplies the structured location field when production defines enable it. Both corrected tests pass on the Android emulator; applicant-detail synthetic rendering also passed. No publishing action or live application submission was invoked. |
| AND-008 — P3: Worker Home banner uses builder-only wording | Samsung build 12 shows a trade user being told to complete their profile to “get applicants,” despite the same screen identifying the account as open for work. [Reproduction](expanded-03-build12-samsung-home.png). **Fixed in build 13:** trades see “get more work,” builders retain “get applicants,” unknown roles use neutral wording, and custom messages retain priority. Two expected RED failures preceded the fix; all 15 profile tests pass. Android trade/builder fixtures and the final Samsung screen verify the correction. |

### Additional checks and boundaries

- Baseline `flutter test --coverage`: **890 passed, 6 skipped**. The six RBAC integration tests require their separately configured shadow environment; skipped is not passed. Instrumented line coverage was **12,159 / 24,386 (49.9%)**, not a guarantee about uninstrumented code or end-to-end functionality.
- Jobs-feed Deno tests: **3 passed**, using the real Dart projection source and local fixtures; no live backend writes.
- Read-only linked `public_apprentice_profile.sql` assertions completed successfully. Empty public-view data can make row-dependent assertions vacuous; this is not a complete authenticated RLS audit.
- Two other linked schema/privacy checks stopped at database authentication circuit-breaker errors. Retries were terminated; no policies, permissions or backend configuration were changed.
- Registration on the release emulator at **1.3 font scale** remained scrollable, with account/terms controls reachable. Captures: [initial](expanded-01-register-large-font.png), [scrolled](expanded-02-register-large-font-scrolled.png). Font scale restored to 1.0.
- Samsung reconnected on build 11, but later entered its screensaver. Further native picker checks await an unlocked phone with Jobdun foreground; no picker upload or profile save was performed.
- Samsung subsequently returned to Jobdun. Identity editor opened Android's `PhotopickerGetContentActivity` and Samsung Camera; System Back from each returned to the unchanged editor. The editor was closed without Save. No gallery contents were inspected/captured, no image selected or taken, and no profile write performed. These are cancellation checks, not successful-upload or permission-denial coverage.
- Docker Desktop was initially stopped; starting it resolved daemon access. Two disposable, network-disabled/no-port/no-mount test containers were created and subsequently stopped; the existing September container was untouched. The cached Postgres image lacks `auth.jwt()`, `storage.objects`, and the signup trigger. Loading the exact current public schema failed at `auth.jwt()` and rolled back atomically. Local database fixture/hiring tests remain **blocked by incomplete Supabase bootstrap**, not a product-test pass. Do not execute the existing hiring fixture against the linked production project: it creates jobs and can trigger notifications.
- Source review found that `application_hiring.sql` inserts profile rows after creating auth users; the real signup trigger already creates those profiles. The September public-schema-only test restore omits that auth-schema trigger, so its earlier pass cannot prove full production parity. This fixture concern needs reproduction and repair in the correctly bootstrapped isolated stack; no production trigger was disabled to bypass it.
- A second approach used the normal Supabase CLI in a fresh temporary project with an internal Docker network, Auth/Storage retained and optional services excluded. Images downloaded, but startup failed before migrations because the CLI could not reach its published local database port (`127.0.0.1:55462`, connection refused). The CLI cleaned up its containers; network isolation was not loosened. No SQL tests ran in this alternative either. Logs: `/private/tmp/jobdun-db-audit-20261001-{bootstrap,schema,preconditions}.log` and `/private/tmp/jobdun-local-stack-20261001-start.log`.
- Full two-role lifecycle, uploads, real push delivery, OAuth/OTP, hire/decline concurrency and destructive account actions still need an isolated environment and designated disposable builder/trade accounts. No production vacancies, applications, messages, SMS, profile changes or account deletions were created in this expanded pass.

Expanded logs currently reside under `/private/tmp/jobdun-expanded-*`, `/private/tmp/jobdun-messaging-isolation-*`, `/private/tmp/jobdun-image-retry-*`, `/private/tmp/jobdun-banner-*` and `/private/tmp/jobdun-build13-*`. Raw logs stay outside version control.

### Feature coverage ledger

These are feature-level summaries, not counts of every planned variant. “Partial” means only the named checks ran; all other cases in the audit plan remain not run or blocked. Baseline unit/widget tests do not establish live backend behavior.

| Plan area | Executed evidence | Remaining live coverage |
|---|---|---|
| F01 Onboarding | Partial: guest/login/create-account entry and canonical emulator captures | Every slide, interruption and reinstall/upgrade combination |
| F02 Authentication | Partial: required/invalid inputs, guest gates, user-assisted test-account sign-in | Disposable registration, email/reset links, OAuth, OTP and expiry matrix |
| F03 Home/navigation | Partial: signed-in trade tabs/Home, guest/detail/back navigation; role completion regression | Builder dashboard, deep links, invalid IDs and cold/warm callbacks |
| F04 Job browsing | Partial: live guest feed/detail, empty search/filter, clear/retry and offline recovery | Multi-page fixtures, combined filters, save persistence and map parity |
| F05 Job creation/lifecycle | Local domain/widget coverage; Android synthetic form rendering/validation passed | Real publish/edit/close/reopen and duplicate/concurrent writes |
| F06 Apprenticeships | Partial: filter and model/widget coverage; synthetic screen rendering | Populated live apprenticeship, resume lifecycle and complete paired journey |
| F07 Applications/hiring | Partial: existing trade application/detail/status filters; synthetic applicant screen passed Android | Apply/withdraw/shortlist/reject/hire, persisted state and concurrent hiring |
| F08 Discovery | Existing automated coverage only | Live builder discovery, map/filter/location permissions and privacy matrix |
| F09 Profile | Partial: trade owner/editor/public view; 80% completion verified on Samsung | Save/relaunch for every field, avatar/crop/portfolio and apprentice changes |
| F10 Verification | Partial: existing ticket sheet/verified badge; automated baseline | Picker cancel/permissions, upload boundaries, submissions and expiry transitions |
| F11 Messaging | Empty-state Samsung check; 79 local tests after account-isolation and image-retry fixes | Real paired send/read/realtime, attachments/retries, moderation and reconnect |
| F12 Notifications | Preferences page load; 14 local tests including account-isolation regressions | Real event delivery, permission decisions, background/terminated taps and token refresh |
| F13 Quotes | Empty-state Samsung load; baseline automated tests | Paired request/respond/terminal actions and duplicate handling |
| F14 Scheduling | Empty-state Samsung load; baseline automated tests | Paired create/respond/cancel, overlaps and Australian DST/date boundaries |
| F15 Timesheets | Baseline automated tests only | Paired entry/submit/approve/reject, overnight/rounding and ownership |
| F16 Reviews | Baseline automated tests only | Eligible completed-job fixtures, duplicates and aggregate reconciliation |
| F17 Settings/legal/account | Partial: settings/preferences load, Terms/Privacy and Back | Setting persistence, sign-out/re-login on disposable accounts and deletion |
| A01–A09 Android resilience | Partial: compatible release update, guest offline recovery, background/resume, Back semantics and 1.3 font scale | Permission matrix, native pickers, oldest API, Samsung keyboard/OTP, power/storage, TalkBack and profile-mode performance/soak |
| Backend/security | Partial: projection unit tests, one read-only SQL assertion script and account-isolation regressions | Authenticated cross-user RLS/Storage/RPC matrix, concurrent writes, deployed parity and event counts |

Release recommendation: **hold production-readiness sign-off** until critical paired-user, authorization, upload, auth-provider and push scenarios have live evidence. The current work supports a limited evaluation build, not a guarantee that every functionality is bug-free.

## Remediation follow-up — build 1.0.3 (11)

The four findings below describe the original build 10 smoke pass. Following the user's instruction to fix them, source changes now:

- **AND-001:** map job-feed connectivity, timeout, and server failures to short safe messages; the UI rejects unrecognized technical error text.
- **AND-002:** listen directly to pagination state and hide the result count during initial loading, refresh, and errors; successful empty results still show zero.
- **AND-003:** use localized Material BackButton controls on job details, legal documents, and both phone-auth steps, preserving existing navigation callbacks.
- **AND-004:** calculate completion from the authenticated role; a stray empty builder row no longer overrides a trade profile. Suppress ambiguous-role guidance while role is unknown.

Focused regression suite: **21 tests passed**, after reproducing the original failures. Read-only independent code review found no material issues. Minor additional coverage opportunities remain for appended-page counts, subsequent-page errors, and ambiguous-role suppression.

### Fix verification

| Check | Result and evidence |
|---|---|
| Full repository validation | **Pass**, `bash scripts/validate.sh`: design, file-size ceiling, architecture, format, analyze and all Flutter test suites. Existing over-400-line advisory warnings remain; no file exceeds the enforced ceiling. |
| Android builds | **Pass**, fresh debug and signed release APKs using `--dart-define-from-file=.env`. An initial overlapping release build failed on generated dev-plugin registration; the isolated release rerun passed without source changes. Avoid concurrent Flutter build/test processes that rewrite plugin metadata. |
| Canonical emulator screenshots | **Pass**, `scripts/capture_app_screenshots.sh` on explicitly selected `emulator-5554`, fresh debug build 11; launch, login, role selection and create-account captures saved under `docs/verification/2026-10-01-emulator-*`. Website create-account asset refreshed locally, not deployed. |
| Samsung update | **Pass**, signed release **1.0.3 (11)** installed with `adb install -r`; matching signer, package-manager version confirmed. Authenticated session survived. No Samsung app data cleared/uninstalled. |
| AND-004 | **Fixed and verified** on Samsung Home and Profile: native semantics reports **80 percent complete**, consistent with trade, location, portfolio and verified licence; phone verification remains the missing 20%. [Home](fixed-01-samsung-home.png), [Profile](fixed-02-samsung-profile.png). |
| AND-001 + AND-002 | **Fixed and verified** on the same signed release build in the emulator: disable Wi-Fi and mobile data, browse guest jobs, observe concise offline message, no result count, and visible Retry without scrolling. Restore connectivity, tap Retry, observe one real job and `1 job found`. [Offline](fixed-03-offline-feed.png), [recovery](fixed-04-feed-recovery.png). |
| AND-003 | **Fixed and verified** by widget semantics tests plus native Android hierarchy: `Button 'Back'` on [Job Details](fixed-05-job-detail-back.png), [Phone Sign In](fixed-06-phone-back.png), [Terms](fixed-07-terms-back.png), and [Privacy](fixed-08-privacy-back.png). Tapping the first three returned to their prior screens. OTP-stage callback preserved in source; SMS/OTP and spoken TalkBack output were not exercised. |
| Crash buffer | No matching Jobdun fatal crash observed during Samsung post-update check. Not an exhaustive crash guarantee. |

Release APK SHA-256: `8a6fced4c02aa7060e95b550919ff52ba27dc4df7b57ea6fd8fe9a2f63cbdc95`. Package: `build/app/outputs/flutter-apk/app-release.apk`. Signer remains the fingerprint recorded in the original installation section below.

Verification logs: `/private/tmp/jobdun-fixes-green.log`, `/private/tmp/jobdun-android-fixes-validation.log`, `/private/tmp/jobdun-fixes-debug-build.log`, `/private/tmp/jobdun-fixes-release-build-retry.log`, `/private/tmp/jobdun-fixes-screenshots.log`. Emulator network restored; Samsung returned to Home in its original light theme. Only dedicated emulator test installations were cleared/replaced for signature compatibility. No SMS, applications or messages sent; no commits, pushes, backend deployments or store submissions.

No production profile rows were edited or deleted to mask the completeness issue. Existing unrelated workspace changes were preserved.

## Installed successfully

- Samsung SM-A266B, Android 16 / API 36: upgraded from **1.0.1 (7)** to **1.0.3 (10)** using `adb install -r`.
- Package `au.com.jobdun.app`, minimum API 24, target API 36. Package manager confirmed version 10 after installation and again at the end of the pass.
- Release APK built from the current working tree at HEAD `271b45b`, including existing uncommitted changes. This is the latest local source, not a claim about the newest remote/store release.
- APK signature verified. Old and new signer SHA-256 fingerprints match: `2b73b16f3710e35e77e6a60fc005766c135d37c3e98648df07d8903ef039c580`.
- APK SHA-256: `882c6e59519050d1d82100b1ad996dd6a9863ed59d7a660a3078d6aca740eb88`.
- APK: `build/app/outputs/flutter-apk/app-release.apk`. Samsung app data was not cleared and the app was not uninstalled. Existing state was logged out before and after the upgrade, so authenticated-session migration was not tested.
- The dedicated emulator's integration-test installation was removed and replaced with the same signed release APK for manual release smoke testing. Only emulator test data was removed.

## Original confirmed issues — all four fixed in build 11

The observations below are historical reproductions from build 10. See the remediation verification above for their current status; the original failing results are retained as evidence, not open defects.

### AND-001 — P2: Offline job browsing displays a raw technical exception

**Impact:** A user without internet sees a long `ClientException`/`SocketException`, backend hostname, REST endpoint, and database projection instead of a useful connection message. The long text pushes Retry below the initial viewport. Retry is reachable by scrolling; this is not a permanently blocked screen.

**Reproduction:** On the release emulator, open Login, disable emulator Wi-Fi and mobile data, then tap Browse open jobs. Wait for loading to fail. Reproduced a second time by disabling connectivity on the loaded feed and selecting Electrician.

**Expected:** A short message such as “You're offline. Check your connection and try again,” with Retry visible. Technical diagnostics belong in sanitized logs.

**Actual:** The full URL/query and native network error fill the page. Reproduced in two separate offline requests. No credential or access token was observed in this message; this is not classified as a demonstrated credential leak.

**Evidence:** [Initial error](17-offline-browse.png), [Retry after scrolling](18-offline-scrolled.png), [second reproduction](20-offline-filter-repeat.png).

**Source trace:** `lib/features/jobs/data/datasources/job_remote_datasource.dart:97` wraps `e.toString()` in `ServerException`; `lib/features/jobs/data/repositories/job_repository_impl.dart:75` forwards the message into `ServerFailure`; `lib/features/jobs/presentation/pages/jobs_page_widgets.dart:56` renders the message directly.

**Resolution:** Implemented and verified in build 11: safe connectivity/timeout messages, defensive UI filtering, and visible Retry. Original reproduction retained above.

### AND-002 — P2: Failed/loading job requests are presented as “0 jobs found”

**Impact:** The UI tells users there are no jobs even though the app has not obtained a valid result. This is distinct from an actual successful empty search and is misleading during poor connectivity.

**Reproduction:** Repeat either AND-001 scenario. The results header says “0 jobs found” during the skeleton state and after the request fails. Reconnect and Retry: the same unfiltered query returns one job.

**Expected:** Loading/error states must not report a successful zero-result count. Show a count only after a successful response, or explicitly mark stale cached counts.

**Evidence:** [Failed request with zero count](17-offline-browse.png), [successful recovery with one job](19-offline-recovery.png).

**Source trace:** `lib/features/jobs/presentation/pages/jobs_page.dart:130` defaults a null item list to zero; the count label at line 319 is rendered without distinguishing initial loading/error from a successful result.

**Resolution:** Implemented and verified in build 11: count listens to pagination and is hidden on loading/error. Successful empty-result and refresh regressions pass; live recovery shows the correct nonempty count.

### AND-003 — P2: Back buttons lack accessible names on multiple screens

**Impact:** Android accessibility exposes unlabeled navigation controls, so a screen-reader user cannot reliably identify their purpose.

**Reproduction:** Inspect the Android accessibility hierarchy on Job Details, Terms of Service, and Phone Sign In. The visible back arrows have no “Back” accessible name. Compare registration's Back button, which is correctly named in the same inspection method.

**Evidence:** [Samsung Job Details](04-job-detail.png), [emulator Terms](12-terms.png), [emulator Phone Sign In](13-phone-entry.png). Runtime hierarchy inspection and source agree. TalkBack spoken output was not separately tested, so the claim is limited to the missing accessible names.

**Source locations:** `lib/features/jobs/presentation/pages/job_detail_page.dart:114`, `lib/features/legal/presentation/pages/legal_document_page.dart:29`, `lib/features/auth/presentation/pages/phone_auth_page.dart:314` and `:324`. Custom `IconButton`s have no tooltip/semantic label.

**Resolution:** Implemented and verified in build 11 using localized BackButton controls and native/widget semantics checks. Spoken TalkBack navigation remains a separate untested scenario.

### AND-004 — P2: Populated trade profile incorrectly shows 0% completion

**Impact:** Both Home and Profile tell an established trade user that their profile is 0% complete, despite populated trade, location, portfolio, experience, and visible verified-licence information. This gives incorrect onboarding guidance.

**Reproduction:** Sign into the provided trade account, observe the 0% banner on Home, open Profile, and compare the banner with the populated profile sections. Revisited after settings/public-profile navigation and the incorrect value persisted.

**Evidence:** [Profile banner](25-samsung-profile.png), [final Home banner](35-samsung-home-final.png), and a narrow read-only database check of this account's profile-presence flags. The query returned: builder row exists; trade row exists; builder company/ABN/suburb absent; trade and trade suburb present; portfolio count 1; phone not verified. No database values were changed.

**Confirmed cause:** `lib/features/profile/presentation/providers/profile_provider.dart:419` chooses `builderProfile != null` before considering `tradeProfile`, without selecting the user's active role. The controller loads both rows. An empty builder row therefore contributes 0/4 and prevents the populated trade profile from being scored. Trade fields alone establish at least 60% under the current formula; the exact licence contribution should be asserted against the verification provider in a regression test.

**Resolution:** Implemented and verified in build 11: active-role scoring with dual-row regression coverage. The Samsung account reports 80% on Home and Profile; no database rows were deleted or changed to mask the defect.

## Original build 10 tests and observations

| Check | Result | Environment/evidence |
|---|---|---|
| Required repository validation | Pass | `bash scripts/validate.sh`: design/architecture/format/analyze/flutter test all passed; APK build was separately executed |
| Signed, shrunk release APK build | Pass | `flutter build apk --release --dart-define-from-file=.env` |
| Compatible update, package version, launch | Pass | Samsung, version 1.0.3 (10), matching certificates |
| Empty login fields | Pass | Samsung; required errors shown, [screenshot](02-empty-login-validation.png) |
| Live guest feed and detail | Pass | Samsung; [feed](03-guest-feed.png), [detail](04-job-detail.png) |
| Guest application gate | Pass | Samsung; Quote this job opens create-account/login gate, [screenshot](05-guest-apply-gate.png) |
| Apprenticeship filter with empty results | Pass | Samsung; [screenshot](06-apprenticeships-filter.png); no live apprenticeship vacancy existed in this response |
| Search with no match; Clear filters restores results | Pass | Samsung; [empty search](07-search-no-match.png), [recovery](08-clear-search-recovery.png) |
| Role selector and trade-registration screen | Pass | Samsung; [role selection](09-role-selection.png), [registration](10-trade-registration.png) |
| Registration terms gate and required fields | Pass | Release emulator; create disabled until terms accepted; empty submit then shows required errors, [screenshot](11-emulator-registration-validation.png) |
| Terms document opens and system Back returns | Pass | Release emulator; [screenshot](12-terms.png) |
| Empty/invalid phone validation | Pass | Release emulator; [required](14-phone-required.png), [invalid](15-phone-invalid.png); no SMS sent |
| Empty reset-email validation and return to Login | Pass | Release emulator; [screenshot](16-reset-required.png); no email sent |
| Offline presentation | Fail | AND-001 and AND-002 |
| Reconnect plus manual Retry | Pass | Release emulator; real job returns, [screenshot](19-offline-recovery.png) |
| Background/resume | Pass | Release emulator; app returns to the guest feed |
| Accessible Back names | Fail | AND-003 |
| Android crash-buffer inspection | No matching crash observed | Both devices inspected; not proof that all crash types are absent |
| Live browse/filter/clear/detail integration test | Pass, 1 test | `integration_test/apprenticeship_live_browse_test.dart` on emulator debug test build; distinct from release smoke evidence |
| User-assisted test-account sign-in | Authenticated state confirmed | User signed in on Samsung; subsequent protected screens loaded. Credential entry and full auth-provider matrix were not automated |
| Existing application and job status | Pass | Shortlisted application and Quote sent detail agree; [application](22-samsung-applications.png), [job](21-samsung-quote-sent.png) |
| Pending/Shortlisted application filters | Pass | [Pending empty](33-samsung-pending-filter.png), [Shortlisted populated](34-samsung-shortlisted-filter.png) |
| Trade profile, editor entry, ticket sheet, public preview | Load checks pass; completion fails | [Editor](23-samsung-edit-profile.png), [tickets](24-samsung-tickets.png), [public preview](31-samsung-public-profile.png); AND-004 affects the banner; profile saves were not tested |
| Settings and notification-preferences page | Pass, load only | [Settings](26-samsung-settings.png), [preferences](27-notification-settings.png); notification toggles were not changed |
| Schedule, quote requests, messages | Pass, empty-state load only | [Schedule](28-samsung-schedule.png), [quotes](29-samsung-quotes.png), [messages](32-samsung-messages.png); no events/messages sent |
| Dark mode and restore light mode | Pass, settings screen | [Dark settings](30-samsung-dark-settings.png); original light preference restored |
| Signed-in completeness guidance | Fail | AND-004, reproduced on Home and Profile |

The integration test's apprenticeship assertion allows an empty result list. Its pass proves filter wiring and error-free completion for observed data, not that an actual apprenticeship vacancy/application/hire works end to end.

## Not tested in this pass

Full login/OAuth/OTP/email-delivery coverage, paired builder/trade/apprentice journeys, posting and hiring, actual message delivery, uploads, push delivery, account deletion, RLS adversarial tests, multi-user races, minimum-API compatibility, full accessibility, and performance profiling remain pending. The provided signed-in trade account enabled read/navigation smoke checks; a designated builder counterpart and controlled write fixtures are still needed for full lifecycle testing. Do not label those workflows passed.

The Samsung switched to another app during registration testing. That step was excluded, the unrelated screenshot was deleted, and testing continued on the dedicated emulator. The user subsequently confirmed exclusive device access and signed into a test account, allowing the signed-in pass. No unrelated app contents are included in this report. Emulator Wi-Fi/mobile data and the Samsung light-theme preference were restored after testing. No production jobs, accounts, applications, messages, reviews, or migrations were created by these checks. Authenticated screenshots are local QA evidence and include the supplied account's profile information; redact before sharing outside the project.

## Original suggested fix order — completed in build 11

1. **Done:** Fix role selection in profile completion so existing users receive accurate guidance.
2. **Done:** Fix offline error presentation and loading/error count handling together, with separate assertions for each defect.
3. **Done for identified controls:** Fix accessible navigation labels on the affected screens. Full TalkBack/accessibility auditing remains pending.
4. **Pending:** Use designated builder and trade/apprentice accounts for the paired-user scenarios in the [full test plan](../../superpowers/plans/2026-10-01-android-production-bug-audit.md).

The original smoke pass found four actionable issues and did not modify app source. All four were subsequently fixed and verified in the build 11 remediation above. This does not certify full production readiness; the untested workflows listed above remain pending. No commits, pushes, backend deployments, or store submissions were performed.
