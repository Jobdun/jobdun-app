# Jobdun — Verification Audit & API-First Plan

> **Last verified:** 2026-05-25 on branch `chore/audit-followups-w1-w3`.
> Supersedes the W3 "Verification + expiry reminders" section of `docs/W1_W3_REALITY_CHECK.md` for product direction.
> Symbols: ✅ in code, ❌ not present, ⚠️ partial / different from spec, ❓ requires live DB / runtime to confirm.

---

## TL;DR

Today's verification flow is the same flow every competitor runs: **trade uploads a doc → admin eyeballs it → status flips to approved.** That is exactly the path The Guardian used to break Checkatrade. It is also the line item competitors lean on in marketing without doing meaningfully more than reading a PDF.

**The pivot:** flip the front door from "upload a doc" to "enter ABN + licence number → Edge Function calls the regulator → status returns in seconds." Manual document review remains in the codebase, but it is now the **fallback** for regulator outages, edge-case licence classes, and missing-API states — not the default.

The single sentence:

> Every competitor verifies by *looking at a PDF*. Jobdun verifies by *asking the government*.

This is the moat. It is also, conveniently, free to run — ABR is a no-cost Commonwealth API and the state regulator lookups are public web endpoints.

---

## Current state (evidence-backed)

### What exists today
| Concern | Status | Evidence |
|---|---|---|
| Trade-side upload page (image_picker → crop → JPEG compress) | ✅ | `lib/features/verification/presentation/pages/verification_page.dart:44-48` |
| `verification_documents` table (rich audit columns) | ✅ | `supabase/migrations/20260511000005_social.sql:23-44` + `20260516000001_schema_reconciliation.sql:20-50` |
| Owner-only RLS on `verification_documents` | ✅ | `supabase/migrations/20260511000006_rls.sql:309-329` (`select_own`/`insert_own`/`update_own`, all keyed off `auth.uid() = trade_id`) |
| Upload guard-rails — 10 MB cap + MIME allowlist | ✅ | `lib/core/services/image_upload_service.dart:58+` (commit `731bc48`) |
| `private-docs` bucket + storage RLS | ✅ | `supabase/migrations/20260511000006_rls.sql:401-435` |
| `expiry_date` column captured on upload (manual entry) | ✅ | `supabase/migrations/20260516000001_schema_reconciliation.sql:31` |
| ABN validator (11-digit + checksum) | ✅ | `lib/core/utils/validators.dart:29-33` |

### What is missing for the *manual-review path* to actually work
| Gap | Impact | Evidence |
|---|---|---|
| Admin RLS policy on `verification_documents` | Admin web app cannot read, approve, or reject any document. The trade upload reaches the bucket and then nothing happens. | Only owner policies exist (`20260511000006_rls.sql:309-329`); no `WHERE EXISTS (… user_roles.role='admin' …)` and no service-role Edge Function. |
| Admin review queue UI | Dashboard tile at `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart:68` advertises "review pending verification documents" but the queue / approve / reject screens do not exist. | `find lib/admin -name "*verif*"` returns nothing. |
| Approve / reject Edge Function (or RPC) | Even with an admin RLS policy, status transitions need to be audited (who reviewed, when, why) before they reach `reviewed_by` / `reviewed_at` / `review_notes`. | `supabase/functions/` directory does not exist (`ls supabase/` → no `functions`). |
| Expiry-reminder cron | `expiry_date` is captured but nothing flips status to `expired` or notifies the trade / open conversations. | No cron Edge Function, no scheduler config. |
| Upload retry / backoff | A flaky upload silently fails; trade re-picks the file. | No retry path in `ImageUploadService`. |
| Sentry breadcrumb on upload failure | Sentry is wired globally (commit `731bc48`) but the upload service does not attach an upload-specific breadcrumb. | `grep Sentry lib/core/services/image_upload_service.dart` → 0 hits. |
| Upload progress UI | Trade has no feedback during long uploads. | ❓ |

### What is missing for the *API-first path* (does not exist at all yet)
| Gap | Impact |
|---|---|
| `verifications` table (state machine) | No place to record "ABR returned active for this user's ABN at this timestamp." |
| `verification_events` table (raw JSONB audit trail) | No regulator response is retained, so disputes after the fact have no evidence. |
| ABR Edge Function (`verify-abn`) | The free, cheap, identity-confirming half of verification is not built. |
| State regulator adapters (NSW / VBA / QBCC / SA CBS / WA BPB / TAS CBOS / ACT / NT) | The differentiated half — actual licence verification — is not built. |
| Adapter interface / `LicenceAdapter` contract | Without this, each state's logic risks landing inline inside one Edge Function and becoming unmaintainable on the first regulator HTML change. |
| Re-check on application submit (≤ 24 h cache) | A builder can hire a trade whose licence was suspended yesterday. |
| Privacy Policy v1 language naming ABR + each state regulator | Lawful basis for retrieving and storing regulator data must be in the policy *before* the first call goes out. |

---

## Target architecture

Two parallel checks, one schema, one adapter pattern.

```
Flutter app
   │
   │  POST /functions/v1/verify-abn      { abn }
   │  POST /functions/v1/verify-licence  { licence_number, state, trade_class }
   ▼
Edge Function (Deno + TS)
   ├──► ABR Web Services (free, Commonwealth) — entity name, ABN status, GST status
   └──► State regulator adapter (one per state, behind a single interface)
           NSW Fair Trading / VBA / QBCC / SA CBS / WA BPB / TAS CBOS / ACT / NT
   ▼
Postgres
   verifications         — state machine, one row per (user, kind)
   verification_events   — append-only audit log, raw JSONB regulator response
   verification_documents — fallback path only (manual review queue)
```

### Schema

```sql
CREATE TYPE verification_status AS ENUM (
  'pending', 'verified', 'failed', 'expired', 'suspended', 'manual_review'
);

CREATE TABLE verifications (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  kind                text NOT NULL CHECK (kind IN ('abn','licence')),
  abn                 text,
  licence_number      text,
  licence_state       text CHECK (licence_state IN ('NSW','VIC','QLD','SA','WA','TAS','ACT','NT')),
  licence_trade_class text,
  status              verification_status NOT NULL DEFAULT 'pending',
  verified_at         timestamptz,
  expires_at          timestamptz,
  last_checked_at     timestamptz,
  failure_reason      text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX verifications_user_idx       ON verifications(user_id);
CREATE INDEX verifications_status_idx     ON verifications(status)
  WHERE status IN ('pending','manual_review');
CREATE INDEX verifications_expiring_idx   ON verifications(expires_at)
  WHERE status = 'verified';

CREATE TABLE verification_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  verification_id uuid NOT NULL REFERENCES verifications(id) ON DELETE CASCADE,
  event_type      text NOT NULL,        -- 'api_call' | 'status_change' | 'manual_override'
  raw_response    jsonb,
  actor_id        uuid REFERENCES profiles(id),  -- NULL for system / API events
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX verification_events_vid_idx
  ON verification_events(verification_id, created_at DESC);
```

### RLS (non-negotiable)

```sql
ALTER TABLE verifications        ENABLE ROW LEVEL SECURITY;
ALTER TABLE verification_events  ENABLE ROW LEVEL SECURITY;

-- Owner read
CREATE POLICY verifications_own_read ON verifications
  FOR SELECT USING (auth.uid() = user_id);

-- Block all client writes — only service-role Edge Functions write
CREATE POLICY verifications_no_client_write ON verifications
  FOR ALL USING (false);

-- Admin read (matches Jobdun's existing user_roles pattern)
CREATE POLICY verifications_admin_read ON verifications
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid() AND role = 'admin')
  );
```

Mirror the same three policy shapes on `verification_events`.

### Adapter pattern

The principal-level move. Every state regulator behind one interface so a future "QBCC redesigned their website" is a one-file change.

```typescript
// supabase/functions/_shared/regulators/types.ts
export interface LicenceAdapter {
  state: 'NSW' | 'VIC' | 'QLD' | 'SA' | 'WA' | 'TAS' | 'ACT' | 'NT';
  verify(licenceNumber: string, tradeClass: string): Promise<LicenceResult>;
}

export type LicenceResult =
  | { status: 'verified'; holderName: string; expiresAt: Date; raw: unknown }
  | { status: 'failed';   reason: string;                       raw: unknown }
  | { status: 'unknown';                                        raw: unknown }; // → manual_review
```

`nsw_adapter.ts`, `vic_adapter.ts`, etc., each implement the same shape. The `verify-licence` Edge Function routes by `licence_state`. When a regulator ships a real JSON API, swap one file; nothing else changes.

---

## Trade-offs

| Choice | Gain | Cost |
|---|---|---|
| API-first instead of admin review | Seconds-to-verified, no admin bottleneck, cannot be faked with Photoshop | Engineering work per state (8 regulators ≠ 1 API) |
| Raw JSONB in `verification_events` | Bulletproof audit trail for disputes / legal | ~5–20 KB per check; at 25 k users with 2 checks + 4 re-checks/yr ≈ ~500 MB lifetime |
| Enum status instead of `is_verified bool` | Models suspended / expired / re-verified correctly | One extra migration if a new status is ever needed |
| Manual review as fallback | Covers regulators with no API + edge cases | Still need a basic admin tool — Supabase Studio + one Edge Function is enough for first 1 k users |

**The real trade-off**: Jobdun becomes legally on the hook for verification accuracy. If we say "verified" and the regulator data is stale, a builder hiring an unlicensed tradie has a claim. That is exactly why `verification_events` (with raw response) + `last_checked_at` + **re-check on application submit** exist in the design. The audit trail is the insurance policy.

---

## Failure modes + mitigations

| Failure | Detection | Mitigation |
|---|---|---|
| Regulator API down | Edge Function 5xx → status stays `pending` | Retry with exponential backoff (3 tries, 1 s / 4 s / 16 s + jitter), then route to `manual_review`. Alert if > 5 % of calls fail in 1 h. |
| Regulator changes response shape | Zod schema validation fails | Per-regulator Zod schema. Sentry alert on schema-mismatch. Pin to known-good shapes. |
| Tradie's licence expires mid-job | `expires_at` passes silently | Nightly cron flips `status = 'expired'` and emits a Realtime event so open conversations see it. `verifications_expiring_idx` makes this cheap. |
| Stale verification at hire time | Builder hires tradie whose licence was suspended last week | Re-check on `applications.submit` if `last_checked_at < now() - 24h`; cache otherwise. |
| Wrong-ABN identity mismatch | ABR returns entity name | Require user to confirm "Yes, my business is `<name>`" before storing. Pairs with phone/SMS verification on the account. |
| Manual review queue stalls | `verifications_status_idx` makes the query 1 line | Dashboard tile + alert when oldest `manual_review` row > 48 h. |
| Privacy Act exposure | We are now retrieving + storing regulator data | Consent screen at signup; Privacy Policy v1 names ABR + every state regulator; deletion-on-request cascades through `verifications` and `verification_events`. |

---

## Implementation plan

Order matters.

### Phase 0 — Privacy + legal (pre-flight, 0.5 day)
- Add ABR + named state regulators to Privacy Policy v1.
- Add a verification-consent screen before the wizard. Wire through `legal_acceptances` with `document_type = 'verification_consent'`.

### Phase 1 — Schema + RLS (1 day)
- New migration: `supabase/migrations/<ts>_verifications.sql` (tables + indexes + RLS).
- Verify with `SELECT polname, polcmd, polqual FROM pg_policies WHERE schemaname='public' AND tablename IN ('verifications','verification_events');`.

### Phase 2 — ABR adapter (1 day)
Free, public, no auth beyond a GUID issued at <https://abr.business.gov.au/Tools/WebServices>.
- `supabase/functions/verify-abn/index.ts` (Deno + TS).
- ABN format + checksum validator (reuse `validators.dart` logic on the server).
- Insert `pending` row → call ABR → log raw to `verification_events` → update status → return entity name + status.
- Require client to confirm entity name before the row flips to `verified`.

### Phase 3 — First state adapter — NSW Fair Trading (2 days)
Biggest tradie population, public lookup at <https://verify.licence.nsw.gov.au>.
- `supabase/functions/_shared/regulators/types.ts` — `LicenceAdapter` interface.
- `supabase/functions/_shared/regulators/nsw_adapter.ts` — DOM-parser adapter (Deno).
- `supabase/functions/verify-licence/index.ts` — routes by `licence_state`.

### Phase 4 — Flutter wizard (1–2 days)
- `lib/features/verification/presentation/pages/verification_wizard_page.dart` — three steps: ABN → licence → review.
- New AsyncNotifier `verificationControllerProvider` calling the Edge Functions.
- Loading state copy is **product marketing**: "Verifying with NSW Fair Trading…" — the user must see the system is real.
- `verified` → home; `failed` → reason + manual-upload fallback CTA; `manual_review` → "We're checking this manually, usually under 24 h."
- Per Jobdun standards: `Notifier.build()` does the initial load (no `addPostFrameCallback`), errors flow as `AsyncValue`, repo provider is public for test overrides.

### Phase 5 — Re-check on application submit (0.5 day)
- In the `submit-application` Edge Function (or wherever the trade applies), look up the active licence verification.
- If `kind = 'licence'` and `last_checked_at < now() - interval '24 hours'`, fire the adapter before allowing the application.

### Phase 6 — Expiry cron (0.5 day)
- Supabase cron Edge Function, nightly: `UPDATE verifications SET status = 'expired' WHERE expires_at < now() AND status = 'verified'`.
- Emit Realtime event to flip the user's UI immediately.
- Notify open conversations referencing that user.

### Phase 7 — VIC + QLD adapters (2–3 days)
Covers ~70 % of AU construction once added.

### Phase 8 — Remaining states (defer until signups demand)
SA, WA, TAS, ACT, NT — add each as the first signup from that state lands.

### Phase 9 — Admin review fallback UI (defer until > 1 k users)
Supabase Studio + a single `admin-override-verification` Edge Function with audit logging is the admin tool until volume justifies a real screen. The dashboard tile in `lib/admin/.../admin_dashboard_page.dart:68` is misleading until then; either build the queue or rewrite the tile copy.

---

## Tests + observability

**Tests**
- Unit: ABN checksum validator (Dart + Deno), per-adapter response parsers (mock regulator HTTP).
- Integration: Edge Function against the ABR sandbox.
- E2E: Flutter widget test for the wizard with the Edge Function mocked.

**Observability**
- Sentry: every Edge Function wraps work in a transaction (`verify_abn`, `verify_licence:NSW`, …).
- Structured logs: `{ user_id, verification_id, regulator, outcome, latency_ms }`.
- Dashboard tiles (Supabase + Sentry):
  - p95 verification latency per regulator
  - Verification success rate per regulator (alert if any state drops below 90 %)
  - `manual_review` queue depth + oldest row age
  - Daily expiring-soon count (licences expiring within 30 days)
- Alerts:
  - ABR failure rate > 5 % in 1 h
  - `manual_review` oldest row > 48 h (matches existing Jobdun project standard)
  - Zod schema mismatch from any regulator (signals their HTML changed)

---

## What does this mean for the *existing* `verification_documents` flow?

Nothing is deleted. The table, the trade upload page, the storage bucket, and the upload guards all stay. What changes is **routing**:

- API-first path → writes to `verifications` + `verification_events`. Most users finish here in seconds.
- Manual fallback path → writes to `verification_documents`. Only enters this path when the Edge Function returns `failed` with a recoverable reason, or `unknown` from an ambiguous regulator response.
- Admin review screen + admin RLS policy are still required, but they're a low-volume escape hatch — not the front door. That re-prioritises Phase 9 below the rest.

This also resolves the dashboard misadvertising in `lib/admin/.../admin_dashboard_page.dart:68`: the tile should describe a *fallback queue* once the API path is live, not the primary review surface.

---

## Phase ordering — ship now vs defer

| When | What | Outcome |
|---|---|---|
| **This week** | Phases 0–4 (consent, schema, ABR, NSW, wizard) | "Verified" stamp working for ~30 % of launch geography in 5 days. |
| **Phase 1 close** | Phase 7 (VIC + QLD) | ~70 % of AU construction covered. |
| **Phase 2** | Phase 5 + 6 (re-check + expiry cron) | Important; will not bite until real volume. |
| **Phase 2** | Phase 8 (SA/WA/TAS/ACT/NT) | As signups from each state land. |
| **Phase 3** | Phase 9 (polished admin UI) | After 1 k+ users. Supabase Studio is the admin tool until then. |

---

## Evidence cheat-sheet

| Claim | Where to look |
|---|---|
| Current verification = upload + manual review | `lib/features/verification/presentation/pages/verification_page.dart` |
| Owner-only RLS on `verification_documents` (no admin) | `supabase/migrations/20260511000006_rls.sql:309-329` |
| No `supabase/functions/` directory yet | `ls supabase/` → only `migrations` / `email-templates` / `snippets` |
| Upload guards already landed | commit `731bc48` + `lib/core/services/image_upload_service.dart` |
| Admin dashboard tile advertises review queue that does not exist | `lib/admin/features/admin_shell/presentation/pages/admin_dashboard_page.dart:68` |
| ABN validator already exists in Flutter | `lib/core/utils/validators.dart:29-33` |
| Existing pattern for service-role-only writes | follow `legal_acceptances` migration shape — `supabase/migrations/20260512000001_legal_acceptances.sql` |

## Related docs
- `docs/W1_W3_REALITY_CHECK.md` — broader sprint check; this doc supersedes its W3 verification section for product direction.
- `docs/RBAC_SUPABASE_AUDIT.md` — `user_roles` shape used by the admin RLS policy.
- `docs/JOBDUN_BACKEND_AUDIT.md` — overall backend posture.
