# Messaging — Phase B: Photo & File Sharing (Design Spec)

- **Date:** 2026-06-08
- **Status:** Draft — awaiting Ken sign-off on open questions before implementation
- **Branch:** `feat/messaging-phase-b-attachments` (to branch off `feat/messaging-reliability-core`)
- **Author:** Ken Garcia (with Claude)
- **Depends on:** Phase A Reliability Core (shipped — `20260608000001_message_client_tag.sql`)

---

## Context

Phase A delivered the optimistic-send outbox, the `sending → sent → seen → failed` status ladder,
scroll-back pagination, and the `client_tag` idempotency key. The thread is now reliable for text.

Phase B adds **image and document attachments** inside that same thread. The product driver is
obvious in construction: a builder messages a tradie about a concrete pour; the tradie needs to send
a site photo; the builder needs to send a revised PDF quote. Both happen in the existing 2-party
job-scoped conversation — no new navigation, no new conversation type.

This spec is intentionally tight. It does NOT redesign the thread (Phase C adds reply/react), does
NOT add push notifications (cross-cutting, separate spec), and does NOT add a dedicated media
gallery view (deferred as polish). It adds exactly one capability: send and receive a file in a
message.

---

## Problem

The current `messages.body` is a plain text column. There is no storage path, no MIME type, no
width/height metadata, and no private storage bucket for chat content. The thread UI has no
attachment affordance, no image bubble, and no file bubble. The Phase A outbox (`PendingMessage`)
models only text — no upload state.

---

## Goals

1. Builders and tradies can attach a **job-site photo** (from camera or gallery) to a message and
   the recipient sees a thumbnail that enlarges to full-screen on tap.
2. Builders and tradies can attach a **PDF document** (e.g. a revised quote) and the recipient
   sees a file chip that opens the document via `url_launcher` / `photo_view`.
3. Outgoing attachments integrate into the Phase A outbox with an **uploading** state that extends
   the existing ladder: `uploading → sending → sent → seen → failed`.
4. The attachment upload is **atomic with the message insert**: if the upload fails, no orphan
   `messages` row is created; if the insert fails after a successful upload, the dangling object
   can be cleaned up (best-effort; no cross-table transaction is possible in Supabase).
5. Private objects in `chat-attachments` are only readable by the two conversation participants —
   enforced by bucket RLS, not just obscure paths.
6. All new `.dart` files stay within the ≤ 400 LOC target (≤ 500 hard ceiling). The existing
   thread files (`message_thread_page.dart` 443 LOC, `message_thread_widgets.dart` 407 LOC,
   `messaging_provider.dart` 452 LOC) are already at or near ceiling — Phase B work is budgeted
   into new part files and a split of the provider.

---

## Non-goals (explicitly deferred)

- A multi-media gallery view inside the thread (swipe through all images in a conversation).
- Audio / video messages.
- Inline image previews in the inbox `last_message_preview` (show "📎 Photo" text instead).
- Attachment editing / deletion after send.
- Download-to-device action for files.
- Push notification thumbnails for image messages.
- Server-side image resizing / transcoding (Supabase Storage does not yet provide this; the client
  compresses before upload instead).

---

## Open Questions (needs Ken)

These are flagged rather than assumed. Implementation is blocked on the answers.

| # | Question | Claude's recommendation | Rationale |
|---|---|---|---|
| OQ-1 | **Scope: images only, or images + PDF, or arbitrary files?** | Images + PDF only (v1) | Camera photos and quote PDFs are the two concrete use-cases; arbitrary files (`.xls`, `.docx`) add MIME-sniffing complexity and widen the attack surface without a clear v1 need. |
| OQ-2 | **Max file size per attachment?** | **LOCKED (Ken, 2026-06-08): 10 MB for ALL types** (images + PDF) | One simple cap. Post-compress images land at 300–800 KB; 10 MB also covers multi-page quote PDFs while bounding storage growth. Enforced in 3 places: client pre-upload, bucket `file_size_limit`, and a `byte_size` CHECK. |
| OQ-3 | **Attachments per message: one or many?** | One attachment per message (v1) | Simplifies the data model (no join fan-out on `getMessages`), the UI (one bubble = one intent), and the outbox state machine. Multi-attach is a Phase C/D concern. |
| OQ-4 | **Image source: gallery only, camera only, or both?** | Both (camera + gallery) — same as `ImageUploadService.pickCropCompress` today | Tradies on site need camera; builders reviewing finished work want gallery picks. |
| OQ-5 | **Cropping for chat images?** | No forced crop (`ImageAspect.free`) — preserve site-photo framing | Unlike avatars (square) or portfolio tiles (4:3), site photos have meaningful natural framing (wide shots of concrete pours, door frames, rooflines). Forced crop destroys context. |

> **Ken's decisions (2026-06-08):** OQ-2 locked to **10 MB for all types**. Added requirement: the design must be **good for long-term Supabase data management** — see the section below. OQ-1/3/4/5 keep the recommended defaults.

## Long-term data management (Ken requirement, 2026-06-08)

Attachments are the only unbounded-growth surface in messaging, so the design keeps storage cost + integrity manageable over time:

- **Hard 10 MB cap** enforced in three layers: client pre-upload reject, the `chat-attachments` bucket `file_size_limit`, and the `byte_size <= 10485760` CHECK on `message_attachments`.
- **Orphan prevention + cleanup.** Upload-first-then-insert can leave a dangling object if the row insert fails. A daily **`pg_cron` sweep** deletes objects under `chat-attachments` with no matching `message_attachments.storage_path` older than 24h. `ON DELETE CASCADE` on `message_id` drops attachment rows when a message/conversation is deleted; the same sweep (or a paired trigger) removes the storage object so deletes don't leak files.
- **Signed-URL caching** (60-min TTL in controller state) bounds API calls, not storage.
- **Retention hook (future).** Schema + sweep are written so a later "purge attachments older than N months in archived conversations" job drops in without migration churn.
- **Observability.** `count(*)` + `sum(byte_size)` on `message_attachments` is the cheap per-environment storage dashboard metric.
- **Upstream compression.** Images always pass through `ImageUploadService.pickCropCompress` (typ. 300–800 KB stored), so 10 MB is a guardrail, not the norm.

---

## Decisions (locked once OQs are resolved)

| # | Decision | Choice | Reason |
|---|---|---|---|
| D-1 | **Attachment storage: separate table vs. columns on `messages`** | **Separate `message_attachments` table** (FK → `messages.id`) | Clean normalisation; doesn't widen every `messages` SELECT; makes multi-attach in a later phase a non-breaking additive migration; keeps `messages` realtime payload small (attachments load in a batched follow-up fetch). See Architecture § Attachment data model. |
| D-2 | **Realtime echo carries attachment metadata?** | No — the `messages` realtime echo confirms the message exists; a batched fetch resolves attachments for the live tail. | Adding `message_attachments` to the realtime publication would be a second channel to manage. A batched SELECT keyed on the arriving `message_id` set is simpler and avoids RLS complexity on a joined publication event. |
| D-3 | **Storage bucket** | New private bucket `chat-attachments` (not the existing public `portfolio-images`) | Chat content must be participant-scoped; sharing a public bucket with portfolio images would expose private job-site photos to anyone with the URL. |
| D-4 | **Storage path convention** | `chat-attachments/<conversation_id>/<message_id>/<filename>` | Conversation-scoped prefix allows a future "delete all attachments for a conversation" purge without scanning the whole bucket. `message_id` subfolder supports multi-attach later without collision. |
| D-5 | **Object reads: signed URLs** | Yes — 60-minute signed URLs fetched at display time, cached in controller state by `message_id` | Private bucket = no public URL. 60 min gives enough headroom for a long conversation session; re-fetch on expiry. Alternatively a short-lived token via RPC, but signed URLs are simpler and well-supported by `supabase_flutter`. |
| D-6 | **Upload sequencing** | Upload object first → insert `messages` row + `message_attachments` row | Avoids an orphan `messages` row if the upload fails. A dangling storage object on insert failure is less harmful (no realtime echo = invisible to the recipient; can be GC'd later). |
| D-7 | **Outbox extension** | Add `uploading` state + `storagePath` field to `PendingMessage`; status derivation in `buildThreadEntries` gains the `uploading` case | Consistent with Phase A's pure-derivation pattern. `uploading` replaces `sending` while the object is in flight; the bubble transitions to `sending` once the storage upload completes and the insert is in flight. |
| D-8 | **`body` for attachment-only messages** | Empty string `''` — not null (column is `NOT NULL`) | Keeps the schema unchanged. The inbox `last_message_preview` trigger can detect `body = '' AND attachment exists` → emit `'📎 Photo'` or `'📎 Document'` preview text (trigger change is small). |
| D-9 | **Image aspect for chat** | `ImageAspect.free` (no forced crop) | See OQ-5. |
| D-10 | **PDF pick** | `file_picker` package (already in `pubspec.yaml`? — **verify**) with `FileType.custom`, extensions `['pdf']` | `ImagePicker` only handles images. `file_picker` is the existing pattern for verification docs. |

---

## Architecture

### Attachment data model

**Choice: `message_attachments` table (not columns on `messages`)**

```
message_attachments
  id            uuid PK
  message_id    uuid FK → messages.id ON DELETE CASCADE
  storage_path  text NOT NULL          -- e.g. chat-attachments/<conv>/<msg>/site.jpg
  mime_type     text NOT NULL          -- image/jpeg | image/png | image/webp | application/pdf
  kind          text NOT NULL          -- 'image' | 'file'  (CHECK constraint)
  byte_size     int  NOT NULL
  width         int                    -- px; null for non-image
  height        int                    -- px; null for non-image
  created_at    timestamptz DEFAULT now()
```

Rationale for `kind` denormalisation: `mime_type` alone is enough to derive image vs file, but an
explicit `kind` column lets the Flutter layer switch bubble type without MIME-string parsing and
makes future kinds (video, audio) a `CHECK` update rather than a client code change.

`width`/`height` are stored so the image bubble can reserve the correct aspect ratio space *before*
the image loads — preventing layout jumps (a `content-jumping` UX anti-pattern per ui-ux-pro-max).

### Signed URL cache

A new `Map<String, String> signedUrlsByMessageId` field on `MessagingState` holds pre-fetched
signed URLs. The controller calls `_resolveSignedUrls(List<String> messagIds)` after:
- `_mergeConfirmed` detects incoming messages that have `hasAttachment == true`
  (a boolean flag added to `Message` entity — computed from the batched attachment fetch)
- A signed URL is about to expire (60 min TTL tracked alongside the URL)

Signed URL fetching is a `storage.from('chat-attachments').createSignedUrl(path, 3600)` call — one
per attachment, batched as `Future.wait` keyed on message ID.

### Upload pipeline

```
User taps attach icon
  │
  ├─ image: ImageUploadService.pickCropCompress(aspect: free, quality: 80)
  │          → File (JPEG, ≤ ~800 KB post-compress)
  │
  └─ PDF:   file_picker FileType.custom extensions: ['pdf']
             → PlatformFile

  ↓ (have a file)
  Generate clientTag UUID
  Add PendingMessage(clientTag, status: uploading, localFile: file, ...) to outbox
  ↓
  supabase.storage.from('chat-attachments').uploadBinary(path, bytes)
  ↓ success
  Outbox entry: status → sending (localFile cleared, storagePath set)
  Insert messages row (upsert on client_tag) + message_attachments row
  ↓ realtime echo arrives with client_tag
  Outbox pruned — bubble becomes confirmed (sent/seen)
  ↓ failure (upload OR insert)
  Outbox entry: failed = true → "Couldn't send · Tap to retry"
  Retry: re-upload if no storagePath yet, else re-insert with same client_tag
```

### How `getMessages` / `watchMessages` load attachments

**Not a join — a batched follow-up SELECT:**

1. `getMessages` / live tail yields a `List<MessageModel>` (unchanged shape).
2. Controller calls `_fetchAttachments(List<String> messageIds)` — a single
   `SELECT * FROM message_attachments WHERE message_id = ANY('{...}'::uuid[])` —
   and merges results into `Map<String, MessageAttachment> attachmentsByMessageId`
   on `MessagingState`.
3. `buildThreadEntries` receives the attachment map and populates each
   `ThreadEntry.attachment` field.

**Why not a join?** The `messages.stream()` realtime path returns flat rows; a join
would require switching to `postgres_changes` (more complex, requires row filters).
The batched SELECT approach keeps the existing realtime architecture intact.

**Realtime and attachments:** When the live tail emits a new message with no
attachment in the local map, the controller fires `_fetchAttachments([newMsgId])` —
a single-row lookup. This is fast (indexed FK) and avoids a second realtime channel
for `message_attachments`.

---

## Schema (exact SQL — grounded in real migrations)

### Migration: `supabase/migrations/20260608000002_message_attachments.sql`

```sql
-- ============================================================
-- Messaging Phase B — message_attachments table + chat-attachments bucket
-- Spec: docs/superpowers/specs/2026-06-08-messaging-phase-b-attachments-design.md
-- ============================================================

-- 1. Attachment metadata table ---------------------------------
CREATE TABLE IF NOT EXISTS public.message_attachments (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id   uuid NOT NULL
                 REFERENCES public.messages(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  mime_type    text NOT NULL,
  kind         text NOT NULL
                 CHECK (kind IN ('image', 'file')),
  byte_size    int  NOT NULL CHECK (byte_size > 0 AND byte_size <= 10485760), -- 10 MB
  width        int  CHECK (width  > 0),
  height       int  CHECK (height > 0),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Attachment lookup by message is the hot path.
CREATE INDEX IF NOT EXISTS message_attachments_message_id_idx
  ON public.message_attachments (message_id);

-- 2. RLS on message_attachments --------------------------------
-- A participant can read/write attachments if they can read the parent message.
-- Because messages.conversation_id is the RLS gate, we join through it.
ALTER TABLE public.message_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "participants can read attachments"
  ON public.message_attachments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
      WHERE m.id = message_attachments.message_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

CREATE POLICY "participants can insert attachments"
  ON public.message_attachments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.messages m
      JOIN public.conversations c ON c.id = m.conversation_id
      WHERE m.id = message_attachments.message_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

-- Attachments are immutable after send (no UPDATE / DELETE by participants).
-- ON DELETE CASCADE on the FK handles cleanup when the parent message is deleted.

-- 3. REPLICA IDENTITY — not needed for Phase B.
--    message_attachments is NOT added to supabase_realtime; the client fetches
--    via batched SELECT after the parent messages row echoes. (See spec D-2.)

-- 4. Update the last_message_preview trigger to show attachment hint -----------
-- When body is empty and an attachment exists (inserted after the message), the
-- preview stays as '' at trigger time. The trigger fires on messages INSERT only;
-- we update the preview as a separate step after attachment insert in the Edge
-- Function / RPC if needed.
-- DECISION OQ-1 PENDING: Only extend the trigger after Ken confirms PDF scope.
-- Placeholder: the preview will show '' for attachment-only messages in v1.
-- A follow-up migration updates the trigger after the scope decision.

-- 5. Storage bucket + RLS (applied via Supabase Dashboard / CLI storage config)
-- ⚠ NOTE: Bucket creation and storage RLS policies are NOT SQL migrations —
-- they are applied via `supabase storage` CLI or the Dashboard. Document here
-- for implementation reference only.
--
-- Bucket name:  chat-attachments
-- Public:       false (private)
-- File size cap: 10 MB (all types — Ken-locked 2026-06-08)
-- Allowed MIME:  image/jpeg, image/png, image/webp, image/heic, application/pdf
--
-- Storage RLS policies (SQL applied to storage.objects):
--
-- Policy: "chat participant upload"
--   ON storage.objects FOR INSERT TO authenticated
--   WITH CHECK (
--     bucket_id = 'chat-attachments'
--     AND (
--       -- path format: chat-attachments/<conv_id>/<msg_id>/<filename>
--       -- extract conv_id from path segment 1
--       EXISTS (
--         SELECT 1 FROM public.conversations c
--         WHERE c.id = (string_to_array(name, '/'))[1]::uuid
--           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
--       )
--     )
--   );
--
-- Policy: "chat participant read"
--   ON storage.objects FOR SELECT TO authenticated
--   USING (
--     bucket_id = 'chat-attachments'
--     AND (
--       EXISTS (
--         SELECT 1 FROM public.conversations c
--         WHERE c.id = (string_to_array(name, '/'))[1]::uuid
--           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
--       )
--     )
--   );
```

**Down migration:** `supabase/rollbacks/20260608000002_message_attachments_down.sql`

```sql
DROP TABLE IF EXISTS public.message_attachments;
-- Storage bucket must be emptied and deleted via Dashboard/CLI before running.
```

---

## Module / file plan (with LOC budget)

The three existing files that are at or near ceiling — `message_thread_page.dart` (443),
`message_thread_widgets.dart` (407), `messaging_provider.dart` (452) — **must be split before
adding Phase B code.** Do not grow the files; split first, then add.

### New files (all new)

| File | Approx LOC | What lives here |
|---|---|---|
| `supabase/migrations/20260608000002_message_attachments.sql` | ~80 SQL | Schema migration (above) |
| `supabase/rollbacks/20260608000002_message_attachments_down.sql` | ~5 SQL | Down script |
| `lib/features/messaging/domain/entities/message_attachment.dart` | ~30 | `MessageAttachment` entity (pure Dart, no Flutter imports) |
| `lib/features/messaging/data/models/message_attachment_model.dart` | ~40 | `MessageAttachmentModel.fromJson` |
| `lib/features/messaging/domain/usecases/send_attachment_message.dart` | ~35 | `SendAttachmentMessage` use case |
| `lib/features/messaging/presentation/state/thread_messages.dart` | +~30 | Extend `PendingMessage` (uploading state), `ThreadEntry` (attachment field), `buildThreadEntries` — file grows from 142 → ~172 LOC |
| `lib/features/messaging/presentation/pages/message_thread_attachments.dart` | ~200 | `part` file — `_ImageBubble`, `_FileBubble`, `_AttachmentProgressOverlay`, `_ImageViewerPage` (pushed, not a sheet) |
| `test/features/messaging/thread_attachment_test.dart` | ~120 | Unit tests for extended `buildThreadEntries` + upload state machine |
| `test/features/messaging/attachment_datasource_test.dart` | ~80 | Data-source tests for `fetchAttachments`, `insertAttachment` |

### Modified files — split plan

| File | Current LOC | Action | Target LOC post-split |
|---|---|---|---|
| `messaging_provider.dart` | 452 | Extract `MessagingState` class + helpers into new `messaging_state.dart`; extract outbox mutations into `messaging_outbox.dart` mixin; provider file retains controller skeleton + providers | Provider ≤ 280; state ≤ 120; outbox mixin ≤ 80 |
| `message_thread_page.dart` | 443 | Move `_TypingBubble`, `_HeaderAvatar`, `_ThreadSkeleton`/`_SkeletonBubble` into the existing `message_thread_widgets.dart` part (they logically belong there) — or into a new `message_thread_misc_widgets.dart` part | ≤ 380 |
| `message_thread_widgets.dart` | 407 | `_MessageBubble` expands to dispatch to `_ImageBubble` / `_FileBubble` / text content; the bubble body itself stays here as a shell that delegates | ≤ 480 — if over, extract `_MessageBubble` core into `message_thread_attachments.dart` |
| `message_remote_datasource.dart` | 259 | Add `fetchAttachments`, `insertAttachment`, `uploadAttachmentBytes`, `createSignedUrl` (4 methods, ~60 lines) | ≤ 320 |
| `message_repository_impl.dart` | 130 | Add thin wrappers for the 4 new datasource methods | ≤ 180 |
| `message_repository.dart` (interface) | 37 | Add 4 new method signatures | ≤ 55 |

### Resulting file tree (messaging feature, Phase B)

```
lib/features/messaging/
  data/
    datasources/message_remote_datasource.dart       ≤ 320 LOC
    models/
      conversation_model.dart                        (unchanged)
      message_model.dart                             (+hasAttachment flag ~5 lines)
      message_attachment_model.dart                  ~40 LOC  [NEW]
    repositories/message_repository_impl.dart        ≤ 180 LOC
    services/messaging_realtime_service.dart         (unchanged)
  domain/
    entities/
      conversation.dart                              (unchanged)
      message.dart                                   (+hasAttachment bool ~3 lines)
      message_attachment.dart                        ~30 LOC  [NEW]
    repositories/message_repository.dart             ≤ 55 LOC
    usecases/
      get_conversations.dart, get_messages.dart,
      get_or_create_conversation.dart,
      send_message.dart, watch_messages.dart         (unchanged)
      send_attachment_message.dart                   ~35 LOC  [NEW]
  presentation/
    pages/
      message_thread_page.dart                       ≤ 380 LOC
      message_thread_widgets.dart                    ≤ 480 LOC
      message_thread_status.dart                     (unchanged ~100 LOC)
      message_thread_attachments.dart                ~200 LOC  [NEW part file]
      messages_page.dart                             (unchanged)
    providers/
      messaging_provider.dart                        ≤ 280 LOC (split)
      messaging_state.dart                           ~120 LOC  [NEW - extracted]
      messaging_outbox.dart                          ~80 LOC   [NEW - mixin]
      messaging_realtime_provider.dart               (unchanged)
    state/
      thread_messages.dart                           ~172 LOC (extended)
```

---

## UI Design (dark aggressive-flat tokens)

All values below reference the Jobdun design tokens and the ui-ux-pro-max Flutter stack guidelines.

### Attachment button in the input bar

A secondary icon button sits **left of the text field** (or inside the left padding of the rounded
input container). It uses `AppIcons.attachment` (Phosphor Bold weight = inactive; no file selected).
Color: `c.text3` idle, `c.text2` on hover/press. Size: `AppIconSize.md.r` (24px). Touch target: 44×44.

When `_uploadingAttachment != null` (a file is staged but not yet sent), the icon changes to an
orange `AppIcons.attachmentFilled` and the send button activates — the user sends both the
(optional) text and the staged file together.

### Image bubble (incoming/outgoing)

```
┌─────────────────────────────────────────────────────┐
│  [shimmer shimmer shimmer shimmer shimmer shimmer ]  │  ← while loading
│  [shimmer shimmer shimmer shimmer shimmer shimmer ]  │
│  (replaces shimmer once loaded ↓)                   │
│  ┌───────────────────────────────────┐              │
│  │  CachedNetworkImage (fill)        │              │
│  │  Hero(tag: 'chat-img:<msg_id>')   │  200×150     │
│  └───────────────────────────────────┘              │
│  10:35 AM  ✓✓ (status tick)                         │
└─────────────────────────────────────────────────────┘
```

- **Max width:** `0.65 * MediaQuery.sizeOf(context).width` — same cap as text bubbles.
- **Aspect ratio:** `image.width / image.height` from `MessageAttachment` — stored at upload time,
  so no CLS (content layout shift) during image load. Floor ratio 0.5 (portrait cap), ceil 2.0
  (landscape cap) — prevents absurd dimensions from fisheye or ultra-wide shots.
- **Thumbnail dimensions:** up to 280×210 (4:3 natural max); the stored `width`/`height` sets
  the `AspectRatio` widget so space is reserved before the image bytes arrive.
- **Shimmer placeholder:** `Shimmer.fromColors` with base `c.surface` and highlight
  `c.surfaceRaised` (matches `JSkeletonList` palette).
- **Border radius:** matching the text bubble corner logic — `round`/`tight` based on
  `groupedWithPrev` / `lastInGroup` + 4px inner clip on the image itself (so image corners
  respect the outer bubble clip). Use `ClipRRect`.
- **Outgoing in-flight overlay:** `Stack` with `LinearPercentIndicator` at the image bottom
  edge (height 4, `c.action` fill, `c.surface` background); fade out when `status != uploading`.
- **Tap:** `GestureDetector.onTap → pushNamed('/messages/image-viewer', extra: {url, heroTag})` —
  a dedicated `ImageViewerPage` wrapping `PhotoView` at the fullscreen route. The hero animation
  from the `Hero`-tagged thumbnail to the fullscreen viewer provides the enlarge transition.
  `ImageViewerPage` is a barebones dark scaffold with a single back button.

### File / PDF bubble

```
┌─────────────────────────────────────────────────────┐
│  ┌──┐  site-quote-v3.pdf                            │
│  │PDF│  2.1 MB                                      │  ← tap whole row to open
│  └──┘                                               │
│  10:35 AM  ✓✓                                       │
└─────────────────────────────────────────────────────┘
```

- Container: same surface+border decoration as the text bubble, min-width 180px, max-width 65%
  viewport. Padding `14.w × 12.h`.
- **Icon:** `AppIcons.document` (Phosphor Bold), size `AppIconSize.feature.r` (32px), color
  `c.actionInk` — orange-on-dark (6.37:1 compliant per MASTER.md). Do NOT use `c.action` (that
  is for backgrounds); use `c.actionInk` for inline icon/text.
- **Filename:** `tt.titleSmall` (Open Sans 600, 14px), `c.text1`, truncated with ellipsis at 1 line.
- **Size chip:** `tt.bodySmall` (Open Sans 500, 12px), `c.text3`, formatted as `"2.1 MB"`.
- **Tap target:** whole bubble row → `url_launcher.launchUrl(signedUrl)`. If the signed URL has
  expired, fetch a fresh one first (controller method `_ensureSignedUrl`).
- **Outgoing in-flight state:** replace the file icon with a `CircularProgressIndicator`
  (size 32, stroke 2.5, color `c.actionInk`) while `status == uploading`.

### Accessibility checklist (ui-ux-pro-max CRITICAL rules)

- `Semantics(label: 'Photo attachment, tap to enlarge')` on image bubble tap target.
- `Semantics(label: 'Document: ${attachment.filename}, ${attachment.humanSize}. Tap to open.')` on
  file bubble.
- Both bubbles have `≥ 44dp` touch targets (min height enforced by `ConstrainedBox`).
- Image bubble reserves space before load (AspectRatio widget) — no content-jumping.
- `prefers-reduced-motion` equivalent: the `Hero` transition respects
  `MediaQuery.disableAnimations`; if true, `transitionOnUserGestures: false` suppresses the shared
  element animation and uses an instant push.

---

## Phase A outbox extension

`PendingMessage` gains two new fields (non-breaking — `const` constructor with defaults):

```
PendingMessage {
  ...existing fields...
  AttachmentUploadPayload? uploadPayload,  // non-null while uploading; cleared on confirm
  String? storagePath,                    // set once upload succeeds, before insert
}

AttachmentUploadPayload {
  File localFile,
  String mimeType,
  String kind,        // 'image' | 'file'
  int byteSize,
  int? width,
  int? height,
}
```

`MessageStatus` gains a new case `uploading` (before `sending` in the ladder). Status derivation
in `buildThreadEntries`:

```
pending + uploadPayload != null + !failed  →  uploading
pending + storagePath != null + !failed    →  sending
pending + failed                           →  failed
confirmed + otherLastReadAt >= createdAt   →  seen
confirmed + otherwise                      →  sent
```

The retry path for a failed attachment message first re-attempts the upload if `storagePath == null`
(upload never completed), then re-attempts the insert if `storagePath != null` (upload succeeded
but insert failed). The retry uses the same `clientTag` — idempotency is preserved.

---

## Testing (TDD — no live Supabase)

### Unit tests — `test/features/messaging/thread_attachment_test.dart`

1. `buildThreadEntries` with a pending image message in `uploading` state returns a single entry
   with `status == MessageStatus.uploading`.
2. Uploading → sending state transition: setting `storagePath` and clearing `uploadPayload` on
   the same `PendingMessage` produces `status == MessageStatus.sending`.
3. Server echo with matching `client_tag` removes the pending entry and produces a confirmed
   entry with `status == MessageStatus.sent`.
4. `failed = true` on an outbox entry with an `uploadPayload` (upload failed) produces
   `status == MessageStatus.failed`.
5. `failed = true` on an outbox entry with `storagePath` set (insert failed) also produces
   `MessageStatus.failed` — retry path is distinguishable.
6. `buildThreadEntries` with a mix of text + image + file confirmed messages preserves correct
   `createdAt` ordering.
7. Duplicate confirmed message IDs from tail + history overlap are deduped correctly even when
   one message has an attachment.

### Unit tests — `test/features/messaging/attachment_datasource_test.dart`

Mock the `MessageRemoteDataSource` interface using `mocktail`.

8. `fetchAttachments([msgId1, msgId2])` maps a valid JSON list to `MessageAttachmentModel` with
   correct `kind`, `mimeType`, `byteSize`, `width`, `height`.
9. `fetchAttachments([])` returns an empty list without hitting Supabase.
10. `insertAttachment(...)` constructs the correct row payload; a `ServerException` from the
    datasource propagates as `left(ServerFailure(...))` from the repository.
11. `createSignedUrl(path)` returns the URL string on success; throws `ServerException` on
    storage error.
12. `uploadAttachmentBytes(path, bytes)` returns `storagePath` string on success; throws on
    storage error with a `ServerException`.

### Widget-level smoke tests (existing test file extension)

13. `_ImageBubble` renders a `Shimmer` placeholder when `signedUrl == null`.
14. `_ImageBubble` renders `CachedNetworkImage` once a signed URL is available.
15. `_FileBubble` renders icon + filename + size chip; whole row has a valid tap target.
16. `_AttachmentProgressOverlay` is visible when `entry.status == MessageStatus.uploading`.

---

## Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Signed URL expiry during a long session | Medium | User sees a broken image | `_ensureSignedUrl` re-fetches if `now() > urlFetchedAt + 55 min`; cache the fetch timestamp alongside the URL |
| Upload partial failure (upload OK, insert fails) | Low | Dangling object in `chat-attachments` | Best-effort: log the orphan path; a future cleanup job (cron or Edge Function) can purge objects with no `message_attachments` row older than 1 hour |
| `messaging_provider.dart` exceeds 500 LOC after Phase B additions | High (currently 452) | CI failure | **The split described in the file plan is non-optional and must happen in Step 3 of the plan, before adding Phase B methods** |
| `message_thread_widgets.dart` exceeds 500 LOC after `_ImageBubble`/`_FileBubble` additions | Medium (currently 407) | CI failure | `_ImageBubble` and `_FileBubble` are in the new `message_thread_attachments.dart` part — the widgets file's `_MessageBubble` dispatches to them; widgets file stays as a shell |
| Storage RLS bypassed by path guessing | Low | Participants can read other conversations' files | RLS policy enforces conversation membership regardless of path knowledge; signed URLs also require authenticated session |
| `file_picker` not yet in `pubspec.yaml` | Unknown | Build failure | Verify at plan execution start; it is already used for verification docs — likely present |
| Image `width`/`height` unavailable for PDFs | Certain | No aspect ratio to pre-reserve for PDFs | PDFs get a fixed 48×48 icon slot — no aspect reservation needed; only images use stored dimensions |
| Supabase Storage `createSignedUrl` rate limits | Very low | Burst of signed URL misses | Batch all newly-arrived message IDs into a single `Future.wait` call; never call per-render |
