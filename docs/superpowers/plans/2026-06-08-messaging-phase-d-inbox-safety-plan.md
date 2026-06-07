# Messaging Phase D — Inbox Power + Safety: Implementation Plan

- **Date:** 2026-06-08
- **Spec:** `docs/superpowers/specs/2026-06-08-messaging-phase-d-inbox-safety-design.md`
- **Branch:** `feat/messaging-phase-d-inbox-safety` (branch from `develop` or the merged Phase A branch)
- **Precondition:** Phase A is merged; `messaging_provider.dart` and `messages_page.dart` reflect the post-Phase-A state described in the spec.

**Verify preconditions before starting:**

```bash
bash scripts/validate.sh            # must be green
flutter test                        # must be green
wc -l lib/features/messaging/presentation/providers/messaging_provider.dart
# expect ~452 LOC (post Phase A); if materially different, re-check ceiling math in spec
```

---

## Checkpoint map

```
CP-1  Migrations + RLS (no Dart changes)
CP-2  get_inbox extended + ConversationModel updated
CP-3  Domain entities + repository contract
CP-4  Data layer (datasource + repo impl)
CP-5  Use cases
CP-6  Controller (MessagingController + InboxSafetyController split)
CP-7  UI — Search bar
CP-8  UI — Swipe actions (pin, mute, mark-unread, block, report)
CP-9  UI — Block confirmation sheet
CP-10 UI — Report sheet
CP-11 Tests (TDD — write tests for each unit before the impl step they cover)
CP-12 Verification + final validate.sh
```

---

## Step 1 — Create the feature branch

```bash
git checkout develop
git pull origin develop
git checkout -b feat/messaging-phase-d-inbox-safety
```

---

## CP-1: Migrations + RLS

**Goal:** All four schema changes land atomically; no Dart yet. After this checkpoint, local Supabase is runnable with the new columns, `blocks`, and `reports` tables.

### Step 1.1 — Migration: pin + mute columns

Create `supabase/migrations/20260608000002_conversations_pin_mute.sql` (exact SQL in spec §"Migration 1").

```bash
supabase db push   # or: supabase migration up (local dev)
supabase db diff   # verify four new columns appear
```

Create the rollback file `supabase/rollbacks/20260608000002_rollback.sql`:

```sql
ALTER TABLE public.conversations
  DROP COLUMN IF EXISTS builder_pinned_at,
  DROP COLUMN IF EXISTS trade_pinned_at,
  DROP COLUMN IF EXISTS builder_muted_at,
  DROP COLUMN IF EXISTS trade_muted_at;
DROP INDEX IF EXISTS conversations_builder_pinned_idx;
DROP INDEX IF EXISTS conversations_trade_pinned_idx;
```

### Step 1.2 — Migration: `blocks` table + amended `messages_insert` + `get_or_create_conversation` guard

Create `supabase/migrations/20260608000003_blocks.sql` (exact SQL in spec §"Migration 2").

```bash
supabase db push
# Verify: `SELECT * FROM public.blocks LIMIT 1;` returns empty (no error).
# Verify: messages_insert policy updated — check via supabase inspect or SQL editor.
```

Create `supabase/rollbacks/20260608000003_rollback.sql`:

```sql
DROP TABLE IF EXISTS public.blocks CASCADE;
-- Restore original messages_insert (copy from 20260511000006_rls.sql):
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
-- ... paste original messages_insert policy body ...
-- Restore original get_or_create_conversation (copy from 20260603000001):
-- ... paste original function body ...
```

### Step 1.3 — Migration: `reports` table

Create `supabase/migrations/20260608000004_reports.sql` (exact SQL in spec §"Migration 3").

```bash
supabase db push
# Verify: table exists, CHECK constraints enforced:
#   INSERT into reports with reason='invalid' should fail.
```

Create `supabase/rollbacks/20260608000004_rollback.sql`:

```sql
DROP TABLE IF EXISTS public.reports CASCADE;
```

**CP-1 done check:**

```bash
# No Dart changes yet — validate should still be green:
bash scripts/validate.sh
flutter test
```

---

## CP-2: `get_inbox` extension + `ConversationModel` update

**Goal:** The Flutter `ConversationModel` can read `is_pinned` and `is_muted` from the new `get_inbox` result. All existing inbox behaviour is unaffected.

### Step 2.1 — Migration: extended `get_inbox`

Create `supabase/migrations/20260608000005_get_inbox_phase_d.sql` (exact SQL in spec §"Migration 4").

```bash
supabase db push
# Verify via SQL editor:
#   SELECT id, is_pinned, is_muted FROM get_inbox('<your_user_id>'::uuid) LIMIT 5;
# All rows should return is_pinned = false, is_muted = false (no data yet).
```

Create `supabase/rollbacks/20260608000005_rollback.sql`:

```sql
-- Re-run the 20260604000004 definition to drop is_pinned/is_muted columns from the result.
-- Paste get_inbox body from 20260604000004_get_inbox_company_name.sql here.
```

### Step 2.2 — Update `ConversationModel`

File: `lib/features/messaging/data/models/conversation_model.dart`

- In `fromInboxRow`: parse `json['is_pinned'] as bool? ?? false` and `json['is_muted'] as bool? ?? false`.
- Map them to the entity fields `builderPinnedAt` / `tradePinnedAt` / `builderMutedAt` / `tradeMutedAt` via a helper: if `is_pinned` is true and the viewer is the builder, set `builderPinnedAt = DateTime(2000)` (sentinel — the actual timestamp is not needed for UI logic; the boolean is the contract from `get_inbox`).

> **Implementation note:** `fromInboxRow` receives the already-resolved booleans (`is_pinned`, `is_muted`) rather than raw timestamps, because `get_inbox` computes them per viewer. `fromJson` (used by `watchConversations` raw stream) maps the raw `builder_pinned_at` / `trade_pinned_at` columns directly.

```bash
flutter analyze --no-fatal-infos
flutter test    # no regressions
```

**CP-2 done check:** `flutter test` green; `messages_page.dart` still compiles (no entity changes yet).

---

## CP-3: Domain entities + repository contract

**Goal:** `Conversation` entity has the four new timestamp fields and two new helpers; `MessageRepository` declares five new methods.

### Step 3.1 — Update `Conversation` entity

File: `lib/features/messaging/domain/entities/conversation.dart`

Add fields:

```dart
final DateTime? builderPinnedAt;
final DateTime? tradePinnedAt;
final DateTime? builderMutedAt;
final DateTime? tradeMutedAt;
```

Add helpers:

```dart
bool isPinnedFor(String userId) =>
    userId == builderId ? builderPinnedAt != null : tradePinnedAt != null;

bool isMutedFor(String userId) =>
    userId == builderId ? builderMutedAt != null : tradeMutedAt != null;
```

Add new fields to `props` list and the constructor. (Do NOT add `copyWith` yet — wait for Step 6 where the controller needs it.)

### Step 3.2 — Update `MessageRepository` interface

File: `lib/features/messaging/domain/repositories/message_repository.dart`

Add five method signatures:

```dart
Future<Either<Failure, void>> pinConversation({
  required String conversationId,
  required bool isBuilder,
  required bool pin,
});

Future<Either<Failure, void>> muteConversation({
  required String conversationId,
  required bool isBuilder,
  required bool mute,
});

Future<Either<Failure, void>> markConversationUnread({
  required String conversationId,
  required bool isBuilder,
});

Future<Either<Failure, void>> blockUser({
  required String blockerId,
  required String blockedId,
  required String conversationId,
});

Future<Either<Failure, void>> reportUser({
  required String reporterId,
  required String reportedId,
  required String conversationId,
  String? messageId,
  required String reason,
  String? details,
});
```

```bash
flutter analyze --no-fatal-infos   # will show unimplemented methods on repo impl — expected
```

**CP-3 done check:** Entity and interface compile; repo impl has analysis errors (expected — resolved in CP-4).

---

## CP-4: Data layer — datasource + repository impl

**Goal:** All five new operations reach Supabase; `MessageRemoteDataSourceImpl` and `MessageRepositoryImpl` compile and are fully implemented.

### Step 4.1 — Update `MessageRemoteDataSource` interface

File: `lib/features/messaging/data/datasources/message_remote_datasource.dart`

Add five method signatures (matching the implementations below). Keep in the abstract interface.

### Step 4.2 — Implement in `MessageRemoteDataSourceImpl`

Same file as above (currently 259 LOC — will grow to ~339 LOC; within 400 target).

```dart
// Pin
Future<void> pinConversation({
  required String conversationId,
  required bool isBuilder,
  required bool pin,
}) async {
  try {
    final column = isBuilder ? 'builder_pinned_at' : 'trade_pinned_at';
    await _client.from('conversations').update({
      column: pin ? DateTime.now().toIso8601String() : null,
    }).eq('id', conversationId);
  } catch (e) { throw ServerException(e.toString()); }
}

// Mute
Future<void> muteConversation({
  required String conversationId,
  required bool isBuilder,
  required bool mute,
}) async {
  try {
    final column = isBuilder ? 'builder_muted_at' : 'trade_muted_at';
    await _client.from('conversations').update({
      column: mute ? DateTime.now().toIso8601String() : null,
    }).eq('id', conversationId);
  } catch (e) { throw ServerException(e.toString()); }
}

// Mark unread (sentinel: last_read_at = null, unread_count = 1)
Future<void> markConversationUnread({
  required String conversationId,
  required bool isBuilder,
}) async {
  try {
    final readAtCol   = isBuilder ? 'builder_last_read_at'  : 'trade_last_read_at';
    final unreadCol   = isBuilder ? 'builder_unread_count'  : 'trade_unread_count';
    await _client.from('conversations').update({
      readAtCol: null,
      unreadCol: 1,
    }).eq('id', conversationId);
  } catch (e) { throw ServerException(e.toString()); }
}

// Block user
Future<void> blockUser({
  required String blockerId,
  required String blockedId,
  required String conversationId,
}) async {
  try {
    await _client.from('blocks').upsert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    }, onConflict: 'blocker_id,blocked_id', ignoreDuplicates: true);
    await _client.from('conversations')
        .update({'status': 'blocked'})
        .eq('id', conversationId);
  } catch (e) { throw ServerException(e.toString()); }
}

// Report
Future<void> reportUser({
  required String reporterId,
  required String reportedId,
  required String conversationId,
  String? messageId,
  required String reason,
  String? details,
}) async {
  try {
    await _client.from('reports').insert({
      'reporter_id':     reporterId,
      'reported_id':     reportedId,
      'conversation_id': conversationId,
      if (messageId != null) 'message_id': messageId,
      'reason':          reason,
      if (details != null && details.isNotEmpty) 'details': details,
    });
  } catch (e) { throw ServerException(e.toString()); }
}
```

### Step 4.3 — Implement in `MessageRepositoryImpl`

File: `lib/features/messaging/data/repositories/message_repository_impl.dart`

Wrap each datasource call in the standard `try/catch → Either` pattern matching existing methods (see `archiveConversation` as the template).

```bash
flutter analyze --no-fatal-infos   # datasource + repo impl should be error-free
flutter test
```

**CP-4 done check:** Analysis clean; no new test failures.

---

## CP-5: Use cases

**Goal:** Five new use case files, each thin and unit-testable. All follow the `call()` → `Future<Either<Failure, T>>` pattern.

### Step 5.1 — Create use case files

```
lib/features/messaging/domain/usecases/pin_conversation.dart
lib/features/messaging/domain/usecases/mute_conversation.dart
lib/features/messaging/domain/usecases/mark_conversation_unread.dart
lib/features/messaging/domain/usecases/block_user.dart
lib/features/messaging/domain/usecases/report_user.dart
```

Template (`pin_conversation.dart`):

```dart
import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class PinConversation {
  const PinConversation(this._repo);
  final MessageRepository _repo;

  Future<Either<Failure, void>> call({
    required String conversationId,
    required bool isBuilder,
    required bool pin,
  }) => _repo.pinConversation(
        conversationId: conversationId,
        isBuilder: isBuilder,
        pin: pin,
      );
}
```

`ReportUser` adds a validation layer before calling the repo:

```dart
Future<Either<Failure, void>> call({...}) async {
  if (reason.isEmpty) {
    return left(const ValidationFailure('A report reason is required.'));
  }
  if (details != null && details!.length > 500) {
    return left(const ValidationFailure('Details must be 500 characters or fewer.'));
  }
  return _repo.reportUser(...);
}
```

(Add `ValidationFailure` to `lib/core/errors/failures.dart` if not already present.)

### Step 5.2 — Register use-case providers in `messaging_provider.dart`

Add provider declarations at the top of the file (alongside existing `getConversationsUseCaseProvider` etc.):

```dart
final pinConversationUseCaseProvider = Provider(
  (ref) => PinConversation(ref.read(messageRepositoryProvider)),
);
final muteConversationUseCaseProvider = Provider(
  (ref) => MuteConversation(ref.read(messageRepositoryProvider)),
);
final markConversationUnreadUseCaseProvider = Provider(
  (ref) => MarkConversationUnread(ref.read(messageRepositoryProvider)),
);
```

`BlockUser` and `ReportUser` providers go in the new `inbox_safety_provider.dart` (Step 6.2).

```bash
flutter analyze --no-fatal-infos
flutter test
```

**CP-5 done check:** Analysis clean.

---

## CP-6: Controller (MessagingController extension + InboxSafetyController split)

**Goal:** All six new user actions are callable from the UI. `messaging_provider.dart` stays under 500 LOC; block+report logic is in the new `inbox_safety_provider.dart`.

### Step 6.1 — Extend `MessagingState`

Add to `MessagingState`:

```dart
final String searchQuery;   // default ''
```

Add `filteredConversations` getter:

```dart
List<Conversation> get filteredConversations {
  if (searchQuery.isEmpty) return conversations;
  final q = searchQuery.toLowerCase();
  return conversations.where((c) {
    final name    = (c.otherUserDisplayName ?? '').toLowerCase();
    final preview = (c.lastMessagePreview ?? '').toLowerCase();
    return name.contains(q) || preview.contains(q);
  }).toList();
}
```

Update `copyWith` and constructor.

### Step 6.2 — Add methods to `MessagingController`

Add to `MessagingController` (in `messaging_provider.dart`):

```dart
void setSearchQuery(String query) {
  state = state.copyWith(searchQuery: query);
}

Future<void> pinConversation(String conversationId, {required bool pin}) async {
  final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
  // Optimistic sort: move/unmove to front of list
  final updated = _applyPinOptimistically(conversationId, pin: pin);
  state = state.copyWith(conversations: updated);
  final result = await ref.read(pinConversationUseCaseProvider).call(
    conversationId: conversationId, isBuilder: isBuilder, pin: pin,
  );
  result.fold((f) {
    // Roll back optimistic change and reload
    state = state.copyWith(error: f.message);
    unawaited(_refreshInbox(readCurrentUserId(ref) ?? ''));
  }, (_) {});
}

Future<void> muteConversation(String conversationId, {required bool mute}) async {
  final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
  final result = await ref.read(muteConversationUseCaseProvider).call(
    conversationId: conversationId, isBuilder: isBuilder, mute: mute,
  );
  result.fold(
    (f) => state = state.copyWith(error: f.message),
    (_) {
      // Update in-memory muted flag optimistically
      final updated = state.conversations.map((c) {
        if (c.id != conversationId) return c;
        // Flip the correct side's muted marker
        // ... (update entity fields via copyWith or rebuild)
      }).toList();
      state = state.copyWith(conversations: updated);
    },
  );
}

Future<void> markConversationUnread(String conversationId) async {
  final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
  final result = await ref.read(markConversationUnreadUseCaseProvider).call(
    conversationId: conversationId, isBuilder: isBuilder,
  );
  result.fold((f) => state = state.copyWith(error: f.message), (_) {
    // Sentinel: update in-memory unread count
    final userId = readCurrentUserId(ref) ?? '';
    final updated = state.conversations.map((c) {
      if (c.id != conversationId) return c;
      // rebuild with unread = 1; last_read_at = null handled server-side
      return c; // (full entity rebuild — see implementation note)
    }).toList();
    state = state.copyWith(
      conversations: updated,
      totalUnread: _computeUnread(updated),
    );
  });
}
```

> **Implementation note:** `Conversation` is an `Equatable` with no `copyWith`. Add a `copyWith` to the entity in this step, or use a builder pattern (add `Conversation.unread()` factory). The simplest approach: add `copyWith` to `Conversation` with nullable overrides for the four new timestamp fields + unread counts.

### Step 6.3 — Create `inbox_safety_provider.dart`

Create `lib/features/messaging/presentation/providers/inbox_safety_provider.dart` (~120 LOC):

```dart
// Use-case providers for block + report (kept separate from MessagingController
// to honour the 500 LOC ceiling).

final blockUserUseCaseProvider = Provider(
  (ref) => BlockUser(ref.read(messageRepositoryProvider)),
);

final reportUserUseCaseProvider = Provider(
  (ref) => ReportUser(ref.read(messageRepositoryProvider)),
);

// InboxSafetyState: minimal — just tracks async status for the block/report
// actions so the sheets can show loading / error states.
class InboxSafetyState {
  const InboxSafetyState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;
  InboxSafetyState copyWith({bool? isLoading, String? error}) => InboxSafetyState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final inboxSafetyControllerProvider =
    NotifierProvider<InboxSafetyController, InboxSafetyState>(
      InboxSafetyController.new,
    );

class InboxSafetyController extends Notifier<InboxSafetyState> {
  @override
  InboxSafetyState build() => const InboxSafetyState();

  Future<bool> blockUser({
    required String blockedId,
    required String conversationId,
  }) async {
    final blockerId = readCurrentUserId(ref);
    if (blockerId == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref.read(blockUserUseCaseProvider).call(
      blockerId: blockerId, blockedId: blockedId, conversationId: conversationId,
    );
    state = result.fold(
      (f) => state.copyWith(isLoading: false, error: f.message),
      (_) => const InboxSafetyState(),
    );
    if (result.isRight()) {
      // Refresh the inbox so the blocked conversation reflects status=blocked.
      final userId = readCurrentUserId(ref);
      if (userId != null) {
        ref.read(messagingControllerProvider.notifier)
            ._refreshInboxPublic(userId); // expose via a package-private method
      }
    }
    return result.isRight();
  }

  Future<bool> reportUser({
    required String reportedId,
    required String conversationId,
    String? messageId,
    required String reason,
    String? details,
  }) async {
    final reporterId = readCurrentUserId(ref);
    if (reporterId == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref.read(reportUserUseCaseProvider).call(
      reporterId: reporterId, reportedId: reportedId,
      conversationId: conversationId, messageId: messageId,
      reason: reason, details: details,
    );
    state = result.fold(
      (f) => state.copyWith(isLoading: false, error: f.message),
      (_) => const InboxSafetyState(),
    );
    return result.isRight();
  }
}
```

> **Cross-controller call note:** `InboxSafetyController` needs to trigger a refresh on `MessagingController`. Add a `refreshInbox()` public method (or expose `_refreshInbox` as package-private via `@visibleForTesting`) on `MessagingController`. Alternatively, use `ref.invalidate` — whichever preserves the existing stream subscriptions (prefer the `_refreshInbox` call over `invalidate` to avoid tearing down the conversation stream).

```bash
flutter analyze --no-fatal-infos
flutter test                      # CP-6 done check
wc -l lib/features/messaging/presentation/providers/messaging_provider.dart
# must be < 500
```

**CP-6 done check:** Both provider files compile; LOC budgets respected.

---

## CP-7: UI — Search bar

**Goal:** A togglable search bar appears below the inbox header. Filtering works in real time.

### Step 7.1 — Create `inbox_search_bar.dart`

Create `lib/features/messaging/presentation/widgets/inbox_search_bar.dart` (~60 LOC).

Widget signature:

```dart
class InboxSearchBar extends StatefulWidget {
  const InboxSearchBar({
    super.key,
    required this.onChanged,      // String → void, called after 200ms debounce
    required this.onClear,        // clears query + requests collapse
  });
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  ...
}
```

Internally uses a `TextEditingController` + `Timer`-based 200ms debounce. Collapses itself on clear (calls `onClear`). Style: see spec §"Search bar" UI section.

### Step 7.2 — Add search toggle to `messages_page.dart`

- Add `bool _searchVisible = false` to `_MessagesPageState`.
- Add a search icon button to the header row: `AppIcons.magnifyingGlass` → `setState(() => _searchVisible = !_searchVisible)`.
- Below the header `Divider`, add:

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 150),
  curve: Curves.easeOut,
  child: _searchVisible
      ? InboxSearchBar(
          onChanged: (q) => ref.read(messagingControllerProvider.notifier)
              .setSearchQuery(q),
          onClear: () {
            ref.read(messagingControllerProvider.notifier).setSearchQuery('');
            setState(() => _searchVisible = false);
          },
        )
      : const SizedBox.shrink(),
),
```

- Update the list source from `msgState.conversations` → `msgState.filteredConversations`.
- Add the empty-search result inline text (see spec).

```bash
flutter analyze --no-fatal-infos
# Run in simulator and manually verify search filters the list.
flutter test
```

**CP-7 done check:** Search bar visible and functional.

---

## CP-8: UI — Swipe actions

**Goal:** Five swipe actions wired. Archive is unchanged; four new actions added.

### Step 8.1 — Update `Slidable` in `messages_page.dart`

Replace the existing single-action `endActionPane` block with the spec's revised layout (see §"Swipe actions — revised layout"):

- Add `startActionPane` (pin + mark-unread).
- Add mute to `endActionPane` before archive.
- Add block action to `endActionPane` after archive — does NOT call block directly; it calls `showJSheet` to open the block confirmation sheet (CP-9).
- Update `extentRatio` values.
- Every `onPressed` starts with `HapticFeedback.lightImpact()` (per CLAUDE.md conventions).

Pin action: read `conv.isPinnedFor(userId)` to toggle label and icon Fill vs Bold.

Mute action: read `conv.isMutedFor(userId)` to toggle label.

```bash
flutter analyze --no-fatal-infos
flutter test
```

**CP-8 done check:** Swipe actions visible in simulator (4 directions per row); haptics fire.

---

## CP-9: UI — Block confirmation sheet

### Step 9.1 — Create `block_confirmation_sheet.dart`

Create `lib/features/messaging/presentation/widgets/block_confirmation_sheet.dart` (~80 LOC).

Widget receives: `otherName`, `blockedId`, `conversationId`, `onBlockConfirmed`, `onAlsoReport`.

Uses `showJSheet` from `lib/core/design/widgets/j_bottom_sheet.dart`.

Wire `BLOCK` button to `ref.read(inboxSafetyControllerProvider.notifier).blockUser(...)`. Show `CircularProgressIndicator` overlay while `isLoading`. On success: pop the sheet. On error: inline error text in `c.urgent`.

Wire `ALSO REPORT [NAME]` button to call `onAlsoReport()` callback (opens report sheet).

### Step 9.2 — Invoke from `messages_page.dart`

In the `BLOCK` swipe action `onPressed`:

```dart
onPressed: (_) {
  HapticFeedback.lightImpact();
  showJSheet(
    context: context,
    builder: (_) => BlockConfirmationSheet(
      otherName: conv.otherUserDisplayName ?? 'this person',
      blockedId: conv.builderId == userId ? conv.tradeId : conv.builderId,
      conversationId: conv.id,
      onBlockConfirmed: () {},
      onAlsoReport: () {
        // Open report sheet after block sheet closes
        showJSheet(context: context, builder: (_) => ReportSheet(...));
      },
    ),
  );
},
```

```bash
flutter analyze --no-fatal-infos
flutter test
```

**CP-9 done check:** Block sheet appears, block action completes, inbox row flips to blocked status.

---

## CP-10: UI — Report sheet

### Step 10.1 — Create `report_sheet.dart`

Create `lib/features/messaging/presentation/widgets/report_sheet.dart` (~120 LOC).

Widget receives: `reportedId`, `conversationId`, `messageId?`.

State: `String? _selectedReason`, `TextEditingController _detailsCtrl`.

Renders 5 reason rows (see spec §"Report sheet" UI). Shows `detailsCtrl` text field only when `_selectedReason == 'other'`.

`SUBMIT REPORT` button disabled when `_selectedReason == null`.

On submit: `ref.read(inboxSafetyControllerProvider.notifier).reportUser(...)`. On success: `Navigator.pop(context)` + `ScaffoldMessenger.of(context).showSnackBar(...)`.

### Step 10.2 — Invoke from thread header (optional — link for Phase C)

Add a `...` icon button to `MessageThreadPage`'s `AppBar` (if it has one) or the thread header widget. The menu item "Report conversation" opens `ReportSheet` with the conversation's context. This entry point is secondary to the swipe action — implement if thread header already has a menu; defer if it would add a new header widget.

```bash
flutter analyze --no-fatal-infos
flutter test
```

**CP-10 done check:** Report sheet opens, reason selection works, submit fires the use case.

---

## CP-11: Tests

Write tests as specified in spec §"Testing (TDD)". Tests are written **before** each implementation step they cover — follow TDD strictly.

### Test file: `test/features/messaging/inbox_search_test.dart`

Mock `MessageRepository`. Test `filteredConversations` getter directly on a `MessagingState` instance (no provider needed — it is a pure getter).

```bash
flutter test test/features/messaging/inbox_search_test.dart
```

### Test file: `test/features/messaging/pin_mute_test.dart`

Use a `ProviderContainer` with `messageRepositoryProvider` overridden to a `MockMessageRepository`.

Test all pin/mute/optimistic-rollback cases.

```bash
flutter test test/features/messaging/pin_mute_test.dart
```

### Test file: `test/features/messaging/mark_unread_test.dart`

Test the sentinel unread count.

```bash
flutter test test/features/messaging/mark_unread_test.dart
```

### Test file: `test/features/messaging/block_report_test.dart`

Test both controllers (`MessagingController` for block status reflection; `InboxSafetyController` for loading/error states; `BlockUser` + `ReportUser` use cases in isolation).

```bash
flutter test test/features/messaging/block_report_test.dart
```

**CP-11 done check:**

```bash
flutter test   # entire suite green
```

---

## CP-12: Verification + final validate.sh

**Goal:** All checks pass; no regressions; file-size budget respected.

### Step 12.1 — LOC audit

```bash
wc -l lib/features/messaging/presentation/providers/messaging_provider.dart
# must be < 500

wc -l lib/features/messaging/presentation/providers/inbox_safety_provider.dart
# should be < 150

wc -l lib/features/messaging/presentation/pages/messages_page.dart
# should be < 450

wc -l lib/features/messaging/presentation/widgets/report_sheet.dart
# should be < 130

wc -l lib/features/messaging/data/datasources/message_remote_datasource.dart
# should be < 400
```

### Step 12.2 — Design-system lint

```bash
bash scripts/validate.sh
# Key checks:
# - No GoogleFonts.* outside app_theme.dart
# - No Colors.white without comment
# - No raw SizedBox(height:/width:) — use Gap()
# - No hardcoded Color(0xFF...)
# - No AppColors.* in features/
```

### Step 12.3 — Architecture check

```bash
bash scripts/check-architecture.sh
# Verify:
# - domain/usecases/ files have NO flutter/supabase imports
# - presentation/ does NOT import data/ directly
# - new use cases are covered by check-architecture.sh use-case-coverage test
```

### Step 12.4 — Full test + lint

```bash
flutter analyze --no-fatal-infos
flutter test --coverage
bash scripts/validate.sh
```

### Step 12.5 — Device smoke test (simulator/emulator)

1. Open inbox — search bar collapses by default.
2. Tap search icon — bar expands (150ms), type "test" — list filters.
3. Tap X — bar collapses, list restores.
4. Swipe right on a conversation — see PIN + UNREAD actions; tap PIN → conversation moves to top + pin glyph appears.
5. Swipe right again — tap UNPIN → conversation returns to recency; glyph removed.
6. Swipe right — tap UNREAD → unread badge appears on the row.
7. Swipe left — see MUTE + ARCHIVE + BLOCK.
8. Tap MUTE → speaker-slash glyph appears on the row.
9. Swipe left → UNMUTE → glyph removed.
10. Swipe left → tap BLOCK → confirmation sheet appears with name.
11. Tap CANCEL → sheet dismissed.
12. Tap BLOCK → confirm → sheet dismisses; conversation row shows blocked status.
13. Tap "ALSO REPORT" → report sheet opens; select a reason → SUBMIT REPORT becomes enabled → tap → snackbar "REPORT SUBMITTED."

**CP-12 done check:** All validation scripts green; smoke test passes.

---

## Branch merge checklist

Before opening the PR:

- [ ] `bash scripts/validate.sh` green (no `FULL=1` required for PR; add it for the release build).
- [ ] `flutter test --coverage` green, no new failures.
- [ ] `bash scripts/check-architecture.sh` green.
- [ ] All four new test files exist and pass.
- [ ] All five migration files have corresponding rollback files in `supabase/rollbacks/`.
- [ ] `messaging_provider.dart` < 500 LOC; `inbox_safety_provider.dart` exists and < 200 LOC.
- [ ] No `GoogleFonts.*`, `Colors.white`, `SizedBox(height:`, hardcoded `Color(0xFF...)`, or `AppColors.*` in new files.
- [ ] PR description includes: screenshots of search, pin, mute, block confirmation, report sheet; migration notes linking to the four new `.sql` files; OQ-1 through OQ-6 marked as resolved (or noted as deferred if Ken's answer changed scope).
- [ ] `superpowers:verification-before-completion` skill invoked before marking PR ready for review.

---

## Estimated complexity

| Checkpoint | Effort |
|---|---|
| CP-1 Migrations | ~1h |
| CP-2 get_inbox + model | ~45m |
| CP-3 Domain | ~30m |
| CP-4 Data layer | ~1h |
| CP-5 Use cases | ~45m |
| CP-6 Controller + split | ~1.5h |
| CP-7 Search UI | ~1h |
| CP-8 Swipe actions | ~1h |
| CP-9 Block sheet | ~45m |
| CP-10 Report sheet | ~1h |
| CP-11 Tests | ~2h |
| CP-12 Verify | ~30m |
| **Total** | **~12h** |

Each CP is independently committable. Recommended commit cadence: one commit per CP.
