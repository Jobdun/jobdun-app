# Messaging — Phase C: Message Actions (Design Spec)

- **Date:** 2026-06-08
- **Status:** Draft — awaiting Ken's answers on Open Questions
- **Branch:** `feat/messaging-phase-c-actions`
- **Author:** Ken Garcia (with Claude)
- **Depends on:** Phase A (reliability core, `feat/messaging-reliability-core`) — landed on `feat/offline-cache-hardening`

## Context

Phase A shipped the reliability core: optimistic send, status ladder
(Sending → Sent → Seen → Failed), paginated history, and a pure value object
(`thread_messages.dart`) that merges confirmed server rows, the outbox, and
the counterparty's read marker into a flat `List<ThreadEntry>` ready for
rendering.

The full program: **A** Reliability core → **B** Photo/file sharing → **C**
Message actions (this spec) → **D** Inbox power + safety (block/report).

This spec covers **Phase C only**: long-pressing a bubble opens an action
sheet (reply/quote, react, copy, unsend). The schema already has the
`deleted_at` and `edited_at` columns on `messages`; reactions and reply-to
require new schema.

### What Phase A left us

| Artefact | Location | LOC | Budget |
|---|---|---|---|
| `message_thread_page.dart` | `presentation/pages/` | 443 | 500 ceiling |
| `message_thread_widgets.dart` | `presentation/pages/` | 407 | 500 ceiling |
| `message_thread_status.dart` | `presentation/pages/` | 100 | 500 ceiling |
| `messaging_provider.dart` | `presentation/providers/` | 452 | 500 ceiling |
| `thread_messages.dart` | `presentation/state/` | 142 | 500 ceiling |
| `message_remote_datasource.dart` | `data/datasources/` | 259 | 500 ceiling |

Every presentation file is already at or above the 400-LOC target. Phase C
adds new widgets, new controller methods, and extended data-source calls, so
the file-split plan is **mandatory, not optional**.

### RLS audit: existing messages UPDATE policy

The current `messages_update_read` policy (`20260511000006_rls.sql`) allows
ANY conversation participant to UPDATE any message:

```sql
CREATE POLICY "messages_update_read"
  ON public.messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );
```

This policy is **too broad** for unsend/soft-delete: it would let the
recipient set `deleted_at` on the sender's messages. Phase C must replace it
with two targeted policies (see Schema section).

---

## Problem

The thread currently has no message-level interactions beyond reading. Users
cannot react, quote-reply, copy text, or retract a mis-sent message. These
are table-stakes features for any 2-party messenger; their absence makes
Jobdun's chat feel unfinished compared to what tradies and builders expect from
a work communication tool.

---

## Goals

1. **Reply / quote** — long-press → Reply; the compose bar shows a quoted
   preview (sender + first ~80 chars); the sent message stores a `reply_to_id`
   FK; bubbles render a quoted preview above their body; tapping the quote
   scrolls to the original message.
2. **Reactions** — a `message_reactions` table (one emoji per user per
   message, enforced by unique constraint); reaction chips render under the
   bubble; realtime-delivered; the reaction set and one-vs-many cardinality are
   decided below (see Open Questions).
3. **Unsend / soft-delete** — sets `messages.deleted_at` via a new
   sender-only UPDATE policy; the bubble becomes a "MESSAGE DELETED"
   tombstone; an unsend time window applies (see Open Questions).
4. **Copy** — copies `entry.body` to clipboard via `Clipboard.setData`;
   available for any non-deleted message.
5. **All actions flow through `showJSheet`** (never `showModalBottomSheet`)
   and fire `HapticFeedback.lightImpact()` on selection.
6. **File-size compliance** — every file stays under the 500-LOC hard ceiling
   after Phase C lands.

---

## Non-goals (explicitly deferred)

- ~~Edit~~ — **NOW IN SCOPE (Ken-locked 2026-06-08): edit allowed within 1
  minute of sending.** See D-13. Reactions on the edited body are kept; the
  edited bubble shows an "edited" marker. The recipient's seen-marker is
  unaffected (it tracks `last_read_at`, not body).
- **Report / flag a message** — Phase D.
- **Jump-to-quoted scrolling** — listed as a goal but marked as a
  best-effort stretch. Reliable jump requires knowing the scroll position of an
  arbitrary historical message, which may not be in the loaded window. The
  spec defines the data wire (reply_to_id) and the bubble chrome; the scroll
  implementation is a P2 follow-up if pagination makes it non-trivial.
- **Reactions on pending (optimistic) messages** — not allowed. The action
  menu only opens on confirmed server messages (non-pending `ThreadEntry`).
- **Animated reaction burst / confetti** — keep Phase C to the data model
  and a clean chip row; animation polish is a separate pass.
- **Push notifications for reactions** — cross-cutting, separate spec.
- **Phase B (photos/files)** and **Phase D (block/report)** remain
  independent.

---

## Decisions (locked)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D-1 | Action menu trigger | Long-press on `_MessageBubble` (`GestureDetector.onLongPress`) | Standard mobile messenger pattern; does not interfere with tap-to-scroll-to-quoted |
| D-2 | Action sheet component | `showJSheet` from `lib/core/design/widgets/j_bottom_sheet.dart` | Per CLAUDE.md: never use `showModalBottomSheet` directly |
| D-3 | Haptic on action select | `HapticFeedback.lightImpact()` inside every action's `onTap` | Per CLAUDE.md sliding-action convention; makes confirm feel physical |
| D-4 | Unsend mechanism | Set `messages.deleted_at` — existing column, soft-delete | Consistent with the existing `deleted_at` column already modelled in `Message` entity and filtered in `getMessages`/`watchMessages` |
| D-5 | Deleted-message render | "MESSAGE DELETED" tombstone chip — replaces body, no body preview | Preserves thread continuity; tombstone acknowledges something was there without leaking content |
| D-6 | Tombstone in quotes | If the reply-to original is deleted, show "Original message deleted" in the quote preview | Prevents content leakage via reply |
| D-7 | Reply-to data model | `messages.reply_to_id uuid` self-FK referencing `messages.id`, nullable | Minimal: one column, one join; no separate table needed |
| D-8 | Reply preview in `ThreadEntry` | `replyTo` field on `ThreadEntry` (nullable `ReplyPreview` value object: `senderId`, `snippet`) | Keeps `buildThreadEntries` pure; preview is denormalised at merge time from the same confirmed list |
| D-9 | Reactions table | `message_reactions(message_id, user_id, emoji, created_at)` with **PRIMARY KEY (message_id, user_id)** — **one reaction per user per message** (Ken-locked 2026-06-08). Switch emoji = upsert (replace); tap same emoji = DELETE (toggle off). | Max **2 reactions per message** (one builder, one tradie). Simpler than multi-emoji and matches the 2-party model. |
| D-10 | Reactions in `ThreadEntry` | `reactions: List<ReactionCount>` (emoji + count + `iMine`) on `ThreadEntry`; computed by `buildThreadEntries` from a per-conversation reactions map | Keeps merge logic pure |
| D-11 | Reactions realtime channel | Separate `.stream()` on `message_reactions` scoped to `conversation_id` (join via messages); reactions map held in `MessagingState` alongside `messagesByConvId` | Minimal new state; reuses existing stream pattern |
| D-12 | RLS (already DONE) | The broad `messages_update_read` policy was **dropped in `20260608000002_messaging_guardrails.sql` (applied 2026-06-08)**. The existing sender-only `messages_modify_own` (USING + WITH CHECK `sender_id = auth.uid()`) already authorises both unsend (`deleted_at`) and edit (`body`,`edited_at`). The 1-minute edit window is enforced client-side **and** by the `BEFORE UPDATE` trigger in D-13 — not by RLS. | Least privilege; the recipient can no longer modify the sender's messages (security fix already live). |
| D-13 | **Edit within 1 minute** (Ken-locked 2026-06-08) | Sender may edit a message `body` for **60 s** after `created_at`; sets `edited_at = now()`; bubble shows an "edited" marker. Enforced client-side (the action menu hides Edit after 60 s) **and** a `BEFORE UPDATE` trigger rejecting `body` changes when `now() - created_at > interval '1 minute'`. | Covers "sent the wrong thing" without indefinite-edit footguns; the trigger makes the window tamper-proof against direct API edits. |
| D-14 | Copy | `Clipboard.setData(ClipboardData(text: entry.body))` — no special infra needed | Zero backend; pure client |
| D-15 | Actions available per role | Mine: Reply, React, Copy, Unsend. Theirs: Reply, React, Copy. (No unsend on other's messages) | Only sender can retract |

---

## Architecture

### Data flow overview

```
Long-press bubble
  → _MessageActionSheet (showJSheet)
      ├── Copy → Clipboard.setData
      ├── Reply → MessagingController.setReplyDraft(entry)
      │          → compose bar shows _QuotePreviewBar
      │          → sendMessage carries replyToId
      ├── React → MessagingController.toggleReaction(messageId, emoji)
      │          → datasource upsert/delete on message_reactions
      └── Unsend → confirmation dialog → MessagingController.unsendMessage(messageId)
                    → datasource UPDATE messages SET deleted_at = now()
                    → realtime echo → watchMessages already filters deleted_at IS NULL
                    → ThreadEntry becomes a tombstone
```

### Extended pure value object (`thread_messages.dart`)

`buildThreadEntries` receives two additional inputs:

```
reactionsMap: Map<String, List<MessageReaction>>  // keyed by message id
me: String?                                       // already present
```

For each confirmed `Message`:
- `isDeleted` (`deletedAt != null`) → `ThreadEntry.isDeleted = true`, body
  replaced by a sentinel. Body is NOT passed through to `ThreadEntry` for
  deleted messages (prevents accidental rendering).
- `replyTo` → look up `reply_to_id` in the same `byId` map; if found and not
  deleted, build `ReplyPreview(senderId, snippet: body.substring(0, 80))`.
  If the original is deleted, set `ReplyPreview.isDeleted = true`.
- `reactions` → look up in `reactionsMap`; fold into
  `List<ReactionCount>(emoji, count, iMine)`.

No database calls inside `buildThreadEntries` — it remains pure and
unit-testable.

### New value objects (all in `thread_messages.dart`)

```dart
class ReplyPreview {
  final String senderId;
  final String snippet; // first 80 chars of body
  final bool isDeleted; // original was soft-deleted
}

class ReactionCount {
  final String emoji;
  final int count;
  final bool iMine;
}
```

`ThreadEntry` gains three new nullable/defaulted fields:
- `bool isDeleted` (default false)
- `ReplyPreview? replyTo`
- `List<ReactionCount> reactions` (default const [])

### New entity

```dart
// lib/features/messaging/domain/entities/message_reaction.dart
class MessageReaction extends Equatable {
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;
}
```

### Controller changes (`messaging_provider.dart`)

New public methods (≤4 params each):

| Method | Params | What it does |
|---|---|---|
| `setReplyDraft(String conversationId, ThreadEntry? entry)` | 2 | Sets/clears the active reply target in state |
| `sendMessage(...)` | extend existing | Accepts optional `replyToId` passthrough |
| `toggleReaction(String conversationId, String messageId, String emoji)` | 3 | Upsert if not mine, DELETE if mine; optimistic update |
| `unsendMessage(String conversationId, String messageId)` | 2 | UPDATE deleted_at; optimistic removal from confirmed list |

New state on `MessagingState`:
- `replyDraftByConvId: Map<String, ThreadEntry?>` — the active reply target per conversation (null = none)
- `reactionsByConvId: Map<String, List<MessageReaction>>` — all reactions for the loaded thread

New stream subscription per thread:
- `_reactionSubs: Map<String, StreamSubscription>` — watches `message_reactions` for the open conversation

### File-size plan (mandatory splits)

| File | Current LOC | Phase C additions (est.) | Action |
|---|---|---|---|
| `message_thread_page.dart` | 443 | +~40 (reply draft bar, scroll-to-quoted glue, action sheet invocation) | Extract `_ReplyDraftBar` and `_MessageListView` into new `part` file |
| `message_thread_widgets.dart` | 407 | +~120 (tombstone, quote preview in bubble, reaction chips row) | Extract tombstone + reaction chips into new `part` file `message_thread_reactions.dart` |
| `message_thread_status.dart` | 100 | +~60 (action sheet widget) | Add `_MessageActionSheet` here — stays within 200 LOC |
| `messaging_provider.dart` | 452 | +~80 (new methods, new state fields, reaction sub) | Extract `MessagingState` class into `presentation/state/messaging_state.dart` (est. 80 LOC); controller drops to ~370 |
| `thread_messages.dart` | 142 | +~80 (new value objects, extended `buildThreadEntries`) | Stays within 250 LOC; no split needed |
| `message_remote_datasource.dart` | 259 | +~80 (reaction CRUD, unsend UPDATE) | Stays within 350 LOC; no split needed |

New files introduced by Phase C:

| File | Purpose | Est. LOC |
|---|---|---|
| `presentation/state/messaging_state.dart` | `MessagingState` class (extracted from provider) | ~90 |
| `presentation/pages/message_thread_reactions.dart` | `part of` — tombstone widget, reaction chip row | ~120 |
| `domain/entities/message_reaction.dart` | `MessageReaction` entity | ~20 |
| `data/models/message_reaction_model.dart` | `MessageReactionModel.fromJson` | ~30 |
| `domain/usecases/toggle_reaction.dart` | `ToggleReaction` use case | ~25 |
| `domain/usecases/unsend_message.dart` | `UnsendMessage` use case | ~25 |

---

## Schema

### Migration: `supabase/migrations/20260608000002_message_actions.sql`

```sql
-- ============================================================
-- Messaging Phase C — reply-to, reactions, sender-only unsend
-- Spec: docs/superpowers/specs/2026-06-08-messaging-phase-c-actions-design.md
-- ============================================================

-- ── 1. reply_to_id: self-FK for quoted replies ──────────────────────────────
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS reply_to_id uuid REFERENCES public.messages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS messages_reply_to_id_idx
  ON public.messages (reply_to_id)
  WHERE reply_to_id IS NOT NULL;

-- ── 2. message_reactions table ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.message_reactions (
  message_id  uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  emoji       text NOT NULL CHECK (char_length(emoji) <= 8),
  created_at  timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (message_id, user_id, emoji)
);

-- Lookup by message (chip rendering) and by user (toggle check)
CREATE INDEX IF NOT EXISTS message_reactions_message_id_idx
  ON public.message_reactions (message_id);
CREATE INDEX IF NOT EXISTS message_reactions_user_id_idx
  ON public.message_reactions (user_id);

-- Realtime: full row needed for DELETE events (toggle-off)
ALTER TABLE public.message_reactions REPLICA IDENTITY FULL;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ── 3. RLS on message_reactions ─────────────────────────────────────────────
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- Participants in the conversation can read all reactions on its messages.
DO $$ BEGIN
  CREATE POLICY "message_reactions_select"
    ON public.message_reactions FOR SELECT
    USING (
      EXISTS (
        SELECT 1
          FROM public.messages m
          JOIN public.conversations c ON c.id = m.conversation_id
         WHERE m.id = message_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- A user can only insert their own reaction.
DO $$ BEGIN
  CREATE POLICY "message_reactions_insert_own"
    ON public.message_reactions FOR INSERT
    WITH CHECK (
      auth.uid() = user_id
      AND EXISTS (
        SELECT 1
          FROM public.messages m
          JOIN public.conversations c ON c.id = m.conversation_id
         WHERE m.id = message_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- A user can only delete their own reaction.
DO $$ BEGIN
  CREATE POLICY "message_reactions_delete_own"
    ON public.message_reactions FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 4. Replace the overly-broad messages UPDATE policy ──────────────────────
-- The existing "messages_update_read" policy lets any participant UPDATE any
-- message row. This is too permissive for unsend (which sets deleted_at) —
-- it would allow the recipient to soft-delete the sender's messages.
-- Drop it and replace with two targeted policies:

DO $$ BEGIN
  DROP POLICY IF EXISTS "messages_update_read" ON public.messages;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- (a) Only the sender can unsend (set deleted_at).
DO $$ BEGIN
  CREATE POLICY "messages_unsend_own"
    ON public.messages FOR UPDATE
    USING (auth.uid() = sender_id)
    WITH CHECK (auth.uid() = sender_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- (b) Any participant can mark messages read (read_at column).
--     This restores the original intent of messages_update_read,
--     scoped to participants only.
DO $$ BEGIN
  CREATE POLICY "messages_mark_read"
    ON public.messages FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.conversations c
         WHERE c.id = conversation_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.conversations c
         WHERE c.id = conversation_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

> **Note on the dual UPDATE policy:** Postgres evaluates USING across all
> matching policies for the same operation with OR semantics when `permissive`
> (the default). Both `messages_unsend_own` and `messages_mark_read` are
> permissive UPDATE policies. The net effect is: any participant can UPDATE any
> message (read_at) OR a sender can UPDATE their own message (deleted_at).
> This is intentional — `messages_mark_read` is the wide participant gate that
> was always needed for read receipts; `messages_unsend_own` is additive for
> the sender's own rows. The restriction that matters is the client calling the
> right column — `markConversationRead` updates `conversations.*_last_read_at`,
> not `messages.read_at` directly, so in practice only `messages_unsend_own`
> is exercised by Phase C. If Phase E ever writes `messages.read_at` per-row,
> the `messages_mark_read` policy already covers it.

### Down-migration: `supabase/rollbacks/20260608000002_message_actions_down.sql`

```sql
ALTER TABLE public.messages DROP COLUMN IF EXISTS reply_to_id;
DROP TABLE IF EXISTS public.message_reactions;
DROP POLICY IF EXISTS "messages_unsend_own" ON public.messages;
DROP POLICY IF EXISTS "messages_mark_read" ON public.messages;
-- Restore the original broad policy
DO $$ BEGIN
  CREATE POLICY "messages_update_read"
    ON public.messages FOR UPDATE
    USING (
      EXISTS (
        SELECT 1 FROM public.conversations c
         WHERE c.id = conversation_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

---

## UI Design (Jobdun design tokens)

All colours via `context.c` (`JColors`). Never `Colors.white` without `// intentional`, never `Color(0xFF...)`, never `AppColors.*` directly.

### Long-press action sheet (`_MessageActionSheet`)

Presented via `showJSheet`. The sheet is a surface-coloured (`c.card` /
`#1E293B`) column. Each action is a full-width row: icon (24dp, `AppIcons.*`)
+ label (Oswald, 14sp, `c.text1`, letter-spacing 0.5). Destructive action
(Unsend) renders in `c.urgent` (`#EF4444`). All rows have a minimum 48dp
touch target. `HapticFeedback.lightImpact()` fires before every action.

```
┌──────────────────────────────┐
│  ←reply  REPLY               │  text1  48dp row
│  ◯       REACT               │  text1  48dp row  → opens emoji picker row
│  copy    COPY TEXT           │  text1  48dp row
│  ✕       UNSEND              │  urgent 48dp row  (mine only)
└──────────────────────────────┘
```

Ordering: non-destructive first, destructive last with a 1dp `c.border`
divider above it. React row expands inline to the emoji picker row on tap
(no nested sheet).

### Emoji picker row (inside the sheet)

A horizontally scrollable single row of circular emoji tap targets (48dp).
The defined set renders as text characters at 22sp inside a `surfaceRaised`
chip (`#334155`). Already-reacted emojis show with a 1.5dp `c.action` border.

### Quoted-reply preview above bubble body (`_QuotedPreview` widget)

Displayed above the message body inside the bubble container. A 3dp left
border in `c.action` (orange) for the sender's side or `c.border` for
incoming; surface colour `surfaceRaised`. Two lines max: sender name
(`c.text2`, 11sp, Oswald caps) + snippet (`c.text3`, 12sp, italic, max 1
line, overflow ellipsis). If original is deleted: grey italic "Original
message deleted".

```
│▌ JAKE M.                        │
│  Can you start Monday?  …       │
└─────────────────────────────────┘
This is my reply body text here.
```

### Reaction chip row (under the bubble)

Chips aligned to the bubble's horizontal axis (trailing for mine, leading for
theirs). Each chip: `surfaceRaised` background (`#334155`), 4dp border radius,
6px horizontal + 3px vertical padding. Content: emoji (14sp) + count (11sp,
`c.text2`). My-reacted chips get a 1dp `c.action` border ring. Chips are
individually tappable to toggle (add/remove) — `HapticFeedback.lightImpact()`
on toggle. Chips use `Wrap` (not `Row`) to handle 2+ reactions gracefully.

### Deleted-message tombstone (`_DeletedTombstone` widget)

Replaces the bubble body entirely. Rendered as a surface-bordered container
(1dp `c.border`), same max-width as a normal bubble. Content: `AppIcons.block`
(or equivalent "slash" icon, 14dp, `c.text3`) + "MESSAGE DELETED" (Oswald
caps, 12sp, `c.text3`). No long-press gesture on tombstones (the GestureDetector
is conditionally omitted). Timestamp and status tick still render below at
reduced opacity (`c.text3`).

### Compose bar — reply draft bar (`_ReplyDraftBar`)

Shown between the thread list and the input bar when a reply target is active.
Background `c.surface`, top 1dp `c.border` divider. Left 3dp orange border
strip. Content row: sender name + snippet (same as quote preview, truncated to
1 line), trailing close/cancel icon (`AppIcons.close`, `c.text3`, 20dp). Gap
between draft bar and input bar: `Gap(0)` — they are adjacent siblings in the
Column.

---

## Testing (TDD list — pure unit tests first)

All tests that exercise `buildThreadEntries` are pure Dart (no Flutter, no
Supabase) in `test/features/messaging/thread_messages_test.dart` (extend the
existing file or add `thread_messages_phase_c_test.dart`).

### Value object tests (pure — `thread_messages_test.dart`)

| # | Test case |
|---|---|
| T-01 | A confirmed message with `deletedAt` set produces `ThreadEntry.isDeleted = true` and an empty `body` |
| T-02 | A deleted message's `body` field is empty string (sentinel); never the original text |
| T-03 | A message with `replyToId` resolves `ThreadEntry.replyTo.snippet` from the same confirmed list |
| T-04 | If the reply-to original is not in the confirmed list (not yet loaded), `replyTo` is null — no crash |
| T-05 | If the reply-to original is deleted, `replyTo.isDeleted = true` and `snippet` is empty |
| T-06 | Reactions map with two emojis from two users on the same message produces correct `ReactionCount` list with counts |
| T-07 | `iMine = true` for the reaction whose `userId == me` |
| T-08 | `iMine = false` for all reactions when `me` is null |
| T-09 | Optimistic (pending) `ThreadEntry` has `reactions = []` and `replyTo = null` regardless of input |
| T-10 | `buildThreadEntries` remains sorted oldest→newest with a mix of deleted, replied, and reacted messages |
| T-11 | A deleted message is NOT filtered out of the list — it becomes a tombstone row (preserves thread shape) |
| T-12 | Two reactions with the same emoji from the same user are deduplicated (DB enforces PK but guard in client too) |

### Controller tests (mocked repo — `messaging_provider_test.dart`)

| # | Test case |
|---|---|
| T-13 | `setReplyDraft` sets `replyDraftByConvId[convId]` to the entry; a second call with null clears it |
| T-14 | `sendMessage` with `replyToId` passes it through to `SendMessage` use case |
| T-15 | `toggleReaction` with a new emoji calls `addReaction` on the repo and optimistically adds to state |
| T-16 | `toggleReaction` with an existing own-reaction calls `removeReaction` on the repo and optimistically removes |
| T-17 | `unsendMessage` calls `unsendMessage` use case; confirmed list no longer contains the message |
| T-18 | `unsendMessage` outside the time window is rejected client-side before hitting the repo |

### Data-source tests (mock Supabase client — `message_datasource_test.dart`)

| # | Test case |
|---|---|
| T-19 | `getMessages` now selects `reply_to_id` and maps it into `MessageModel` |
| T-20 | `addReaction(messageId, userId, emoji)` calls upsert on `message_reactions` |
| T-21 | `removeReaction(messageId, userId, emoji)` calls delete on `message_reactions` |
| T-22 | `unsendMessage(messageId)` calls UPDATE on `messages` with `deleted_at` and sender_id filter |
| T-23 | `watchReactions(conversationId)` emits a list of `MessageReactionModel` from the stream |

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `message_reactions` realtime stream fan-out on busy threads | Low (2-party chat, not group) | Single `.stream()` scoped to conversation |
| Dual UPDATE policy ambiguity (permissive OR) | Low | Document intent clearly in migration; phase E per-message `read_at` is already covered |
| `reply_to_id` ON DELETE SET NULL leaves orphan null — confusing after original is hard-deleted | Low (soft-delete only) | `buildThreadEntries` handles null gracefully (T-04); hard-delete is not a current RLS operation |
| File-size ceiling breached before split | High if skipped | Splits are checkpoint 0 of the plan — must happen before any new widget code |
| Scroll-to-quoted not working for messages outside loaded window | Medium | Deferred to P2; spec only commits to data wire and bubble chrome in Phase C |
| Unsend time-window enforcement is client-side only | Medium | Server-side enforcement via a DB check constraint or Edge Function trigger is a Phase D hardening task; document the gap |

---

## Open Questions (needs Ken)

| # | Question | Recommendation |
|---|---|---|
| OQ-1 | **Reaction emoji set** — which emojis? | Recommend the 6-emoji set: 👍 ❤️ 😂 😮 😢 🙏 — covers the emotional range of a work chat without feeling social-media-heavy; small set = clean chip row with no wrapping on most messages. Unicode code points: U+1F44D U+2764 U+1F602 U+1F62E U+1F622 U+1F64F |
| OQ-2 | **One reaction per user (per message) vs multiple** | Recommend: **one emoji per (user, message)** — simpler DB constraint (`UNIQUE (message_id, user_id)`), no per-emoji cardinality, tapping any emoji replaces the previous one. Chosen emoji is the whole identity. Less flexible but feels right for a trades work chat. Current spec has one-per-(user, message, emoji) which allows multiple; flip the PK if Ken prefers one-per-user. |
| OQ-3 | **Unsend time window** | Recommend: **any time** (no window), matching iMessage and Telegram. Rationale: a work conversation where someone sends site details or a quote to the wrong thread needs a no-stress retraction. If Ken prefers a window for auditability, recommend 10 minutes. Enforce client-side only for Phase C; server-side check in Phase D. |
| OQ-4 | **Edit in scope?** | Strongly recommend **DEFER to Phase D**. `edited_at` column is already there for when it's needed. Edit adds: edited indicator on bubble, re-delivery of body to recipient (realtime), reaction-body drift (reactions on the old text survive), and potential abuse of conversation history. The unsend path already covers the "wrong message" case. |
| OQ-5 | **Confirmed: jump-to-quoted as stretch (P2)?** | Recommendation is yes — wire the data, ship the chrome, defer reliable scroll for a follow-up. The `ScrollController` + `ItemScrollController` from `scrollable_positioned_list` is the right tool, but it is a new dependency and needs pagination awareness. |
