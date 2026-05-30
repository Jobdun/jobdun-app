# STEP 6 — Capture & Display Verified Builder Details (Spec + Orchestration)

> **Status:** BUILT (2026-05-30) on branch `feat/verified-builder-details-step6`. Migrations are written but
> **not yet applied to a live DB** (Docker was down at build time — apply via `supabase db reset`). One design
> correction vs the original spec: the counterparty projection is a SECURITY DEFINER **function**
> `get_builder_public_verification()`, not a `security_invoker` view (a view would re-apply owner+admin RLS and
> hide cross-user reads). The admin approval→`verifications` upsert and the audited "view raw" are RPCs too.
> **Author trail:** distilled from a pasted "STEP 6 / Verification v3" plan, then *corrected* against the
> live repo by three Explore agents (2026-05-30). Several assumptions in the original plan were stale —
> the corrected scope below is what actually applies.
> **Mandatory skills for the build:** `ui-ux-pro-max` + `impeccable` (all UI), `context7` (all APIs),
> `superpowers:test-driven-development` + `:verification-before-completion` (every agent). See `CLAUDE.md`.

---

## 1. Context — why this exists

When a builder verifies their ABN, the ABR hands back a small dossier (legal entity name, status, entity
type, GST registration, business location). Jobdun already **fetches** that dossier and already **persists most
of it** — but a few useful fields are dropped, there's no counterparty-facing projection, and the admin can't
see the raw receipt. STEP 6 captures the remaining useful fields, stamps every display with an "as-at" date
(a business can be cancelled the day after a check), exposes a *minimized* public projection to trades (a trust
signal that makes them comfortable applying), and gives admins an audit-logged "view raw" — **while keeping
data minimization** (Australian Privacy Act / APP 3 & 5 & 12) front of mind.

The principal move: **display a curated projection; keep the raw blob as the receipt.** Raw stays in
`verification_events.raw_response` (already there, never rendered as-is). Curated fields live as typed columns
on `verifications` (already mostly there). Counterparties see a tight, register-derived view — not the row, not the blob.

---

## 2. Reality-check — pasted plan vs. the actual repo

| Pasted-plan assumption | Reality in repo (verified) | Action |
|---|---|---|
| `verify-abn` mirrors only "ABN + company name" | Persists `abn_entity_name`, `entity_type`, `abn_registered_at`, `abr_state`, `abr_postcode` to `verifications` (`20260527000005`) **and** mirrors `abn`/`company_name` to `builder_profiles` (`238–251` of `verify-abn/index.ts`) | Reuse — don't re-add these |
| Add `credential_kind`, `verified_legal_name`, `licence_class` columns | Already exist as `kind`, `abn_entity_name`, `licence_trade_class` | Reuse in DB; map to friendlier names only in the Dart model |
| `verification_events.raw_response` exists (jsonb) | ✅ confirmed; ABR payload logged with `_meta.latency_ms`/`regulator` | Use as-is for "view raw" |
| `verifications` RLS = owner+admin read, no client write | ✅ exactly (`20260525000001`: `verifications_owner_read`, `verifications_admin_read`, `*_no_client_insert/update/delete`) | No new owner/admin RLS needed |
| "Step 1 bridge" `licence_registers` table | ❌ does not exist (state adapters are hardcoded under `supabase/functions/_shared/regulators/`) | Drop — derive `register_source` from a constant/adapter name |
| "Step 2" `log_admin_action` RPC + admin audit table | ❌ does not exist (only `user_role_events` + `log_role_event` for role changes) | **Build** a minimal `admin_actions` table + `log_admin_action` RPC (needed for audit-logged "view raw") |
| `builder_public_verification` view | ❌ does not exist | **Build** — genuine gap |
| "v3 prompt / STEP 1–5" docs | ❌ none; repo uses **Phase 0–9** (`docs/VERIFICATION_AUDIT.md`). Phases 0–4 done; 5–9 pending | This spec stands alone; cross-refs Phase numbering |
| Re-verify cron for expiry | ❌ missing — Phase 6 outstanding | Out of scope; `detail_captured_at` "as-at" label works without it |
| Erasure path covers PII | ❌ missing — `delete-my-account` is a P0 gap (`F-PRIV-12`, see `docs/audit/04_storage_privacy.md`) | Inventory new+existing verification PII for erasure; view excludes soft-deleted; full delete-account stays a separate P0 |

**Net:** the builder-facing "verified business card" is *largely already built* —
`lib/features/verification/presentation/widgets/verification_receipts.dart` + the profile "COMPANY DETAILS"
card (`profile_page_sections.dart:136–293`) already read `myVerificationsProvider` and render legal name, ABN
(with tick), entity type, "in business since", registered location. **The genuine STEP 6 gaps are small.**

---

## 3. Scope — the genuine gaps only

1. **3 new columns** on `verifications`: `gst_registered`, `register_source`, `detail_captured_at`.
2. **Persist GST** (already fetched, currently only returned to client) + set `register_source`/`detail_captured_at` in `verify-abn` and the manual-licence approval path.
3. **`builder_public_verification`** view — minimized, register-derived projection for trades.
4. **`admin_actions` table + `log_admin_action` RPC** — so admin "view raw" is audited.
5. **Builder/trade profile** — add a GST line + "Verified as at {date}" label + a "re-verify" action (mostly extends existing widgets).
6. **Counterparty surfaces** — builder "Verified business" badge + minimized fields on applicant cards; wire `job_card_poster_badge` to the public projection.
7. **Admin** — "Captured details" card + audit-logged "view raw" reading `verification_events.raw_response`.
8. **Privacy** — erasure inventory for the new+existing PII; name ABR + state registers in the Privacy Policy (APP 5); "as-at" everywhere.

---

## 4. Schema — one idempotent migration (with DOWN block)

New migration, e.g. `supabase/migrations/2026MMDD000001_verifications_display_projection.sql`:

```sql
-- UP
alter table public.verifications
  add column if not exists gst_registered     boolean,
  add column if not exists register_source    text,          -- 'ABR' | 'QBCC' | 'NSW_FT' | 'admin_manual' ...
  add column if not exists detail_captured_at timestamptz;    -- the "as at" date — ALWAYS shown
create index if not exists verifications_kind_status_idx
  on public.verifications (kind, status);

-- DOWN
drop index if exists public.verifications_kind_status_idx;
alter table public.verifications
  drop column if exists detail_captured_at,
  drop column if exists register_source,
  drop column if exists gst_registered;
```

**Reuse (do NOT re-add):** `kind` (= credential kind), `abn_entity_name` (= legal name), `entity_type`,
`licence_number`, `licence_state`, `licence_trade_class` (= licence class), `verified_at`, `last_checked_at`,
`expires_at`. These exist from `20260525000001` + `20260527000005`.

Run via the supabase skill + `supabase-postgres-best-practices`; confirm the `(kind, status)` index isn't already present before adding.

---

## 5. Edge function & approval-path population

- **`supabase/functions/verify-abn/index.ts`** — when writing the `verifications` row (currently ~`204–216`):
  also set `gst_registered` (the ABR `Gst` field it already parses and returns to the client ~`256`),
  `register_source = 'ABR'`, `detail_captured_at = now()`.
- **Manual licence approval — works for ALL 8 states (NSW/VIC/QLD/SA/WA/TAS/ACT/NT).** This path needs **no
  per-state adapter**: the `licence_state` column already CHECK-accepts all 8, and the admin review sheet reads
  the state/number/class/expiry off the uploaded licence. Only *auto-verify* is NSW-only (out of scope, §13).
  When admin approves a `verification_documents` row, **upsert a `verifications` row** —
  `kind='licence'`, `status='verified'`, the transcribed `licence_number`/`licence_state`/`licence_trade_class`,
  `register_source='admin_manual'`, `detail_captured_at=now()` — so the verified status appears on the owner's
  profile, the counterparty view, and the admin card. **This approval→`verifications` upsert is the one real gap
  in the manual flow today and is in scope for STEP 6** (admin can currently set `verification_documents.status`
  but that does not create the `verifications` row, so non-owners never see the receipt).
- Keep all writes service-role only (RLS forbids client writes — unchanged).

---

## 6. Counterparty view — minimized, register-derived only

```sql
create or replace view public.builder_public_verification
with (security_invoker = true) as
select v.user_id,
       (v.status = 'verified')                                              as is_verified,
       v.abn_entity_name                                                    as verified_legal_name,
       v.licence_trade_class,
       case when v.expires_at is null or v.expires_at > now()
            then 'current' else 'expired' end                              as licence_status,
       v.detail_captured_at
from public.verifications v
join public.profiles p on p.id = v.user_id
where v.kind in ('abn','licence')
  and p.deleted_at is null;        -- exclude soft-deleted users
```

- Exposes **only** register-derived, already-public facts (ABN/licence are public on the official registers).
- **No** ABN-status internals, **no** raw blob, **no** GST/entity-type internals beyond what's needed for the badge.
- Grant `select` to `authenticated`; rely on `security_invoker` so the caller's RLS context applies.
- Used by trades viewing a builder. Confirm with the supabase skill that `security_invoker` + the grant give
  trades read without exposing the underlying `verifications` row.

---

## 7. Admin audit dependency — `admin_actions` + `log_admin_action`

Mirror the existing `user_role_events` / `log_role_event()` pattern (`20260520000002`):

- Table `admin_actions (id, actor_id, action text, target_table text, target_id uuid, metadata jsonb, created_at)`.
- `log_admin_action(action, target_table, target_id, metadata)` `security definer` RPC that inserts a row keyed
  to `auth.uid()` (must be admin). RLS: admin read; no client write except via the RPC.
- The admin "view raw" action calls this RPC, then reads `verification_events.raw_response`.

---

## 8. Dart domain / data changes (Clean Architecture)

- **`lib/features/verification/domain/entities/verification.dart`** — add `gstRegistered`, `registerSource`,
  `detailCapturedAt`. (Friendly getters `verifiedLegalName => abnEntityName`, `licenceClass => licenceTradeClass` optional.)
- **`lib/features/verification/data/models/verification_model.dart`** — parse the 3 new fields from JSON.
- **New projection** `BuilderPublicVerification` entity + a `getBuilderPublicVerification(userId)` use case + repo
  method reading the `builder_public_verification` view (separate from the owner `verifications` read).
- Provider: extend `verifications_provider.dart`; add a counterparty provider for the public projection.
- **Layer rules:** `presentation` imports `domain` only; the provider file is the only seam wiring `data/` impls;
  no direct Supabase from `Notifier`s; controllers ≤10 public methods; files ≤500 LOC. Verify each API via `context7`.

---

## 9. UI surfaces (3) — `ui-ux-pro-max` + `impeccable` on every screen

**Builder/trade profile (owner)** — *mostly exists*:
- `verification_receipts.dart` + COMPANY DETAILS card: add a **GST registered** line, a
  **"Verified as at {detail_captured_at}"** label (never a bare "Verified"), and a **re-verify** action.
- Render curated fields only — never raw JSON. Conventions: `Gap`, `.w/.h/.sp/.r`, `AppIcons`, `JCard`,
  `JStaggeredList`/`JSkeletonList`, `showJSheet`.

**Counterparty (trade viewing a builder)**:
- Applicant cards (`lib/features/applications/presentation/pages/applications_page_card.dart`): add a builder
  **"Verified business"** badge + minimized fields (legal name · ABN current · licence class/status · as-at),
  mirroring the existing trade-verified tick at ~`192–195`. Source = `builder_public_verification`.
- Wire `lib/features/verification/presentation/widgets/job_card_poster_badge.dart` to read the public projection
  rather than `unknown`.

**Admin** (`lib/admin/features/admin_verifications/presentation/widgets/admin_verification_review_sheet.dart`):
- Add a **"Captured details"** card (curated fields).
- Add an audit-logged **"view raw"** action → `log_admin_action` then show `verification_events.raw_response`
  (behind the existing signed-URL/metadata block).

---

## 10. Privacy (APP 3 / 5 / 12 — partially addresses `F-PRIV-12`)

- **Erasure inventory** — the columns a future `delete-my-account` (`F-PRIV-12`) must null/anonymise when a
  user is erased (the `get_builder_public_verification` function already excludes soft-deleted users, and
  `ON DELETE CASCADE` on `verifications.user_id` removes rows on hard auth-user deletion):

  | Table | PII columns to null/anonymise |
  |---|---|
  | `verifications` | `abn`, `abn_entity_name`, `entity_type`, `abr_state`, `abr_postcode`, `gst_registered`, `register_source`, `detail_captured_at`, `licence_number`, `licence_state`, `licence_trade_class`, `failure_reason` |
  | `verification_events` | `raw_response` (the full register payload — purge or redact) |
  | `admin_actions` | `metadata`, `target_id` referencing an erased user (retain the audit row, scrub PII) |
- Name the **ABR + state registers** as data sources in `assets/legal/privacy_policy.md` (APP 5 notice).
- "As-at" label everywhere a verification is shown (owner, counterparty, admin) — **never** a bare "Verified".
- **Out of scope here:** the full `delete-my-account` Edge Function (P0, separate workstream) — this spec only
  ensures the new surface is *accounted for* in that future erasure path, not that the path is built.

---

## 11. Tests (TDD — write first)

- Migration up/down applies cleanly; `(kind, status)` index present.
- `verify-abn` populates `gst_registered`/`register_source='ABR'`/`detail_captured_at` (mock ABR payload).
- Manual-licence approval populates `register_source`/`detail_captured_at`.
- Builder reads own curated fields (owner RLS); trade reads **only** `builder_public_verification` (not the row/blob).
- Admin "view raw" writes an `admin_actions` row (audit assertion).
- Widget tests: profile card shows GST + "as-at" label; applicant card shows builder badge; raw JSON never rendered to non-admins.

---

## 12. Orchestration — wave-based parallel agents

Per `superpowers:dispatching-parallel-agents` + `:subagent-driven-development`. Agents within a wave run in
parallel (independent files); **gates** between waves = human review + `bash scripts/validate.sh`, because UI
depends on the Dart model, which depends on the schema. Each agent: TDD, CLAUDE.md STRICT standards
(≤500 LOC, Riverpod `Notifier`/`AsyncNotifier`, layer rules, no direct Supabase from controllers), `context7`
for APIs, UI agents add `ui-ux-pro-max` + `impeccable`, and `:verification-before-completion` before "done".

**Wave 1 — Backend foundation (parallel):**
- **A1 — Migration & view:** the §4 migration + the §6 `builder_public_verification` view + DOWN blocks. Uses the `supabase` + `supabase-postgres-best-practices` skills.
- **A2 — Admin audit:** the §7 `admin_actions` table + `log_admin_action` RPC (independent files).
- *Gate.*

**Wave 2 — Edge fn + Dart domain (parallel; depend on Wave 1 columns):**
- **B1 — `verify-abn` + approval path** (§5): persist GST / register_source / detail_captured_at.
- **B2 — Dart domain/data** (§8): extend `Verification` entity/model + `BuilderPublicVerification` projection + repo + providers.
- *Gate.*

**Wave 3 — Flutter + admin UI (parallel; depend on Wave 2):**
- **C1 — Owner profile card** (§9): GST line + as-at label + re-verify. `ui-ux-pro-max` + `impeccable`.
- **C2 — Counterparty surfaces** (§9): builder badge + minimized fields on applicant/job cards. `ui-ux-pro-max` + `impeccable`.
- **C3 — Admin** (§9): "Captured details" card + audit-logged "view raw" (uses A2's RPC).
- *Gate.*

**Wave 4 — Verify (sequential):**
- **D — Integration & sign-off:** end-to-end + widget/migration tests green, `bash scripts/validate.sh`,
  `flutter analyze` + `flutter test`, privacy-policy + erasure-inventory doc updates;
  `superpowers:verification-before-completion` before claiming done.

```
Wave 1            Wave 2              Wave 3                       Wave 4
A1 (migration) ─┐
                ├─ gate ─ B1 (edge) ─┐
A2 (audit)    ─┘        B2 (domain) ─┴─ gate ─ C1 (owner UI)  ─┐
                                              C2 (counterparty)├─ gate ─ D (verify)
                                              C3 (admin UI)   ─┘
```

---

## 13. Out of scope (explicitly deferred)
- Re-verify expiry cron (Phase 6).
- Full `delete-my-account` Edge Function (`F-PRIV-12`, P0 — separate workstream).
- Licence **auto-verify** for states beyond NSW (adapters are stubs; `AUTO_VERIFY_ENABLED=false`). **Note:** *manual* licence verification for all 8 states is **in scope** (§5) — only the automated API adapters are deferred.
- The core G1–G4 post/apply/message loop (standing flag — does not block this, but must not be jumped).

## 14. How to verify this feature, end-to-end (after build)
1. `supabase db reset` (or apply migration) → confirm 3 columns + index + view exist.
2. Run `verify-abn` against a known test ABN → row has `gst_registered`/`register_source='ABR'`/`detail_captured_at`.
3. As a builder: profile shows GST + "Verified as at …" + re-verify.
4. As a trade: applicant/job card shows "Verified business" badge from `builder_public_verification`; cannot read the raw row.
5. As admin: "Captured details" renders; "view raw" shows the blob **and** writes an `admin_actions` row.
6. `bash scripts/validate.sh` + `flutter analyze` + `flutter test` all green.
