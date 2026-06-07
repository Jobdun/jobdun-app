# Messaging Phase C — Implementation Plan

- **Date:** 2026-06-08
- **Spec:** `docs/superpowers/specs/2026-06-08-messaging-phase-c-actions-design.md`
- **Branch:** `feat/messaging-phase-c-actions` (branch off `feat/offline-cache-hardening` or `develop` after Phase A merges)
- **Author:** Ken Garcia (with Claude)

## Prerequisites (before writing a single line of Phase C code)

- [ ] Phase A branch merged to `develop`.
- [ ] Ken has answered OQ-1 through OQ-4 (emoji set, one-vs-many reactions, unsend window, edit scope).
- [ ] `flutter test` green on `develop`.

---

## Checkpoint 0 — File-size splits (MANDATORY FIRST)

> Do this before adding any Phase C feature code. Splitting after is much harder.
> All splits are extract-only refactors; zero behaviour change. Run `flutter test` after each.

### 0-A: Extract `MessagingState` out of `messaging_provider.dart`

**Why:** `messaging_provider.dart` is at 452 LOC. Phase C adds ~80 LOC of new methods and state fields; it would breach 500 without this extraction.

1. Create `lib/features/messaging/presentation/state/messaging_state.dart`.
2. Move the `MessagingState` class (lines ~386–452 in the current file) verbatim.
3. In `messaging_provider.dart`, add the import and delete the moved class.
4. Verify: `flutter analyze --no-fatal-infos` clean; `flutter test` green.

**Target:** `messaging_provider.dart` → ~370 LOC; `messaging_state.dart` → ~90 LOC.

### 0-B: Extract reaction/tombstone widgets into a new `part` file

**Why:** `message_thread_widgets.dart` is at 407 LOC. Phase C adds ~120 LOC of tombstone + reaction chips + quoted preview widgets.

1. Create `lib/features/messaging/presentation/pages/message_thread_reactions.dart` as a `part of 'message_thread_page.dart'` file.
2. Move `_SkeletonBubble`, `_ThreadSkeleton`, and `_ThreadEmpty` to this file (they will be joined by new Phase C widgets). Alternatively, if that makes the new file too small, keep them in `_widgets` and only seed the new file with stub comment lines — the important thing is the new file exists and has room for ~180 LOC of Phase C additions.
3. Add `part 'message_thread_reactions.dart';` to `message_thread_page.dart`.
4. Verify: `flutter analyze` clean; `flutter test` green.

**Target:** `message_thread_widgets.dart` → ~300 LOC post-extraction; new `message_thread_reactions.dart` → seeds at ~100 LOC.

### 0-C: Extract `_ReplyDraftBar` slot + `_MessageListView` from page

**Why:** `message_thread_page.dart` is at 443 LOC. Phase C adds ~40 LOC of reply-draft bar invocation and scroll glue; without pre-extraction it hits ~483 and risks the ceiling.

1. Extract the `ListView.builder` block (lines ~276–341) into a private widget `_MessageListView` inside `message_thread_widgets.dart` — pass it only what it needs (`entries`, `me`, `lastSeenKey`, `hasMore`, `initials`, `imageUrl`, `onRetry`, `onLongPress`).
2. The page's `build()` becomes thinner by ~65 LOC.
3. Verify: `flutter analyze` clean; `flutter test` green.

**Checkpoint 0 done when:** `flutter test` green, `bash scripts/validate.sh` passes.

---

## Checkpoint 1 — Schema migration + RLS

**Files touched:**
- `supabase/migrations/20260608000002_message_actions.sql` (new)
- `supabase/rollbacks/20260608000002_message_actions_down.sql` (new)

### Steps

1. Create the migration file exactly as specified in the spec's Schema section.
   Key operations (in order):
   - `ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES messages(id) ON DELETE SET NULL`
   - `CREATE INDEX messages_reply_to_id_idx ... WHERE reply_to_id IS NOT NULL`
   - `CREATE TABLE message_reactions (PRIMARY KEY (message_id, user_id, emoji))`
   - Two indexes on `message_reactions`
   - `ALTER TABLE message_reactions REPLICA IDENTITY FULL`
   - `ALTER PUBLICATION supabase_realtime ADD TABLE message_reactions`
   - RLS enable + 3 policies on `message_reactions` (select/insert/delete)
   - `DROP POLICY "messages_update_read"`
   - `CREATE POLICY "messages_unsend_own"` (sender-only UPDATE)
   - `CREATE POLICY "messages_mark_read"` (participant UPDATE, restores read-receipt path)

2. Create the down-migration (rollback) file.

3. Push to Supabase:
   ```bash
   supabase db push --include-all
   ```

4. Verify in Supabase dashboard:
   - `messages.reply_to_id` column visible
   - `message_reactions` table visible with correct PK
   - `message_reactions` in the `supabase_realtime` publication
   - Old `messages_update_read` policy gone; two new policies present

**Checkpoint 1 done when:** `supabase db push` succeeds; policies verified in dashboard.

---

## Checkpoint 2 — Domain entities + repository contract

**Files touched / created:**
- `lib/features/messaging/domain/entities/message_reaction.dart` (new)
- `lib/features/messaging/domain/entities/message.dart` (extend)
- `lib/features/messaging/domain/repositories/message_repository.dart` (extend)
- `lib/features/messaging/domain/usecases/toggle_reaction.dart` (new)
- `lib/features/messaging/domain/usecases/unsend_message.dart` (new)
- `lib/features/messaging/domain/usecases/send_message.dart` (extend)

### Steps

**2-A: `MessageReaction` entity**

Create `lib/features/messaging/domain/entities/message_reaction.dart`:
- Fields: `messageId`, `userId`, `emoji`, `createdAt`
- Extends `Equatable`; `props = [messageId, userId, emoji]`
- Zero Flutter/Supabase imports

**2-B: Extend `Message` entity**

Add `replyToId: String?` to `Message` — nullable, no default.
Update `props` list to include it.

**2-C: Repository contract additions**

Add to `MessageRepository`:
```dart
Future<Either<Failure, List<MessageReaction>>> getReactions(String conversationId);
Stream<List<MessageReaction>> watchReactions(String conversationId);
Future<Either<Failure, void>> addReaction({required String messageId, required String userId, required String emoji});
Future<Either<Failure, void>> removeReaction({required String messageId, required String userId, required String emoji});
Future<Either<Failure, void>> unsendMessage({required String messageId, required String senderId});
```

Also extend `sendMessage` contract to accept optional `replyToId: String?`.

**2-D: Use cases**

`toggle_reaction.dart`:
- Takes `(MessageRepository repo)` in constructor
- `call({required String conversationId, required String messageId, required String userId, required String emoji, required bool iMine})` → delegates to `addReaction` or `removeReaction` based on `iMine`
- Returns `Future<Either<Failure, void>>`

`unsend_message.dart`:
- Takes `(MessageRepository repo)` in constructor
- `call({required String messageId, required String senderId})` → delegates to `repo.unsendMessage`
- Returns `Future<Either<Failure, void>>`

**2-E: Extend `SendMessage` use case**

Add optional `String? replyToId` parameter to `call(...)`. Pass through to repo.

**Checkpoint 2 done when:** `dart analyze lib/features/messaging/domain/` is clean.

---

## Checkpoint 3 — Data layer (model + datasource + repo impl)

**Files touched / created:**
- `lib/features/messaging/data/models/message_reaction_model.dart` (new)
- `lib/features/messaging/data/models/message_model.dart` (extend)
- `lib/features/messaging/data/datasources/message_remote_datasource.dart` (extend)
- `lib/features/messaging/data/repositories/message_repository_impl.dart` (extend)

### Steps

**3-A: `MessageReactionModel`**

Create `lib/features/messaging/data/models/message_reaction_model.dart`:
- Extends `MessageReaction`
- `factory MessageReactionModel.fromJson(Map<String, dynamic> json)` — maps `message_id`, `user_id`, `emoji`, `created_at`

**3-B: Extend `MessageModel.fromJson`**

Add `replyToId: json['reply_to_id'] as String?` to the factory constructor.

**3-C: Datasource additions**

Add to `MessageRemoteDataSourceImpl`:
- `getMessages`: add `reply_to_id` to the select (no explicit column list currently — verify the default `select()` returns all; if it does, no change needed; if not, change to `.select('*, reply_to_id')`)
- `sendMessage`: add `if (replyToId != null) 'reply_to_id': replyToId` to the upsert payload
- `getReactions(String conversationId)`: REST query — join via `messages` to scope by `conversation_id`; return `List<MessageReactionModel>`
- `watchReactions(String conversationId)`: `.stream(primaryKey: ['message_id', 'user_id', 'emoji'])` on `message_reactions`, filter by joining to `messages.conversation_id`
- `addReaction({messageId, userId, emoji})`: upsert into `message_reactions` with `onConflict: 'message_id,user_id,emoji'`, `ignoreDuplicates: true`
- `removeReaction({messageId, userId, emoji})`: `.delete().eq('message_id', ...).eq('user_id', ...).eq('emoji', ...)`
- `unsendMessage({messageId, senderId})`: `.update({'deleted_at': DateTime.now().toIso8601String()}).eq('id', messageId).eq('sender_id', senderId)`

  > The `.eq('sender_id', senderId)` filter adds a belt-and-suspenders check
  > at the data layer even though the RLS policy already enforces it.

**3-D: Repo impl additions**

Implement the new `MessageRepository` methods in `MessageRepositoryImpl`,
following the existing `try / on ServerException / return right/left` pattern.

**Checkpoint 3 done when:** `flutter analyze` clean; T-19 through T-23 pass.

---

## Checkpoint 4 — Pure value object extensions (`thread_messages.dart`)

**File touched:** `lib/features/messaging/presentation/state/thread_messages.dart`

Work TDD-first: write tests in `test/features/messaging/thread_messages_test.dart`
(or a new `thread_messages_phase_c_test.dart`) for T-01 through T-12 **before** touching the value object.

### Steps

**4-A: Write T-01 through T-12 tests — expect failures.**

**4-B: Add new value objects to `thread_messages.dart`:**

```dart
class ReplyPreview {
  const ReplyPreview({
    required this.senderId,
    required this.snippet,
    this.isDeleted = false,
  });
  final String senderId;
  final String snippet;
  final bool isDeleted;
}

class ReactionCount {
  const ReactionCount({
    required this.emoji,
    required this.count,
    required this.iMine,
  });
  final String emoji;
  final int count;
  final bool iMine;
}
```

**4-C: Extend `ThreadEntry`:**

Add fields:
```dart
final bool isDeleted;       // default false
final ReplyPreview? replyTo;
final List<ReactionCount> reactions; // default const []
```

Update constructor; update `ThreadEntry` usages in `buildThreadEntries`.

**4-D: Extend `buildThreadEntries` signature:**

```dart
List<ThreadEntry> buildThreadEntries({
  required List<Message> confirmed,
  required List<PendingMessage> outbox,
  required DateTime? otherLastReadAt,
  required String? me,
  Map<String, List<MessageReaction>> reactionsMap = const {},  // new
})
```

**4-E: Implement the new derivation inside `buildThreadEntries`:**

For each confirmed `Message m`:
- `isDeleted = m.deletedAt != null`
- If `isDeleted`, pass `body: ''` to `ThreadEntry`
- `replyTo`: if `m.replyToId != null` → look up in `byId`; if found and not deleted → `ReplyPreview(senderId, snippet: body.substring(0, min(80, body.length)))`; if found and deleted → `ReplyPreview(senderId: '', snippet: '', isDeleted: true)`; if not found → null
- `reactions`: look up `reactionsMap[m.id]` → fold into `List<ReactionCount>` (group by emoji, count, `iMine = r.userId == me`)

For pending `PendingMessage`: `isDeleted = false`, `replyTo = null`, `reactions = const []`.

**4-F: Run tests — all T-01 through T-12 should pass.**

**Checkpoint 4 done when:** all 12 value-object tests pass; `flutter analyze` clean.

---

## Checkpoint 5 — Controller extension (`messaging_provider.dart`)

**Files touched:**
- `lib/features/messaging/presentation/providers/messaging_provider.dart`
- `lib/features/messaging/presentation/state/messaging_state.dart` (extend)

Work TDD-first: write T-13 through T-18 before changing the controller.

### Steps

**5-A: Extend `MessagingState` (in `messaging_state.dart`):**

Add fields:
```dart
final Map<String, List<MessageReaction>> reactionsByConvId;
final Map<String, ThreadEntry?> replyDraftByConvId;
```

Update `copyWith`, helper accessors:
```dart
List<MessageReaction> reactionsFor(String conversationId) => ...
ThreadEntry? replyDraftFor(String conversationId) => ...
```

Update `entriesFor` to pass `reactionsMap` to `buildThreadEntries`:
```dart
List<ThreadEntry> entriesFor(String conversationId, String? me) =>
    buildThreadEntries(
      confirmed: messagesFor(conversationId),
      outbox: outboxFor(conversationId),
      otherLastReadAt: otherLastReadFor(conversationId),
      me: me,
      reactionsMap: { for (final r in reactionsFor(conversationId)) r.messageId: [r] },
      // Note: fold properly into Map<messageId, List<Reaction>>
    );
```

**5-B: Add new use case providers to `messaging_provider.dart`:**

```dart
final toggleReactionUseCaseProvider = Provider(...);
final unsendMessageUseCaseProvider = Provider(...);
```

**5-C: Add stream map and subscription management:**

```dart
final Map<String, StreamSubscription<List<MessageReaction>>> _reactionSubs = {};
```

In `unsubscribeMessages`, also cancel `_reactionSubs[conversationId]`.
In `_cancelAllSubscriptions`, cancel and clear `_reactionSubs`.

In `loadMessages` (after `_subscribeToConversation`):
```dart
_subscribeToReactions(conversationId);
```

New private method `_subscribeToReactions(String conversationId)`:
- Guard: if already subscribed, return
- Call `repo.watchReactions(conversationId).listen(...)` → merge reactions into state

**5-D: New public methods:**

`setReplyDraft(String conversationId, ThreadEntry? entry)`:
- Update `replyDraftByConvId`

Extend `sendMessage` to accept `String? replyToId`:
- Pass `replyToId` through to `SendMessage` use case

`toggleReaction(String conversationId, String messageId, String emoji)`:
- Get `me = readCurrentUserId(ref)`; guard null
- Determine `iMine` from current `reactionsFor(conversationId)`
- Optimistic update: add or remove from `reactionsByConvId`
- Call `toggleReactionUseCase.call(...)`
- On failure: revert optimistic change; set error

`unsendMessage(String conversationId, String messageId)`:
- Get `me`; guard null
- Optional client-side time-window check (if Ken picks a window at OQ-3)
- Optimistic: remove message from `messagesByConvId[conversationId]`
- Call `unsendMessageUseCase.call(messageId: messageId, senderId: me)`
- On failure: re-add message; set error

**5-E: Run T-13 through T-18 — all should pass.**

**Checkpoint 5 done when:** T-13–T-18 pass; `flutter analyze` clean; `messaging_provider.dart` < 460 LOC.

---

## Checkpoint 6 — UI: new widgets

**Files touched:**
- `lib/features/messaging/presentation/pages/message_thread_reactions.dart` (extend — `part of`)
- `lib/features/messaging/presentation/pages/message_thread_status.dart` (extend — add `_MessageActionSheet`)
- `lib/features/messaging/presentation/pages/message_thread_widgets.dart` (extend — quoted preview inside bubble)
- `lib/features/messaging/presentation/pages/message_thread_page.dart` (wire reply draft bar + long-press + scroll glue)

Apply Jobdun design tokens throughout: `context.c`, `Gap()`, `AppIcons.*`, `HapticFeedback.lightImpact()`, `showJSheet`. No `SizedBox`, no `PhosphorIcons`, no `Colors.white` without `// intentional`.

### Steps

**6-A: `_DeletedTombstone` widget** (in `message_thread_reactions.dart`)

- Renders when `entry.isDeleted == true`
- Container with `c.border` 1dp border, `surfaceRaised` background, 8dp border radius
- Row: `AppIcons.block` (or `Icons.block`, 14dp, `c.text3`) + `Gap(6.w)` + "MESSAGE DELETED" (Oswald caps, 12sp, `c.text3`)
- 44dp minimum height (touch target rule even though non-interactive)
- No `GestureDetector` wrapper

**6-B: `_QuotedPreview` widget** (in `message_thread_reactions.dart`)

- `final ReplyPreview replyTo`
- `final bool isMine` (for border colour)
- Left vertical bar: 3dp wide, colour `c.action` (mine) or `c.border` (theirs), 12dp height-matched
- Content: sender name (Oswald caps, 11sp, `c.text2`), snippet (Open Sans italic, 12sp, `c.text3`, max 1 line, overflow ellipsis)
- If `replyTo.isDeleted`: show "Original message deleted" in `c.text3` italic

**6-C: `_ReactionChipRow` widget** (in `message_thread_reactions.dart`)

- `final List<ReactionCount> reactions`
- `final void Function(String emoji) onToggle`
- `Wrap` with spacing 4dp
- Each chip: `GestureDetector` → `HapticFeedback.lightImpact()` then `onToggle(emoji)`
- Chip container: `c.surfaceRaised` bg, `iMine ? c.action : c.border` 1dp border, 4dp border radius
- Content: emoji text (14sp) + `Gap(3.w)` + count text (11sp, `c.text2`)
- Only renders if `reactions.isNotEmpty`

**6-D: Update `_MessageBubble`** (in `message_thread_widgets.dart`)

1. Add params: `final VoidCallback onLongPress`, `final void Function(String)? onReactionToggle`
2. Wrap the entire bubble `Container` in a `GestureDetector` with `onLongPress` (replaces the current bare Container; only when `!entry.isPending && !entry.isDeleted`)
3. If `entry.isDeleted`: replace the body text + padding Container with `_DeletedTombstone()`
4. If `entry.replyTo != null` and not deleted: prepend `_QuotedPreview(replyTo: entry.replyTo!, isMine: isMine)` above the body, inside the Column, with `Gap(4.h)` between
5. After the status tick row: if `entry.reactions.isNotEmpty`, add `Gap(3.h)` + `_ReactionChipRow(reactions: entry.reactions, onToggle: ...)`
6. Pending messages (`entry.isPending`): disable long-press (no `GestureDetector`); no reaction chips

**6-E: `_MessageActionSheet`** (in `message_thread_status.dart`)

New stateless widget. Called via `showJSheet`:
```dart
showJSheet(context: context, builder: (_) => _MessageActionSheet(entry: entry, isMine: isMine, onReply: ..., onReact: ..., onCopy: ..., onUnsend: ...));
```

Structure:
- `c.card` background, `BorderRadius.vertical(top: Radius.circular(16.r))`
- Drag handle: 4dp×32dp `c.border` pill, centered, `Gap(12.h)` padding
- Title: message snippet (max 1 line, `c.text3`, 12sp), `Gap(4.h)` top padding
- Action rows (48dp each), separated by 1dp `c.border` dividers:
  - Reply: `AppIcons.reply`, "REPLY" label
  - React: `AppIcons.emoji` (or `Icons.emoji_emotions_outlined`), "REACT" → expands inline emoji picker row
  - Copy: `AppIcons.copy` (or `Icons.copy`), "COPY TEXT"
  - (divider + red)
  - Unsend: `AppIcons.delete`, "UNSEND", `c.urgent` colour — only when `isMine && !entry.isDeleted`
- Each action row taps: `HapticFeedback.lightImpact()` → callback → `Navigator.pop(context)`
- Emoji picker row (visible only when React is expanded): horizontal `SingleChildScrollView` of 6 emoji chips (defined emoji set), each 48dp tap target

**6-F: `_ReplyDraftBar`** (in `message_thread_widgets.dart` or new part file)

- Shown between messages area and input bar when `replyDraft != null`
- `Container(color: c.surface, decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))))`
- Left 3dp orange strip (BoxDecoration leftBorder trick or a narrow Container sibling)
- Content row: sender name + snippet (1 line, overflow ellipsis) + `Gap(auto)` + close icon (`AppIcons.close`, 20dp, `c.text3`)
- Close tap: `HapticFeedback.lightImpact()` + `_messaging.setReplyDraft(_conversationId, null)`

**6-G: Wire everything in `message_thread_page.dart`**

1. Read `replyDraft = mState.replyDraftFor(_conversationId)`
2. Pass `onLongPress` to `_MessageListView` (or directly to `_MessageBubble` via `_MessageListView`)
3. `onLongPress` callback: `showJSheet(context: context, builder: (_) => _MessageActionSheet(...))`
4. `_send()` extended: pass `replyToId: replyDraft?.key` (server message id) if non-null; clear draft after send
5. Add `_ReplyDraftBar` to the Column between the expanded messages area and the input bar, conditionally on `replyDraft != null`
6. Add `onReactionToggle` wiring from bubble → `_messaging.toggleReaction(...)`
7. Add `onUnsend` confirmation: show a simple `AlertDialog` ("UNSEND THIS MESSAGE? / This cannot be undone." — CTA: "UNSEND" in `c.urgent`, secondary: "CANCEL"); on confirm → `_messaging.unsendMessage(conversationId, messageId)`

**Checkpoint 6 done when:** `flutter analyze` clean; app runs and long-press opens the sheet; all Phase C widgets render; `bash scripts/validate.sh` passes.

---

## Checkpoint 7 — Integration + TDD green bar

### Steps

1. Run the full test suite: `flutter test`
2. Verify T-01 through T-23 are all green.
3. Run `bash scripts/validate.sh` — all checks pass.
4. Manual smoke test (device or emulator):
   - [ ] Long-press my bubble → sheet opens with Reply / React / Copy / Unsend
   - [ ] Long-press their bubble → sheet opens with Reply / React / Copy (no Unsend)
   - [ ] Long-press pending bubble → no sheet
   - [ ] Long-press deleted tombstone → no sheet
   - [ ] Reply: draft bar appears, send, quoted preview renders in new bubble
   - [ ] React: emoji row visible in sheet, tap emoji → chip appears under bubble
   - [ ] Tap chip again (my own) → chip disappears (toggle off)
   - [ ] React shows across devices (realtime — open two simulator windows)
   - [ ] Copy: toast or system copy feedback fires
   - [ ] Unsend confirmation dialog → confirm → tombstone renders
   - [ ] Unsend on their message: Unsend option not visible in sheet
   - [ ] Deleted message still appears as tombstone in the thread (not removed)
   - [ ] Reply to a message that is later unsent shows "Original message deleted" quote preview
   - [ ] File sizes: `bash scripts/validate.sh` file-size section all green

**Checkpoint 7 done when:** all tests green, validate.sh passes, smoke test complete.

---

## Checkpoint 8 — PR

1. `git status` — confirm only intended files staged.
2. PR title: `feat(messaging): Phase C — message actions (reply, react, unsend, copy)`
3. PR body must include:
   - Summary of changes (schema, RLS policy change, new entities/use cases, value object extensions, new widgets)
   - **RLS change callout**: explain the removal of `messages_update_read` and what replaced it
   - Screenshots: action sheet open, quoted reply bubble, reaction chips, tombstone
   - Migration notes: `supabase/migrations/20260608000002_message_actions.sql`
   - Answers to OQ-1 through OQ-4 (filled in by Ken before review)
   - Test coverage note: T-01 through T-23

---

## File map (final state after Phase C)

```
lib/features/messaging/
  data/
    datasources/
      message_remote_datasource.dart        ~340 LOC  (was 259, +80 for reaction/unsend methods)
    models/
      message_model.dart                    ~45 LOC   (was 40, +replyToId)
      message_reaction_model.dart           ~30 LOC   (new)
    repositories/
      message_repository_impl.dart          ~180 LOC  (was 130, +50 for new repo methods)
  domain/
    entities/
      message.dart                          ~40 LOC   (was 34, +replyToId field)
      message_reaction.dart                 ~20 LOC   (new)
    repositories/
      message_repository.dart               ~50 LOC   (was 37, +new methods)
    usecases/
      toggle_reaction.dart                  ~25 LOC   (new)
      unsend_message.dart                   ~25 LOC   (new)
      send_message.dart                     ~30 LOC   (was 25, +replyToId param)
  presentation/
    pages/
      message_thread_page.dart              ~430 LOC  (was 443, net -13 from extraction +40 from Phase C)
      message_thread_widgets.dart           ~340 LOC  (was 407, net -67 from extraction +replyTo in bubble)
      message_thread_status.dart            ~200 LOC  (was 100, +_MessageActionSheet ~100)
      message_thread_reactions.dart         ~200 LOC  (new — tombstone, quote preview, reaction chips, reply draft bar)
    providers/
      messaging_provider.dart               ~440 LOC  (was 452, -80 from extraction +80 new methods, net ~440)
    state/
      thread_messages.dart                  ~240 LOC  (was 142, +value objects and extended function)
      messaging_state.dart                  ~90 LOC   (new — extracted from provider)
  supabase/
    migrations/
      20260608000002_message_actions.sql    (new)
    rollbacks/
      20260608000002_message_actions_down.sql (new)
```

All files stay under the 500-LOC hard ceiling.
