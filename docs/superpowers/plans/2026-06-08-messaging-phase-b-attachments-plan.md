# Messaging — Phase B: Photo & File Sharing (Implementation Plan)

- **Date:** 2026-06-08
- **Status:** Ready to execute — pending Ken's answers to OQ-1 through OQ-5
- **Branch:** `feat/messaging-phase-b-attachments`
  (branch off `feat/messaging-reliability-core` **after** Phase A is merged)
- **Spec:** `docs/superpowers/specs/2026-06-08-messaging-phase-b-attachments-design.md`
- **Validation command:** `bash scripts/validate.sh`
- **Architecture audit:** `bash scripts/check-architecture.sh`

---

## Prerequisites (before writing any code)

- [ ] Ken has answered OQ-1 (scope: images + PDF confirmed?), OQ-2 (max file sizes), OQ-3 (one
      attachment per message), OQ-4 (camera + gallery), OQ-5 (no forced crop for chat images).
- [ ] Phase A branch `feat/messaging-reliability-core` is merged (or this branch is rebased on
      top of it with `git rebase feat/messaging-reliability-core`).
- [ ] Run `flutter pub get` and confirm `file_picker` is in `pubspec.yaml` (used for verification
      docs — should already be present). If absent, add it before Step 1.
- [ ] Create and push the branch:
      `git checkout -b feat/messaging-phase-b-attachments feat/messaging-reliability-core`

**New pubspec dependencies (check each — add only if absent):**

| Package | Already present? | Used for |
|---|---|---|
| `file_picker` | Likely yes (verification docs) | PDF pick |
| `cached_network_image` | Yes (profiles) | Image bubbles |
| `shimmer` | Yes (job feed) | Image placeholder |
| `photo_view` | Yes (portfolio) | Tap-to-enlarge viewer |
| `flutter_image_compress` | Yes (image upload service) | Image pre-compress |

No new packages expected. Verify before `flutter pub get`.

---

## Step 1 — Supabase: create storage bucket + RLS

**Verification:** bucket exists in Supabase Dashboard Storage tab; storage RLS policies are active.

### 1a. Create the `chat-attachments` bucket

Via Supabase Dashboard → Storage → New bucket:
- Name: `chat-attachments`
- Public: **No** (private)
- File size limit: `20971520` (20 MB)
- Allowed MIME types: `image/jpeg,image/png,image/webp,image/heic,application/pdf`

Or via CLI (if bucket management is wired in your Supabase config):
```bash
supabase storage create-bucket chat-attachments --public=false
```

### 1b. Apply storage RLS policies

In Supabase Dashboard → Storage → Policies → `chat-attachments`, add two policies:

**Policy 1 — Insert (authenticated participants only)**
```sql
-- Name: "chat participant upload"
-- Operation: INSERT
-- Target roles: authenticated
(bucket_id = 'chat-attachments')
AND EXISTS (
  SELECT 1 FROM public.conversations c
  WHERE c.id = (string_to_array(name, '/'))[1]::uuid
    AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
)
```

**Policy 2 — Select (authenticated participants only)**
```sql
-- Name: "chat participant read"
-- Operation: SELECT
-- Target roles: authenticated
(bucket_id = 'chat-attachments')
AND EXISTS (
  SELECT 1 FROM public.conversations c
  WHERE c.id = (string_to_array(name, '/'))[1]::uuid
    AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
)
```

**Checkpoint:** Upload a test file to `chat-attachments/<any-conv-id>/test/file.jpg` while
authenticated as a participant; confirm it succeeds. Attempt to read it while authenticated as a
non-participant; confirm it returns 403.

---

## Step 2 — Migration: `message_attachments` table

**Files touched:**
- `supabase/migrations/20260608000002_message_attachments.sql` ← **CREATE**
- `supabase/rollbacks/20260608000002_message_attachments_down.sql` ← **CREATE**

### 2a. Write the migration

Paste the exact SQL from the spec (§ Schema). Key points:
- `CREATE TABLE IF NOT EXISTS public.message_attachments (...)` with the FK, CHECK, index.
- RLS enabled + two policies (participant-scoped SELECT + INSERT via message→conversation join).
- No `REPLICA IDENTITY` / no `supabase_realtime` publication entry — attachments are fetched via
  batched REST, not streamed.

```bash
# Apply locally
supabase db push
# Or against the linked project
supabase db push --linked
```

**Checkpoint:** `\d public.message_attachments` in psql shows the table, FK, index, and RLS
enabled. `SELECT * FROM pg_policies WHERE tablename = 'message_attachments';` returns 2 rows.

### 2b. Write the rollback

```sql
-- supabase/rollbacks/20260608000002_message_attachments_down.sql
DROP TABLE IF EXISTS public.message_attachments;
-- Storage bucket must be manually emptied + deleted via Dashboard before this runs.
```

---

## Step 3 — Split existing files (mandatory before adding Phase B code)

The three files at or near the 500 LOC ceiling **must** be split before any new code is added.
This step adds zero functionality — it is a pure refactor. Run `flutter analyze` and `flutter test`
before and after to confirm the refactor is neutral.

### 3a. Extract `MessagingState` + helpers → `messaging_state.dart`

**File to create:**
`lib/features/messaging/presentation/providers/messaging_state.dart`

Move out of `messaging_provider.dart`:
- The `MessagingState` class and its `copyWith`
- The `messagesFor`, `isThreadLoaded`, `outboxFor`, `otherLastReadFor`, `hasMoreFor`,
  `entriesFor` helper methods
- The `MessagingState` constructor and field declarations

`messaging_provider.dart` imports `messaging_state.dart`.

Target: `messaging_state.dart` ≤ 120 LOC; `messaging_provider.dart` ≤ 300 LOC.

### 3b. Extract outbox mutation helpers → `messaging_outbox.dart`

**File to create:**
`lib/features/messaging/presentation/providers/messaging_outbox.dart`

Move out of `messaging_provider.dart`:
- `_addToOutbox`
- `_updateOutbox`
- `_dispatch` (the private send dispatcher)
- The `_sendTimeout` constant

This is a mixin on `MessagingController` — use `mixin _OutboxMixin on Notifier<MessagingState>`
and `with _OutboxMixin` on the class. See CLAUDE.md file-size recipe: "mixin-on-Notifier".

Target: `messaging_outbox.dart` ≤ 100 LOC; `messaging_provider.dart` ≤ 260 LOC.

### 3c. Move `_TypingBubble`, `_HeaderAvatar` into `message_thread_widgets.dart`

These two widgets are currently in `message_thread_page.dart` (443 LOC) but logically belong with
the other presentational widgets. Moving them frees ~80 LOC from the page file, leaving room for
the attachment input affordance and dispatch logic to be added in Step 6.

After move: `message_thread_page.dart` ≤ 370 LOC; `message_thread_widgets.dart` ≤ 480 LOC.

**Checkpoint after Step 3:**
```bash
flutter analyze --no-fatal-infos
flutter test
bash scripts/validate.sh
```
All green. No functionality change.

---

## Step 4 — Domain: entities + use case

### 4a. `MessageAttachment` entity

**File to create:**
`lib/features/messaging/domain/entities/message_attachment.dart`

```
MessageAttachment {
  final String id;
  final String messageId;
  final String storagePath;
  final String mimeType;
  final String kind;      // 'image' | 'file'
  final int byteSize;
  final int? width;
  final int? height;
  final DateTime createdAt;

  // Derived helpers (no Flutter/Supabase imports)
  bool get isImage => kind == 'image';
  String get filename => storagePath.split('/').last;
  String get humanSize => ... // e.g. '2.1 MB'
}
```

Rule: domain entity — **no** `flutter`, **no** `supabase_flutter`, **no** `core/config` imports.
Extends `Equatable`.

**Checkpoint:** `bash scripts/check-architecture.sh` — domain-purity check passes.

### 4b. Add `hasAttachment` to `Message` entity

**File:** `lib/features/messaging/domain/entities/message.dart`

Add `final bool hasAttachment;` (default `false`) to the entity and update `props`. This flag
is set from the data layer when `MessageModel` is constructed — it avoids the controller needing
to cross-reference the attachment map just to know whether to fire `_fetchAttachments`.

### 4c. `SendAttachmentMessage` use case

**File to create:**
`lib/features/messaging/domain/usecases/send_attachment_message.dart`

Parameters:
```
call({
  required String conversationId,
  required String senderId,
  required String clientTag,
  required String storagePath,
  required String mimeType,
  required String kind,
  required int byteSize,
  int? width,
  int? height,
  String body,       // defaults to '' for attachment-only messages
})
```

Returns `Future<Either<Failure, void>>`. Calls:
1. `_repository.sendMessage(conversationId, senderId, body, clientTag)` — inserts the `messages`
   row (body is `''` for attachment-only).
2. `_repository.insertAttachment(messageId: ..., storagePath: ..., ...)` — inserts
   `message_attachments` row.

Note: `messageId` is not known until after the `sendMessage` insert. The repository's
`sendMessage` method must return the server-assigned `id` (add `select('id')` to the upsert
in the datasource — see Step 5b). Update `sendMessage` signature accordingly (returns
`Future<Either<Failure, String>>` instead of `void`).

**Checkpoint:** `bash scripts/check-architecture.sh` — use-case-coverage check; the new use case
is wired in Step 7 (controller) and tested in Step 8.

---

## Step 5 — Data layer: datasource + model + repository

### 5a. `MessageAttachmentModel`

**File to create:**
`lib/features/messaging/data/models/message_attachment_model.dart`

`fromJson` maps the `message_attachments` SELECT response. Extends `MessageAttachment`.

### 5b. Extend `MessageRemoteDataSource`

**File:** `lib/features/messaging/data/datasources/message_remote_datasource.dart`

Add to the interface and implementation:

```dart
/// Fetch attachments for a batch of message IDs in a single SELECT.
Future<List<MessageAttachmentModel>> fetchAttachments(List<String> messageIds);

/// Insert a message_attachments row after the message insert.
Future<void> insertAttachment({
  required String messageId,
  required String storagePath,
  required String mimeType,
  required String kind,
  required int byteSize,
  int? width,
  int? height,
});

/// Upload raw bytes to chat-attachments bucket. Returns the final storage path.
Future<String> uploadAttachmentBytes({
  required String path,   // e.g. '<conv_id>/<msg_id>/site.jpg'
  required Uint8List bytes,
  required String contentType,
});

/// Generate a 60-minute signed URL for a private object.
Future<String> createSignedUrl(String storagePath);
```

Also update `sendMessage` to return the server-assigned row id:
```dart
// Change return type: Future<void> → Future<String>  (returns messages.id)
Future<String> sendMessage({...});
```

The `upsert` call gains `.select('id')` and returns the inserted ID.

**Budget check:** datasource should stay ≤ 320 LOC.

### 5c. Extend `MessageRepository` interface and `MessageRepositoryImpl`

**Files:**
- `lib/features/messaging/domain/repositories/message_repository.dart` — add 4 new method
  signatures + update `sendMessage` return type.
- `lib/features/messaging/data/repositories/message_repository_impl.dart` — add 4 thin wrappers
  with try/catch → `left(ServerFailure(...))` / `right(...)` pattern (same as existing methods).

Update `MessageModel.fromJson` to set `hasAttachment: false` by default — the flag is populated
by the controller after `_fetchAttachments`, not from the SELECT itself.

**Checkpoint:**
```bash
flutter analyze --no-fatal-infos
```
No new errors. The `sendMessage` return-type change will surface as a compile error in
`SendMessage` use case and `MessagingController._dispatch` — fix those in this step.

---

## Step 6 — Presentation: new `part` file for attachment widgets

**File to create:**
`lib/features/messaging/presentation/pages/message_thread_attachments.dart`

```dart
part of 'message_thread_page.dart';
```

Contains (all private, single-caller per file rule):

### `_ImageBubble`

```
_ImageBubble({
  required ThreadEntry entry,
  required bool isMine,
  required MessageAttachment attachment,
  String? signedUrl,          // null = shimmer; non-null = CachedNetworkImage
  required bool groupedWithPrev,
  required bool lastInGroup,
})
```

Structure:
```
Container (bubble shape + border)
  Stack
    ├── AspectRatio(ratio: attachment.width / attachment.height, clamped 0.5–2.0)
    │     ├── signedUrl == null ? Shimmer placeholder
    │     └── Hero(tag: 'chat-img:${entry.key}')
    │           CachedNetworkImage(url: signedUrl, fit: BoxFit.cover)
    │           ClipRRect(borderRadius matches bubble)
    └── if entry.status == MessageStatus.uploading
          Positioned(bottom: 0) LinearPercentIndicator(...)
  Gap(4.h)
  Row (time + status tick)  — reuse existing _StatusTick
```

On tap: push `/messages/image-viewer` with `{signedUrl, heroTag}` via `context.push`.

### `_ImageViewerPage`

A full-screen route (registered in `app_router.dart` at `/messages/image-viewer`):
```
Scaffold(backgroundColor: Colors.black // intentional — viewer is always black)
  Stack
    PhotoView(imageProvider: NetworkImage(signedUrl), heroTag: heroTag)
    Positioned(top: safeTop) back button (c.text1 icon on translucent surface)
```

Registration in `lib/app/router/app_router.dart`:
```dart
GoRoute(
  path: '/messages/image-viewer',
  builder: (ctx, state) {
    final extra = state.extra as Map<String, dynamic>;
    return ImageViewerPage(
      signedUrl: extra['signedUrl'] as String,
      heroTag: extra['heroTag'] as String,
    );
  },
),
```

### `_FileBubble`

```
_FileBubble({
  required ThreadEntry entry,
  required bool isMine,
  required MessageAttachment attachment,
  required String? signedUrl,
  required VoidCallback? onOpen,
  required bool groupedWithPrev,
  required bool lastInGroup,
})
```

Structure:
```
GestureDetector(onTap: signedUrl != null ? onOpen : null)
  Container (bubble shape — same as text bubble)
    Column
      Row
        ├── status == uploading
        │     CircularProgressIndicator(size: 32, color: c.actionInk)
        └── otherwise
              Icon(AppIcons.document, size: AppIconSize.feature.r, color: c.actionInk)
        Gap(10.w)
        Column(crossAxisAlignment: start)
          Text(attachment.filename, style: tt.titleSmall, maxLines: 1, overflow: ellipsis)
          Text(attachment.humanSize, style: tt.bodySmall, color: c.text3)
      Gap(4.h)
      Row (time + status tick)
```

### `_AttachmentPickerSheet`

A `showJSheet` bottom sheet triggered by the attachment icon. Two rows:
- `AppIcons.camera` + "TAKE PHOTO" → `ImageSource.camera`
- `AppIcons.gallery` + "CHOOSE FROM GALLERY" → `ImageSource.gallery`
- (If OQ-1 includes PDF) `AppIcons.document` + "ATTACH DOCUMENT" → `file_picker`

Each row is a full-width `ListTile`-style row (48dp minimum height) with an icon (`c.text2`) and
label (`tt.titleSmall`, `c.text1`, uppercase).

**Budget check:** `message_thread_attachments.dart` ≤ 200 LOC. If over, `_ImageViewerPage`
can move to its own file `message_image_viewer_page.dart`.

---

## Step 7 — Controller: upload orchestration + signed URL cache

**Files:** `messaging_provider.dart` (post-split) + `messaging_outbox.dart` mixin

### 7a. Extend `MessagingState`

**File:** `messaging_state.dart` (from Step 3a)

Add two new fields:
```dart
final Map<String, MessageAttachment> attachmentsByMessageId;
final Map<String, String> signedUrlsByMessageId;    // messageId → signed URL
final Map<String, DateTime> signedUrlFetchedAt;     // for expiry tracking
```

Add helpers: `attachmentFor(String msgId)`, `signedUrlFor(String msgId)`.

### 7b. Wire attachment pick into `MessagingController`

Add to the controller (or outbox mixin):

```dart
/// Called when the user taps the attachment icon and picks a file.
/// Stages the attachment for the next send — does NOT start the upload yet.
/// The upload starts when the user taps Send (so text + attachment send together).
Future<void> stageAttachment({
  required String conversationId,
  required AttachmentUploadPayload payload,
}) async { ... }

/// Called on Send tap when an attachment is staged. Runs:
///   upload → insert messages row → insert message_attachments row
/// Integrates with the outbox; uses the same clientTag for idempotency.
Future<void> sendAttachmentMessage({
  required String conversationId,
  required String? body,
  required AttachmentUploadPayload payload,
}) async {
  final senderId = readCurrentUserId(ref);
  if (senderId == null) return;

  final tag = uuidV4();
  final pending = PendingMessage(
    clientTag: tag,
    conversationId: conversationId,
    senderId: senderId,
    body: body ?? '',
    createdAt: DateTime.now(),
    uploadPayload: payload,   // status: uploading
  );
  _addToOutbox(conversationId, pending);

  // 1. Upload
  final path = '$conversationId/$tag/${_basename(payload.localFile)}';
  Either<Failure, String> uploadResult;
  try {
    final bytes = await payload.localFile.readAsBytes();
    uploadResult = await _repo.uploadAttachmentBytes(
      path: path, bytes: bytes, contentType: payload.mimeType,
    );
  } catch (e) {
    _updateOutbox(conversationId, tag, failed: true);
    return;
  }
  uploadResult.fold(
    (f) => _updateOutbox(conversationId, tag, failed: true),
    (storagePath) async {
      // Transition uploading → sending
      _updateOutboxStoragePath(conversationId, tag, storagePath);

      // 2. Insert messages row (returns server id)
      final msgResult = await ref.read(sendAttachmentMessageUseCaseProvider).call(
        conversationId: conversationId,
        senderId: senderId,
        clientTag: tag,
        storagePath: storagePath,
        mimeType: payload.mimeType,
        kind: payload.kind,
        byteSize: payload.byteSize,
        width: payload.width,
        height: payload.height,
        body: body ?? '',
      ).timeout(_sendTimeout);

      msgResult.fold(
        (_) => _updateOutbox(conversationId, tag, failed: true),
        (_) {},  // realtime echo prunes the outbox
      );
    },
  );
}
```

### 7c. `_fetchAttachments` — batched lookup

```dart
Future<void> _fetchAttachments(String conversationId, List<String> messageIds) async {
  if (messageIds.isEmpty) return;
  final result = await _repo.fetchAttachments(messageIds);
  result.fold(
    (_) {},  // non-fatal — bubbles degrade to placeholder
    (attachments) {
      final map = Map<String, MessageAttachment>.from(state.attachmentsByMessageId);
      for (final a in attachments) map[a.messageId] = a;
      state = state.copyWith(attachmentsByMessageId: map);
      // Kick off signed URL resolution for any new entries.
      _resolveSignedUrls(attachments.map((a) => a.messageId).toList());
    },
  );
}
```

Called from `_mergeConfirmed` after any messages with `hasAttachment == true` arrive.

### 7d. `_resolveSignedUrls` — batched URL fetch

```dart
Future<void> _resolveSignedUrls(List<String> messageIds) async {
  // Filter to only those without a valid (non-expired) signed URL.
  final now = DateTime.now();
  final toFetch = messageIds.where((id) {
    final fetchedAt = state.signedUrlFetchedAt[id];
    return fetchedAt == null || now.difference(fetchedAt).inMinutes > 55;
  }).toList();
  if (toFetch.isEmpty) return;

  final attachments = toFetch
      .map((id) => state.attachmentsByMessageId[id])
      .whereType<MessageAttachment>()
      .toList();

  final results = await Future.wait(
    attachments.map((a) => _repo.createSignedUrl(a.storagePath)),
    eagerError: false,
  );

  final urls = Map<String, String>.from(state.signedUrlsByMessageId);
  final fetchedAt = Map<String, DateTime>.from(state.signedUrlFetchedAt);
  for (var i = 0; i < attachments.length; i++) {
    final result = results[i];
    result.fold((_) {}, (url) {
      urls[attachments[i].messageId] = url;
      fetchedAt[attachments[i].messageId] = now;
    });
  }
  state = state.copyWith(
    signedUrlsByMessageId: urls,
    signedUrlFetchedAt: fetchedAt,
  );
}
```

### 7e. Wire `sendAttachmentMessageUseCaseProvider`

Add to `messaging_provider.dart` (alongside existing use-case providers):
```dart
final sendAttachmentMessageUseCaseProvider = Provider(
  (ref) => SendAttachmentMessage(ref.read(messageRepositoryProvider)),
);
```

**Checkpoint:**
```bash
flutter analyze --no-fatal-infos
flutter test
```
Compile-clean. No new test failures.

---

## Step 8 — Input bar: attachment affordance

**File:** `lib/features/messaging/presentation/pages/message_thread_page.dart`

### 8a. State additions to `_MessageThreadPageState`

```dart
AttachmentUploadPayload? _stagedAttachment;   // non-null when a file is staged

void _clearStaged() => setState(() => _stagedAttachment = null);
```

### 8b. Attachment icon button (left of text field)

In the input bar `Row`, add before the `Expanded` text field:

```dart
GestureDetector(
  onTap: _pickAttachment,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 42.r,
    height: 42.r,
    alignment: Alignment.center,
    child: Icon(
      _stagedAttachment != null ? AppIcons.attachmentFilled : AppIcons.attachment,
      size: AppIconSize.md.r,
      color: _stagedAttachment != null ? c.actionInk : c.text3,
    ),
  ),
),
Gap(6.w),
```

### 8c. `_pickAttachment` — shows `_AttachmentPickerSheet`

```dart
Future<void> _pickAttachment() async {
  final result = await showJSheet<AttachmentUploadPayload?>(
    context: context,
    child: _AttachmentPickerSheet(),
  );
  if (result == null) return;
  setState(() => _stagedAttachment = result);
  // Activate the send button even if text field is empty.
}
```

### 8d. Staged attachment preview strip (above input bar)

When `_stagedAttachment != null`, render a thin preview row between the typing indicator and the
input bar:

```
┌─────────────────────────────────────────────────────┐
│ [img thumb or file icon]  site.jpg  ✕               │  ← 56dp tall
└─────────────────────────────────────────────────────┘
```

- Background: `c.surface`, top border `c.border`.
- Thumbnail (image kind): 40×40 `Image.file` with `BoxFit.cover` and `ClipRRect(4.r)`.
- File kind: `AppIcons.document` 32px `c.actionInk`.
- Filename: `tt.bodySmall`, `c.text2`, 1-line truncated.
- `✕` button (dismiss) calls `_clearStaged()`.

### 8e. `_send` override

```dart
Future<void> _send() async {
  final text = _textCtrl.text.trim();
  final attachment = _stagedAttachment;
  // Require at least one of: text or attachment.
  if (text.isEmpty && attachment == null) return;

  _textCtrl.clear();
  _clearStaged();

  if (attachment != null) {
    await _messaging.sendAttachmentMessage(
      conversationId: _conversationId,
      body: text.isEmpty ? null : text,
      payload: attachment,
    );
  } else {
    await _messaging.sendMessage(
      conversationId: _conversationId,
      body: text,
    );
  }
}
```

The send button activates when `text.isNotEmpty || _stagedAttachment != null`.

**Checkpoint:** manually test with a real device — pick a photo from gallery, confirm the preview
strip appears, tap send, confirm the `uploading` spinner shows on the outgoing bubble, confirm the
image renders once the upload completes.

---

## Step 9 — Bubble dispatch: wire `_MessageBubble` to `_ImageBubble` / `_FileBubble`

**File:** `lib/features/messaging/presentation/pages/message_thread_widgets.dart`

Modify `_MessageBubble.build` to check `entry.attachment`:

```dart
final attachment = entry.attachment;  // from ThreadEntry (added in Step 4b extension of state)

// Bubble content: image, file, or text
final Widget content;
if (attachment != null && attachment.isImage) {
  content = _ImageBubble(
    entry: entry,
    isMine: isMine,
    attachment: attachment,
    signedUrl: ref.watch(
      messagingControllerProvider.select(
        (s) => s.signedUrlFor(entry.key),
      ),
    ),
    groupedWithPrev: groupedWithPrev,
    lastInGroup: lastInGroup,
  );
} else if (attachment != null) {
  content = _FileBubble(
    entry: entry,
    isMine: isMine,
    attachment: attachment,
    signedUrl: ref.watch(
      messagingControllerProvider.select((s) => s.signedUrlFor(entry.key)),
    ),
    onOpen: () => _openFile(context, ref, entry.key),
    groupedWithPrev: groupedWithPrev,
    lastInGroup: lastInGroup,
  );
} else {
  content = ... // existing text bubble Container
}
```

Add `_openFile` helper:

```dart
Future<void> _openFile(BuildContext ctx, WidgetRef ref, String messageKey) async {
  final url = ref.read(
    messagingControllerProvider.select((s) => s.signedUrlFor(messageKey)),
  );
  if (url == null) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

**Note:** `_MessageBubble` needs access to `ref` to watch the signed URL. Convert it from
`StatelessWidget` to `ConsumerWidget`. This is a targeted exception to the "private widgets
are StatelessWidget" convention — the signed URL is reactive state that must rebuild when
the URL resolves, and the widget is a single-file `part` so it has no independence.

---

## Step 10 — Router: register `ImageViewerPage` route

**File:** `lib/app/router/app_router.dart`

Add inside the `/messages` route group:

```dart
GoRoute(
  path: 'image-viewer',
  builder: (ctx, state) {
    final extra = state.extra as Map<String, dynamic>;
    return ImageViewerPage(
      signedUrl: extra['signedUrl'] as String,
      heroTag: extra['heroTag'] as String,
    );
  },
),
```

Full path becomes `/messages/image-viewer`.

**Checkpoint:** tap an image bubble → viewer pushes with hero transition → back button pops with
reverse hero. `flutter analyze` clean.

---

## Step 11 — Tests

**Files to create:**
- `test/features/messaging/thread_attachment_test.dart`
- `test/features/messaging/attachment_datasource_test.dart`

### `thread_attachment_test.dart` — TDD unit tests (write tests FIRST, then fix until green)

Cover all 7 cases from the spec § Testing:

1. `buildThreadEntries` with `uploading` pending → `MessageStatus.uploading`
2. `storagePath` set + `uploadPayload` cleared → `MessageStatus.sending`
3. Server echo with matching `client_tag` → confirmed entry, `MessageStatus.sent`
4. `failed: true` + `uploadPayload` non-null → `MessageStatus.failed`
5. `failed: true` + `storagePath` non-null → `MessageStatus.failed` (insert-fail retry path)
6. Mixed text + image + file messages → correct `createdAt` ordering
7. Duplicate IDs from tail + history → deduped; attachment field preserved

### `attachment_datasource_test.dart` — datasource/repo tests (mocktail)

Cover cases 8–12 from the spec § Testing. Mock `MessageRemoteDataSource` with mocktail.

```bash
flutter test test/features/messaging/thread_attachment_test.dart
flutter test test/features/messaging/attachment_datasource_test.dart
```

Both must be green before proceeding.

---

## Step 12 — Final validation

```bash
# Full validate
bash scripts/validate.sh

# Architecture check
bash scripts/check-architecture.sh

# LOC sanity — none of the modified files should exceed 500
wc -l \
  lib/features/messaging/presentation/pages/message_thread_page.dart \
  lib/features/messaging/presentation/pages/message_thread_widgets.dart \
  lib/features/messaging/presentation/pages/message_thread_attachments.dart \
  lib/features/messaging/presentation/providers/messaging_provider.dart \
  lib/features/messaging/presentation/providers/messaging_state.dart \
  lib/features/messaging/presentation/providers/messaging_outbox.dart \
  lib/features/messaging/data/datasources/message_remote_datasource.dart
```

Expected: all files ≤ 400 (target) or at worst ≤ 500 (hard ceiling). If any file exceeds 400,
review what can be extracted to a new part or helper file before opening the PR.

### Design system checks (run as part of validate.sh but double-check manually)

- No `GoogleFonts.*` calls outside `app_theme.dart`.
- No `Colors.white` without `// intentional` (the `_ImageViewerPage` scaffold background is
  `Colors.black` with a comment — add `// intentional` to satisfy the linter).
- No raw `SizedBox(height:...)` — use `Gap(n)`.
- No hardcoded `Color(0xFF...)` in `lib/features/`.
- `c.actionInk` used for orange icon-on-dark (not `c.action`).
- All touch targets ≥ 44dp.

---

## Commit sequence (one commit per step)

```
feat(messaging): Phase B step 1 — chat-attachments bucket + storage RLS [docs only]
feat(messaging): Phase B step 2 — message_attachments migration
refactor(messaging): Phase B step 3 — split provider/widgets under LOC budget
feat(messaging): Phase B step 4 — MessageAttachment entity + SendAttachmentMessage use case
feat(messaging): Phase B step 5 — attachment data layer (model + datasource + repo)
feat(messaging): Phase B step 6 — attachment bubble widgets (image + file + picker sheet)
feat(messaging): Phase B step 7 — upload orchestration + signed URL cache in controller
feat(messaging): Phase B step 8 — attachment pick affordance in input bar
feat(messaging): Phase B step 9 — wire image/file bubble dispatch in _MessageBubble
feat(messaging): Phase B step 10 — ImageViewerPage route registration
test(messaging): Phase B step 11 — attachment TDD test suite
```

---

## PR checklist (before opening)

- [ ] All OQ-1 through OQ-5 answered by Ken and reflected in the implementation
- [ ] `bash scripts/validate.sh` green (format + lint + tests + design checks)
- [ ] `bash scripts/check-architecture.sh` green (domain purity, layer boundaries, use-case
      coverage)
- [ ] No file exceeds 500 LOC (`wc -l` verified in Step 12)
- [ ] Screenshots attached: outgoing image bubble (uploading state), incoming image bubble
      (loaded), file bubble, `_ImageViewerPage` full-screen, attachment preview strip
- [ ] Migration noted in PR description: `20260608000002_message_attachments.sql`
- [ ] Storage bucket + RLS setup documented in PR description (requires manual Supabase
      Dashboard step — not automated by the migration)
- [ ] No `Colors.white` without `// intentional` in `lib/features/`
- [ ] `c.actionInk` (not `c.action`) used for all orange-on-dark icon/text in bubbles
