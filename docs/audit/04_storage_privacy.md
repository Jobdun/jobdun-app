# Storage & Privacy Audit — Jobdun Backend

**Auditor:** storage-privacy-auditor
**Date:** 2026-05-16

## Scope

Every Supabase Storage bucket (name, public/private, policies); verification-doc
isolation + signed-URL handling; client-side image compression/EXIF; file type &
size validation; Australian Privacy Act 1988 / 13 APPs coverage (APP 1, 3, 5, 6,
8, 11, 12, 13); retention schedule; right-to-deletion/anonymisation; Notifiable
Data Breaches runbook. Lens applied to every finding: *does this hold at 25k AU
accounts, one solo engineer, Supabase Pro, Privacy Act 1988?*

## Files reviewed

- `supabase/migrations/20260511000006_rls.sql` (bucket definitions + storage RLS)
- `supabase/migrations/20260511000005_social.sql` (`verification_documents` schema)
- `supabase/migrations/20260512000001_legal_acceptances.sql`
- `lib/features/verification/data/datasources/verification_remote_datasource.dart`
- `lib/features/profile/data/datasources/profile_remote_datasource.dart`
- `lib/features/verification/presentation/pages/verification_page.dart`
- `lib/features/profile/presentation/widgets/portfolio_strip.dart`
- `lib/features/legal/data/legal_acceptance_repository.dart`
- `lib/features/legal/data/legal_document_repository.dart`
- `lib/features/verification/data/models/verification_document_model.dart`
- `assets/legal/privacy_policy.md`, `assets/legal/versions.json`
- Repo root secrets inventory (`.env`, Google OAuth `client_secret_*` / `.plist`)

---

## Summary

| Severity | Count |
|---|---|
| P0 | 3 |
| P1 | 5 |
| P2 | 4 |
| P3 | 2 |

**Overall verdict: RED.**

The relational + bucket scaffolding is sensible (correct public/private split,
owner-scoped storage RLS, immutable consent table, a genuinely thorough
lawyer-reviewable privacy policy). But there are present-tense P0s: the
verification-document upload path **writes columns that do not exist** (broken
today, not "at scale"), verification documents are **never served via signed
URLs** (no code path renders them at all, and the licence path leaks raw private
storage paths into a publicly-readable column), and **APP 8 cross-border data
residency is undetermined** with an active US/Singapore data-flow risk. The
privacy policy *promises* a 30-day delete flow, a retention schedule, and an NDB
process that **have no implementation, no Edge Function, and no data model**
behind them — promising APP rights you cannot technically fulfil is itself a
compliance exposure.

The two answer-the-questions items: **(1)** Yes, `private-docs` is a separate
private bucket. **(5)** Region is **NEEDS HUMAN INPUT** — see F-PRIV-05.

### Direct answers to the 8 scope questions

1. **Private verifications bucket separate from public?** YES — `private-docs`
   (`public=false`) vs `public-media` (`public=true`). Correct split. (F-PRIV-01 PASS-WITH-NOTE)
2. **Signed URLs short-lived (<1h), re-fetched not stored?** NO — there is **zero**
   `createSignedUrl` anywhere in `lib/`. Private docs are never served. The
   licence path also stores the raw storage path into `trade_profiles.licence_url`
   (publicly-readable row). (F-PRIV-02 P0)
3. **App resizes images >2MB before upload?** PARTIAL — `image_picker`
   `maxWidth/maxHeight` + `imageQuality:85` only; `flutter_image_compress`
   present in pubspec but **not wired**; no byte-size cap; PDFs uncompressed. (F-PRIV-07 P2)
4. **EXIF stripped server or client side?** NEITHER reliably — relying on
   `image_picker` re-encode as an implicit side-effect; PDF/`image_cropper` paths
   retain metadata; no server strip. GPS-leak risk for rural tradies. (F-PRIV-08 P1)
5. **Project in `ap-southeast-2`?** **NEEDS HUMAN INPUT** — not determinable from
   repo. APP 8 consequence documented. (F-PRIV-05 P0)
6. **Documented retention schedule?** Policy *text* has one (clause 9); **no
   enforcement, no cron, no `expires_at`/`deleted_at` columns**. (F-PRIV-09 P1)
7. **`data_export_requests` table + Edge Function for APP 12?** MISSING entirely. (F-PRIV-11 P1)
8. **Privacy policy URL versioned + acceptance timestamp stored?** YES —
   `legal_acceptances` is well-designed (immutable, versioned, timestamped,
   admin-readable). Strong PASS. (F-PRIV-13 PASS-WITH-NOTE; one upsert nuance)

---

## Findings

### F-PRIV-01 — Bucket public/private split is correct
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `supabase/migrations/20260511000006_rls.sql:358-403` —
  `public-media` (`public=true`), `private-docs` (`public=false`). Storage RLS
  scopes write/update/delete to `(storage.foldername(name))[1] = auth.uid()::text`
  on both buckets; `private-docs` SELECT is owner-only (no public read policy).
- **Why it matters at 25k AU users:** Correct isolation of licences/insurance
  (sensitive ID-grade data) from avatars/portfolio is the foundational APP 11
  control. This is implemented properly and is the strongest part of the storage layer.
- **Fix (concrete):** None required. Note: there is **no `private_docs_owner_update`
  policy** (only select/insert/delete) — re-uploads use `upsert:true`
  (`profile_remote_datasource.dart:149`) which needs UPDATE on `storage.objects`.
  This means licence re-upload silently fails RLS today. Add:
  ```sql
  -- supabase/migrations/20260516000001_private_docs_update_policy.sql
  CREATE POLICY "private_docs_owner_update" ON storage.objects FOR UPDATE
    USING (bucket_id='private-docs' AND auth.uid()::text=(storage.foldername(name))[1]);
  ```
- **Effort:** XS
- **Phase:** 0
- **Layman's:** Sensitive docs are correctly walled off from public files, but a
  missing rule means re-uploading a licence will fail.

### F-PRIV-02 — Verification documents are never served via signed URLs; licence path leaks raw storage path into a public row
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `grep -rn "createSignedUrl|signedUrl" lib/` → **0 hits**.
  `profile_remote_datasource.dart:154` writes the raw storage path into
  `trade_profiles.licence_url`; `trade_profiles` has a
  `trade_profiles_select_authenticated` policy (`rls.sql:111-114`) — **every
  authenticated user can read every trade's `licence_url` path**. No screen mints
  a time-boxed signed URL to view a doc.
- **Why it matters at 25k AU users:** APP 11 requires private licences/insurance
  to be access-controlled. Storing the object path in a row readable by all 25k
  users defeats the private bucket: while bucket RLS still blocks the *download*,
  the path discloses `userId/trade_licence.pdf` structure and enumerates which
  users hold docs — and the moment any admin/Edge function serves these via a
  long-lived or public URL the leak is total. The verification feature is also
  functionally dead: there is no code that renders an uploaded doc back to the
  owner or a reviewer. At one engineer this ships as a silent privacy hole.
- **Fix (concrete):** Never persist a public/raw URL for private docs. Store only
  the storage *key*; serve via short-lived signed URLs minted on demand and never
  cached:
  ```dart
  // verification_remote_datasource.dart
  Future<String> signedUrlFor(String path) =>
    _client.storage.from('private-docs').createSignedUrl(path, 300); // 5 min
  ```
  Change `trade_profiles.licence_url` to a boolean `has_licence_on_file` (or keep
  path but restrict the column via a column-masking view / drop it from the
  `select_authenticated` policy). Migration:
  `supabase/migrations/20260516000002_licence_url_to_flag.sql`.
- **Effort:** M
- **Phase:** 0
- **Layman's:** Private licence docs have no secure viewing path and their file
  locations are visible to every logged-in user.

### F-PRIV-03 — Verification upload writes columns that do not exist (feature broken at runtime)
- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** Schema `verification_documents` =
  `id, trade_id, type, url, status, created_at, updated_at`
  (`20260511000005_social.sql:27-35`). But
  `verification_remote_datasource.dart:84-99` inserts `doc_type, file_path,
  state, issuer, document_number, issued_date, expiry_date` and filters/orders
  on `deleted_at` and `submitted_at` (lines 39-40, 113, 127, 130). The model
  reads `file_path` (`verification_document_model.dart:26`). Meanwhile
  `profile_remote_datasource.dart:165-170` inserts the *correct* `type, url`.
  Two datasources disagree with each other and with the schema.
- **Why it matters at 25k AU users:** The trade-verification path
  (`VerificationRemoteDataSourceImpl.uploadDocument`/`getMyDocuments`) will throw
  PostgREST `column does not exist` / `PGRST204` on every call — verification is
  non-functional now, before any scale. It also means there is **no
  `expiry_date`** to drive licence-expiry retention/notification (ties to
  F-PRIV-09) and **no `deleted_at`** so verification docs cannot be soft-deleted
  for APP 13 (F-PRIV-12).
- **Fix (concrete):** Add the missing columns and reconcile the two datasources
  to one contract:
  ```sql
  -- supabase/migrations/20260516000003_verification_documents_extend.sql
  ALTER TABLE public.verification_documents
    RENAME COLUMN url TO file_path;            -- pick one name app-wide
  ALTER TABLE public.verification_documents
    ADD COLUMN IF NOT EXISTS state text,
    ADD COLUMN IF NOT EXISTS issuer text,
    ADD COLUMN IF NOT EXISTS document_number text,
    ADD COLUMN IF NOT EXISTS issued_date date,
    ADD COLUMN IF NOT EXISTS expiry_date date,
    ADD COLUMN IF NOT EXISTS submitted_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
  CREATE INDEX IF NOT EXISTS verification_documents_expiry_idx
    ON public.verification_documents(expiry_date) WHERE deleted_at IS NULL;
  ```
  Then standardise both datasources on `doc_type`/`file_path` (or `type`/`url`)
  and update RLS soft-delete (currently RLS has no UPDATE-with-deleted_at guard).
- **Effort:** M
- **Phase:** 0
- **Layman's:** The licence/verification upload screen is broken today because
  the app saves fields the database doesn't have.

### F-PRIV-04 — No file content sniffing; type/size trusted from client extension
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `verification_remote_datasource.dart:64` derives extension from
  `file.path.split('.').last` and maps it to a MIME type
  (`_mimeFromExt`, lines 136-141); `profile_remote_datasource.dart:232-244`
  (`_extOf`/`_contentTypeFor`) does the same. No magic-byte/content sniff. No
  explicit byte-size cap in app code. `supabase/config.toml` has
  `storage.file_size_limit="50MiB"` but that is the *local CLI* value, not
  production, and 50 MiB is far too high for a licence photo.
- **Why it matters at 25k AU users:** An attacker can upload an arbitrary blob
  (e.g. HTML/SVG/script renamed `.jpg`) into `public-media` — publicly readable
  and served from your Supabase domain — enabling stored-XSS/phishing hosted
  under your brand, plus storage-cost abuse with no size ceiling. On Supabase Pro
  storage egress/storage is metered; uncapped uploads at 25k users is a cost and
  abuse vector with one engineer to firefight it.
- **Fix (concrete):** (a) Enforce a per-bucket size + MIME allowlist on the
  bucket in a migration (`UPDATE storage.buckets SET file_size_limit=5242880,
  allowed_mime_types=ARRAY['image/jpeg','image/png','image/webp','application/pdf']
  WHERE id='private-docs';` and similar 2 MB for `public-media`). (b) Add a
  client-side magic-byte check before upload (read first 12 bytes, verify
  JPEG `FF D8 FF` / PNG `89 50 4E 47` / PDF `25 50 44 46`). (c) Reject files
  over the cap before `uploadBinary`.
- **Effort:** S
- **Phase:** 1
- **Layman's:** Anyone can upload a disguised malicious file because we trust the
  filename, not the actual contents, and there's no size limit.

### F-PRIV-05 — APP 8: Supabase data residency / cross-border disclosure undetermined
- **Severity:** P0
- **Status:** RISKY — **NEEDS HUMAN INPUT**
- **Evidence:** No region in `supabase/.temp`, `config.toml`, or any repo file
  (confirmed by 00_SCOPE.md §3). `assets/legal/privacy_policy.md:178,195` itself
  carries `[PLACEHOLDER — confirm Supabase region: Singapore or Sydney]` and
  `[PLACEHOLDER — confirm with Supabase support]`.
- **Why it matters at 25k AU users:** APP 8 makes Jobdun *accountable for the acts
  of overseas recipients* of personal information unless an exception applies. If
  the project is **not** in `ap-southeast-2` (Sydney) — e.g. Singapore or US —
  then 25k Australian tradies' PII (phone, ABN, licence images, location) is
  routinely disclosed cross-border. The policy attempts an APP 8.2(b) consent
  carve-out, but its own `[VERIFY WITH LAWYER]` flags this is unconfirmed.
  Operating with an *unknown* region means you cannot truthfully state where AU
  PII lives — a direct APP 1/8 transparency failure.
- **Fix (concrete):** **NEEDS HUMAN INPUT — Ken must confirm in the Supabase
  dashboard (Project Settings → General → Region) that the project
  `zethpanvkfyijislxesn` is `ap-southeast-2` (Sydney).** If it is not, plan a
  region migration *before* scale (Supabase region cannot be changed in place —
  requires a new project + data migration; do this at low data volume now, not at
  25k users). Then replace both `[PLACEHOLDER]` blocks in `privacy_policy.md` with
  the confirmed region and bump `versions.json` privacy_policy to `1.1.0`.
- **Effort:** S (verify) / XL (if migration needed)
- **Phase:** 0
- **Layman's:** We don't know which country Australians' data is stored in, which
  is itself an Australian privacy-law problem until confirmed as Sydney.

### F-PRIV-06 — Portfolio images public-by-URL with no access control or moderation
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `profile_remote_datasource.dart:182-209` uploads portfolio to
  `public-media` and stores `getPublicUrl(...)` in a profile array via
  `append_portfolio_url`. `public_media_public_read` (`rls.sql:363-366`) makes
  the whole bucket world-readable (no auth required).
- **Why it matters at 25k AU users:** Portfolio job-site photos frequently
  contain client property, addresses on signage, faces of other workers, and
  retained EXIF GPS (see F-PRIV-08). World-readable + guessable
  `userId/portfolio/<microsecond>.jpg` paths means anyone on the internet can
  scrape every tradie's site photos with no auth and no rate limit, and there is
  no takedown/moderation path. Justification check: portfolio *can* be public
  (it's marketing), but it must be (a) auth-gated read or (b) at minimum
  EXIF-stripped + moderatable. Currently neither.
- **Fix (concrete):** Either move portfolio to a private bucket served via
  short-TTL signed URLs (consistent with avatars), OR keep public but: strip EXIF
  before upload (F-PRIV-08), randomise the object key (UUID not timestamp), and
  add a `flagged`/moderation column so abusive images can be removed. Pair with
  trust-safety auditor's moderation gap.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Every tradie's job photos are downloadable by anyone on the
  internet with no login and no way to take bad ones down.

### F-PRIV-07 — No real image compression before upload (rural 3G + cost)
- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `verification_page.dart:43-45` and `portfolio_strip.dart:27-29`
  use only `image_picker` `imageQuality:85` + `maxWidth/maxHeight` 2000/1600.
  `portfolio_strip.dart:15-17` explicitly defers `flutter_image_compress`
  ("if bills get spicy we can layer it later"). No byte-size gate; PDFs (licence
  scans) uploaded raw via `uploadBinary` with no compression.
- **Why it matters at 25k AU users:** `image_picker` quality is platform-variant
  and does not guarantee a byte ceiling — a modern phone photo can still be
  3–6 MB after re-encode. On rural AU 3G (explicit target) a tradie uploading a
  licence + 6 portfolio shots over a flaky link will time out and abandon.
  Storage egress on Supabase Pro is metered; uncompressed multi-MB uploads × 25k
  users is a recurring cost the solo engineer eats.
- **Fix (concrete):** Wire the already-installed `flutter_image_compress`:
  compress to JPEG quality 70, target ≤ 800 KB, before `readAsBytes()` in
  `addPortfolioImage`/`uploadAvatar`/`uploadDocument`. Reject anything still
  > 5 MB. Compress/flatten PDF scans or cap at 2 pages.
- **Effort:** S
- **Phase:** 2
- **Layman's:** Photos aren't shrunk before upload, so uploads fail on slow rural
  internet and storage bills grow faster than they should.

### F-PRIV-08 — EXIF/GPS not stripped (location leak for remote tradies)
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** No EXIF-strip call anywhere
  (`grep -rin "exif" lib/` → 0). Reliance on `image_picker` re-encode is
  implicit and not guaranteed to drop GPS on all platforms; the
  `image_cropper`/PDF paths and any future `flutter_image_compress` use will
  retain EXIF unless explicitly told otherwise. Portfolio images are
  world-readable (F-PRIV-06).
- **Why it matters at 25k AU users:** Job-site and licence photos commonly embed
  GPS coordinates. A rural sole-trader's portfolio photo can geolocate their home
  workshop/residence to within metres, exposed to the entire internet. This is a
  realistic safety risk for an audience of solo tradies and a clear APP 11
  (reasonable security steps) shortfall.
- **Fix (concrete):** Strip EXIF client-side before upload. With
  `flutter_image_compress` set `keepExif: false` (its default) and re-encode;
  for PDFs, sanitise metadata server-side in a future Edge Function. Add a
  belt-and-braces server check (reject objects whose bytes contain an `Exif`/GPS
  IFD) once Edge Functions exist.
- **Effort:** S
- **Phase:** 1
- **Layman's:** Photos can carry hidden GPS tags, so a public portfolio picture
  could reveal a tradie's home location.

### F-PRIV-09 — Retention schedule documented in policy but unenforced (no cron, no expiry/deleted_at)
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** `privacy_policy.md:222-236` defines concrete retention periods
  (messages 90 days post-deletion, verification docs 7 years, etc.). No
  implementation: no `expires_at`/`deleted_at` on `verification_documents`
  (F-PRIV-03), no `deleted_at` on `messages`/`profiles`/`applications`
  (00_SCOPE §2), **no Edge Functions at all** (`supabase/functions/` absent), no
  pg_cron job, no retention worker.
- **Why it matters at 25k AU users:** APP 11.2 requires destroying/de-identifying
  PII no longer needed. The policy makes a binding public promise ("After
  retention periods expire, data is deleted or de-identified" — clause 9.1) that
  the system cannot keep. Indefinitely retained licences/messages for 25k users
  is both an APP 11 breach and an enlarged breach-blast-radius (F-PRIV-14).
- **Fix (concrete):** Add `deleted_at` to messages/profiles/applications;
  `expires_at` to verification_documents (F-PRIV-03). Create a scheduled
  retention Edge Function (cron) `supabase/functions/retention-sweep/` that
  de-identifies/hard-deletes per the clause-9 table, plus a documented
  `docs/runbooks/retention.md`. Coordinate with edge-functions-auditor.
- **Effort:** L
- **Phase:** 2
- **Layman's:** We promise to delete old data on a schedule but nothing actually
  does it.

### F-PRIV-10 — Repo-root secrets unencrypted (`.env`, Google OAuth client secrets)
- **Severity:** P1
- **Status:** RISKY
- **Evidence:** Repo root contains `.env` (1070 B), and three Google OAuth
  files: `client_secret_*-4s51...json`, `client_secret_*-j5ko...json`,
  `client_*-8t1l...plist`. `git check-ignore .env` passes and `git ls-files`
  shows none tracked (per 00_SCOPE §3). Unencrypted on local disk, not in git
  history.
- **Why it matters at 25k AU users:** Not a git-history leak, but a real
  local-disk / accidental-share / backup-sync exposure of OAuth client secrets
  and Supabase keys for the production project. With a solo engineer there is no
  second pair of eyes; an exfiltrated client secret enables OAuth-app
  impersonation against the 25k-user base, and a leaked anon/Supabase key plus
  the residency uncertainty (F-PRIV-05) compounds the APP 11 picture.
- **Fix (concrete):** Move secrets out of the repo tree entirely (OS keychain or
  `~/.config/jobdun/`); document required env in `.env.example` only; rotate the
  two Google `client_secret_*` values now (cheap insurance); add a
  CI/pre-commit secret scanner (gitleaks) to keep them out of history forever.
- **Effort:** S
- **Phase:** 1
- **Layman's:** Production passwords/keys sit as plain files in the project
  folder where they could be copied or synced by accident.

### F-PRIV-11 — APP 12: no data-export path (no `data_export_requests`, no Edge Function)
- **Severity:** P1
- **Status:** MISSING
- **Evidence:** No `data_export_requests` table (00_SCOPE §2), no
  `export-my-data` Edge Function (`supabase/functions/` absent). Privacy policy
  clause 11 promises access to personal information on request.
- **Why it matters at 25k AU users:** APP 12 gives individuals a right to access
  their personal information; the policy commits to honouring it. At 25k AU users
  these requests *will* arrive, and a solo engineer hand-running SQL exports per
  request is unsustainable and error-prone (risk of over-disclosing another
  user's PII in a join).
- **Fix (concrete):** Add `data_export_requests(id, user_id, status,
  requested_at, fulfilled_at, file_path)` table + RLS (own rows), and an
  `export-my-data` Edge Function that assembles a per-user JSON/zip into a
  short-TTL signed-URL in `private-docs`. Migration
  `20260516000004_data_export_requests.sql`. Coordinate with
  edge-functions-auditor for the function skeleton.
- **Effort:** L
- **Phase:** 2
- **Layman's:** Users have a legal right to a copy of their data and there's no
  way to give it to them.

### F-PRIV-12 — APP 13: no deletion/anonymisation flow despite policy promising 30-day delete
- **Severity:** P0
- **Status:** MISSING
- **Evidence:** `privacy_policy.md:284-294` promises "Settings → Account →
  Delete Account", 30-day soft window then hard-delete, 7-year doc retention,
  legal hold. Code: no `deleteAccount`/`anonymise` anywhere
  (`grep -rln "deleteAccount|anonymis" lib/` → 0), no `delete-my-account` Edge
  Function, only `ON DELETE CASCADE` FKs and `jobs`-only soft delete.
- **Why it matters at 25k AU users:** This is the most acute compliance gap: the
  published privacy policy makes a specific, dated APP 13 commitment with a
  concrete UI path that **does not exist**. Promising a deletion right you cannot
  fulfil is a misleading-conduct / Privacy-Act exposure independent of scale, and
  the missing "legal hold vs. delete" logic (keep verification docs 7 yrs while
  anonymising the rest) means a naive cascade would also destroy records you are
  legally required to retain.
- **Fix (concrete):** Build a `delete-my-account` Edge Function implementing:
  mark `profiles.deleted_at`, 30-day grace, then anonymise PII
  (null/redact name/email/phone, replace with `deleted-user-<hash>`), **retain**
  `verification_documents` + `legal_acceptances` per legal hold, hard-delete
  messages after 90 days. Add `deleted_at` columns (F-PRIV-09). Add the Settings
  UI entry the policy already advertises. Migration
  `20260516000005_soft_delete_columns.sql`.
- **Effort:** XL
- **Phase:** 2
- **Layman's:** Our policy promises a delete-my-account button with a 30-day
  grace; that button and its logic do not exist.

### F-PRIV-13 — Versioned consent capture (`legal_acceptances`) is well-built
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `20260512000001_legal_acceptances.sql` — immutable (RLS allows
  only own SELECT + own INSERT, no UPDATE/DELETE), `document_version` +
  `accepted_at` + `app_version`, `UNIQUE(user_id,document_type,document_version)`,
  admin-read for disputes. `legal_acceptance_repository.dart:21-26` records
  acceptance; `legal_document_repository.dart` reads version from
  `assets/legal/versions.json` (currently `1.0.0`/`1.0.0`).
- **Why it matters at 25k AU users:** This is exactly the APP 1/5 consent
  audit-trail you want for 25k users and any future dispute — versioned,
  timestamped, immutable, defensible. Strong.
- **Fix (concrete):** Minor: `recordAcceptance` uses `upsert` (line 21) with no
  explicit `onConflict` — on the `UNIQUE` triple this updates `app_version` and
  is fine, but the *original* acceptance timestamp could be lost if Postgres
  re-touches the row; prefer `insert(...).onError(ignore duplicate)` so the
  first `accepted_at` is preserved verbatim for legal defensibility. Also bump
  `versions.json` whenever the policy `[PLACEHOLDER]`s (F-PRIV-05) are resolved
  so existing users re-consent to the corrected APP 8 disclosure.
- **Effort:** XS
- **Phase:** 1
- **Layman's:** The "user agreed to v1.0.0 of the policy at this time" record is
  done well; just make sure re-saving never overwrites the original timestamp.

### F-PRIV-14 — No Notifiable Data Breaches runbook
- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `privacy_policy.md:324-332` describes the NDB obligation
  (OAIC + affected-individual notification). No `docs/runbooks/` exists
  (00_SCOPE §2), no operational NDB procedure, no breach-detection telemetry
  (observability-ops auditor: no Sentry/logging).
- **Why it matters at 25k AU users:** Part IIIC of the Privacy Act 1988 requires
  assessing a suspected eligible data breach and notifying the OAIC + affected
  individuals if serious harm is likely. With 25k AU users and a solo engineer,
  improvising this under incident pressure guarantees a blown statutory timeline.
  A 1-page runbook is the cheapest compliance control here.
- **Fix (concrete):** Add `docs/runbooks/ndb.md`: detection signals, who
  assesses, the assessment decision tree, OAIC notification template + 30-day
  clock, affected-user comms template, post-incident review. Pair with
  observability-ops auditor for the detection-signal side.
- **Effort:** S
- **Phase:** 2
- **Layman's:** If we get breached there's no written plan for the legally
  required notifications.

### F-PRIV-15 — Avatar served via permanent public URL (acceptable, noted)
- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** `profile_remote_datasource.dart:124` —
  `getPublicUrl('userId/avatar.jpg')`, fixed path, `upsert:true`,
  `public-media`.
- **Why it matters at 25k AU users:** Avatars are low-sensitivity and a stable
  public URL is reasonable for caching/CDN. Acceptable. Two minor notes: the
  fixed `avatar.jpg` path means the CDN can serve a stale image after replacement
  (cache-bust with `?v=updated_at`), and avatars share the EXIF gap (F-PRIV-08) —
  strip EXIF on avatar upload too.
- **Effort:** XS
- **Phase:** 3
- **Layman's:** Public profile pictures are fine as-is; just strip hidden photo
  metadata and bust the cache when changed.

---

## Cross-cutting recommendations

1. **Phase 0 (now, before any further feature work):** Confirm Supabase region
   (F-PRIV-05); fix the broken verification schema/datasource mismatch
   (F-PRIV-03); stop leaking private storage paths and add signed-URL serving
   (F-PRIV-02); add the missing `private_docs` UPDATE policy (F-PRIV-01).
2. **Stop promising APP rights you can't fulfil.** The privacy policy (a
   genuinely good document) currently advertises delete-account (F-PRIV-12),
   data export (F-PRIV-11), and a retention schedule (F-PRIV-09) that have **no
   implementation**. Either build them (Phase 2) or amend the published policy
   until they exist — the current state is the worst of both.
3. **One image pipeline, one place.** Centralise compress + EXIF-strip +
   magic-byte validation + size cap into a single `core/` helper used by all
   three upload paths (avatar, portfolio, verification). Fixes F-PRIV-04/07/08
   together and is the only sustainable shape for a solo engineer.
4. **Bucket-level hardening migration.** Set `file_size_limit` +
   `allowed_mime_types` on both buckets in SQL (don't rely on client checks or
   the local-only `config.toml`).
5. **Edge Functions are the critical path for compliance.** Retention sweep,
   data export, account deletion, and licence-expiry all require the (currently
   non-existent) `supabase/functions/`. Sequence this with the
   edge-functions-auditor.
6. **Secrets off the repo tree + rotate** (F-PRIV-10) and add a secret scanner.

## Open questions for Ken

1. **APP 8 / F-PRIV-05 — what region is project `zethpanvkfyijislxesn`?**
   Confirm in Supabase dashboard → Project Settings → General → Region. If it is
   *not* `ap-southeast-2` (Sydney), a region migration is needed and is far
   cheaper now than at 25k users (Supabase cannot relocate a project in place).
2. The privacy policy promises a **7-year retention** for verification docs and
   legal records (`privacy_policy.md:231,294`) marked `[VERIFY WITH LAWYER]` —
   has the AU privacy lawyer review (budgeted in the policy at AUD $1,500–3,500)
   been done? It directly drives the retention/deletion data model.
3. Should **portfolio images** be auth-gated (private bucket + signed URLs) or
   remain world-public marketing? This decision changes F-PRIV-06/08 effort.
4. Is there an **admin web app** consuming `private-docs` for verification
   review? If so, how does it mint URLs today (service-role? signed?) — that path
   is outside this repo and must be audited for the F-PRIV-02 leak.
5. Confirm the canonical `verification_documents` column names
   (`type/url` vs `doc_type/file_path`) so the schema migration in F-PRIV-03
   matches the intended app contract.
