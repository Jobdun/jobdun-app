# App Review — 1.0 (5) resubmission pack

Rejection being answered: **Submission 3cc8d879-1085-4413-b514-5f2ec165f13b**,
reviewed 2026-07-15 on iPhone 17 Pro Max + iPad Air 11-inch (M3), version 1.0 (4).
Two findings: Guideline **5.1.1(v)** (registration required to browse jobs) and
Guideline **4** (Sign in with Apple asked for name/email again).

Both are fixed in code in build 5 — this file carries (A) the Resolution Center
reply, (B) the App Review notes for the new submission, and (C) the Console
steps Ken performs.

---

## A. Resolution Center reply (paste as the message on the rejected submission)

> Hello,
>
> Thank you for the detailed review. Both issues are resolved in build 1.0 (5):
>
> **Guideline 5.1.1(v) — account-free browsing.** The app no longer requires
> registration to browse posted jobs. From the first-launch screens, tapping
> "BROWSE OPEN JOBS" (also available as "Browse open jobs" on the log-in
> screen) opens the public job board: real open jobs, search, trade filters,
> and complete job details — no account, no personal information. An account
> is only requested for the account-based features themselves: submitting a
> quote/application, saving jobs, messaging, and viewing builder profiles.
>
> **Guideline 4 — Sign in with Apple.** After authenticating with Apple, the
> app no longer shows any name or email entry. The name provided by the
> Authentication Services framework is used as-is (including when the user
> chooses to hide their email). The only remaining post-sign-in step asks the
> user to choose their marketplace role (Builder or Tradie) — app-specific
> information Apple does not provide — plus an optional, skippable profile
> photo.
>
> Testing notes for both fixes are in the App Review Information section.
> Thank you again — happy to answer anything else.

## B. App Review notes (App Review Information → Notes field for 1.0 (5))

```
WHAT CHANGED SINCE 1.0 (4)

1) Browse without an account (5.1.1(v)):
   • Launch the app → on the last intro screen tap "BROWSE OPEN JOBS"
     (or on the log-in screen tap "Browse open jobs").
   • You land on the public job board: live job list, search, trade filters,
     and full job details — no sign-in, no data entry.
   • Tapping QUOTE THIS JOB, a builder profile, or saving a job shows the
     account prompt — those are account-based features (applications,
     bookmarks, messaging). Everything else stays open.

2) Sign in with Apple (Guideline 4):
   • On the log-in screen choose Sign in with Apple with any Apple ID
     (Hide My Email works too).
   • After authentication the app asks only for the marketplace role
     (Builder or Tradie) and offers an optional profile photo (SKIP).
   • The app never asks for your name or email — the name Apple provides is
     used automatically.

DEMO ACCOUNT (Trade role): unchanged — sign in with the provided email +
password using the email option. The account is pre-onboarded and lands on
the home feed.
```

## C. Console-side steps (Ken)

1. **Archive + upload build 5**: `flutter build ipa --release` (version is
   `1.0.0+5` from pubspec), then upload the `.ipa` via Xcode Organizer or
   Transporter. (Or the usual Xcode Product → Archive flow — the build number
   now flows from pubspec, no manual bump needed.)
2. In App Store Connect → the 1.0 version page → replace the rejected build
   with build 5.
3. Paste section **A** as the reply in the Resolution Center thread (replying
   keeps the same review context).
4. Replace the review **Notes** with section **B**; leave the demo-account
   sign-in info as-is; verify `appreview@jobdun.com.au` still signs in on a
   release build first (existing checklist item in APP_STORE_METADATA.md).
5. Screenshots: current screenshots remain valid (no store-screenshot claims
   changed). Optional: add one showing the public job board later.
6. Submit for review.

## Evidence in this branch

- Root causes + design: `docs/superpowers/plans/2026-07-20-appstore-guest-browse-siwa.md`
- DB: `supabase/migrations/20260720000001_jobs_public_browse.sql` (anon view,
  live on zethpanvkfyijislxesn; base-table RLS unchanged — verified via anon
  REST probes).
- E2E on the reviewer's device model (iPhone 17 Pro Max simulator):
  `integration_test/guest_browse_flow_test.dart` → screenshots
  `docs/verification/2026-07-20-ios-guest-*.png`.
- Regression tests: `test/app/guest_routing_test.dart`,
  `test/features/auth/onboarding_completion_sheet_test.dart`,
  `test/features/auth/onboarding_gate_test.dart`, `test/features/auth/sso_identity_test.dart`,
  `test/features/jobs/guest_read_path_test.dart`.
