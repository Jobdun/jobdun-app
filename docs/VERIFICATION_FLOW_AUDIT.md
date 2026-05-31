# Verification Flow Audit — Builder & Trade

**Date:** 2026-05-30 · **Scope:** full stack (Flutter app + edge functions + DB triggers/RLS/RPCs + admin web) · **Type:** findings only, zero code changed.

This audit traces the end-to-end verification flow for both roles, both paths (automatic
regulator check + manual upload-and-review), the admin review queue, and every UI surface
that consumes "verified". It was prompted by two questions: *what happens when a user enters
the wrong identifier*, and *when a user is already verified, does the rest of the UI update
or go stale*. There is **no email field anywhere in this flow**, so "wrong email" is read as
**wrong identifier / wrong identity** (mistyped or not-yours ABN, mistyped licence number,
wrong state/class, mismatched document).

Severity legend: **Critical** (data/trust breach or user-blocking) · **High** (visible
correctness/UX failure a real user hits) · **Med** (edge-case or inconsistency) · **Low**
(hygiene / future-proofing). Every claim is pinned to `file:line` and is provable from source
unless marked *(needs live repro)*.

---

## 1. Flow maps

### Builder → ABN (automatic, live)

```
Profile / nudge / receipts CTA → /verification/wizard
  → WizardIntroStep (choose automatic | manual)
    AUTOMATIC: WizardAbnStep → invoke verify-abn EF
        phone_verified_at? ──no──► VerifyFailed(phone_required) → deep link /profile/verify-phone
        ABR lookup: Active ──────► "Is this your business?" (entity name) + attest checkbox
                                     → verifications row status=verified (+ABR facts)
                                     → builder_profiles.abn/company_name auto-seeded (NULL-only)
                    Cancelled/Susp ► VerifyFailed (cancelled = no manual fallback)
                    ABR down/breaker► manual_review + manual_verification_requests
    MANUAL: ManualUploadSheet (abn_certificate) → verification_documents (pending)
        → admin review → review_verification_document RPC → verifications row verified
```

### Trade → Licence (auto path DISABLED — manual only today)

```
Profile / nudge / receipts CTA → /verification/wizard
  → role=trade ⇒ short-circuit straight to ManualUploadSheet (tradeLicence)
       (auto path off: _supportedStates=[] client-side; AUTO_VERIFY_ENABLED=false server-side)
  → verification_documents (pending, owner-only)
  → ADMIN approves → review_verification_document RPC
       → upsert verifications row kind=licence status=verified (register_source=admin_manual)
       → trigger sync_trade_is_verified → trade_profiles.is_verified=true (cross-user channel)
```

Verification is **optional** in v2 — it never blocks posting, applying, or messaging.

---

## 2. Findings

### A. Wrong identifier / identity correctness

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| A1 | Med | **ABN ownership is unprovable; a mistyped-but-valid ABN verifies as someone else's business** and auto-seeds it into `builder_profiles.abn` (+ `company_name` if empty). | `verify-abn/index.ts:54-77` (phone gate), `:211-261` (verify + seed) | A typo that still resolves to a real *Active* ABN passes. ABR confirms existence, not operation. Only controls: phone gate + the "Is this your business?" attestation (`wizard_abn_step.dart:215-221`). Wrong ABN then pollutes the COMPANY DETAILS card. | Keep phone+attestation (good). Add an admin spot-check/dispute path; never write `builder_profiles` from a non-attested row (already gated on attest — verify it stays that way). |
| A2 | Med | **Manual approval stores the user-TYPED number, not what the reviewer saw on the document.** | `manual_upload_form.dart:152-157` (only non-empty validated for licence), `review_verification_document.sql:90,98` (`licence_number = v_doc.document_number`) | A typo'd licence number becomes the "verified" number shown on receipts + counterparty. The reviewer approved the *image*, but the stored identifier is unchecked. | Let the admin edit/confirm the number at approval, or store a doc-derived value. |
| A3 | Low | **Manual licence upload never captures `trade_class`.** | `manual_upload_sheet.dart` (no class field), `review_verification_document.sql:91` (sets state only) | Approved manual licence row has `licence_trade_class = NULL` → counterparty `licence_class` renders blank (`get_builder_public_verification`). | Collect trade class in the manual sheet (it exists in the auto licence step already). |

### B. Already-verified & status propagation / refresh  *(the core of the user's question)*

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| B1 | **High** | **Same profile page contradicts itself after admin approval.** Receipts panel updates **live** (it reads the `verification_documents` realtime stream), but the availability **banner**, the **nudge banner**, and the builder **COMPANY DETAILS** card read `myVerificationsProvider`, which has **no realtime** and is invalidated only on the user's *own* submit. | live: `verification_receipts.dart:99-101,145-159`; stale: `profile_page_sections.dart:319-324` (banner), `:175-185` (company card), `verification_nudge_banner.dart:37-48` | Trade's upload is approved → receipts say "Verified by document review", but the banner ~3 cm above still says "Available for work" and the nudge still says "Get verified" until app restart. *(needs live repro to see the exact split, provable from source.)* | Realtime-subscribe `verifications` for the owner, or invalidate `verificationsForUserProvider` when the documents stream emits / on profile resume. |
| B2 | **High** | **No approval/rejection notification.** Nothing in the review RPC or any trigger inserts a `notifications` row. | `review_verification_document.sql` (no notifications insert); no verification→notifications trigger exists | Combined with B1, an approved **or rejected** trade gets **zero** signal that their status changed. Rejected users have no prompt to re-upload. | Insert an in-app notification (+ push) on approve/reject inside the RPC. |
| B3 | Med | **"Re-verify →" dead-ends for ABN.** The CTA pushes the wizard, which immediately short-circuits an already-verified ABN and pops. | CTA: `verification_receipts.dart:282-290`; short-circuit: `verification_wizard_page.dart:63-84` | A builder can never re-verify/correct their ABN from the UI — the button shows a "You're already verified" snackbar and exits. (Licence re-verify opens the manual sheet directly, so it works.) | Add an explicit re-verify intent that bypasses the short-circuit (e.g. `/verification/wizard?reverify=abn`), or drop the dead CTA. |
| B4 | Med | **No self-service correction / un-verify once verified.** | RLS `verifications_no_client_update/delete` (`20260525000001_verifications.sql:220-228`), + B3 dead path | A wrongly-verified ABN (A1) or wrong licence (A2) cannot be cleared or replaced from the app — only an admin/service role can. `builder_profiles.abn` stays seeded. | Admin "revoke verification" action + a working re-verify path (B3). |
| B5 | Med | **Duplicate pending uploads.** The wizard short-circuit checks only `isVerified` rows, so a user with a *pending* (not yet approved) upload re-enters and submits another. | `verification_wizard_page.dart:69` (checks `isVerified` only), `:89-105` (trade re-opens sheet) | Every entry point (nudge, receipts CTA, wizard) re-opens the sheet during the pending window → N pending docs for one user in the admin queue. | Guard on an existing pending doc/row; show "Under review" instead of re-opening the sheet. |
| B6 | Low | **Counterparty staleness within a session** — `builderPublicVerificationProvider` and the cross-user `is_verified` are per-session fetches. | `builder_verified_badge.dart:25-29`, `verifications_provider.dart:62-71` | A viewer won't see a counterparty's just-changed status until a re-fetch. Acceptable; noted for completeness. | Optional: refresh on pull-to-refresh / screen focus. |

### C. Expiry & re-check lifecycle

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| C1 | Med | **Nothing ever writes `status='expired'`.** The enum value and two partial indexes for a sweep exist, but no job/trigger/cron uses them. | enum `20260525000001_verifications.sql:19-20`; orphan indexes `:56-59` (`verifications_expiring_idx`, `verifications_recheck_idx`); no `set status='expired'` writer anywhere in `supabase/` | A licence past `expires_at` stays `verified` → `is_verified` stays true → owner banner, receipts, and applicant lists all keep showing verified forever. | Scheduled job (pg_cron / edge cron) flips expired rows to `expired`; the `is_verified` trigger then corrects cross-user surfaces automatically. |
| C2 | Med | **Inconsistent expiry across surfaces.** The counterparty RPC computes `licence_status='expired'` on the fly, but no other surface does. | `get_builder_public_verification` `20260530000001:77-78` | The counterparty sees "expired" while `is_verified` (applicant lists/tradie cards) and the owner's own banner/receipts still say verified — two viewers of the same trade disagree. | Resolved by C1 (single source of truth in the row's `status`). |
| C3 | Low | **ABN is never re-checked.** A cancelled-after-verify ABN stays verified. | `verify-abn` runs only on user action; `verifications_recheck_idx` unused | Same root as C1. | Periodic re-check for `kind=abn` verified rows. |

### D. Admin path & docs

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| D1 | Low | Approval trusts the typed identifier (cross-ref **A2**). | `review_verification_document.sql:90,98` | — | See A2. |
| D2 | Low | **Stale, contradictory header comment** in verify-licence: claims a verified ABN is a prerequisite and returns 412, but the body explicitly requires neither and never returns 412. | `verify-licence/index.ts:8-9` vs `:101` | Misleads maintainers about the contract. | Correct the comment. |

### E. Data integrity / RLS

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| E1 | Low | **No `UNIQUE(user_id, kind)`** — the "one row per (user, kind)" invariant is app-code only; both edge functions select-then-insert (race window). | `review_verification_document.sql:23-24`, `verify-abn/index.ts:98-115`, `verify-licence/index.ts:105-126` | Possible duplicate `abn` rows under a race. The RPC + trigger tolerate dups ("latest"/"ANY verified"), so impact is low. | Partial unique index on `(user_id)` where `kind='abn'`, and `(user_id, licence_state, licence_trade_class)` where `kind='licence'`, if strictness is wanted. |
| E2 | OK | **RLS is solid.** `verifications`: owner_read + admin_read, client insert/update/delete all `false`. `verification_documents`: owner + admin select/update. `private-docs`: admin select + owner-path RLS. | `20260525000001_verifications.sql:198-228`, `20260527000001_verification_documents_admin_review.sql:14-52` | No issue — documented as confirmation. | — |

### F. Edge / role conditions

| # | Sev | Finding | Where | Repro / impact | Recommended fix |
|---|-----|---------|-------|----------------|-----------------|
| F1 | Low | **Role-null defaults to the builder ABN flow.** | `verification_wizard_page.dart:60-61` | A trade entering the wizard during a transient null role briefly gets the ABN entry screen instead of manual upload. Narrow window. | Show a spinner / block until role resolves before branching. |
| F2 | Med | **Manual upload has no phone-verified precondition, but both auto paths do.** | gate present: `verify-abn/index.ts:61-77`, `verify-licence/index.ts:50-66`; absent: `manual_upload_sheet.dart:125-181` (no phone check) | A user can manually upload a licence/ABN without a verified phone — the exact identity anchor the auto path insists on. The attestation is the only control. Inconsistent trust bar. | Apply the same phone gate before a manual upload, or consciously document the exception. |
| F3 | Low | **A trade's ABN verification is invisible.** Schema allows `kind=abn` for trades, but no trade surface renders it (`showAbnRow` is false on the trade profile). | `profile_page_sections.dart` (trade uses `showLicenceRow`), `verify-abn` seeds `builder_profiles` only for role=builder | A trade who verifies an ABN gets a verified row nothing shows. | Confirm intended; if not, surface it or block ABN verify for trades. |

---

## 3. What's already solid

- **Phone-verified gate + explicit attestation** on both auto paths — a real, cheap identity anchor before a row is marked verified (`verify-abn/index.ts:54-77`, `wizard_abn_step.dart:82-95`).
- **Atomic admin review** via a single `SECURITY DEFINER` RPC that updates the doc, upserts the verified row, and writes an audit row in one transaction — and the app correctly calls the RPC, not a raw update (`admin_verifications_provider.dart:266-286`, `review_verification_document.sql`).
- **`is_verified` trigger** keeps the cross-user channel truthful (incl. multi-state holders via "ANY verified") without exposing the owner-only `verifications` table (`20260527000002_trade_is_verified_sync.sql`).
- **Honest "as at" dating** next to every verified badge so a stale snapshot never reads as a bare "Verified" (`verification_receipts.dart:271-278`).
- **Counterparty projection** exposes only already-public register fields via `SECURITY DEFINER`, never the raw blob / number / failure reason (`20260530000001:53-94`).
- **Manual-only kill switch** short-circuits before any adapter/DB write, so the NSW dev stub can't mint a fake verified row (`verify-licence/index.ts:32,72-82`).
- **Circuit breaker + rate limits + audit trail** on both functions; failures degrade to `manual_review`, never silent.

---

## 4. Prioritized fix list (recommendations only — no code this pass)

1. **B1 + B2 — close the "approved but the app doesn't show it / doesn't tell me" gap.** Realtime or invalidate `verifications` for the owner, and emit an approve/reject notification from the RPC. Highest user-visible impact; affects every approved trade.
2. **B5 — block duplicate pending uploads** (guard the wizard/receipts entry points on an existing pending doc).
3. **B3 + B4 — make "Re-verify" work and add an admin revoke** so a wrong ABN/licence is fixable.
4. **C1 — build the expiry/re-check sweep** (the indexes are already waiting); resolves C2/C3 at once.
5. **A2/A3 — capture/confirm the identifier and trade class at manual approval** instead of trusting free text.
6. **F2 — align the manual path's phone gate with the auto path** (or document the exception).
7. **D2 — fix the stale verify-licence header comment.**

---

## 5. Method & confidence

Every app-path claim is backed by the widget/provider/use-case trace cited; every backend claim
is read directly from edge-function source or migration SQL. Propagation claims name the exact
refresh seam present or missing (`invalidate` / `.stream` / RPC). No runtime or DB execution was
performed. The two items marked *(needs live repro)* (the precise B1 banner-vs-receipts split and
the post-approval timing) are provable from source but worth a one-device confirmation before fixing.
