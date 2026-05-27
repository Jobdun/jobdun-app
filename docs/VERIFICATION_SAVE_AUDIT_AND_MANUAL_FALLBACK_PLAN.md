# Jobdun — Verification Save-Path Audit + Skip-to-Manual UX Plan

> **Created:** 2026-05-27 on `chore/audit-followups-w1-w3`.
> **Companions:** `docs/VERIFICATION_AUDIT.md` (architecture), `docs/VERIFICATION_USER_FLOWS.md` (v2.1 user model).
> **Why this doc exists:** the v2.1 flow assumes the user will *try* the regulator first and only fall back to a doc upload after a failure. That assumption breaks for (1) users in states with no adapter (everyone outside NSW today), (2) users who already know they only have a paper licence and no number to type, and (3) builders/trades who land on a "no automated check available" branch. This doc audits how verification is saved today, then plans an equal-weight "skip to manual" path, end-to-end, mobile + admin web.

---

## TL;DR

Today verification has **two save paths** that already work in isolation:

- **API-first** → `verifications` + `verification_events` (service-role inserts via Edge Functions, regulator JSON kept as audit trail)
- **Manual fallback** → `verification_documents` + `private-docs/<userId>/...` (owner-write RLS, admin reviews via web app)

But the *only way to reach the manual fallback* today is to fail the regulator call first. Every entry point (home banner, profile receipts, wizard intro) routes to the wizard, which forces the regulator path. Users outside NSW dead-end on a `501 state_not_supported` red error.

**The fix:** add a wizard intro step that offers two co-equal CTAs (`VERIFY AUTOMATICALLY` / `UPLOAD A DOCUMENT INSTEAD`), surface a secondary "Or upload a document →" link on the receipts panel, auto-route unsupported states to manual, capture metadata (state / number / expiry / issuer) in the upload sheet so reviewers don't get a bare photo, and retire the legacy `/verification` page that duplicates the upload path. In the admin web app, classify the queue by audience (Builder ABN / Trade Licence / Other), join `profiles` to show real names + role, and surface the regulator's failure reason from `verification_events` so reviewers see why the API path didn't catch it.

Role-scoping stays strict: a trade only ever sees the licence path, a builder only ever sees the ABN path. The manual sheet asserts the doc type matches the caller's role so a mismatched upload can't slip through.

---

## 1. How verification is saved today (evidence)

### 1.1 The two save paths

| Path | Saves to | Who can write | RLS posture |
|---|---|---|---|
| **API-first** | `public.verifications` (one row per `(user_id, kind)`), `public.verification_events` (append-only JSONB), `public.manual_verification_requests` (when regulator unreachable / circuit-breaker open) | Service-role only (Edge Functions `verify-abn`, `verify-licence`) | Owner SELECT + admin SELECT; all client INSERT/UPDATE/DELETE blocked (`USING (false)`) |
| **Manual fallback** | `public.verification_documents` (status pipeline: pending → approved/rejected/expired) + `private-docs/<userId>/verification/<doc_type>/...` storage object | Owner INSERT, owner SELECT/UPDATE on own rows. Admin SELECT + UPDATE shipped 2026-05-27. | Owner-only-write, admin-can-review-and-approve |

Evidence:
- `supabase/migrations/20260525000001_verifications.sql:189-229` — service-role write lock on `verifications`
- `supabase/migrations/20260527000001_verification_documents_admin_review.sql` — admin SELECT + UPDATE policies (live)
- `supabase/functions/verify-abn/index.ts`, `supabase/functions/verify-licence/index.ts` — Edge Functions that write `verifications` + audit
- `lib/features/verification/data/datasources/verifications_remote_datasource.dart:38-66` — client invokes Edge Functions; never writes the row itself
- `lib/features/verification/data/datasources/verification_remote_datasource.dart:52-106` — client writes `verification_documents` directly (storage + insert)

### 1.2 API-first save flow (today)

```
WizardAbnStep / WizardLicenceStep
   ↓
invokeVerifyAbnUseCaseProvider / invokeVerifyLicenceUseCaseProvider
   ↓
VerificationsRemoteDataSource._invoke(fn, body)
   ↓
SupabaseClient.functions.invoke('verify-abn' | 'verify-licence', body)
   ↓
Edge Function (Deno, service-role):
   1. Auth caller from JWT
   2. Validate input (ABN checksum / state allowlist)
   3. Rate-limit check (user + IP sliding window)
   4. Upsert `verifications` row (status='pending', last_checked_at=now())
   5. Circuit-breaker check per regulator → if open, flip row to `manual_review`
      + insert `manual_verification_requests` row, return early
   6. Call adapter (ABR Web Services / NSW Fair Trading scraper / stub)
   7. Insert `verification_events` row with raw JSONB response
   8. Update `verifications` row to verified / failed / manual_review based on result
   9. Return JSON to client: { status, regulator_display_name, ... }
   ↓
Client deserialises into VerifyResult (sealed: Verified | Failed | ManualReview)
   ↓
Wizard step decides: hand to result screen, stay for retry, or offer manual upload
   ↓
On wizard finish: ref.invalidate(verificationsForUserProvider(userId))
   → receipts panel re-fetches, row flips green
```

### 1.3 Manual fallback save flow (today)

```
showManualUploadSheet(context, docType)
   ↓
_ManualUploadSheet picks file via ImageUploadService.pickCropCompress
   (free aspect, JPEG, 10MB cap)
   ↓
VerificationRemoteDataSource.uploadDocument({ tradeId, docType, file, … })
   ↓
Storage upload to private-docs/<tradeId>/verification/<doc_type>/<ts>.<ext>
   ↓
Insert verification_documents { trade_id, doc_type, file_path, status: 'pending',
                                state?, issuer?, document_number?, issued_date?,
                                expiry_date? }
   ↓
ref.invalidate(verificationsForUserProvider(userId)) on sheet close
   → receipts row updates to "Under review · uploaded just now"
   ↓
Admin web app polls verification_documents, splits PENDING / REVIEWED,
admin clicks row → AdminVerificationReviewSheet
   ↓
adminVerificationsProvider.setStatus(id, 'approved' | 'rejected', notes?)
   → UPDATE verification_documents SET status, reviewed_at, reviewed_by, review_notes
   ↓
Realtime/refresh — owner's profile receipt flips to verified
```

### 1.4 Entry points (today)

| Surface | Wizard CTA | Manual CTA |
|---|---|---|
| Home jobs feed `VerificationNudgeBanner` | "Get verified →" → `/verification/wizard` | ❌ none |
| Profile `VerificationReceipts` rows (not verified) | "Verify in about a minute →" | ❌ none |
| Wizard `_Step.choose` (NEW — not yet built) | n/a | n/a |
| Wizard `WizardAbnStep` (entry, builder) | "NEXT" → call ABR | ❌ none on entry; only after failure |
| Wizard `WizardLicenceStep` (entry, trade) | "VERIFY" → call adapter | ❌ none on entry; only after failure |
| Wizard ABN failure | "TRY A DIFFERENT ABN" | "UPLOAD DOCUMENT INSTEAD" (only when `manual_fallback_allowed`) |
| Wizard ABN manual_review | "CONTINUE WITHOUT UPLOAD" | "UPLOAD DOCUMENT" (primary) |
| Wizard Licence failure | "TRY AGAIN" + "CONTINUE" | "UPLOAD DOCUMENT INSTEAD" (when allowed) |
| Wizard Licence manual_review | "TRY AGAIN" + "CONTINUE" | "UPLOAD DOCUMENT INSTEAD" |
| Legacy `/verification` page (`VerificationPage`) | n/a | Direct "TAKE A PHOTO" / "CHOOSE FROM GALLERY" → `profileControllerProvider.uploadTradeLicence` (a *third* code path that writes `verification_documents` independently of the modal) |

### 1.5 Edge cases the current code handles

- **ABR JSONP wrapper** — `verify-abn` strips the JSONP padding before parsing (fixed 2026-05-27).
- **Adapter throw** — `verify-licence` wraps the adapter call in try/catch and downgrades to `status='unknown'` → manual_review.
- **Circuit breaker open** — flips the row to manual_review + writes a `manual_verification_requests` row before even attempting the regulator call.
- **Rate limit** — 429 returned with reset time; not surfaced as a manual fallback offer.

---

## 2. UX gaps in skip-to-manual (today)

| # | Gap | Impact | Severity |
|---|---|---|---|
| **G1** | No "skip to manual" *before* the first regulator call | User must type a number + hit Verify + wait for failure + see the upload option. For users with no licence number / paper-only / unsupported state, this is friction with no payoff. | High |
| **G2** | Unsupported state returns `501 state_not_supported` with no client-side fallback CTA | Everyone outside NSW dead-ends on red error text. Today that's ~70% of the AU market. | **Blocker** for non-NSW launch |
| **G3** | Receipts panel & nudge banner have no manual-direct CTA | "Verify in about a minute →" is the only path; users who already know they want manual have to back-and-forth through the wizard. | Medium |
| **G4** | Manual upload sheet doesn't capture state / number / expiry / issuer | Admin reviewers get a bare photo — they have to read it, type it in, then cross-check. Slower per-review; higher error rate. | Medium |
| **G5** | Legacy `/verification` page duplicates manual upload (`profileControllerProvider.uploadTradeLicence`) | Two code paths write to the same table with different shapes. Risk of drift, double-counting, and reviewer confusion. | Medium |
| **G6** | `manual_verification_requests` rows are server-side but invisible client-side | Returning users can't see "I'm queued" status; only `verification_documents` rows show on receipts. | Low |
| **G7** | Admin queue mixes Builder ABN + Trade Licence rows with no filter | Admin reviewing licences sees ABN certs and vice versa. No fast filter. | Medium |
| **G8** | Admin queue shows `trade ${tradeId.substring(0,8)}…` instead of name/role | Reviewers can't identify users without copying the UUID to look up. The DB column `trade_id` is also misleading for builder uploads (it's the uploader's user_id, not a trade-specific FK). | Medium |
| **G9** | Admin review sheet doesn't show the *API attempt* (if any) | When an upload follows a failed regulator call, the reviewer can't see the regulator's failure detail. `verification_events.raw_response` is right there — just not shown. | Low |

Severity drives ordering in §4 (Implementation Plan).

---

## 3. Proposed design

### 3.1 Mobile — wizard flow

**Role-scoped throughout.** Wizard inspects `auth.role` in `initState` (already does) and never offers a kind the role doesn't own.

```
/verification/wizard

  Builder
  ─────────────────────────────────────────
  _Step.choose   ── (skipped if user already has a verified ABN row)
      │
      ├── "VERIFY AUTOMATICALLY"  →  _Step.abn  → _Step.result
      └── "UPLOAD A DOCUMENT INSTEAD"  →  showManualUploadSheet(DocType.abnCertificate)
                                          → on close: pop wizard

  Trade
  ─────────────────────────────────────────
  _Step.choose   ── (skipped if user already has a verified licence row)
      │
      ├── "VERIFY AUTOMATICALLY"  →  _Step.licence
      │       │
      │       ├── supported state (NSW today)   →  call verify-licence
      │       └── unsupported state (everywhere else)
      │             → inline hint + primary "UPLOAD A DOCUMENT INSTEAD"
      │             → showManualUploadSheet(DocType.tradeLicence, prefilledState)
      │
      └── "UPLOAD A DOCUMENT INSTEAD"  →  showManualUploadSheet(DocType.tradeLicence)
```

**Intro step (`_Step.choose`) copy:**

| Role | Title | Body | Primary | Secondary |
|---|---|---|---|---|
| Builder | "Verify your business" | "Pick how you'd like to do this. The automatic check uses the Australian Business Register and takes about 15 seconds." | ⚡ `VERIFY AUTOMATICALLY` (call ABR) | 📄 `UPLOAD A DOCUMENT INSTEAD` (24 h review) |
| Trade | "Verify your trade licence" | "Pick how you'd like to do this. The automatic check uses the state regulator's public register and takes about a minute." | ⚡ `VERIFY AUTOMATICALLY` (call adapter) | 📄 `UPLOAD A DOCUMENT INSTEAD` (24 h review) |

**Auto-skip rules for `_Step.choose`:**
- Trade has a `verifications.kind='licence'` row with `status='verified'` → skip choose, jump to result
- Builder has a `verifications.kind='abn'` row with `status='verified'` → skip choose, jump to result
- Otherwise → show choose first

**Unsupported state branch (`WizardLicenceStep`):**

When the trade picks a state with no adapter (today: everything except NSW), don't call the Edge Function. Render inline:

```
┌───────────────────────────────────────────────────┐
│  We don't have an automated check for VIC yet     │
│                                                   │
│  Upload a photo of your licence and a reviewer    │
│  will confirm it within 24 hours.                 │
│                                                   │
│  [ UPLOAD A DOCUMENT INSTEAD ]                    │
│                                                   │
│  Or pick a different state ↑                      │
└───────────────────────────────────────────────────┘
```

The `Verify` button is disabled while an unsupported state is selected; the upload CTA replaces it inline. Supported-state list is a Dart constant mirroring `supabase/functions/_shared/regulators/index.ts` (`['NSW']` today). When VIC/QLD adapters land in Phase 7, update the constant.

### 3.2 Mobile — manual upload sheet (metadata)

Add a FormBuilder section above the file picker. Fields are role-gated by `docType`.

| Field | Trade Licence | ABN Certificate | Validation |
|---|---|---|---|
| State (dropdown: NSW/VIC/QLD/SA/WA/TAS/ACT/NT) | required | hidden | `FormBuilderValidators.required()` |
| Issuer (read-only, derived) | derived from state ("VIC Building Authority", etc.) | "Australian Business Register" | n/a |
| Document number (text) | required ("e.g. EL-12345") | required ("11 digits") | required + ABN checksum for builders |
| Expiry date (date picker) | required | optional | future date |
| File (image/PDF) | required | required | existing 10 MB cap + MIME allowlist |

Sheet layout (top → bottom):
1. Title + helper copy
2. Form section (above)
3. Image preview block (when file picked)
4. Camera / Gallery buttons (or Change when file picked)
5. UPLOAD primary CTA (enabled only when form valid + file picked)

`uploadDocument()` signature already accepts these optional params — no datasource change needed.

### 3.3 Mobile — receipts panel secondary CTA

Under the "Not yet verified" row:

```
◯ Trade licence
  Not yet verified
  Verify in about a minute →                ← existing primary CTA (orange, weight 600)
  Or upload a document →                    ← NEW secondary CTA (text3, weight 500, smaller)
```

The secondary CTA calls `showManualUploadSheet(context, docType: docs.DocType.tradeLicence)` directly (or `.abnCertificate` on builder profiles). No wizard transition.

### 3.4 Mobile — legacy `/verification` retirement

Replace `VerificationPage` body with `context.go('/verification/wizard')` and delete the older trade-only upload UI (`_StatusCard`, `_BuilderNotVerifiedScreen`, `_pick`). The route entry stays so deep links and any cached navigations land at the wizard.

`profileControllerProvider.uploadTradeLicence` only has one caller (the legacy page) — once the page redirects, the method + repo + datasource + use case can be deleted. Confirmed by `grep "uploadTradeLicence" lib --include="*.dart"` → 5 hits, all in the chain leading from the legacy page.

### 3.5 Admin web — classification

```
VERIFICATIONS
─────────────────────────────────────────────────────────────────
[ All 12 ]  [ Trade Licence 7 ]  [ Builder ABN 4 ]  [ Other 1 ]    ← filter chips
─────────────────────────────────────────────────────────────────

PENDING (5)

🟠  TRADE LICENCE  ·  NSW                              [ PENDING ]
     Sam Wilson  ·  sam@example.com  ·  ROLE: TRADE
     Licence #EL-12345  ·  expires 14 Feb 2028
     ⚠ API attempt failed: regulator returned "not_found"
     submitted 2 h ago

🟠  BUILDER ABN                                        [ PENDING ]
     Jones Building & Electrical Pty Ltd  ·  ROLE: BUILDER
     ABN 12 345 678 901  ·  submitted 4 h ago

REVIEWED (7)
  …
```

**Provider changes (`admin_verifications_provider.dart`):**
- Add `kind` enum: `tradeLicence`, `builderAbn`, `other`
- `AdminVerificationItem` gains `userDisplayName`, `userEmail`, `userRole`, `lastVerificationFailureReason`
- `_load()` switches to a single query joining `verification_documents` ← `profiles` ← `verifications` (latest matching kind) via a Postgres view *or* via the existing `auth.users` email pattern. Spec: add a SQL view `admin_verification_queue` to keep the provider thin and let RLS continue to gate access.
- Add `kindFilter` state + `setKindFilter()` so the chips re-derive the list without a re-fetch.

**Page changes (`admin_verifications_page.dart`):**
- Filter chips row above the PENDING section, derived counts per kind
- Row layout: kind badge (`TRADE LICENCE` / `BUILDER ABN`) + state suffix + role tag + name + email + key claim (number/expiry/ABN) + API-failure breadcrumb when present
- Empty state per filter ("No pending trade licence reviews.")

**Review sheet changes (`admin_verification_review_sheet.dart`):**
- Header swaps `trade ${i.tradeId}` for `${userDisplayName} (${role.toUpperCase()})` with email subtitle
- New "WHAT THE REGULATOR SAID" block when `lastVerificationFailureReason != null`, expandable to raw JSONB (from the most recent `verification_events.raw_response` for that user's matching kind)

**No schema/RLS changes required.** The admin RLS policies shipped on 2026-05-27 already allow SELECT on `verifications` + `verification_events`. Adding a view + a join doesn't change that.

### 3.6 Telemetry

Funnel events to write through the existing `verification_funnel_events` table:

| step | When |
|---|---|
| `wizard_open` | wizard mounted (existing/needs verification) |
| `intro_choose_auto` | NEW — user taps "VERIFY AUTOMATICALLY" on `_Step.choose` |
| `intro_choose_manual` | NEW — user taps "UPLOAD A DOCUMENT INSTEAD" on `_Step.choose` |
| `licence_state_unsupported` | NEW — user picked a state with no adapter |
| `manual_fallback_after_failure` | existing failure-screen upload tap |
| `manual_upload_submitted` | sheet successfully inserts `verification_documents` row |
| `receipts_manual_cta` | NEW — secondary upload CTA tapped from receipts panel |

These let product see what % of users *choose* manual vs. *fall back* into manual.

---

## 4. Implementation plan

### Phase 1 — mobile UX (this PR)

| Order | File | Change |
|---|---|---|
| 1 | `lib/features/verification/presentation/widgets/wizard_intro_step.dart` | **NEW** — `WizardIntroStep` with role-aware copy + two CTAs |
| 2 | `lib/features/verification/presentation/pages/verification_wizard_page.dart` | Add `_Step.choose` (the new default), auto-skip when verified row exists, route manual CTA into `showManualUploadSheet` |
| 3 | `lib/features/verification/presentation/widgets/wizard_licence_step.dart` | Add `_supportedStates` const, inline unsupported-state branch, disable Verify + swap to upload CTA |
| 4 | `lib/features/verification/presentation/widgets/manual_upload_sheet.dart` | Add FormBuilder section (state / number / expiry / issuer auto-derived); plumb to `uploadDocument` |
| 5 | `lib/features/verification/presentation/widgets/verification_receipts.dart` | Add "Or upload a document →" tertiary CTA |
| 6 | `lib/features/verification/presentation/pages/verification_page.dart` | Replace body with redirect to `/verification/wizard` |
| 7 | `lib/features/profile/presentation/providers/profile_provider.dart`, `data/repositories/profile_repository_impl.dart`, `data/datasources/profile_remote_datasource.dart`, `domain/repositories/profile_repository.dart` | (Optional follow-up) delete `uploadTradeLicence` once the legacy page is gone — defer to a cleanup PR to keep this diff scoped |

### Phase 2 — admin web classification (this PR)

| Order | File | Change |
|---|---|---|
| 1 | `lib/admin/features/admin_verifications/presentation/providers/admin_verifications_provider.dart` | Add `kind`, `userDisplayName`, `userEmail`, `userRole`, `lastVerificationFailureReason` to `AdminVerificationItem`. Join `profiles` (and optionally `verifications` + `verification_events`) in `_load()`. Add `kindFilter` notifier + setter. |
| 2 | `lib/admin/features/admin_verifications/presentation/pages/admin_verifications_page.dart` | Add filter chip row, derived per-kind counts, rich row layout (badge + role tag + name + claim + API-failure breadcrumb). |
| 3 | `lib/admin/features/admin_verifications/presentation/widgets/admin_verification_review_sheet.dart` | Header: name + role. New "WHAT THE REGULATOR SAID" block when failure detail present. |

### Phase 3 — telemetry (this PR)

| Step | Place |
|---|---|
| `intro_choose_auto` / `intro_choose_manual` | `wizard_intro_step.dart` onTap handlers |
| `licence_state_unsupported` | `wizard_licence_step.dart` state-changed handler |
| `manual_upload_submitted` | `manual_upload_sheet.dart` after successful insert |
| `receipts_manual_cta` | `verification_receipts.dart` secondary CTA onTap |

Implementation: write directly to `verification_funnel_events` via `SupabaseConfig.client.from('verification_funnel_events').insert({user_id, step, metadata})`. The funnel table allows authenticated INSERTs by design (`verification_funnel_insert_own` policy).

### Phase 4 — DB view for admin queue (deferred to follow-up PR if join gets ugly)

Add `public.admin_verification_queue` view:

```sql
CREATE OR REPLACE VIEW public.admin_verification_queue AS
SELECT
  vd.*,
  p.display_name           AS user_display_name,
  p.role                   AS user_role,
  CASE vd.doc_type
    WHEN 'trade_licence'   THEN 'trade_licence'
    WHEN 'abn_certificate' THEN 'builder_abn'
    ELSE 'other'
  END                      AS audience,
  vf.failure_reason        AS last_verification_failure_reason,
  vf.status                AS last_verification_status
FROM public.verification_documents vd
JOIN public.profiles p                       ON p.id = vd.trade_id
LEFT JOIN LATERAL (
  SELECT failure_reason, status
  FROM public.verifications v
  WHERE v.user_id = vd.trade_id
    AND ( (vd.doc_type = 'trade_licence'   AND v.kind = 'licence')
       OR (vd.doc_type = 'abn_certificate' AND v.kind = 'abn') )
  ORDER BY v.updated_at DESC
  LIMIT 1
) vf ON true;
```

Views inherit RLS from base tables, so admin SELECT on `verification_documents` + `verifications` is sufficient. Email comes from `auth.users` — fetch via a separate service-role RPC if we want to surface it, otherwise stick to `display_name` for the first cut.

For this PR we'll keep the join in Dart (two queries: `verification_documents` + `profiles`) and revisit the view if perf becomes a concern at > 1k pending rows.

---

## 5. Test plan

### Mobile
- Wizard intro renders for builder; tapping "Verify automatically" advances to `_Step.abn`.
- Wizard intro renders for trade; tapping "Verify automatically" advances to `_Step.licence`.
- Wizard intro tapping "Upload a document instead" opens `manual_upload_sheet` with the correct `DocType`.
- Trade who picks VIC sees the unsupported-state hint, no Edge Function call fires (verified via network-mock).
- Manual upload sheet validation: cannot submit without state (trade only), document number, expiry (trade only), and a picked file.
- Receipts panel renders "Or upload a document →" only when the row is not verified; tapping opens the sheet.
- Legacy `/verification` route redirects to `/verification/wizard` synchronously (no upload chrome flash).

### Admin web
- Filter chip "Trade Licence" filters to only `doc_type='trade_licence'` rows.
- Filter chip "Builder ABN" filters to only `doc_type='abn_certificate'` rows.
- Each row shows `display_name` + role tag instead of truncated UUID.
- Review sheet header shows `display_name` + role.
- When the matching `verifications` row has a `failure_reason`, the sheet renders the "WHAT THE REGULATOR SAID" block; otherwise the block is absent.
- Approving / rejecting still writes to `verification_documents` (unchanged path).

### Manual cross-role smoke
- Sign in as a trade — wizard never offers ABN. Receipts panel never offers the ABN row. Manual sheet asserts `DocType.tradeLicence` if a builder caller is mocked.
- Sign in as a builder — wizard never offers licence. Receipts panel never offers the licence row.

---

## 6. Non-goals (deferred)

- VIC / QLD / other state adapters — Phase 7 of `VERIFICATION_AUDIT.md`.
- Real NSW Fair Trading scraper — Phase 2 of `VERIFICATION_AUDIT.md`; NSW today is still a deterministic stub.
- Surfacing `manual_verification_requests` to the user as an explicit "you're queued" card — covered by the existing "Under review" receipt copy; revisit if support tickets show confusion.
- Mass-upload / multi-doc support — single-doc is enough for v2 launch.
- Deleting `profileControllerProvider.uploadTradeLicence` — leave the symbols in place for one release so any lingering deep links still work; clean up in a follow-up.

---

## 7. Risk + mitigations

| Risk | Mitigation |
|---|---|
| Adding a choose-step bumps wizard from 1 step to 2 → lower API-first verification rate | Auto-skip when a verified row already exists; copy emphasises auto-path; secondary CTA visually subordinate (text3 grey, smaller font). Watch `intro_choose_auto / intro_choose_manual` ratio. If manual share > 40% in first 4 weeks, tighten the secondary CTA's visual weight. |
| Required metadata fields in manual sheet add friction | Fields mirror the regulator-claim shape (state + number + expiry) so users with the doc on screen complete them in seconds. If completion rate drops, soften to required-on-trade-only / optional-on-ABN-cert. |
| Admin queue join blows up with no `display_name` for legacy profiles | Coalesce to email; if email is also null (shouldn't happen post-onboarding lock), fall back to UUID prefix with a "MISSING NAME" tag so reviewers can flag the profile. |
| Removing legacy `/verification` page breaks a notification deep link | Convert to redirect (not delete) — `/verification` continues to resolve and just sends users to the wizard. The wizard's intro then offers them the upload path. |

---

## 8. Files touched (this PR)

```
NEW:
  docs/VERIFICATION_SAVE_AUDIT_AND_MANUAL_FALLBACK_PLAN.md
  lib/features/verification/presentation/widgets/wizard_intro_step.dart

MODIFIED (mobile):
  lib/features/verification/presentation/pages/verification_wizard_page.dart
  lib/features/verification/presentation/pages/verification_page.dart
  lib/features/verification/presentation/widgets/manual_upload_sheet.dart
  lib/features/verification/presentation/widgets/wizard_licence_step.dart
  lib/features/verification/presentation/widgets/verification_receipts.dart

MODIFIED (admin web):
  lib/admin/features/admin_verifications/presentation/providers/admin_verifications_provider.dart
  lib/admin/features/admin_verifications/presentation/pages/admin_verifications_page.dart
  lib/admin/features/admin_verifications/presentation/widgets/admin_verification_review_sheet.dart
```

No schema migration. No RLS change. No new package. No deleted public APIs (`uploadTradeLicence` chain stays for one release; legacy page becomes a redirect).
