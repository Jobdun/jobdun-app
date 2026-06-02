# Messaging + Realtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the real (non-mock) backend work end-to-end for messaging — fix the DB so realtime + read-receipts + unread counts function, give builders a way to start a chat with an applicant, wire the thread screen to the live controller — then remove the mock fallbacks.

**Architecture:** The Supabase data layer + `MessagingController` already exist and are correct. This plan (1) corrects the database (realtime publication, missing columns, trigger, two RPCs), (2) replaces the unreliable inbox embed with a `get_inbox` RPC and adds an atomic `get_or_create_conversation` RPC, (3) wires the thread UI to the existing controller, (4) adds a builder-side "Message" CTA on the applicant card, and (5) strips the mock data. Chat entry point (decided): **builder messages an applicant**; the tradie replies from their inbox.

**Tech Stack:** Flutter 3.11 / Dart, Riverpod 3 (`Notifier`), Supabase (Postgres + RLS + Realtime), `fpdart` (`Either`), `mocktail` (tests). Reference audit: `docs/SUPABASE_REALTIME_BACKEND_AUDIT.md`.

---

## Multi-agent execution map

File ownership is disjoint within a phase so agents never edit the same file concurrently (per superpowers:dispatching-parallel-agents).

| Phase | Agent | Workstream | Owns (files) | Depends on |
|---|---|---|---|---|
| **1** (parallel ×3) | **A** | DB migration + RPCs | `supabase/migrations/20260603000001_*.sql` (+ a verify `.sql`) | — |
| **1** | **B** | Messaging data layer | `message_remote_datasource.dart`, `message_repository.dart`, `message_repository_impl.dart`, `conversation_model.dart`, new `domain/usecases/get_or_create_conversation.dart`, `messaging_provider.dart` (provider wiring only), tests | Contract of A's RPCs (codes against the agreed signature; runtime verified in Phase 4) |
| **1** | **C** | Thread page wiring | `message_thread_page.dart`, test | Existing controller (already shipped) |
| **2** (after 1) | **D** | Builder "Message" CTA | `messaging_provider.dart` (add `getOrCreateConversation` controller method), `applications_page.dart`, `applications_page_card.dart`, test | A (RPC), B (use case), C (thread route) |
| **3** (after 2) | **E** | Remove mock | `home_page.dart`, delete `home_sample_data.dart`, `home_map_view.dart`, `messages_page.dart`, `message_thread_page.dart` (mock remnants) | B, C, D merged + green |
| **4** | — (with user) | Live simulation | none (runtime) | migration applied + trader/builder accounts |

> ⚠️ **Phase-1 conflict note:** Agent B edits `messaging_provider.dart` for *provider/use-case wiring only* (the `getOrCreateConversationUseCaseProvider`). Agent D later edits the same file for the *controller method*. Run B fully and merge before dispatching D, so D edits a settled file. Agents A, B, C touch disjoint files and run truly parallel.

---

# PHASE 1

## Workstream A — Database migration + RPCs

Fixes audit findings F-2 (realtime), F-4 (read-receipt columns), F-6 (trigger), and adds the F-1/F-5 RPCs.

### Task A1: Create the corrective migration

**Files:**
- Create: `supabase/migrations/20260603000001_messaging_realtime_fixes.sql`

- [ ] **Step 1: Write the migration**

```sql
-- ============================================================
-- Messaging realtime + integrity fixes (audit F-2/F-4/F-6 + F-1/F-5 RPCs)
-- See docs/SUPABASE_REALTIME_BACKEND_AUDIT.md
-- ============================================================

-- ---------- F-4: read-receipt columns the datasource already writes ----------
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_last_read_at timestamptz,
  ADD COLUMN IF NOT EXISTS trade_last_read_at   timestamptz;

-- ---------- F-6: maintain preview + unread on every new message ----------
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.conversations c
     SET last_message_at        = NEW.created_at,
         last_message_preview   = left(NEW.body, 140),
         last_message_sender_id = NEW.sender_id,
         builder_unread_count   = c.builder_unread_count
                                   + CASE WHEN NEW.sender_id = c.trade_id   THEN 1 ELSE 0 END,
         trade_unread_count     = c.trade_unread_count
                                   + CASE WHEN NEW.sender_id = c.builder_id THEN 1 ELSE 0 END
   WHERE c.id = NEW.conversation_id;
  RETURN NEW;
END;
$$;
-- Trigger from 20260511000004 already calls this AFTER INSERT — no re-create.

-- ---------- F-1: atomic get-or-create conversation ----------
-- SECURITY DEFINER so the find-or-insert is atomic and bypasses the
-- chicken-and-egg of RLS during insert; we still assert the caller is a
-- participant. Builder-initiated per product decision, but symmetric.
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  p_builder uuid,
  p_trade   uuid,
  p_job     uuid DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.uid() NOT IN (p_builder, p_trade) THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  SELECT id INTO v_id FROM public.conversations
   WHERE builder_id = p_builder AND trade_id = p_trade
     AND (p_job IS NULL AND job_id IS NULL OR job_id = p_job)
   LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.conversations (builder_id, trade_id, job_id)
    VALUES (p_builder, p_trade, p_job)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.get_or_create_conversation(uuid,uuid,uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid,uuid,uuid) TO authenticated;

-- ---------- F-5: viewer-shaped inbox (counterparty resolved server-side) ----------
CREATE OR REPLACE FUNCTION public.get_inbox(p_user uuid)
RETURNS TABLE (
  id uuid, job_id uuid, builder_id uuid, trade_id uuid,
  last_message_at timestamptz, last_message_preview text, last_message_sender_id uuid,
  status text, created_at timestamptz,
  my_unread_count int,
  other_display_name text, other_avatar_url text, job_title text
) LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                      AS my_unread_count,
         other.display_name                                      AS other_display_name,
         other.avatar_url                                        AS other_avatar_url,
         j.title                                                 AS job_title
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
   WHERE (c.builder_id = p_user AND c.builder_archived_at IS NULL)
      OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL)
   ORDER BY c.last_message_at DESC NULLS LAST;
$$;
GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;
-- SECURITY INVOKER: RLS on conversations still applies; the function only
-- runs for rows the caller can already see, and reads display fields only.

-- ---------- F-2: enable realtime delivery ----------
ALTER TABLE public.messages               REPLICA IDENTITY FULL;
ALTER TABLE public.conversations          REPLICA IDENTITY FULL;
ALTER TABLE public.notifications          REPLICA IDENTITY FULL;
ALTER TABLE public.verification_documents REPLICA IDENTITY FULL;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['messages','conversations','notifications','verification_documents']
  LOOP
    BEGIN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    EXCEPTION WHEN duplicate_object THEN NULL;  -- already published (Dashboard toggle)
    END;
  END LOOP;
END $$;
```

- [ ] **Step 2: Apply locally and verify (no errors)**

Run: `supabase db reset` (local stack) **or** paste into the Supabase SQL editor on the dev project.
Expected: no errors; `supabase_realtime` now lists the 4 tables.

- [ ] **Step 3: Verify the RPCs + trigger with a seed script**

Create `supabase/migrations/_verify_messaging.sql` (scratch, not committed) or run inline:

```sql
-- as an authenticated builder (set request.jwt or use service role for the check)
select public.get_or_create_conversation('<BUILDER_UUID>','<TRADE_UUID>',null) as conv_id; -- returns a uuid
-- run again with same args -> returns the SAME uuid (idempotent)
insert into public.messages (conversation_id, sender_id, body)
  values ('<CONV_UUID>','<TRADE_UUID>','test');
select last_message_preview, trade_unread_count, builder_unread_count
  from public.conversations where id = '<CONV_UUID>';
-- expect: preview='test', builder_unread_count=1 (recipient), trade_unread_count=0
select * from public.get_inbox('<BUILDER_UUID>'); -- one row, other_display_name = trade's name
```
Expected: idempotent conv id; preview + recipient unread populated; inbox row carries counterparty name.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/20260603000001_messaging_realtime_fixes.sql
git commit -m "fix(db): enable realtime + read-receipt cols + msg trigger + inbox/conv RPCs"
```

**Agent A return contract (give to Agents B & D):**
- `get_or_create_conversation(p_builder uuid, p_trade uuid, p_job uuid default null) -> uuid`
- `get_inbox(p_user uuid) -> table(id, job_id, builder_id, trade_id, last_message_at, last_message_preview, last_message_sender_id, status text, created_at, my_unread_count int, other_display_name text, other_avatar_url text, job_title text)`

---

## Workstream B — Messaging data layer

Implements F-5 (inbox via RPC) and the F-1 backend (`getOrCreateConversation`). Codes against Agent A's return contract above.

### Task B1: `getConversations` reads `get_inbox` RPC; model maps the flat row

**Files:**
- Modify: `lib/features/messaging/data/models/conversation_model.dart`
- Modify: `lib/features/messaging/data/datasources/message_remote_datasource.dart:33-53` (the `getConversations` body)
- Test: `test/features/messaging/conversation_model_test.dart` (create)

- [ ] **Step 1: Write the failing model test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/messaging/data/models/conversation_model.dart';

void main() {
  test('fromInboxRow maps viewer-shaped get_inbox row', () {
    final row = {
      'id': 'c1', 'job_id': 'j1', 'builder_id': 'b1', 'trade_id': 't1',
      'last_message_at': '2026-06-03T10:00:00Z', 'last_message_preview': 'hi',
      'last_message_sender_id': 't1', 'status': 'active',
      'created_at': '2026-06-01T00:00:00Z', 'my_unread_count': 2,
      'other_display_name': 'Marcus Webb', 'other_avatar_url': null,
      'job_title': 'Switchboard',
    };
    final c = ConversationModel.fromInboxRow(row, viewerId: 'b1');
    expect(c.otherUserDisplayName, 'Marcus Webb');
    expect(c.builderUnreadCount, 2); // viewer is builder -> my_unread maps to builder side
    expect(c.lastMessagePreview, 'hi');
    expect(c.jobTitle, 'Switchboard');
  });
}
```

- [ ] **Step 2: Run it — verify it fails**

Run: `flutter test test/features/messaging/conversation_model_test.dart`
Expected: FAIL — `fromInboxRow` not defined.

- [ ] **Step 3: Add `fromInboxRow` to `ConversationModel`**

Append to `conversation_model.dart` inside the class (keep the existing `fromJson`):

```dart
  /// Maps a row from the `get_inbox(p_user)` RPC, which has already resolved
  /// the counterparty and the viewer's unread count server-side.
  factory ConversationModel.fromInboxRow(
    Map<String, dynamic> json, {
    required String viewerId,
  }) {
    final unread = json['my_unread_count'] as int? ?? 0;
    final isBuilderViewer = json['builder_id'] == viewerId;
    return ConversationModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String?,
      builderId: json['builder_id'] as String,
      tradeId: json['trade_id'] as String,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      builderUnreadCount: isBuilderViewer ? unread : 0,
      tradeUnreadCount: isBuilderViewer ? 0 : unread,
      status: ConversationStatusX.fromDb(json['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUserDisplayName: json['other_display_name'] as String?,
      otherUserAvatarUrl: json['other_avatar_url'] as String?,
      jobTitle: json['job_title'] as String?,
    );
  }
```

- [ ] **Step 4: Run it — verify it passes**

Run: `flutter test test/features/messaging/conversation_model_test.dart`
Expected: PASS.

- [ ] **Step 5: Point `getConversations` at the RPC**

Replace `message_remote_datasource.dart` `getConversations` body (the `.from('conversations').select(...)` block) with:

```dart
  @override
  Future<List<ConversationModel>> getConversations(String userId) async {
    try {
      final data = await _client.rpc(
        'get_inbox',
        params: {'p_user': userId},
      );
      return (data as List)
          .map((e) => ConversationModel.fromInboxRow(
                e as Map<String, dynamic>,
                viewerId: userId,
              ))
          .toList();
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/messaging/data/ test/features/messaging/conversation_model_test.dart
git commit -m "fix(messaging): load inbox via get_inbox RPC (counterparty + unread server-side)"
```

### Task B2: Add `getOrCreateConversation` through datasource → repo → use case

**Files:**
- Modify: `message_remote_datasource.dart` (interface + impl)
- Modify: `message_repository.dart` (contract)
- Modify: `message_repository_impl.dart`
- Create: `lib/features/messaging/domain/usecases/get_or_create_conversation.dart`
- Modify: `messaging_provider.dart` (add `getOrCreateConversationUseCaseProvider` only)
- Test: `test/features/messaging/get_or_create_conversation_test.dart` (create)

- [ ] **Step 1: Datasource — add to interface + impl**

Interface (add to `abstract interface class MessageRemoteDataSource`):

```dart
  Future<String> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  });
```

Impl (add method body):

```dart
  @override
  Future<String> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    try {
      final id = await _client.rpc('get_or_create_conversation', params: {
        'p_builder': builderId,
        'p_trade': tradeId,
        'p_job': jobId,
      });
      return id as String;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
```

- [ ] **Step 2: Contract + repo impl**

`message_repository.dart` — add:

```dart
  Future<Either<Failure, String>> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  });
```

`message_repository_impl.dart` — add:

```dart
  @override
  Future<Either<Failure, String>> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    try {
      return right(await _datasource.getOrCreateConversation(
        builderId: builderId, tradeId: tradeId, jobId: jobId,
      ));
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    }
  }
```

- [ ] **Step 3: Use case**

Create `get_or_create_conversation.dart`:

```dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/message_repository.dart';

class GetOrCreateConversation {
  const GetOrCreateConversation(this._repository);
  final MessageRepository _repository;

  Future<Either<Failure, String>> call({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) => _repository.getOrCreateConversation(
    builderId: builderId, tradeId: tradeId, jobId: jobId,
  );
}
```

- [ ] **Step 4: Wire the use-case provider** (in `messaging_provider.dart`, beside the other `*UseCaseProvider`s; add the import):

```dart
import '../../domain/usecases/get_or_create_conversation.dart';
// ...
final getOrCreateConversationUseCaseProvider = Provider(
  (ref) => GetOrCreateConversation(ref.read(messageRepositoryProvider)),
);
```

- [ ] **Step 5: Failing repo test (mocktail)**

`test/features/messaging/get_or_create_conversation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jobdun/features/messaging/data/datasources/message_remote_datasource.dart';
import 'package:jobdun/features/messaging/data/repositories/message_repository_impl.dart';

class _MockDs extends Mock implements MessageRemoteDataSource {}

void main() {
  test('repo returns conversation id from datasource', () async {
    final ds = _MockDs();
    when(() => ds.getOrCreateConversation(
          builderId: any(named: 'builderId'),
          tradeId: any(named: 'tradeId'),
          jobId: any(named: 'jobId'),
        )).thenAnswer((_) async => 'conv-1');
    final repo = MessageRepositoryImpl(ds);
    final r = await repo.getOrCreateConversation(builderId: 'b', tradeId: 't');
    expect(r, const Right<dynamic, String>('conv-1'));
  });
}
```

- [ ] **Step 6: Run — fails, then passes**

Run: `flutter test test/features/messaging/get_or_create_conversation_test.dart`
Expected: FAIL before Steps 1-3 compile, PASS after.

- [ ] **Step 7: Commit**

```bash
git add lib/features/messaging test/features/messaging/get_or_create_conversation_test.dart
git commit -m "feat(messaging): getOrCreateConversation through datasource/repo/use case"
```

---

## Workstream C — Wire the message thread page (F-3)

Connects the existing controller to the UI. No backend change.

### Task C1: Rebuild `message_thread_page.dart` as a `ConsumerStatefulWidget`

**Files:**
- Modify: `lib/features/messaging/presentation/pages/message_thread_page.dart` (delete `_mockThread`, `_Msg`, `isMock`, `_localMessages`)
- Test: `test/features/messaging/message_thread_page_test.dart` (create)

- [ ] **Step 1: Failing widget test — loads on open, sends through controller**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/messaging/domain/entities/message.dart';
import 'package:jobdun/features/messaging/domain/repositories/message_repository.dart';
import 'package:jobdun/features/messaging/presentation/providers/messaging_provider.dart';
import 'package:jobdun/features/messaging/presentation/pages/message_thread_page.dart';
import 'package:fpdart/fpdart.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  setUpAll(() => registerFallbackValue(<Message>[]));

  testWidgets('renders messages from controller and sends', (tester) async {
    final repo = _MockRepo();
    when(() => repo.getMessages(any())).thenAnswer((_) async => right([
      Message(id: 'm1', conversationId: 'c1', senderId: 'other', body: 'Hello there',
          createdAt: DateTime(2026, 6, 3, 10)),
    ]));
    when(() => repo.watchMessages(any())).thenAnswer((_) => const Stream.empty());
    when(() => repo.markConversationRead(
        conversationId: any(named: 'conversationId'),
        userId: any(named: 'userId'), isBuilder: any(named: 'isBuilder')))
      .thenAnswer((_) async => right(null));
    when(() => repo.sendMessage(
        conversationId: any(named: 'conversationId'),
        senderId: any(named: 'senderId'), body: any(named: 'body')))
      .thenAnswer((_) async => right(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        messageRepositoryProvider.overrideWithValue(repo),
        currentUserIdSyncProvider.overrideWithValue('me'),
      ],
      child: const MaterialApp(
        home: MessageThreadPage(
          args: ConversationArgs(conversationId: 'c1', otherName: 'Marcus'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hello there'), findsOneWidget); // loaded from controller
    await tester.enterText(find.byType(TextField), 'My reply');
    await tester.tap(find.byIcon(/* send icon */ Icons.send)); // adjust to AppIcons.send finder
    await tester.pump();
    verify(() => repo.sendMessage(
        conversationId: 'c1', senderId: 'me', body: 'My reply')).called(1);
  });
}
```

> Note: replace the send-button finder with one matching `AppIcons.send` (e.g. wrap the send `GestureDetector` in a `Key('thread-send')` and use `find.byKey`). Add that key in Step 3.

- [ ] **Step 2: Run — verify it fails**

Run: `flutter test test/features/messaging/message_thread_page_test.dart`
Expected: FAIL (page is still the mock `StatefulWidget`; no controller read).

- [ ] **Step 3: Rewrite the page**

Replace the whole file. Key changes — class becomes `ConsumerStatefulWidget`; `initState` loads + marks read; `build` reads `messagesFor`; `_send` calls the controller; `dispose` unsubscribes. Delete `_mockThread`, `_Msg`, `_localMessages`, and `ConversationArgs.isMock`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/message.dart';
import '../providers/messaging_provider.dart';

class ConversationArgs {
  const ConversationArgs({
    required this.conversationId,
    required this.otherName,
    this.jobTitle,
    this.otherInitials,
  });
  final String conversationId;
  final String otherName;
  final String? jobTitle;
  final String? otherInitials;
}

class MessageThreadPage extends ConsumerStatefulWidget {
  const MessageThreadPage({super.key, required this.args});
  final ConversationArgs args;
  @override
  ConsumerState<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final id = widget.args.conversationId;
    Future.microtask(() {
      final n = ref.read(messagingControllerProvider.notifier);
      n.loadMessages(id);
      n.markConversationRead(id);
    });
  }

  @override
  void dispose() {
    ref.read(messagingControllerProvider.notifier)
        .unsubscribeMessages(widget.args.conversationId);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await ref.read(messagingControllerProvider.notifier).sendMessage(
          conversationId: widget.args.conversationId,
          body: text,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final args = widget.args;
    final me = ref.watch(currentUserIdSyncProvider);
    final messages = ref.watch(messagingControllerProvider
        .select((s) => s.messagesFor(args.conversationId)));
    final initials = args.otherInitials ?? _initials(args.otherName);

    // ... reuse the EXISTING header + input-bar layout from the old file,
    // but the message list now maps `messages` (List<Message>):
    //   final msg = messages[i];
    //   final isMine = msg.senderId == me;
    //   bubble text = msg.body; time = _fmtTime(msg.createdAt);
    // Empty list -> a centered "Say hello 👋 / No messages yet" placeholder.
    return const Placeholder(); // REPLACE with the migrated layout
  }

  static String _fmtTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
```

> The executing agent must port the **existing** header `Container`, the `ListView.builder` bubble styling, and the input bar verbatim from the current file (lines 112-345), substituting the data source as commented. Keep `Colors.white // intentional` on the bubble/send icon. Add `key: const Key('thread-send')` to the send `GestureDetector`.

- [ ] **Step 4: Run — verify it passes**

Run: `flutter test test/features/messaging/message_thread_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/messaging/presentation/pages/message_thread_page.dart test/features/messaging/message_thread_page_test.dart
git commit -m "feat(messaging): wire thread page to live controller (load/send/realtime/read)"
```

---

# PHASE 2

## Workstream D — Builder "Message" CTA (F-1 UI)

After Phase 1 merges. Adds a controller method + a CTA on the builder's applicant card that opens (or creates) the conversation and navigates to the thread.

### Task D1: Controller method `getOrCreateConversation`

**Files:**
- Modify: `lib/features/messaging/presentation/providers/messaging_provider.dart`
- Test: `test/features/messaging/messaging_controller_get_or_create_test.dart` (create)

- [ ] **Step 1: Failing test**

```dart
// Pump a ProviderScope with messageRepositoryProvider overridden by a mock
// whose getOrCreateConversation returns Right('conv-9'); read the controller,
// call getOrCreateConversation(builderId:'b', tradeId:'t', jobId:'j'),
// expect the returned String == 'conv-9'.
```
(Full mock setup mirrors Task B2's `_MockRepo`; assert the controller returns the id and sets no error.)

- [ ] **Step 2: Run — fails** (`getOrCreateConversation` not on controller).

- [ ] **Step 3: Add the method to `MessagingController`**

```dart
  /// Returns the conversation id (existing or newly created), or null on error.
  Future<String?> getOrCreateConversation({
    required String builderId,
    required String tradeId,
    String? jobId,
  }) async {
    final result = await ref.read(getOrCreateConversationUseCaseProvider).call(
          builderId: builderId, tradeId: tradeId, jobId: jobId,
        );
    return result.fold((f) {
      state = state.copyWith(error: f.message);
      return null;
    }, (id) => id);
  }
```

- [ ] **Step 4: Run — passes. Step 5: Commit**

```bash
git commit -am "feat(messaging): controller getOrCreateConversation"
```

### Task D2: "Message" CTA on the builder applicant card

**Files:**
- Modify: `lib/features/applications/presentation/pages/applications_page_card.dart` (add `onMessage` callback + button)
- Modify: `lib/features/applications/presentation/pages/applications_page.dart` (pass `onMessage`, wire to controller + navigation)

- [ ] **Step 1: Add `onMessage` to `_AppCard`**

In the constructor add `this.onMessage;` and field `final VoidCallback? onMessage;`. In the builder action rows (the `if (isBuilder && status == ApplicationStatus.shortlisted)` block, and optionally the pending block), add a secondary "MESSAGE" button beside HIRE:

```dart
Gap(AppSpacing.sm.h),
JButton(
  label: 'MESSAGE',
  variant: JButtonVariant.secondary,
  size: JButtonSize.compact,
  onPressed: onMessage,
),
```

- [ ] **Step 2: Wire it in `applications_page.dart`**

Where `_AppCard(...)` is constructed for the builder (incoming applications), add:

```dart
onMessage: () async {
  final n = ref.read(messagingControllerProvider.notifier);
  final convId = await n.getOrCreateConversation(
    builderId: app.builderId,
    tradeId: app.tradeId,
    jobId: app.jobId,
  );
  if (convId == null || !context.mounted) return;
  context.push('/messages/$convId', extra: ConversationArgs(
    conversationId: convId,
    otherName: app.tradeFullName ?? 'Tradesperson',
  ));
},
```

Add imports: `messaging_provider.dart` and `message_thread_page.dart` (for `ConversationArgs`).

- [ ] **Step 3: Manual smoke (analyzer + format)**

Run: `flutter analyze --no-fatal-infos && dart format --output=none --set-exit-if-changed lib/features/applications`
Expected: no issues.

- [ ] **Step 4: Commit**

```bash
git commit -am "feat(applications): builder Message CTA opens/creates conversation"
```

---

# PHASE 3

## Workstream E — Remove mock data

Only after B+C+D are merged and green, so the real paths exist. (Original task; scope = user-facing fake content only, per the earlier decision; **hide** the builder "Available now" section.)

### Task E1: Home — delete sample data, hide tradies, real jobs + empty state

**Files:** Delete `lib/features/home/presentation/pages/home_sample_data.dart`; modify `home_page.dart` (drop `part`, drop `_tradies`/`_mockJobs` usage, hide builder section, real `feedJobs` + compact empty state), `home_map_view.dart` (drop `_sampleJobsAround`).

- [ ] Drop `part 'home_sample_data.dart';` (`home_page.dart:38`) and delete the file.
- [ ] Builder branch (`home_page.dart:356-377`): render nothing — wrap the section title + list so they only build `if (!isBuilder)`.
- [ ] Tradie branch: `itemCount: feedJobs.length`; remove the `_mockJobs[i]` else-branch + its `JobDetailArgs(...)` push; when `feedJobs.isEmpty`, show a compact inline empty (icon + "No jobs nearby yet" + `JButton('BROWSE JOBS')` → `context.go('/jobs')`).
- [ ] `home_map_view.dart:258`: `final jobsToShow = widget.jobs;` (drop the `_sampleJobsAround` fallback).
- [ ] Remove now-unused `TradieCard` import.
- [ ] Run: `flutter analyze --no-fatal-infos` → no unused-symbol errors. **Commit** `refactor(home): remove sample jobs/tradies; real feed + empty state`.

### Task E2: Messaging list — remove `_mockConvos`, real-or-empty

**Files:** `messages_page.dart`.

- [ ] Delete `_MockConvo` + `_mockConvos` (lines 400-453).
- [ ] Replace `useReal`/`totalUnread = ... : 3` with direct `msgState.conversations` / `msgState.totalUnread`.
- [ ] Branch: loading → skeleton (keep); `conversations.isEmpty` → existing `_EmptyState`; else the real `JStaggeredList` branch (keep). Delete the `_mockConvos` `JStaggeredList` branch + the `mock-${m.initials}` push.
- [ ] Run analyze. **Commit** `refactor(messaging): remove mock inbox; real conversations or empty state`.

### Task E3: Thread — remove any mock remnants

**Files:** `message_thread_page.dart` (already rebuilt in C1 — confirm `_mockThread`/`_Msg`/`isMock` are gone). If C1 is merged, this is a no-op verification.

- [ ] Run: `bash scripts/validate.sh` (design grep + format + analyze + tests). **Commit** if any cleanup needed.

---

# PHASE 4 — Live simulation (with the user)

Runtime end-to-end verification using real trader + builder accounts. Cannot run from tests alone (realtime + RLS + auth).

**Preconditions the user provides / approves:**
1. Migration `20260603000001` applied to the dev Supabase project (via `supabase db push`, the SQL editor, or the Supabase MCP once authenticated).
2. In Supabase **Database → Replication / Publications**, confirm `supabase_realtime` lists `messages`, `conversations`, `notifications`, `verification_documents` (the migration adds them; verify the toggle).
3. Two accounts: one **builder** (your builder id), one **trade**, both with a `profiles` row + role. A `jobs` row owned by the builder, and a `job_applications` row from the trade (so an applicant card exists to message from).

**Simulation script:**
- [ ] Sign in as **builder** → `/applications` (incoming) → tap **MESSAGE** on the trade's applicant card → lands on the thread (conversation auto-created via RPC).
- [ ] Send a message → it persists and appears.
- [ ] On a second device/emulator signed in as the **trade**, open `/messages` → the conversation shows with the builder's name + preview + unread badge (validates F-5 + F-6) → open it → the builder's message is **already there**, and a new message from the builder appears **live** without refresh (validates F-2 realtime).
- [ ] Trade replies → builder's open thread updates live; builder's inbox unread resets after open (validates F-4 `markConversationRead` no longer throws).
- [ ] Insert a `messages` row via SQL → confirm it streams into both open threads (pure realtime check).

**Exit criteria:** all five steps pass → real setup confirmed working → Phase 3 mock removal is safe to merge (or already merged).

---

## Self-review (against the audit spec)

- **F-1 conversation creation** → Tasks A1 (RPC), B2 (use case), D1 (controller), D2 (CTA). ✅
- **F-2 realtime publication** → Task A1 (publication + replica identity). ✅
- **F-3 thread wiring** → Task C1. ✅
- **F-4 `last_read_at` columns** → Task A1. ✅ (markConversationRead now targets real columns; exercised in C1 test + Phase 4.)
- **F-5 inbox counterparty** → Task A1 (`get_inbox`) + B1 (datasource/model). ✅
- **F-6 preview/unread trigger** → Task A1. ✅
- **Mock removal (original ask)** → Tasks E1–E3. ✅
- **F-7 builder tradies** → hidden in E1 (no backend; deferred by design). ✅
- **Type consistency:** RPC names (`get_inbox`, `get_or_create_conversation`), method `getOrCreateConversation`, factory `fromInboxRow`, controller `getOrCreateConversation` used consistently across A/B/D. ✅
- **Placeholders:** the only intentional "fill from existing file" marker is the thread-page layout port in C1 Step 3 (explicitly instructed to copy lines 112-345 of the current file) — not a spec gap.

---

*Plan derived from `docs/SUPABASE_REALTIME_BACKEND_AUDIT.md`. Phases 1-3 are codeable now; Phase 4 needs the migration applied + the two test accounts.*
