# Messaging — Phase A: Reliability Core (Design Spec)

- **Date:** 2026-06-08
- **Status:** Approved (design) — pending implementation plan
- **Branch:** `feat/messaging-reliability-core`
- **Author:** Ken Garcia (with Claude)

## Context

The messaging feature (`lib/features/messaging/`) is already wired end-to-end:
inbox via `get_inbox()`, live thread over Supabase realtime, send, typing
indicators, online presence, message grouping, day separators, swipe-to-archive,
and `markConversationRead`. The old `docs/SUPABASE_REALTIME_BACKEND_AUDIT.md`
note that the thread was "still mock" is **stale** — that work has since landed
(migration `20260603000001_messaging_realtime_fixes.sql`).

This spec is the first of a sequenced messaging-upgrade program. The full program
(decided 2026-06-08): **A** Reliability core → **B** Photo/file sharing → **C**
Message actions (reply/react/unsend) → **D** Inbox power + safety (block/report),
with **push notifications** and an **offline send queue** as cross-cutting work.
Each phase gets its own spec → plan → build cycle. This document covers **Phase A
only**.

## Problem

Three reliability gaps in the current thread:

1. **No optimistic send.** A sent message only appears after the realtime echo
   round-trips, so sending feels laggy and there is no failure/retry affordance.
2. **No delivery signal.** The sender cannot tell whether a message was sent or
   seen ("did they get it?"). The data exists (`*_last_read_at`) but is unused in
   the thread.
3. **No pagination.** `getMessages` loads *every* message in a conversation with
   no limit, and `watchMessages` streams the entire set. This does not scale past
   a long thread.

## Goals

- Optimistic send: an instant local bubble on send, reconciled with the server
  echo without duplicate/flickering bubbles.
- A reliable, honest status ladder: **Sending → Sent → Seen → Failed**, with
  tap-to-retry on failure.
- "Seen" rendered as the counterparty's mini-avatar under the last message they
  have read (Messenger pattern), driven by the existing `*_last_read_at`.
- Paginated history: load the latest page, fetch older pages on scroll-up, keep
  a live tail for new messages.

## Non-goals (explicitly deferred)

- Photo/file attachments (Phase B), reply/react/unsend (Phase C), inbox search /
  pin / mute / block / report (Phase D).
- Push notifications and offline send queue (cross-cutting, separate specs).
- A true **"Delivered"** state. Genuine delivery acks require the recipient's
  device to confirm receipt; Supabase provides nothing for this out of the box,
  so a real "Delivered" tick would be a guess. **Decided 2026-06-08:** ship only
  states we can know reliably (Sending/Sent/Seen/Failed).

## Decisions (locked)

| Decision | Choice |
|---|---|
| Status ladder | Sending → Sent → Seen → Failed (no fake "Delivered") |
| Seen granularity | Per-conversation (other party's `last_read_at`), not per-message read tracking — matches the 2-party model |
| Seen display | Counterparty mini-avatar under the last message they've read |
| Optimistic↔echo reconciliation | New `messages.client_tag` UUID column + dedup |
| List direction | Switch thread `ListView` to `reverse: true` |

## Architecture

### Three merged sources (per conversation)

The controller replaces today's single flat `List<Message>` with a merge of:

| Source | What it is | How it arrives |
|---|---|---|
| **Historical pages** | Older messages fetched on scroll-up | REST, paginated (`order desc limit 30`, older-than-cursor) |
| **Live tail** | The most-recent ~30 — new incoming + echoes of my sends | realtime `.stream()` (ordered, limited) |
| **Optimistic outbox** | Locally-created pending messages not yet on the server | in-memory, per conversation |

**Rendered list** = historical ⊕ live tail ⊕ outbox, **deduped by `id` (server
rows) and `client_tag` (optimistic ↔ echo match)**, sorted by `createdAt`.

The merge + dedup logic lives in a small, pure, unit-testable value object
(`thread_messages.dart`) rather than inline in the controller.

### Status is derived, not stored

`MessageStatus { sending, sent, seen, failed }` is **not** a DB column. It is
computed at render time:

- `sending` / `failed` → only ever exist for outbox entries (in-flight / errored)
- `sent` → server has the row **and** `otherLastReadAt < createdAt`
- `seen` → server has the row **and** `otherLastReadAt >= createdAt`

This keeps the domain `Message` entity pure; it only gains the real persisted
`clientTag` field. Status is a presentation concern.

## Schema change (one migration)

`supabase/migrations/<ts>_message_client_tag.sql`:

```sql
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS client_tag uuid;

-- Make retries idempotent: a re-send with the same client_tag cannot double-insert.
CREATE UNIQUE INDEX IF NOT EXISTS messages_conv_client_tag_uidx
  ON public.messages (conversation_id, client_tag) WHERE client_tag IS NOT NULL;
```

- `messages` already has `REPLICA IDENTITY FULL` (set in
  `20260603000001_messaging_realtime_fixes.sql`), so the realtime echo carries
  `client_tag`.
- "Seen" needs **no** schema change — it reads the existing
  `conversations.builder_last_read_at` / `trade_last_read_at`.
- A down-script goes in `supabase/rollbacks/` per the repo convention (down
  migrations are not auto-run forward).

## Send state machine

1. `sendMessage(body)` → generate `clientTag` (UUID v4) → push
   `PendingMessage(clientTag, body, createdAt: now, status: sending)` to the
   outbox → **instant bubble**; clear the input.
2. Insert with `client_tag`, idempotent (`upsert` / `on conflict do nothing` on
   `(conversation_id, client_tag)`), with a ~10s timeout.
3. **Success** → the realtime echo arrives carrying `client_tag`; the merge drops
   the matching outbox entry → the bubble seamlessly becomes a confirmed `sent`
   (no flicker, because dedup keys on `client_tag`).
4. **Error / timeout** → outbox entry flips to `failed` → "⚠ Couldn't send — tap
   to retry"; retry re-sends with the **same** `clientTag` (idempotent).

## "Seen" receipts

A thin per-thread subscription on the single conversation row streams the
**other** party's `last_read_at` live (RLS already lets a participant read it).
The page renders the counterparty's mini-avatar sliding under the last of *my*
messages where `otherLastReadAt >= createdAt`. The existing `markConversationRead`
(called on thread open) is what advances the other side's marker.

A dedicated per-thread conversation subscription is used (not the inbox stream),
because the thread can be opened without the inbox being loaded (e.g. from a
builder's "Message" CTA via `getOrCreateConversation`).

## Pagination

- **Initial load:** latest 30 (`order created_at desc limit 30`, reversed for
  display) + open the live-tail stream.
- **Scroll-to-top → `loadOlder`:** fetch 30 older than the current oldest
  (`lt created_at <oldest> order desc limit 30`), prepend, dedup;
  `hasMore = (returned == 30)`.
- **Live tail** via `.stream(...).order(desc).limit(30)` covers new messages +
  echoes. *(Verify Supabase `.stream()` honours `.limit()` via context7 during
  planning; fall back to an unbounded stream + client-side window if not.)*
- **`reverse: true` ListView** — index 0 = newest at the bottom — makes both
  auto-scroll-on-new and prepend-older robust without scroll-jump hacks.

## Module / file plan (+ size budget)

`message_thread_page.dart` is already **410 LOC** and `message_thread_widgets.dart`
is **373** — both near the 400 target / 500 hard ceiling. Adding status ticks,
the seen-avatar, retry UI, and pagination would breach the ceiling, so the work
**includes** splitting:

- New `thread_messages.dart` — pure merge/dedup/status-derivation value object.
- New bubble/status/seen-avatar widget file (extract from the page).
- `messaging_provider.dart` (controller, 251 LOC) gains outbox + pagination +
  seen state; keep merge logic in the value object to stay under budget.
- Data layer: `message_remote_datasource` (paged `getMessages`, `client_tag`
  insert, `watchConversation` for other-party read marker),
  `message_repository`(+impl), use cases as needed (`get_messages` gains paging
  params; new `watch_conversation` or reuse).
- Domain: `Message` gains `clientTag`; `MessageStatus` enum in presentation;
  `Conversation` entity + model gain the two `last_read_at` values so the
  per-thread conversation stream can surface the counterparty's read marker.
  `get_inbox` does **not** need to change for Phase A (the thread reads the raw
  conversation row directly).

Net effect: more, smaller, single-purpose files — consistent with the file-size
budget and clean-architecture rules.

## Testing (TDD, controller/value-object level — no live Supabase)

- Optimistic bubble appears immediately on send (`sending`).
- Echo with matching `client_tag` replaces the optimistic entry (no duplicate;
  `sending` → `sent`).
- Insert failure → `failed`; retry → `sending` → `sent`.
- Seen derivation flips a message `sent` → `seen` when `otherLastReadAt` crosses
  its `createdAt`.
- `loadOlder` prepends + dedups; `hasMore` flips to false at `< 30` returned.
- Tail + historical never produce duplicate `id`s.
- Data-source tests follow the existing pattern (override
  `messageRepositoryProvider` / mock the datasource interface).

## Risks / open questions

- **`.stream().limit()` support** — verify via context7; fallback noted above.
- **Clock skew** — `createdAt` for optimistic bubbles uses device time; the
  server row's `created_at` is authoritative and replaces it on echo, so ordering
  self-corrects within the dedup window.
- **Scroll preservation** when prepending older pages — mitigated by
  `reverse: true`; confirm during implementation.

## Out of scope reminder

Phases B/C/D, push notifications, and the offline send queue are tracked
separately and are **not** part of this spec.
