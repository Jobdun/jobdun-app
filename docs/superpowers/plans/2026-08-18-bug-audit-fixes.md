# Live Bug Audit Fixes Implementation Plan (2026-08-18)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every code-fixable finding from `docs/BUG_AUDIT_2026-08-18.md` (Sam's 6 live bugs + the sweep findings), plus any quick wins from the supplemental hunt, on branch `fix/live-bug-audit-2026-08-18`.

**Architecture:** Client-side Flutter fixes grouped into one commit per bounded area (P0 first). The audit report is the spec — every task below cites its section. Errors are converted into the app's existing typed channels (`UploadGuardException`, `Failure`, friendly-copy mappers) rather than new frameworks. DB/backend items produce migration files; prod pushes are called out explicitly and done last.

**Tech Stack:** Flutter/Dart, Riverpod 3 Notifiers, GoRouter, Supabase. Tests with `flutter test` + mocktail. Verify with `bash scripts/validate.sh`.

**Out of scope (documented, needs Ken):** Twilio paid upgrade (payment action); S5 trade-type-at-signup (Ken+Sam product decision — recommended option A in report §S5).

---

### Task 1: FTUE slide-3 escapes (S4, P0-2)

**Files:** Modify `lib/features/ftue/presentation/pages/ftue_page.dart` (+ its widgets file if the header lives there). Test: `test/features/ftue/ftue_page_test.dart`.

- [ ] Show the back caret on every slide when there is somewhere to go: slide 0 + `fromLogin` → `/login`; slide ≥1 → previous slide (all users).
- [ ] Keep the LOG IN link for `fromLogin` users (remove the `widget.fromLogin ? null :` guard).
- [ ] Add `PopScope`: system back steps back one slide; on slide 0 pops through (or goes `/login` when `fromLogin`).
- [ ] Widget test: pump FTUE with `fromLogin: true`, page to slide 3, assert back caret + LOG IN link present; simulate pop → assert slide 2.
- [ ] Commit `fix(ftue): restore back/login escapes on role slide + PopScope`.

### Task 2: Camera pick pipeline (S6, P0-3)

**Files:** Modify `lib/core/services/image_upload_service.dart`, `lib/features/profile/presentation/widgets/identity_sheet.dart` (path per audit), `lib/features/messaging/presentation/pages/message_thread_page.dart:187-209`, `lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart:135-188`. Test: `test/core/services/image_upload_service_test.dart`.

- [ ] Inside `pickCropCompress`: wrap pick/crop/compress in try/catch; map `PlatformException` codes (`camera_access_denied`, `photo_access_denied`, `no_available_camera`, `already_active`) + compress errors to `UploadGuardException` with human copy; `null` stays cancel-only.
- [ ] `identity_sheet.dart`: existing `on UploadGuardException` catch now receives camera failures (verify the error renders); keep behavior.
- [ ] `message_thread_page.dart:200`: replace `on Exception { return; }` with `on UploadGuardException` → SnackBar with the message (+ generic fallback catch with copy).
- [ ] `onboarding_completion_sheet.dart:187`: consume `uploadAvatar`'s bool; on false show a non-blocking "Photo didn't upload — add it later from your profile" note (don't fail onboarding).
- [ ] Unit tests for the PlatformException→copy mapping.
- [ ] Commit `fix(media): surface camera failures instead of silently discarding them`.

### Task 3: Verification UX trio (S1, P0-4 + P1-11 blank page)

**Files:** Modify `lib/features/profile/presentation/providers/profile_provider.dart:66-73`, `lib/features/verification/presentation/widgets/manual_upload_sheet.dart:146-152`, `lib/features/verification/data/datasources/verifications_remote_datasource.dart:104-113`, `lib/features/verification/presentation/widgets/verification_receipts.dart:80-90`, `lib/features/verification/presentation/pages/verification_wizard_page.dart:221-225`, `lib/features/verification/presentation/pages/verification_page.dart`. Test: verification widget/unit tests alongside.

- [ ] `ProfileController.build()` self-loads via `Future.microtask(_load)` (canonical `ftue_gate_provider` pattern); make `loadProfile` idempotent/coalescing so Home/Profile double-hydration is harmless.
- [ ] Phone gate in `manual_upload_sheet` treats *unknown* profile as unknown: while profile is null show loading (never the phone-verify block).
- [ ] Friendly error mapping for `verify-abn`/`verify-licence` non-2xx: map `unauthenticated`→"Your session expired — log in again", 429→"Too many attempts — try again in a few minutes", `db_error`/other→generic copy. No raw bodies to UI (datasource-level).
- [ ] `verification_receipts.dart`: replace `sub: '$e'` with fixed copy + RETRY.
- [ ] `verification_wizard_page.dart:223`: no empty-uuid query — if `currentUserIdSync == null`, render the signed-out error state instead.
- [ ] `verification_page.dart`: replace blank `SizedBox.shrink()` + `go` with a real redirect that preserves the stack (`pushReplacement` to wizard) and a fallback scaffold with back button.
- [ ] Commit `fix(verification): kill false phone gate, raw error copy, blank stranding page`.

### Task 4: Auth — Apple SSO + error hygiene (K10, P0-5 + P1-12)

**Files:** Modify `lib/features/auth/presentation/providers/auth_provider.dart` (`:332-355`, `:146-150`, `:456-464`), `lib/features/auth/presentation/providers/auth_state.dart:81`, `lib/features/auth/presentation/pages/login_page.dart:257-262`, `lib/features/auth/presentation/pages/register_page_role_step.dart:116-120`, `lib/features/auth/presentation/pages/phone_auth_page.dart:279-280`, `lib/features/auth/presentation/pages/verify_email_page.dart:34-37`, `lib/features/auth/presentation/providers/auth_provider_phone.dart:89-99`. Tests: extend existing auth provider tests.

- [ ] Apple: catch `SignInWithAppleAuthorizationException` with `code == canceled` → silent return (mirror Google's guard); don't Sentry-report cancels.
- [ ] Hide the Apple tile on Android (`Platform.isIOS` guard at both call sites).
- [ ] `resendPhoneOtp()` → `Future<bool>`; phone + email resend start the cooldown only on success (and await the email resend).
- [ ] `signOut()`: try/catch — on failure still clear local session state.
- [ ] `AuthState.copyWith`: stop silently dropping `errorMessage`/`infoMessage` on unrelated updates (sentinel-based copyWith); clear error state on route change (listener or explicit clears in page inits).
- [ ] Commit `fix(auth): Apple cancel/Android tile, honest resend cooldowns, signOut + state hygiene`.

### Task 5: Keyboard pass (S3, P0-6)

**Files:** Modify `lib/app/app.dart:44-48`, `lib/core/design/widgets/edit_sheet_scaffold.dart`, `lib/features/jobs/presentation/pages/job_create_page.dart:345`, `lib/features/profile/presentation/pages/about_edit_page.dart`, `lib/features/messaging/presentation/pages/message_thread_page.dart:361`, `lib/features/verification/presentation/widgets/wizard_abn_step.dart`, plus the sheet scrollables listed in audit §S3 table.

- [ ] App-level tap-to-unfocus: translucent `GestureDetector` in the `MaterialApp.router` `builder` calling `FocusManager.instance.primaryFocus?.unfocus()`.
- [ ] `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` on: job-create scroll, about-edit scroll, message thread list, ABN step scroll, `EditSheetScaffold` scroll, apply/quote/review/report sheet scrollables.
- [ ] Commit `fix(ux): app-wide keyboard dismissal (tap-outside + drag)`.

### Task 6: Fabricated feed data (K7+K8, P1-7/8)

**Files:** Modify `lib/features/jobs/presentation/pages/jobs_page.dart:348-351`, `lib/features/home/presentation/pages/home_page.dart:361-363`, `lib/features/jobs/presentation/pages/jobs_page_widgets.dart:167-169`, `lib/features/jobs/domain/entities/job.dart:193`, `lib/core/services/maptiler_places_service.dart:186-194` (or the pick handler in `job_create_page.dart:218-221`).

- [ ] `distanceKm: null` in the Find feed (chip hides per `JobCard` contract).
- [ ] `startDate` fallback `'TBD'` at all 3 call sites (match `job_detail_args.dart:55-57`).
- [ ] `displayLocation` null/empty-tolerant join (copy `trade_profile.dart:90-92` pattern) — fixes map callouts + builder listings too.
- [ ] Reject region/country-level MapTiler picks (require a real locality + state before accepting the selection).
- [ ] Commit `fix(jobs): no fabricated distance/start data, tolerant location join, region-pick guard`.

### Task 7: Licence truth split + completeness (K9, P1-9)

**Files:** Modify `lib/features/profile/domain/entities/trade_profile.dart:87`, `lib/features/profile/presentation/providers/profile_provider.dart:89-101,330-356`, `lib/features/profile/presentation/widgets/profile_completeness_banner.dart:56-69`.

- [ ] Completeness + nag treat a verified `public.verifications` licence row as "has licence" (bridge via the existing verification providers/datasource at the provider seam — domain stays pure).
- [ ] Stop swallowing profile-load failures (`fold((_) {}, …)`) — set error state; banner hides on loading AND error (no "0%", no false analytics event).
- [ ] Commit `fix(profile): completeness honours wizard-verified licence + honest banner states`.

### Task 8: Settings + routes (K11, P1-10)

**Files:** Modify `lib/app/router/app_router.dart:383-386,446`, `lib/features/settings/presentation/pages/settings_page.dart:83-87,114-117,220`.

- [ ] Remove the duplicate `/schedule` shell branch so the real `SchedulePage` (bookings) is reachable; keep availability calendar on its own route; fix the two wrong-landing call sites (`home_status_bar.dart:46`, `account_sheet.dart:111`) to point at the intended pages.
- [ ] "Change password" row → sends the existing reset-password email (reuses the shipped 2026-07-31 flow) + confirmation SnackBar.
- [ ] Remove "Change email" and "Privacy settings" rows (no backing flows; don't ship dead chevrons); `_ActionRow` requires a real onTap (no `?? () {}`).
- [ ] Commit `fix(settings): reachable schedule page, working password row, no dead rows`.

### Task 9: Remaining nav traps (P1-11 rest)

**Files:** Modify `lib/features/auth/presentation/pages/verify_email_page.dart`, `lib/features/auth/presentation/widgets/onboarding_completion_sheet.dart:43-45,222,253-257`.

- [ ] `/verify-email`: add an explicit "Back to log in" escape that clears `pendingVerificationEmail` (router stops forcing the page).
- [ ] Onboarding sheet: role step gets `onBack`; failure state gets RETRY + a "Log out" escape link; sheet no longer an unrecoverable trap offline.
- [ ] Commit `fix(auth): escapes for verify-email and onboarding traps`.

### Task 10: Empty-looks-real sweep (P6, P2-13)

**Files:** the 13 screens listed in audit §P6 (profile_completeness_banner done in Task 7). Pattern source: `jobs_page_widgets.dart:35-76` `_PageError`.

- [ ] Priority order: verification_receipts counterparty (`:115-117`), applicant_detail chips, avatar verified rings, applications_page, messages_page, reviews_page, profile_page/provider, home_builder_bento, schedule_page, builder_listings_view, profile_reviews_preview, legal_index_page.
- [ ] Each gets an error branch (inline error + RETRY where a list; conservative "—/unknown" rendering where a chip/ring) instead of defaulting to confident empty data.
- [ ] Commit `fix(ux): failed loads render as errors, not confident empty data (13 screens)`.

### Task 11: Verification backend tidy (P4, P2-14) — code + migration files

**Files:** Create `supabase/migrations/<ts>_verifications_unique_user_kind.sql` (+ rollback in `supabase/rollbacks/`); modify `supabase/functions/_shared/rate-limit.ts:33-49`, `supabase/functions/verify-licence/index.ts` client parse (`lib/features/verification/data/models/verification_model.dart:118-119`, `wizard_licence_step.dart:156-160`), `lib/features/verification/presentation/providers/verification_provider.dart:80-96`.

- [ ] Migration: dedupe then `UNIQUE(user_id, kind)` on `public.verifications`.
- [ ] `rate-limit.ts`: catch the read error (fail-open with log), drop the phantom `increment_rate_limit` RPC call.
- [ ] Client parses `detail` for human copy; unknown status parses defensively (no user-facing FormatException).
- [ ] Realtime invalidation listens to `verifications` changes (admin revoke reflects without restart).
- [ ] Deploy edge fn + push migration to **staging first, then prod** (memory: staging has no migration history — push schema to BOTH). Prod push called out in final report.
- [ ] Commit `fix(verification-backend): unique rows, rate-limit resilience, human detail copy, live revoke`.

### Task 12: Media/pipeline extras + docs drift (P3, P2-15/16)

**Files:** Modify `lib/core/services/image_upload_service.dart:80-113`, `lib/features/verification/presentation/widgets/manual_upload_sheet.dart`, `CLAUDE.md` (bucket list), `.env` (trailing slash).

- [ ] PDF path for verification docs: `file_picker` (already a dependency) wired into manual upload; MIME/extension guard that doesn't produce "We can't accept .IMG_0421".
- [ ] CLAUDE.md storage-bucket list → real buckets (`public-media`, `private-docs`, `chat-attachments`); fix `.env` trailing slash.
- [ ] Commit `chore(media,docs): pdf upload path, sane extension guard, docs drift`.

### Task 13: Ops (no code)

- [ ] Raise prod `sms_otp_exp` 60→300 via Management API (token from keychain per `reference_supabase_project`). Do NOT touch the test-OTP override or appreview account.
- [ ] Twilio upgrade: NOT doable by agent (payment) — restate in final report.

### Task 14: Supplemental-hunt triage

- [ ] When the three hunter agents return: fix confirmed P0/P1 quick wins in-line (same commit discipline); append everything found to `docs/BUG_AUDIT_2026-08-18.md` as an addendum with fixed/deferred status.

### Task 15: Verification + wrap-up

- [ ] `bash scripts/validate.sh` green (format, analyze, tests, design checks).
- [ ] superpowers:verification-before-completion — spot-check each fix's diff against the audit citation.
- [ ] Update `docs/BUG_AUDIT_2026-08-18.md` fix-list items with ✅ status; republish the artifact (same URL); update memory.
