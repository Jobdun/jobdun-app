# Profile Page — Comprehensive Improvement Plan

> **Generated:** 2026-05-21
> **Scope:** `/profile`, `/profile/edit`, `/verification`, and the account-creation seam (sign-up → role assignment → first profile save).
> **Related audits:** `docs/UI_MODERN_AUDIT.md`, `docs/AUTH_ONBOARDING_AUDIT.md`, `docs/RBAC_SUPABASE_AUDIT.md`, `docs/JOBDUN_SCHEMA.md`.
> **Companion code (do not duplicate):** `lib/features/profile/`, `lib/features/auth/`, `supabase/migrations/2026051*.sql`.

---

## 0 · TL;DR

The profile + account-creation flow is **mostly wired correctly**. Every form field on `/profile/edit` currently maps to a real column and persists through `ProfileController.saveProfile`. The sign-up trigger (`handle_new_user`) seeds the right rows on every signup path. The completeness banner and verification document upload both work.

The **gap is in coverage, not correctness**. About a dozen schema columns are already defined (model layer reads them, profile page sometimes displays them) but `/profile/edit` has no field to set them. The biggest user-visible miss is **no in-app avatar picker** — `uploadAvatar` exists in the provider, no UI invokes it. The biggest hidden tech-debt items are a **dead `completeOnboarding()` method**, a **dormant `profiles.bio` column**, and a **divergence between `display_name` and `full_name`** that has no documented intent.

This doc inventories the gap and stages it into five sprints, prioritised so anyone (you or a future agent) can pick up a single one and ship it without unpicking the others. **No new schema is required for Sprints P1, P3, or P4** — they're pure UI-wiring sprints against columns that already exist. Only **Sprint P2 ships a migration** (column cleanup).

---

## 1 · Current State Snapshot

### 1.1 What works (keep)

| Surface | Verified-working path |
|---|---|
| Sign-up | `register_page` collects `full_name` + `email` + `password` + `role` → `auth.signUp(data:)` → `handle_new_user` trigger seeds `profiles`, `user_roles`, role-specific stub |
| Role assignment for SSO | `RoleSelectionSheet` → `setRoleAndStubProfile` → INSERT (never UPDATE — gated by the `forbid_role_mutation` trigger from `20260520000001`) → JWT refresh |
| Hydrate role from DB on JWT-claim race | `hydrateRoleFromDb` covers the gap when the `custom_access_token_hook` isn't wired in the Supabase Dashboard |
| Profile edit save | `_save()` → `ProfileController.saveProfile` writes to `profiles` + role-specific table in a single try-block; reload after |
| Trade licence upload | `verification_page._pick` → `ImageUploadService.pickCropCompress(aspect: free, quality: 88)` → `uploadTradeLicence` → sets `trade_profiles.licence_url` |
| Portfolio | `portfolio_strip` → 4:3 crop pipeline → `addPortfolioImage` → `trade_profiles.portfolio_urls` array; long-press to remove |
| Phone verification | `/profile/verify-phone` uses `PhoneAuthMode.addToAccount` → sets `profiles.phone_verified_at` |
| Completeness banner | Server-side `profile_completeness` view, scoped to `auth.uid()`, drives the home banner |

### 1.2 What's broken or dead

| # | Issue | File / location | Impact |
|---|---|---|---|
| B1 | `completeOnboarding()` is **never called** — `/onboarding` route was removed in T1.3, the redirect now routes `/onboarding → /home`. Method body still tries to set `onboarding_completed_at`, but nothing invokes it. | `auth_provider.dart:575-646` | `profiles.onboarding_completed_at` is permanently NULL on every user. `AuthState.onboardingComplete` is permanently `false`. Currently no router gate uses it, so the app works — but it's a landmine for the next person who adds a "has onboarded?" check. |
| B2 | `profiles.bio` is **read but never written** | schema has the column, `UserProfile.bio` reads it, `ProfileController.uploadAvatar` preserves it on rebuild, but the `/profile/edit` "About" field saves to `builder_profiles.about` / `trade_profiles.about` — never to `profiles.bio` | Dormant column. Migration story unclear: was it intended to be the canonical bio, then split into role-specific? |
| B3 | No in-app avatar picker | `profile_edit_page.dart` has no upload affordance | `uploadAvatar` dead code unless invoked elsewhere. Users see whatever avatar is in DB (set by SSO providers or admin); can't change in-app. |

### 1.3 Schema columns that exist but are never editable

| Table | Column | Read path | Editable? |
|---|---|---|---|
| `profiles` | `bio` | `UserProfile.bio` | ❌ |
| `profiles` | `avatar_url` | `_ProfileHeader` shows it via `CachedNetworkImage` | ❌ (no picker) |
| `builder_profiles` | `website` | `BuilderProfile.website` | ❌ |
| `builder_profiles` | `years_in_business` | `BuilderProfile.yearsInBusiness` | ❌ |
| `builder_profiles` | `contact_name` | not in entity? | ❌ |
| `builder_profiles` | `logo_url` | not surfaced | ❌ (duplicate of `profiles.avatar_url`?) |
| `builder_profiles` | `service_postcode` | `BuilderProfile.servicePostcode` | ❌ (form has suburb + state only) |
| `builder_profiles` | `description` | possibly legacy — form uses `about` | ❌ |
| `trade_profiles` | `years_experience` | `TradeProfile.yearsExperience`, shown on `/profile` as `YRS EXP` stat | ❌ |
| `trade_profiles` | `hourly_rate` | legacy single-value rate | ❌ |
| `trade_profiles` | `day_rate` | legacy single-value rate | ❌ |
| `trade_profiles` | `hourly_rate_min` | newer range form | ❌ |
| `trade_profiles` | `hourly_rate_max` | newer range form | ❌ |
| `trade_profiles` | `hourly_rate_visible` | privacy toggle | ❌ |
| `trade_profiles` | `base_postcode` | `TradeProfile.basePostcode` | ❌ (form has suburb + state only) |
| `trade_profiles` | `bio` | legacy — form uses `about` | ❌ |

### 1.4 Subtle behaviours

- **Display name vs full name divergence (tradies).** Sign-up seeds `profiles.display_name` and `trade_profiles.full_name` from the same metadata. The /profile/edit form exposes both as separate fields. Post-signup, they can drift. No documented intent.
- **Builders lose their personal name post-signup.** `handle_new_user` writes the builder's name to `profiles.display_name`. The builder-side `/profile/edit` form only has `display_name`, `company_name`, `abn`, `contact_phone`, `service_suburb`, `service_state`, `about`. Builder can rename `display_name` to anything; no "real name" field for legal/invoicing.
- **`/verification` post-mount bounce.** Builders deep-linking to `/verification` are kicked back via `addPostFrameCallback`. Brief flash of the page is possible before the redirect.
- **`onboarding_completed_at` always NULL.** Per B1 above. Don't add gates that depend on this.

---

## 2 · Sprints

Each sprint is sized so one PR can land it. Effort is T-shirt: **S** = < 2 hours, **M** = half-day, **L** = full day.

### Sprint P1 — Critical Polish (M, ~4–6 hours, no migration)

**Goal:** close the user-facing gaps a real customer would notice in the first hour of use.

| # | Change | Files | Effort |
|---|---|---|---|
| P1.1 | **Avatar picker on `/profile/edit`** — tap the avatar at the top of the page → `showJSheet` with "Take photo" / "Pick from gallery" / "Remove" actions → `ImageUploadService.pickCropCompress(source, aspect: square)` → existing `uploadAvatar`. Hero-animate from `profile_page` avatar so the transition flows. | `profile_edit_page.dart` (avatar header), `profile_provider.dart` (already has `uploadAvatar`) | S |
| P1.2 | **`years_experience` editable for tradies** — already displayed on `/profile`, currently a "—". Add as a `JTextField` with `FormBuilderValidators.integer` + min 0 + max 60. Wire through `saveProfile` (extend the named-arg list). | `profile_edit_page.dart`, `profile_provider.dart::saveProfile`, model already supports it | S |
| P1.3 | **`years_in_business` editable for builders** — same pattern as P1.2. | same files | S |
| P1.4 | **Builder `contact_name` field** — fills the gap where builders lose their personal name. Renders as "YOUR NAME" above "COMPANY NAME" on the builder branch. Pre-fill from `profiles.display_name` on first edit. | `profile_edit_page.dart`, `saveProfile`, entity + model add `contactName` if missing | S |
| P1.5 | **Postcode field (both roles)** — append to the suburb/state row. 4-digit AU postcode validator (`RegExp(r'^\d{4}$')`). Writes to `service_postcode` / `base_postcode`. | `profile_edit_page.dart`, `saveProfile` | S |

**Verification** (run after each item):
- `flutter analyze --no-fatal-infos` clean.
- Manual: edit each new field → save → reopen page → field persists.
- DB check: `SELECT contact_name, service_postcode FROM builder_profiles WHERE id = '<user>'` returns the saved value.

**Risk:** low. Pure UI + named-arg extension. No schema changes, no auth code touched.

---

### Sprint P2 — Schema Cleanup (S, ~2 hours, **one migration**)

**Goal:** remove dead code and dormant columns so the next agent doesn't trip over them.

| # | Change | Files | Effort |
|---|---|---|---|
| P2.1 | **Delete `completeOnboarding()` + its caller hooks** — method body, `onboardingComplete` state field, `_fetchOnboardingStatus`, all reads of `profiles.onboarding_completed_at`. Replace any router checks with role + completeness checks (already used elsewhere). | `auth_provider.dart`, `auth_remote_datasource.dart`, `user_profile_model.dart`, `app_user.dart`, `app_router.dart:72` | S |
| P2.2 | **Decide: keep or drop `profiles.bio`** — recommended action is **drop**. Migration `20260521000001_drop_dormant_columns.sql`: `ALTER TABLE public.profiles DROP COLUMN IF EXISTS bio;` plus drop `onboarding_completed_at` if P2.1 is in the same PR. Remove from `UserProfile` entity + model. | new migration + `user_profile.dart` + `user_profile_model.dart` | S |
| P2.3 | **Decide: keep or drop `builder_profiles.description`** — looks like a legacy duplicate of `about`. If unused everywhere (grep confirms), drop in the same migration. | same migration | S |
| P2.4 | **Decide: keep or drop legacy single-value rates (`hourly_rate`, `day_rate`)** — superseded by `hourly_rate_min`/`max`/`visible` from `20260516000001_schema_reconciliation.sql`. Drop after confirming no read path. | same migration | S |
| P2.5 | **Resolve `logo_url` vs `avatar_url`** — for builders, do we use `profiles.avatar_url` (cross-role consistent) or `builder_profiles.logo_url` (semantically distinct)? Recommended: use `avatar_url` everywhere, drop `logo_url`. Update the bucket policy if you go the other way. | same migration if dropping | S |

**Migration template** (`supabase/migrations/20260521000001_profile_schema_cleanup.sql`):

```sql
-- Drop dormant columns surfaced by docs/PROFILE_IMPROVEMENT_PLAN.md Sprint P2.
-- Safe: every column dropped here has zero read paths in lib/ after the
-- companion Dart changes ship together.
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS bio,
  DROP COLUMN IF EXISTS onboarding_completed_at;

ALTER TABLE public.builder_profiles
  DROP COLUMN IF EXISTS description,
  DROP COLUMN IF EXISTS logo_url;

ALTER TABLE public.trade_profiles
  DROP COLUMN IF EXISTS hourly_rate,
  DROP COLUMN IF EXISTS day_rate,
  DROP COLUMN IF EXISTS bio;
```

**Verification:**
- `flutter analyze` clean after model + entity prunes.
- `supabase db push` applies the migration without dropping data anyone reads.
- Smoke test: sign in as existing user → open profile → all displayed fields render (none were sourced from dropped columns).

**Risk:** medium. Migration is destructive — apply after the companion code is merged. Run `pg_dump` of staging before pushing.

---

### Sprint P3 — Tradie Marketplace Fields (M, ~4–6 hours, no migration)

**Goal:** make the tradie profile useful as a marketplace listing. Right now a tradie can't tell builders their rate.

| # | Change | Files | Effort |
|---|---|---|---|
| P3.1 | **Hourly rate range** — two side-by-side `JTextField`s: `MIN $/hr` and `MAX $/hr`. Integer validator, min ≥ 0, max ≥ min (custom validator). Writes to `hourly_rate_min` + `hourly_rate_max`. Display on `/profile` as `$65–95/hr`. | `profile_edit_page.dart`, `saveProfile`, `profile_page.dart::_TradeProfile` | M |
| P3.2 | **Rate visibility toggle** — `JSwitch` row: "Show my rate to builders". Writes to `hourly_rate_visible` (defaults true). When false, profile shows "Rate on request" instead of the range. | same files | S |
| P3.3 | **Optional skills / specialisations field** — multi-line input or chip picker. Writes to `trade_profiles.required_certifications`? No — that's on `jobs`. Need a new `trade_profiles.skills text[]` column. **This is the one P3 item that needs a migration** if you take it on. Defer if not. | new migration + UI | M |

Decision needed before starting P3.3: do tradies show "skills" (free-text) or "certifications" (curated)? If the latter, source from `trade_categories` rather than a free text array.

**Verification:**
- Manual: set rate range as tradie → builder sees `$X–Y/hr` on their applicant card on `/applications`.
- DB: `SELECT hourly_rate_min, hourly_rate_max, hourly_rate_visible FROM trade_profiles WHERE id = '<user>'` reflects edits.
- Toggle visibility off → profile shows "Rate on request" → toggle on again → range returns.

**Risk:** low for P3.1–P3.2 (columns already exist). Medium for P3.3 (new column + migration + UX decision).

---

### Sprint P4 — Builder Profile Completion (M, ~3–4 hours, no migration)

**Goal:** builders can give tradies enough to decide whether to apply to a listing.

| # | Change | Files | Effort |
|---|---|---|---|
| P4.1 | **Website field** — `JTextField` with `FormBuilderValidators.url(protocols: ['https'])`. Writes to `builder_profiles.website`. Render as a tap-to-launch row on the builder profile page. | `profile_edit_page.dart`, `profile_page.dart::_BuilderProfile`, `saveProfile` | S |
| P4.2 | **Build out builder verification rows** — currently shows three `_VerificationRow`s but only `email_verified` is wired. Wire `phone_verified` (already on `profiles`), `insurance_docs` (would need a new doc type + upload flow — defer or stub for now), `abn_verified` (Australian Business Register API integration — definitely defer). | `profile_page.dart::_BuilderProfile`, possibly `verification_documents` migration if you want to ship insurance docs | M |
| P4.3 | **Service area picker** — currently single suburb. Builders typically service multiple suburbs ("Inner West Sydney"). Add an `additional_service_suburbs text[]` array column + chip multi-select. **Needs a migration.** Defer if not in scope. | new migration + UI + chip picker | L |

**Verification:**
- Manual: builder edits website → save → profile shows the URL → tap opens in browser.
- Manual: builder profile page renders all three verification rows with correct status.

**Risk:** low for P4.1. Higher for P4.2 if it touches the verification flow (which has RLS + admin review queue implications).

---

### Sprint P5 — Account Creation Hardening (S, ~2–3 hours, no migration)

**Goal:** smooth the cracks at the sign-up seam.

| # | Change | Files | Effort |
|---|---|---|---|
| P5.1 | **Pre-fill `profile_edit_page` after first sign-in** — currently a brand-new user lands on `/home`, sees the completeness banner, taps it, lands on `/profile/edit` with empty fields. Pre-fill `display_name` and `full_name` from the auth metadata so the user doesn't retype what they entered at sign-up. | `profile_edit_page.dart::initState` | S |
| P5.2 | **Set `onboarding_completed_at` on first successful `saveProfile`** (only if you keep the column — see P2.1). Otherwise drop the column and the state field. | `profile_provider.dart::saveProfile`, plus the schema-removal migration | S |
| P5.3 | **Reconcile `display_name` vs `full_name`** — decision: (a) collapse into one — display_name is the only field, full_name dropped from trade_profiles; or (b) keep both with clearer labels: "Display name (shown publicly)" vs "Legal name (for invoices)". Recommend (b). Update form labels + helper text. | `profile_edit_page.dart` field labels, no schema change | S |
| P5.4 | **`/verification` builder-bounce flash** — replace `addPostFrameCallback` redirect with a synchronous early-return that renders a small "Builders don't need verification" card with a back button. No flash. | `verification_page.dart` | S |

**Verification:**
- Fresh sign-up → email verify → home → tap banner → profile edit shows pre-filled name.
- Save profile once → DB check: `onboarding_completed_at IS NOT NULL` (if column retained).
- Builder navigates to `/verification` → no flash, sees the explainer card.

**Risk:** low across the board.

---

## 3 · Migration Inventory

Only one migration is required for the entire plan (P2). Everything else is UI-wiring against existing columns.

| Migration | Sprint | Reversible? | Notes |
|---|---|---|---|
| `20260521000001_profile_schema_cleanup.sql` | P2 | No (DROP COLUMN destroys data) | Apply after the companion Dart changes merge so no live reader breaks |
| Optional: `2026052100000X_trade_skills.sql` | P3.3 | Yes (add nullable column) | Only if you take P3.3 |
| Optional: `2026052100000Y_builder_service_areas.sql` | P4.3 | Yes (add nullable column) | Only if you take P4.3 |
| Optional: `2026052100000Z_insurance_documents.sql` | P4.2 | Yes (add row to enum) | Only if you ship insurance doc upload |

**Apply procedure for the destructive one (P2):**
1. Confirm zero read paths in `lib/` via grep before merging the companion code.
2. Take a staging `pg_dump` of `profiles`, `builder_profiles`, `trade_profiles`.
3. Merge code + migration in the same PR.
4. `supabase db push` on staging.
5. Verify the staging app boots, profile page renders, sign-up still works.
6. Apply to production during a quiet window.

---

## 4 · Per-File Touch Map

Each sprint's surface, so a reviewer can predict the diff.

| File | P1 | P2 | P3 | P4 | P5 |
|---|---|---|---|---|---|
| `lib/features/profile/presentation/pages/profile_edit_page.dart` | ✓✓✓✓✓ | ✓ | ✓✓ | ✓ | ✓ |
| `lib/features/profile/presentation/providers/profile_provider.dart` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `lib/features/profile/presentation/pages/profile_page.dart` |   |   | ✓ | ✓ |   |
| `lib/features/profile/data/models/*.dart` |   | ✓ |   |   |   |
| `lib/features/profile/domain/entities/*.dart` |   | ✓ |   |   |   |
| `lib/features/auth/presentation/providers/auth_provider.dart` |   | ✓ |   |   | ✓ |
| `lib/features/auth/data/models/user_model.dart` |   | ✓ |   |   |   |
| `lib/features/auth/data/datasources/auth_remote_datasource.dart` |   | ✓ |   |   |   |
| `lib/features/verification/presentation/pages/verification_page.dart` |   |   |   | ✓ | ✓ |
| `lib/app/router/app_router.dart` |   | ✓ |   |   |   |
| `supabase/migrations/*` |   | ✓ |   |   |   |

---

## 5 · Verification Checklist (apply per sprint)

```
[ ] flutter analyze --no-fatal-infos    (clean — 3 pre-existing infos OK)
[ ] dart format --output=none --set-exit-if-changed .
[ ] flutter test test/features/         (current baseline: 69/69)
[ ] bash scripts/validate.sh            (design-system grep checks)
[ ] Manual smoke (per item):
    [ ] Sign-up new user → fields seeded → can edit → save persists → re-open shows saved values
    [ ] Existing user → load profile → all fields render → edit a single field → save → reload
    [ ] Each role (builder + tradie) tested independently — the form forks heavily
    [ ] Trade licence upload still works (P2 cleanup risk surface)
    [ ] Avatar picker (P1) — gallery + camera + cancel mid-crop all behave
[ ] Migration verification (P2 only):
    [ ] pg_dump staging before push
    [ ] supabase db push completes without DROP COLUMN errors
    [ ] No reader in lib/ references a dropped column (grep)
    [ ] Profile completeness view still computes (it doesn't touch the dropped cols)
```

---

## 6 · Risks

| Risk | Mitigation |
|---|---|
| **P2 destructive migration applied before code merges** | Single PR for both; don't push to prod until staging proves out |
| **Avatar picker breaks the existing `avatarUrl` render** in `_ProfileHeader` | The CachedNetworkImage already has `errorWidget` falling back to `AvatarBlock` — safe |
| **`hourly_rate_min > hourly_rate_max`** if validator isn't cross-field | Use `FormBuilderField.builder` to read both values; add a custom validator that compares them on submit |
| **Builders deep-linking to `/verification` after P5.4 still see the bounce screen on cold start** if role hasn't loaded yet | Gate on `auth.isRoleLoaded` — show a brief skeleton until role resolves, then route or render the explainer |
| **`completeOnboarding` removal breaks an undiscovered caller** | Grep before deleting; `git log -p auth_provider.dart` to confirm no recent ref |
| **Postcode validation rejects valid Australian alphanumeric ranges** (Norfolk Island = 2899; ACT = 0200) | Use `^\d{3,4}$` not `^\d{4}$`, or skip validation and let backend normalize |

---

## 7 · Appendix — Full Field Inventory

Source of truth for what's in the schema today, what the model reads, and what's editable.

### profiles

| Column | In model | In form? | Sprint |
|---|---|---|---|
| `id` | ✓ | (auth-managed) | — |
| `display_name` | ✓ | ✓ | shipped |
| `phone` | ✓ | (via `/profile/verify-phone`) | shipped |
| `phone_verified_at` | ✓ | (via verify flow) | shipped |
| `avatar_url` | ✓ | ❌ no picker | P1.1 |
| `bio` | ✓ | ❌ never written | P2.2 (drop) |
| `onboarding_completed_at` | ✓ | ❌ never set | P2.1 (drop) |
| `created_at` / `updated_at` | ✓ | (auto) | — |

### builder_profiles

| Column | In model | In form? | Sprint |
|---|---|---|---|
| `id` | ✓ | (auto-keyed) | — |
| `company_name` | ✓ | ✓ | shipped |
| `abn` | ✓ | ✓ | shipped |
| `contact_name` | ❌? | ❌ | P1.4 |
| `contact_phone` | ✓ | ✓ | shipped |
| `about` | ✓ | ✓ | shipped |
| `website` | ✓ | ❌ | P4.1 |
| `years_in_business` | ✓ | ❌ | P1.3 |
| `service_suburb` | ✓ | ✓ | shipped |
| `service_state` | ✓ | ✓ | shipped |
| `service_postcode` | ✓ | ❌ | P1.5 |
| `logo_url` | ❌ | ❌ | P2.5 (drop or wire) |
| `description` | ❌ | ❌ legacy duplicate | P2.3 (drop) |

### trade_profiles

| Column | In model | In form? | Sprint |
|---|---|---|---|
| `id` | ✓ | (auto-keyed) | — |
| `full_name` | ✓ | ✓ | shipped |
| `primary_trade` | ✓ | ✓ | shipped |
| `trade_other` | ✓ | ✓ (when slug == 'other') | shipped |
| `is_verified` | ✓ | (server-set) | — |
| `licence_url` | ✓ | (via `/verification`) | shipped |
| `about` | ✓ | ✓ | shipped |
| `bio` | ❌ | ❌ legacy | P2 (drop) |
| `portfolio_urls` | ✓ | (via portfolio_strip) | shipped |
| `base_suburb` | ✓ | ✓ | shipped |
| `base_state` | ✓ | ✓ | shipped |
| `base_postcode` | ✓ | ❌ | P1.5 |
| `years_experience` | ✓ | ❌ | P1.2 |
| `hourly_rate` | ✓ legacy | ❌ | P2 (drop) |
| `day_rate` | ✓ legacy | ❌ | P2 (drop) |
| `hourly_rate_min` | ✓ | ❌ | P3.1 |
| `hourly_rate_max` | ✓ | ❌ | P3.1 |
| `hourly_rate_visible` | ✓ | ❌ | P3.2 |

---

## 8 · Skills & Design-System Usage Protocol

> **This section is binding.** Every sprint in §2 starts by invoking the
> skills below, in the order shown. Don't skip — the design-system docs
> drift fast; the skills regenerate the latest stack-aware guidance.

### 8.1 Skills to invoke (always, before any UI work)

| When | Skill | Command | Purpose |
|---|---|---|---|
| **Before** starting a sprint | `ui-ux-pro-max` | `python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<topic>" --stack flutter` | Fetch the latest Flutter-specific style + a11y + animation guidance. The static MASTER file is a snapshot; the skill produces fresh recommendations. |
| **Before** designing a new component or screen affordance | `frontend-design` | invoke via the `Skill` tool | Cross-checks the component against modern interaction patterns (Lucide-style icon hygiene, hover/cursor rules, light/dark contrast, layout pitfalls). |
| **After** drafting the implementation | `ui-ux-pro-max` (review mode) | `... --domain ux "animation accessibility"` | Sanity-check the change for reduce-motion, contrast, touch-target size before merging. |

**Per-sprint trigger words** for the `ui-ux-pro-max` search — pick one that matches the work, don't run a generic search:

- **P1** — `"profile avatar upload mobile picker"` and `"form field number validation"`.
- **P2** — `"schema migration safe drop column"` (not stack-specific, skip the search; rely on the MASTER's "destructive changes" rules instead).
- **P3** — `"marketplace listing rate visibility toggle"` and `"profile dashboard tradie service worker"`.
- **P4** — `"company profile website link"` and `"verification badge status row"`.
- **P5** — `"first run onboarding signup nudge"` and `"empty state CTA mobile"`.

### 8.2 Design-system file order of consultation

Per `CLAUDE.md`'s "Design System" block:

1. **First** read `design-system/jobdun/MASTER.md` — global tokens, anti-patterns.
2. **Second** check `design-system/jobdun/pages/profile-dashboard.md` — overrides for this surface.
3. **Third** invoke the skill (§8.1) for delta guidance the static docs don't capture.

When the static docs disagree with the shipped code, **code wins** (per MASTER §"Sources of Truth"). Surface the drift in the same PR — patch the doc, don't just code around it.

### 8.3 Doc-sync done in this plan

The audit found drift between the static docs and the code shipped in UI sprints 1–6:

| File | Drift | Fix |
|---|---|---|
| `design-system/jobdun/MASTER.md` | Mentions `Iconsax.*` directly | Updated to point at `AppIcons.*` catalogue |
| `design-system/jobdun/MASTER.md` | "Loading: skeletonizer wrapping real widgets" | Updated to point at `JSkeletonList` wrapper |
| `design-system/jobdun/pages/profile-dashboard.md` | `Iconsax.edit` reference, no mention of JBottomSheet / ImageUploadService / new affordances | Patched in this PR alongside the plan |
| `design-system/jobdun/pages/jobs-feed.md` | Multiple `Iconsax.*` references | Patched in this PR |
| `design-system/jobdun/pages/auth-onboarding.md` | Multiple `Iconsax.*` references | Patched in this PR |

Going forward, every UI sprint **must** end with the doc-sync step: any new wrapper, new icon, new modal pattern lands in MASTER + the relevant page-override file in the same PR.

### 8.4 What "frontend-design" gives us on a Flutter project

The skill is web-centric (its examples lean React/Tailwind), but its **principles are stack-agnostic** and worth running before each sprint:

- Hover/cursor hygiene (Flutter: `MouseRegion` + `SystemMouseCursors.click`)
- Light/dark contrast ratios (Flutter: verify `JColors.light` overrides hold up — currently the app is dark-only and `JColors.light` is gated, but P2 might revisit that)
- Layout pitfalls (consistent `max-width`, floating navbar spacing)
- Icon hygiene (no emojis — we already enforce phosphor through `AppIcons`)

When the skill recommends a pattern that doesn't map cleanly to Flutter, translate it to the closest native Flutter idiom and note the translation in the PR description so the next agent can verify.

---

## 9 · Order of Operations (Recommended)

If you ship one sprint per PR, in this order, no PR blocks the next:

1. **P1** — pure UI wins, no schema. Highest immediate user value. Land first.
2. **P5** — small cleanups that don't depend on schema decisions. Land second.
3. **P3.1 + P3.2** — rate range + visibility. No migration. Marketplace-critical for tradies.
4. **P4.1** — website field for builders. Trivial.
5. **P2** — schema cleanup migration. Land last so all UI is settled before destructive drops.
6. **(Optional) P3.3 / P4.2 / P4.3** — each needs its own migration + UX decision; treat as standalone follow-ups.

---

*Run `python3 .claude/skills/ui-ux-pro-max/scripts/search.py "profile dashboard" --stack flutter` against this doc whenever you start a sprint to fetch the latest Flutter-specific guidelines.*
