# Live-User Bug-Pattern Page-by-Page Audit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Root-cause every bug Sam reported from the live App Store build, then sweep every mobile page for the same defect patterns so nothing of the same class ships again — output is `docs/BUG_AUDIT_2026-08-18.md` with confirmed findings (file:line), severity, and fix recommendations.

**Architecture:** Read-only audit. Six pattern passes run as parallel read-only subagents over `lib/features/**` + `lib/app/router/` + `supabase/functions/**`; ops checks (prod edge-function deployment, phone/SMS provider) run via Supabase CLI. Findings compile into one report; fixes are a separate follow-up plan (each via superpowers:systematic-debugging + TDD).

**Tech Stack:** Flutter/Dart (Riverpod 3, GoRouter), Supabase (Auth, Storage, Edge Functions), Supabase CLI.

---

## Reported bugs under audit (source: Sam's WhatsApp session 2026-08-18 + Ken's IMG_0453–0462 screenshots)

| ID | Report | Suspected surface |
|----|--------|-------------------|
| S1 | "When we pressed verify the licence this happened" (error) | `lib/features/verification/**` → `supabase/functions/verify-licence` (prod deploy/env?) |
| S2 | "Text is not coming to the phone" (SMS OTP dead — Twilio trial expired) | Supabase phone auth provider (ops) + `phone_auth_page.dart` error UX |
| S3 | "Keyboard not going down" | Any form screen — sweep all |
| S4 | Role picker "I'm hiring / I'm looking for work" — "you can not go back at all" | `register_page_role_step.dart` / `register_page.dart` |
| S5 | Trade-type selection should be at signup (product request, not bug) | `register_page_form_step.dart` — document options only |
| S6 | "Taking a photo for your profile does not upload" | `identity_sheet.dart` → `image_upload_service.dart` camera path |
| K7 | Every job card shows `Distance 0.0 km` | discovery feed distance calc / missing coords |
| K8 | Job cards show `Start Australia,` / `Start Queensland,` (dangling comma; location under a "Start" label) | job card widget field mapping + location formatter |
| K9 | Home says `COMPLETE YOUR PROFILE 0%` while profile shows verified licence + "profile incomplete — add licence" contradiction | profile-completion provider |
| K10 | Login shows generic red "Something went wrong. Please try again." (seen mid Apple sign-in) | `error_messages.dart` mapping + OAuth cancel handling |
| K11 | Settings lists both "Schedule" and "Availability calendar" (dupe-looking) + "Quote requests" | `settings_page.dart` nav targets — verify both work, flag UX |

## Defect patterns to sweep app-wide

- **P1 Navigation dead ends** — full-screen page reachable by push/redirect with no back affordance and no PopScope escape.
- **P2 Keyboard handling** — text-input screens with no tap-outside dismiss, no `keyboardDismissBehavior`, wrong `resizeToAvoidBottomInset`, missing `textInputAction`.
- **P3 Media capture/upload** — every camera/gallery call site: swallowed errors, no progress/failure UI, permission-denied dead ends, upload path/bucket mismatches.
- **P4 External verification calls** — licence/ABN verify: client→function contract, prod deployment, env secrets, error mapping.
- **P5 Auth error surfacing** — every auth action's failure path: generic copy, errors shown for user-cancel, silent failures.
- **P6 Silent failures & contradictory state** — empty catch blocks, unrendered `AsyncValue.error`, derived-state contradictions (K9).
- **P7 Data-display defects** — placeholder/zero values rendered as real data (K7), mislabeled fields, dangling separators (K8).

---

### Task 0: Report skeleton

**Files:**
- Create: `docs/BUG_AUDIT_2026-08-18.md`

- [x] **Step 1:** Write report skeleton with sections: Executive summary · Sam's bugs S1–S6 root causes · Screenshot defects K7–K11 · Pattern sweep findings P1–P7 (page × pattern matrix) · Ops findings · Severity-ranked fix list. (Done inline by orchestrator.)

### Task 1: Root-cause S1 licence verify + P4 sweep (subagent A4)

**Files (read):**
- `lib/features/verification/presentation/pages/verification_page.dart`
- `lib/features/verification/presentation/pages/verification_wizard_page.dart`
- `lib/features/verification/data/**` (repos/services — locate with `grep -rn "verify-licence\|verify_licence\|functions.invoke" lib/features/verification lib/core`)
- `supabase/functions/verify-licence/index.ts`, `supabase/functions/verify-abn/index.ts`, `supabase/functions/_shared/**`
- `lib/features/profile/presentation/pages/profile_page_trade.dart` (the "Re-verify →" entry point)

- [x] **Step 1:** Trace tap→UI-error chain: find the exact widget for "Re-verify" and "ADD NOW", the provider action it calls, the repo method, the function name it invokes, and the request payload shape.
- [x] **Step 2:** In `verify-licence/index.ts` list every `Deno.env.get(...)` secret it needs and every non-200 path (which client then renders as error).
- [x] **Step 3:** Check client error mapping: does a function 4xx/5xx surface as a raw dialog, generic copy, or a typed Failure?
- [x] **Step 4:** Log findings to report §S1/§P4 with file:line.

### Task 2: S4 role-picker dead end + P1 sweep (subagent A1)

**Files (read):**
- `lib/app/router/app_router.dart` (full route table + redirect logic), `lib/app/router/guest_browse_policy.dart`
- `lib/features/auth/presentation/pages/register_page.dart`, `register_page_role_step.dart`, `register_page_form_step.dart`
- Every page file listed in the Page Inventory appendix — check each `Scaffold`/`AppBar`/`leading`/`automaticallyImplyLeading`/`PopScope` and how the route is entered (push vs go vs redirect).

- [x] **Step 1:** For `register` flow: confirm whether the role step can navigate back (to login / previous step) — check for `context.pop()` affordance, `PopScope(canPop: false)`, and whether the route is entered with `context.go` (which clears the stack → system back exits app on Android, and iOS has no back at all).
- [x] **Step 2:** Sweep every route: build a table `route → entry method (go/push/redirect) → back affordance (AppBar back / close / none) → verdict`. Flag every "none" on a non-root page. Tab roots (`/home`, `/jobs`, `/applications`, `/messages`, `/schedule`) are exempt.
- [x] **Step 3:** Special attention: `/verify-email`, `/phone-auth`, `/profile/verify-phone`, `/verification/wizard`, `/timesheets`, `/browse` (guest mode), FTUE→role handoff, onboarding_completion_sheet (can it be dismissed?).
- [x] **Step 4:** Log findings to report §S4/§P1.

### Task 3: S3 keyboard + P2 sweep (subagent A2)

**Files (read):** every page/sheet with text input. Locate with:
`grep -rln "TextField\|TextFormField\|FormBuilderTextField\|CupertinoTextField" lib/features --include="*.dart"`

- [x] **Step 1:** For each hit, record: wrapped in scroll view? `keyboardDismissBehavior` set? tap-outside `GestureDetector`/`FocusScope.unfocus` present (page-level or app-level in `main.dart`/shell)? `resizeToAvoidBottomInset` overridden? `textInputAction` on last field? bottom-sheet forms: `viewInsets` padding present?
- [x] **Step 2:** Verdict per screen: can the user always dismiss the keyboard (tap outside, scroll, or done key)? Flag screens where the only escape is submitting the form. Prime suspects: `job_create_page`, `job_apply_sheet`, `register_page_form_step`, `login_page`, `forgot_password_page`, `message_thread_input`, discovery search bar, profile edit sheets.
- [x] **Step 3:** Log findings to report §S3/§P2, one row per screen.

### Task 4: S6 camera upload + P3 sweep (subagent A3)

**Files (read):**
- `lib/core/services/image_upload_service.dart` (full)
- Call sites: `identity_sheet.dart`, `portfolio_strip.dart`, `message_thread_input.dart`, `message_thread_page.dart`, `onboarding_completion_sheet.dart`, `manual_upload_sheet.dart`, `manual_upload_form.dart`
- Storage layer: `grep -rn "storage.from\|uploadBinary\|\.upload(" lib --include="*.dart"`
- `ios/Runner/Info.plist:61-64`, `android/app/src/main/AndroidManifest.xml`

- [x] **Step 1:** In `ImageUploadService`: trace the `ImageSource.camera` path vs gallery path — cropper step, compress step (does `flutter_image_compress` handle HEIC from iOS camera?), null returns, and every `catch`: is the error rethrown/surfaced or swallowed to a silent `null`?
- [x] **Step 2:** In `identity_sheet.dart` (profile avatar): what renders while uploading, what renders on failure — is there any user-visible error, or does the sheet just do nothing (Sam's symptom)?
- [x] **Step 3:** Verify upload target: bucket name + path per call site vs the five buckets (`avatars`, `company-logos`, `portfolio-images`, `verification-documents`, `job-attachments`); check `contentType` passed; check permission-denied (camera) handling — iOS returns an error, not a picker.
- [x] **Step 4:** Log findings to report §S6/§P3, one row per call site.

### Task 5: S2/K10 auth errors + P5 sweep (subagent A5)

**Files (read):**
- `lib/features/auth/presentation/pages/login_page.dart`, `phone_auth_page.dart`, `forgot_password_page.dart`, `verify_email_page.dart`, `register_page*.dart`
- `lib/features/auth/data/services/` (EmailAuthService, OAuthService, PhoneAuthService, RoleResolver)
- `lib/core/errors/error_messages.dart` (the "Something went wrong. Please try again." source)
- Auth controllers/providers in `lib/features/auth/presentation/providers/`

- [x] **Step 1:** K10: find which failures map to the generic banner. Specifically: does Apple/Google sign-in **user cancellation** surface the red error banner? (Screenshot shows the banner while the Apple sheet opens — cancel should be silent.)
- [x] **Step 2:** S2: in PhoneAuthService + phone_auth_page: when Supabase returns an SMS-provider failure (Twilio unfunded), what does the user see — spinner forever, generic copy, or actionable copy? Is there a resend cooldown that locks the user out?
- [x] **Step 3:** Sweep every auth action (login, register, SSO ×2, phone OTP send/verify, forgot password, verify email resend) → table: action → failure paths → copy shown → stuck-state risk.
- [x] **Step 4:** Log findings to report §S2/§K10/§P5.

### Task 6: K7/K8/K9/K11 + P6/P7 sweep (subagent A6)

**Files (read):**
- Discovery: `discovery_page.dart`, `discovery_page_widgets.dart`, discovery data layer (`lib/features/discovery/data/**`, locate distance calc with `grep -rn "distance\|km" lib/features/discovery --include="*.dart"`)
- Job card widgets: `grep -rn "Start\|Distance" lib/features/discovery lib/features/jobs --include="*.dart" -l`
- Profile completion: `grep -rn "completion\|COMPLETE YOUR PROFILE\|0%" lib/features/profile lib/features/home --include="*.dart" -l`
- `settings_page.dart` (K11 targets: `/schedule` vs `/settings/availability` vs `/quotes`)
- App-wide: `grep -rn "catch (_) {}\|catch (e) {}\|on Exception catch" lib/features --include="*.dart"` and every `AsyncValue` consumer that renders only `data`/`loading` (no `error` branch).

- [x] **Step 1:** K7: find where `Distance` is computed — confirm why it renders `0.0 km` (null trade coords → default 0? jobs missing lat/lng? haversine bug?). State the exact null chain.
- [x] **Step 2:** K8: find the card's "Start" cell — is it bound to a location string (bug: wrong field) or is the label wrong? Find the `"$city, $state"` join that produces `Australia,` and the missing-part guard.
- [x] **Step 3:** K9: locate the completion-% provider; list which fields it counts; explain 0% with a verified licence + why the banner and the "WHAT'S BEEN CHECKED ✓" can contradict; check the home card and profile banner read the same source.
- [x] **Step 4:** K11: confirm what `/schedule`, `/settings/availability`, `/quotes` each open for a trade account, and whether "Schedule" and "Availability calendar" are genuinely distinct (flag as UX dupe if overlapping).
- [x] **Step 5:** P6 sweep: list every swallowed catch + every AsyncValue consumer with no error branch, per feature. Log all to report.

### Task 7: Ops checks — prod backend state (orchestrator, Bash)

- [x] **Step 1:** `supabase functions list --project-ref zethpanvkfyijislxesn` → confirm `verify-licence` + `verify-abn` are deployed to PROD and ACTIVE (staging having them is not enough).
  Expected: 4 rows; if `verify-licence` missing/older version → S1 root cause candidate.
- [x] **Step 2:** `supabase secrets list --project-ref zethpanvkfyijislxesn` → confirm names required by verify-licence/verify-abn (from Task 1 Step 2) exist (values not needed).
- [x] **Step 3:** Phone provider: `curl -s -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" https://api.supabase.com/v1/projects/zethpanvkfyijislxesn/config/auth | jq '{external_phone_enabled, sms_provider, sms_twilio_account_sid: (.sms_twilio_account_sid // "unset")}'` (token from keychain item "Supabase CLI", strip `go-keyring-base64:` + base64-decode). Confirm SMS provider config; document that Twilio funding is the S2 fix + monthly cost estimate for the boss report.
- [x] **Step 4:** Log to report §Ops.

### Task 8: Compile report + deliverables (orchestrator)

- [x] **Step 1:** Merge all six subagent result sets + ops results into `docs/BUG_AUDIT_2026-08-18.md`; verify every S/K item has a root cause or an explicit "needs device repro" note; de-duplicate cross-pattern findings.
- [x] **Step 2:** Rank fixes: P0 (blocks core flows: S1, S2, S6, S4), P1 (trust/data bugs: K7, K8, K9, K10), P2 (UX debt: S3 instances, K11, sweep leftovers). Attach effort estimate (S/M/L) per fix.
- [x] **Step 3:** Publish the report as a private artifact (load `artifact-design` skill first) so Ken can share with Jam/Sam.
- [x] **Step 4:** Final summary message: root causes of Sam's bugs, count of new findings, where the report lives. **No code fixes in this plan** — fixes are the next plan, one systematic-debugging + TDD cycle each.

---

## Appendix — Page inventory (audit matrix rows)

Auth/FTUE: `splash_page`, `ftue_page`, `login_page`, `register_page` (+`_role_step`, `_form_step`), `phone_auth_page`, `forgot_password_page`, `verify_email_page`, `onboarding_completion_sheet` (widget)
Home: `home_shell_page`, `home_page` (+`home_builder_bento`, `home_tradie_availability`), `home_map_view`, `jobs_map_page`
Discovery: `discovery_page`, `discovery_map_page`
Jobs: `jobs_page`, `builder_listings_view`, `job_create_page`, `job_detail_page` (+loader), `job_apply_sheet`
Applications: `applications_page`, `job_applicants_page`, `applicant_detail_page`
Messaging: `messages_page`, `message_thread_page` (+`_input`)
Notifications: `notifications_page`
Profile: `profile_page` (+`_trade`), `profile_edit_hub_page`, `about_edit_page`, edit sheets (`identity_sheet` et al.), `builder_public_profile_page`, `availability_calendar_page`, `notification_settings_page`, `settings_page`
Quotes: `quote_requests_inbox_page` · Reviews: `reviews_page` · Scheduling: `schedule_page` · Timesheets: `timesheet_page`
Verification: `verification_page`, `verification_wizard_page`, `manual_upload_sheet`/`_form`
Legal: `legal_index_page`, `legal_document_page`

Out of scope: `lib/admin/**`, `lib/website/**` (not in the mobile release Sam is testing), `dev_*`/`design_preview`/`logo_animation` dev-only pages (verify they're not linked in release, then skip).
