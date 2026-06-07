# Messaging — Phase D: Inbox Power + Safety (Design Spec)

- **Date:** 2026-06-08
- **Status:** Draft — pending Ken review
- **Branch:** `feat/messaging-phase-d-inbox-safety` (branch from `feat/messaging-reliability-core` or `develop`)
- **Author:** Ken Garcia (with Claude)
- **Precondition:** Phase A (reliability core — optimistic send, seen receipts, pagination) is shipped.

---

## Context

The messaging program sequence (decided 2026-06-08): **A** Reliability core → **B** Photo/file sharing → **C** Message actions (reply/react/unsend) → **D** Inbox power + safety → push notifications (cross-cutting). This spec covers **Phase D only**.

The inbox (`messages_page.dart`) already has swipe-to-archive via `flutter_slidable` with `HapticFeedback.lightImpact()`, unread badges driven by the `get_inbox()` RPC, and a live `watchConversations()` stream that re-fetches through `get_inbox` on any change. The `conversations` table already has `status` (enum: `active | archived | blocked`), `builder_archived_at` / `trade_archived_at`, and `builder_muted_until` / `trade_muted_until` (added in `20260520000004_swipe_actions.sql`).

**Note on `muted_until`:** The swipe-actions migration added `builder_muted_until` / `trade_muted_until` (temporary mute until a timestamp). Phase D extends this to a **permanent toggle** (`builder_muted_at` / `trade_muted_at`) for cleaner UX. The `*_muted_until` columns remain but are superseded for the toggle use-case; they may be used in a future "mute for X hours" flow. See Open Questions.

**Platform note:** This is a **2-party, job-scoped chat** (Builder ↔ Tradie), not group chat. Block and report have simplified semantics compared to a social network. The **admin web app is separate** — reports surface there, not in the Flutter app.

---

## Problem

1. **No search** — with 20+ conversations the inbox has no filter. Users must scroll to find a thread.
2. **No pin** — high-priority conversations (a job starting tomorrow) get buried by newer chitchat.
3. **Mute exists in DB but is not wired to any UI** — the `muted_until` columns were added in the swipe migration but no action triggers them.
4. **No mark-unread** — once a thread is opened it is always read. Users lose their "come back to this" signal.
5. **Block is missing (app-store required)** — the `status` enum already has `blocked` but nothing sets it. App-store guidelines require a user-level block mechanism.
6. **Report is missing (app-store required)** — there is no report table, no report flow, and no path to admin review.

---

## Goals

- Searchable inbox: filter in real time by counterparty name and last-message preview.
- Pin conversations to the top of the inbox with a swipe action.
- Wire the mute toggle: muted conversations stay visible in the inbox but suppress push notifications (cross-cutting with the push-notifications phase — a `muted_at` flag is the contract boundary).
- Mark-unread: restore the unread dot / bold treatment on demand.
- Block a user: prevents further messages; the existing thread freezes but is not deleted. A `blocks` table (user-level, not conversation-level) enforces this at the RLS + RPC layer.
- Report a conversation or individual message: a `reports` table; reviewed in the admin web app. An in-app sheet captures reason + optional detail.
- All six features are wired through Clean Architecture (use cases → repo → datasource) with TDD tests.

---

## Non-Goals (explicitly deferred)

- Search over message bodies (requires a full-text index or vector search — Phase D v1 is client-side name/preview filter only; a body-search RPC is noted as a follow-up).
- Push notification suppression logic (the `muted_at` flag is the contract; the push phase wires it into the Edge Function payload filter).
- Admin UI for reviewing reports (admin web app, separate scope).
- "Mute for X hours" incremental mute (the existing `muted_until` column supports this, but the v1 UI is a permanent toggle — see Open Questions).
- Unblocking from within a conversation (v1: unblock via profile page or a future account-settings page — not from the inbox).
- Bulk actions (select multiple conversations to archive/mute/block).

---

## Decisions (locked unless noted as Open Question)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D-1 | Search scope v1 | Client-side filter on `conversations` list (name + preview) | The inbox is naturally small (2-party, job-scoped — typically < 50 rows). A round-trip RPC per keystroke is unnecessary and adds latency. A body-search RPC is noted as a follow-up. |
| D-2 | Search state location | `MessagingState.searchQuery` + a derived `filteredConversations` getter | Keeps all inbox state co-located in the existing controller; no new provider needed. |
| D-3 | Pin columns | `conversations.builder_pinned_at` / `trade_pinned_at timestamptz` | Per-side, consistent with the existing `archived_at` pattern. Pinned = non-null. |
| D-4 | `get_inbox` sort order with pins | `builder_pinned_at IS NULL ASC, last_message_at DESC` (per-viewer CASE) | Pins float to the top; within the pinned and unpinned groups, recency order is preserved. |
| D-5 | Mute UX | Permanent toggle stored in new `builder_muted_at` / `trade_muted_at timestamptz` columns | The existing `muted_until` requires a future expiry — too complex for v1. The toggle is cleaner; `muted_until` is left for a future "mute 8 hours" flow. |
| D-6 | Mark-unread implementation | Set `builder_last_read_at` / `trade_last_read_at` to `NULL` and `*_unread_count` to `1` (sentinel) | Avoids a new column; `NULL` last-read-at means "treated as unread" — consistent with the existing read-receipt logic. The sentinel count of `1` is enough to restore the unread badge. |
| D-7 | Block architecture | New `public.blocks(blocker_id, blocked_id, created_at)` table + RLS guard on `messages` INSERT + `get_or_create_conversation` early-exit | User-level (not conversation-level) so a block persists across all jobs between two people, not just one thread. Conversation `status` column stays; `get_or_create_conversation` flips it to `blocked` as a durable signal for the UI ("THIS CONVERSATION IS BLOCKED"). |
| D-8 | Block visibility | Existing thread freezes (read-only) but is NOT deleted or hidden | Deleting the thread destroys the reporting context. The blocked party sees their last sent message; future sends are rejected by RLS. Both sides still see the thread in their inbox (with a "BLOCKED" status banner) until they archive it. |
| D-9 | Report target | `reports` can target a `conversation_id` (mandatory) + optionally a `message_id` | Gives admin enough context. A report without a specific message still identifies the conversation. |
| D-10 | Report review surface | Admin web app only — no in-app review UI | As per the project architecture note: "Admin is a separate web application." |
| D-11 | Swipe action grouping | `startActionPane`: pin + mark-unread (non-destructive, blue/surface tones); `endActionPane`: mute + archive (existing) + block+report via a sheet trigger (destructive, red) | Matches the mental model: left = power tools, right = removal/safety. Archive already lives on the right. |

---

## Open Questions (needs Ken)

| # | Question | Recommendation |
|---|---|---|
| OQ-1 | **Block: user-level vs conversation-level?** The spec recommends a `blocks` table (user-level), meaning a block applies across ALL jobs/threads between two users. Alternative: flip `conversations.status = blocked` (conversation-level), which scopes the block to one job thread. | **Recommend user-level (`blocks` table).** A tradie who sends harassing messages across 3 job threads shouldn't be able to re-open a new one. App-store reviewers expect user-level blocking. |
| OQ-2 | **Does blocking hide or delete the existing thread?** | **Recommend: freeze, don't delete.** Keeps the evidence trail intact for reporting. The blocker can archive their side independently after blocking. |
| OQ-3 | **Report reason taxonomy** — what categories should appear in the report sheet? | **Recommend (5 options):** `harassment`, `spam_or_scam`, `fake_profile`, `inappropriate_content`, `other`. "Other" surfaces a free-text `details` field (max 500 chars). All others are optional-detail. Keep it short — fewer options = more reports filed. |
| OQ-4 | **Search: include message bodies in v1?** | **Recommend: no.** Name + preview covers ~90% of use cases. Body search needs a `to_tsvector` index and an RPC rewrite of `get_inbox` — a separate migration. Flag as Phase D v2. |
| OQ-5 | **Mute toggle vs "mute for X hours"?** The `muted_until` column already supports timed mutes. | **Recommend: ship a permanent toggle for v1** using the new `muted_at` columns. The "mute for 8h / 24h / 1 week" sheet is a v2 feature using `muted_until`. The two columns coexist. |
| OQ-6 | **Pin limit?** Should there be a cap (e.g. max 3 pinned)? | **Recommend: no cap for v1.** The inbox is small; unlimited pins cause no UX harm. Re-evaluate if users abuse it. |

---

## Architecture

### Search (client-side)

```
MessagingState
  + searchQuery: String          // set by MessagingController.setSearchQuery()
  + filteredConversations getter // conversations where name or preview contains query (case-insensitive)
  
MessagesPage
  + _InboxSearchBar widget       // AnimatedContainer that slides down below the header; 
                                 // TextField debounced 200ms → controller.setSearchQuery()
  + list source: msgState.filteredConversations (instead of msgState.conversations)
```

`filteredConversations` is a pure getter — no async, no provider, no rebuild of unrelated state. When `searchQuery` is empty it returns `conversations` unchanged.

### Pin

- New columns on `conversations`: `builder_pinned_at timestamptz`, `trade_pinned_at timestamptz`.
- `get_inbox` ORDER BY extended: `CASE WHEN <viewer>_pinned_at IS NOT NULL THEN 0 ELSE 1 END ASC, last_message_at DESC NULLS LAST`.
- New `pinConversation(id, pin: bool)` method on `MessagingController` → repo → datasource (UPDATE `builder_pinned_at` / `trade_pinned_at`).
- Optimistic: swap the row in the in-memory list; re-fetch reconciles on next realtime event.
- UI: left `startActionPane` swipe action — `AppIcons.pushPin` (Fill when pinned), `c.info` background (`#3B82F6` blue — readable on dark; add `info` / `infoBg` token if not present). Label: `PIN` / `UNPIN`.

### Mute toggle

- New columns on `conversations`: `builder_muted_at timestamptz`, `trade_muted_at timestamptz`.
- `get_inbox` adds `builder_muted_at` / `trade_muted_at` to the result columns (so the Flutter model can read them and show a muted icon badge on the row).
- New `muteConversation(id, mute: bool)` on controller → repo → datasource.
- `Conversation` entity gains `builderMutedAt` / `tradeMutedAt` nullable fields.
- A `isMutedFor(userId)` helper on the entity (parallel to `unreadCountFor`).
- UI: right `endActionPane` — add `MUTE` / `UNMUTE` action before the existing `ARCHIVE` (left-to-right: mute | archive). `AppIcons.speakerSlash` (Fill when muted), `c.surfaceRaised` background. Label: `MUTE` / `UNMUTE`. Muted rows show a small `AppIcons.speakerSlash` glyph next to the name in the row (secondary text colour).
- **Push contract:** the push-notification Edge Function must `SELECT builder_muted_at, trade_muted_at FROM conversations WHERE id = $conv_id` and skip the push when the recipient's column is non-null. This is the only cross-phase coupling.

### Mark-unread

- No new columns. Uses existing `builder_last_read_at` / `trade_last_read_at` + `builder_unread_count` / `trade_unread_count`.
- New `markConversationUnread(id)` on controller → datasource: UPDATE sets `*_last_read_at = NULL` and `*_unread_count = 1` (sentinel).
- The inbox row re-renders as unread (bold name, orange timestamp, badge dot) because the existing `unreadCountFor(userId)` check already drives that styling.
- The realtime `watchConversations` stream will detect the update and re-fetch `get_inbox`, which re-applies the sentinel.
- UI: left `startActionPane` — second action after Pin. `AppIcons.envelope` (or `AppIcons.chatCircleDots`), `c.surfaceRaised` background. Label: `UNREAD`. (The action is always "mark unread" — if already unread, it's a no-op.)

### Block

#### Schema — `public.blocks` table

```sql
CREATE TABLE public.blocks (
  blocker_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);
```

- RLS: SELECT / INSERT / DELETE all scoped to `auth.uid() = blocker_id`.
- The blocked user can never see that they are blocked (no SELECT policy for `blocked_id`).

#### Enforcement on `messages` INSERT

The existing `messages_insert` policy is amended (or a second `WITH CHECK` expression added) to reject a send when the sender is blocked by the recipient:

```sql
-- Amended messages_insert policy WITH CHECK expression:
auth.uid() = sender_id
AND EXISTS (
  SELECT 1 FROM public.conversations c
   WHERE c.id = conversation_id
     AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
     AND c.status <> 'blocked'  -- frozen thread guard
)
AND NOT EXISTS (
  SELECT 1 FROM public.blocks b
   WHERE b.blocker_id IN (
     SELECT CASE WHEN c2.builder_id = auth.uid() THEN c2.trade_id ELSE c2.builder_id END
       FROM public.conversations c2 WHERE c2.id = conversation_id
   )
     AND b.blocked_id = auth.uid()
)
```

#### `get_or_create_conversation` guard

Add an early-exit when a `blocks` row exists between the two participants:

```sql
-- Inside get_or_create_conversation, after participant check:
IF EXISTS (
  SELECT 1 FROM public.blocks
   WHERE (blocker_id = p_builder AND blocked_id = p_trade)
      OR (blocker_id = p_trade   AND blocked_id = p_builder)
) THEN
  RAISE EXCEPTION 'user_blocked';
END IF;
```

#### Block action flow (app)

1. User swipes right → taps `BLOCK & REPORT` or a dedicated `BLOCK` action in the right pane (see UI section).
2. `showJSheet` confirmation sheet: "Block [Name]? They won't be able to message you." Two buttons: `BLOCK` (red, `c.urgent`) + `CANCEL` (surface).
3. On confirm: `blockUser(blockerId, blockedId)` → INSERT into `blocks` + UPDATE `conversations.status = 'blocked'`.
4. Optimistic: conversation row shows `ConversationStatus.blocked` banner ("CONVERSATION BLOCKED"); input is hidden in the thread.
5. The blocked user's next `sendMessage` call returns an RLS error → their thread shows a generic "message not sent" failure (they are not told they're blocked).

#### Domain: new use case `BlockUser`

```
domain/usecases/block_user.dart
  call(blockerId, blockedId, conversationId) → Future<Either<Failure, void>>
```

### Report

#### Schema — `public.reports` table

```sql
CREATE TABLE public.reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id  uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  message_id       uuid REFERENCES public.messages(id) ON DELETE SET NULL,
  reason           text NOT NULL CHECK (reason IN (
                     'harassment', 'spam_or_scam', 'fake_profile',
                     'inappropriate_content', 'other'
                   )),
  details          text CHECK (char_length(details) <= 500),
  status           text NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')),
  created_at       timestamptz NOT NULL DEFAULT now()
);
```

- RLS: INSERT scoped to `auth.uid() = reporter_id`; SELECT scoped to `auth.uid() = reporter_id` (reporter can see their own reports); no UPDATE/DELETE for users (admin updates via `service_role`).
- No realtime publication needed (admin uses the dashboard, not the mobile app).

#### Report flow (app)

1. Entry points:
   - Inbox swipe right → `REPORT` action (no block, just report).
   - Thread: long-press a message bubble → "Report message" in the context menu (Phase C adds message actions; for Phase D, expose a "Report conversation" option from the thread header `...` menu).
2. `showJSheet` reason picker: 5 radio-style choices (tight, no frills); optional `details` `TextField` appears only when "Other" is selected or when user taps "Add detail" link.
3. Submit → `reportUser(...)` use case → INSERT into `reports`. On success: brief snackbar "Report submitted. We review all reports within 48 hours." — no navigation change.
4. Reporting does NOT automatically block. The user is offered a separate "Also block this person?" prompt after submitting the report (optional, separate action).

#### Domain: new use case `ReportUser`

```
domain/usecases/report_user.dart
  call({reporterId, reportedId, conversationId, messageId?, reason, details?}) → Future<Either<Failure, void>>
```

---

## Schema SQL (exact)

### Migration 1 — `20260608000002_conversations_pin_mute.sql`

```sql
-- Per-side pin + permanent mute toggle for conversations.
-- Mirrors the existing builder_archived_at / trade_archived_at pattern.

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_pinned_at  timestamptz,
  ADD COLUMN IF NOT EXISTS trade_pinned_at    timestamptz,
  ADD COLUMN IF NOT EXISTS builder_muted_at   timestamptz,
  ADD COLUMN IF NOT EXISTS trade_muted_at     timestamptz;

-- Partial index: pinned conversations for each side (small set, fast lookup).
CREATE INDEX IF NOT EXISTS conversations_builder_pinned_idx
  ON public.conversations (builder_id, builder_pinned_at DESC)
  WHERE builder_pinned_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS conversations_trade_pinned_idx
  ON public.conversations (trade_id, trade_pinned_at DESC)
  WHERE trade_pinned_at IS NOT NULL;

-- The existing conversations_update_participant policy (added in
-- 20260520000004_swipe_actions.sql) already covers UPDATE for participants;
-- no new policy needed for these columns.
```

### Migration 2 — `20260608000003_blocks.sql`

```sql
-- User-level block table.
-- A block is symmetric in effect (neither side can send) but asymmetric in
-- storage (only the blocker's row exists). The blocked user cannot query this
-- table, so they cannot detect the block.

CREATE TABLE IF NOT EXISTS public.blocks (
  blocker_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  blocked_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE INDEX IF NOT EXISTS blocks_blocked_id_idx ON public.blocks (blocked_id);

ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "blocks_select_own"
    ON public.blocks FOR SELECT
    USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "blocks_insert_own"
    ON public.blocks FOR INSERT
    WITH CHECK (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "blocks_delete_own"
    ON public.blocks FOR DELETE
    USING (auth.uid() = blocker_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Amend messages_insert to reject sends from a blocked user.
-- Drop the old policy and recreate with the additional guard.
DROP POLICY IF EXISTS "messages_insert" ON public.messages;

DO $$ BEGIN
  CREATE POLICY "messages_insert"
    ON public.messages FOR INSERT
    WITH CHECK (
      auth.uid() = sender_id
      AND EXISTS (
        SELECT 1 FROM public.conversations c
         WHERE c.id = conversation_id
           AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
           AND c.status <> 'blocked'
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.blocks b
         WHERE b.blocked_id = auth.uid()
           AND b.blocker_id IN (
             SELECT CASE WHEN c2.builder_id = auth.uid()
                         THEN c2.trade_id
                         ELSE c2.builder_id END
               FROM public.conversations c2
              WHERE c2.id = conversation_id
           )
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Guard get_or_create_conversation against blocked pairs.
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

  -- Refuse to open/re-open a thread between blocked users.
  IF EXISTS (
    SELECT 1 FROM public.blocks
     WHERE (blocker_id = p_builder AND blocked_id = p_trade)
        OR (blocker_id = p_trade   AND blocked_id = p_builder)
  ) THEN
    RAISE EXCEPTION 'user_blocked';
  END IF;

  SELECT id INTO v_id FROM public.conversations
   WHERE builder_id = p_builder AND trade_id = p_trade
     AND ((p_job IS NULL AND job_id IS NULL) OR job_id = p_job)
   LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO public.conversations (builder_id, trade_id, job_id)
    VALUES (p_builder, p_trade, p_job)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.get_or_create_conversation(uuid, uuid, uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid, uuid) TO authenticated;
```

### Migration 3 — `20260608000004_reports.sql`

```sql
CREATE TABLE IF NOT EXISTS public.reports (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reported_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conversation_id  uuid        NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  message_id       uuid                 REFERENCES public.messages(id)      ON DELETE SET NULL,
  reason           text        NOT NULL CHECK (reason IN (
                                 'harassment', 'spam_or_scam', 'fake_profile',
                                 'inappropriate_content', 'other'
                               )),
  details          text                 CHECK (char_length(details) <= 500),
  status           text        NOT NULL DEFAULT 'pending'
                                        CHECK (status IN (
                                          'pending', 'reviewed', 'actioned', 'dismissed'
                                        )),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS reports_reporter_id_idx    ON public.reports (reporter_id);
CREATE INDEX IF NOT EXISTS reports_reported_id_idx    ON public.reports (reported_id);
CREATE INDEX IF NOT EXISTS reports_conversation_id_idx ON public.reports (conversation_id);
CREATE INDEX IF NOT EXISTS reports_status_created_idx ON public.reports (status, created_at DESC);

ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Reporters can see their own submissions.
DO $$ BEGIN
  CREATE POLICY "reports_select_own"
    ON public.reports FOR SELECT
    USING (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "reports_insert_own"
    ON public.reports FOR INSERT
    WITH CHECK (auth.uid() = reporter_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- No UPDATE / DELETE for users. Admin reviews via service_role.
```

### Migration 4 — `20260608000005_get_inbox_phase_d.sql`

Extends the current `get_inbox` (last defined in `20260604000004_get_inbox_company_name.sql`) to:
- Add `builder_pinned_at`, `trade_pinned_at`, `builder_muted_at`, `trade_muted_at` to the result columns (so the Flutter model can read them).
- Apply the per-viewer pin sort: pinned rows first, then recency.

```sql
-- 20260608000005_get_inbox_phase_d.sql
-- Extends get_inbox: adds pin/mute columns + pin-first sort order.
-- Builds on 20260604000004 (SECURITY DEFINER, company_name logic).
-- Reversible: re-run 20260604000004 definition.

CREATE OR REPLACE FUNCTION public.get_inbox(p_user uuid)
RETURNS TABLE (
  id                     uuid,
  job_id                 uuid,
  builder_id             uuid,
  trade_id               uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  status                 text,
  created_at             timestamptz,
  my_unread_count        int,
  other_display_name     text,
  other_avatar_url       text,
  job_title              text,
  -- Phase D additions
  is_pinned              boolean,
  is_muted               boolean
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                        AS my_unread_count,
         CASE
           WHEN c.builder_id <> p_user
             THEN COALESCE(NULLIF(btrim(bp.company_name), ''), other.display_name)
           ELSE other.display_name
         END                                                       AS other_display_name,
         other.avatar_url                                          AS other_avatar_url,
         j.title                                                   AS job_title,
         CASE WHEN c.builder_id = p_user THEN c.builder_pinned_at IS NOT NULL
              ELSE c.trade_pinned_at IS NOT NULL END               AS is_pinned,
         CASE WHEN c.builder_id = p_user THEN c.builder_muted_at IS NOT NULL
              ELSE c.trade_muted_at IS NOT NULL END                AS is_muted
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
    LEFT JOIN public.builder_profiles bp ON bp.id = c.builder_id
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY
     -- Pinned conversations float to the top per viewer
     CASE WHEN c.builder_id = p_user THEN (c.builder_pinned_at IS NOT NULL)::int
          ELSE (c.trade_pinned_at IS NOT NULL)::int
     END DESC,
     c.last_message_at DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;
```

---

## UI Design (Phase D — Aggressive-Flat, Jobdun tokens)

### Search bar (`_InboxSearchBar` widget)

- Lives between the header row and the conversation list.
- Collapsed by default (height = 0); a search icon button in the header triggers an `AnimatedContainer` expand (150ms `easeOut`). A second tap (or clearing the field + focus loss) collapses it.
- **Field style:** `c.surface` fill, `c.border` border (1px), `c.text3` hint "SEARCH MESSAGES", `c.text1` input text. No rounded corners (flat, consistent with the rest of the inbox).
- **Leading:** `AppIcons.magnifyingGlass` in `c.text3`.
- **Trailing:** `AppIcons.x` in `c.text3` — clears query and collapses. Only visible when `query.isNotEmpty`.
- Input type `TextInputType.text`, `textCapitalization: TextCapitalization.none`, `textInputAction: TextInputAction.search`.
- Debounce 200ms before calling `controller.setSearchQuery(value)`.
- When results are empty: full-width inline message "NO CONVERSATIONS MATCH." in `c.text3`, `tt.bodyMedium`. No Lottie animation — the search result is ephemeral, not a true empty state.
- **LOC budget:** extract as `lib/features/messaging/presentation/widgets/inbox_search_bar.dart` (~60 LOC).

### Swipe actions — revised layout

`flutter_slidable` with `HapticFeedback.lightImpact()` on every `onPressed`.

**`startActionPane` (swipe right → reveal; left side of the row):**

| Order | Action | Icon | Background | Label |
|---|---|---|---|---|
| 1 | Pin / Unpin | `AppIcons.pushPin` (Fill when pinned) | `c.info` (blue `#3B82F6` — add token if missing) | `PIN` / `UNPIN` |
| 2 | Mark Unread | `AppIcons.envelope` | `c.surfaceRaised` | `UNREAD` |

**`endActionPane` (swipe left → reveal; right side of the row — existing + new):**

| Order | Action | Icon | Background | Label |
|---|---|---|---|---|
| 1 | Mute / Unmute | `AppIcons.speakerSlash` (Fill when muted) | `c.surfaceRaised` | `MUTE` / `UNMUTE` |
| 2 | Archive | `AppIcons.archive` | `c.surfaceRaised` | `ARCHIVE` (existing) |
| 3 | Block+Report | `AppIcons.prohibit` | `c.urgent` (error red `#EF4444`) | `BLOCK` |

The `extentRatio` for each pane must grow to accommodate the extra actions: start = `0.44` (2 × 22%), end = `0.44` (3 × ~15%). Exact ratios tuned during implementation to keep labels readable.

### Muted indicator on the row

When `conv.isMutedFor(userId)` is true, a `AppIcons.speakerSlash` glyph (size 12.r, `c.text3`) is appended inline after the name text on the `_ConvoRow`. Implemented as an `if (isMuted) ...` block inside the existing `Row` — not a separate widget file (single caller, private scope).

### Pinned indicator on the row

A `AppIcons.pushPin` glyph (size 12.r, `c.action`) appears after the name when `conv.isPinnedFor(userId)` is true. Pinned rows are visually indistinguishable beyond the pin glyph — no accent border or background change (aggressive-flat principle: no decorative colour blobs).

### Block confirmation sheet

Triggered by the `BLOCK` swipe action. Uses `showJSheet` (never raw `showModalBottomSheet`).

```
┌─────────────────────────────────────────────┐
│  [c.border top handle]                      │
│                                             │
│  BLOCK [NAME]?                    [Oswald,  │
│                                   headlineS]│
│  They won't be able to send you             │
│  messages. You can still see past           │
│  messages and archive this thread.          │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  BLOCK                              │   │  ← JButton filled c.urgent
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  ALSO REPORT [NAME]                 │   │  ← JButton outlined/surface, opens report sheet
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  CANCEL                             │   │  ← JButton ghost / text-only
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

- `BLOCK` button: `JButton(label: 'BLOCK', style: JButtonStyle.danger, onPressed: ...)` — red fill, `c.onUrgent` text.
- `ALSO REPORT [NAME]` button: secondary surface style — opens the report sheet on top (or after the block sheet closes).
- `CANCEL` button: dismisses sheet, no action.
- LOC budget: `lib/features/messaging/presentation/widgets/block_confirmation_sheet.dart` (~80 LOC).

### Report sheet

Triggered from: (a) `BLOCK` sheet → "ALSO REPORT", or (b) thread header `...` menu → "Report conversation". Uses `showJSheet`.

```
┌─────────────────────────────────────────────┐
│  REPORT [NAME]                   [headlineS]│
│  ─────────────────────────────────────────  │
│  WHY ARE YOU REPORTING THIS?     [labelLg]  │
│                                             │
│  ( ) HARASSMENT                             │
│  ( ) SPAM OR SCAM                           │
│  ( ) FAKE PROFILE                           │
│  ( ) INAPPROPRIATE CONTENT                  │
│  ( ) OTHER                                  │
│                                             │
│  [details TextField — visible only when     │
│   OTHER selected, max 500 chars, optional   │
│   for others via "Add detail" link]         │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  SUBMIT REPORT                      │   │  ← JButton filled c.urgent, disabled until reason selected
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │  CANCEL                             │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

- Radio rows: full-width `GestureDetector`, `c.surface` background, `c.text1` label (Open Sans, `titleMedium`), `AppIcons.radioButton` / `AppIcons.radioButtonChecked` in `c.action` when selected.
- `SUBMIT REPORT` disabled (opacity 0.4) until a reason is selected.
- On submit: show `CircularProgressIndicator` (inline, overlay-style) while the use case runs. On success: dismiss sheet, show `ScaffoldMessenger` snackbar "REPORT SUBMITTED." (`c.success` left-border style). On error: inline error text above the button in `c.urgent`.
- LOC budget: `lib/features/messaging/presentation/widgets/report_sheet.dart` (~120 LOC).

---

## Module / File Plan + LOC Budget

All new files remain under 400 LOC target; hard ceiling 500 LOC.

| File | Status | Notes |
|---|---|---|
| `supabase/migrations/20260608000002_conversations_pin_mute.sql` | New | Pin + mute columns + partial indexes |
| `supabase/migrations/20260608000003_blocks.sql` | New | `blocks` table + RLS + amended `messages_insert` policy + `get_or_create_conversation` guard |
| `supabase/migrations/20260608000004_reports.sql` | New | `reports` table + RLS |
| `supabase/migrations/20260608000005_get_inbox_phase_d.sql` | New | Extended `get_inbox` with pin/mute columns + pin-first sort |
| `supabase/rollbacks/20260608000002_rollback.sql` | New | `ALTER TABLE … DROP COLUMN` for pin/mute columns |
| `supabase/rollbacks/20260608000003_rollback.sql` | New | `DROP TABLE blocks`, restore `messages_insert`, restore `get_or_create_conversation` |
| `supabase/rollbacks/20260608000004_rollback.sql` | New | `DROP TABLE reports` |
| `supabase/rollbacks/20260608000005_rollback.sql` | New | Re-run `20260604000004` definition |
| `lib/features/messaging/domain/entities/conversation.dart` | Modify | Add `builderPinnedAt`, `tradePinnedAt`, `builderMutedAt`, `tradeMutedAt`; add `isPinnedFor()`, `isMutedFor()` helpers |
| `lib/features/messaging/data/models/conversation_model.dart` | Modify | Parse `is_pinned`, `is_muted` from `get_inbox` row; parse raw columns in `fromJson` |
| `lib/features/messaging/domain/repositories/message_repository.dart` | Modify | Add `pinConversation`, `muteConversation`, `markConversationUnread`, `blockUser`, `reportUser` |
| `lib/features/messaging/data/datasources/message_remote_datasource.dart` | Modify | Implement five new methods (~+80 LOC; watch ceiling: currently 259 LOC → ~339 after; ok) |
| `lib/features/messaging/data/repositories/message_repository_impl.dart` | Modify | Wire five new datasource calls through `Either` |
| `lib/features/messaging/domain/usecases/block_user.dart` | New | `BlockUser(repo).call(blockerId, blockedId, conversationId)` → `Future<Either<Failure, void>>` (~30 LOC) |
| `lib/features/messaging/domain/usecases/report_user.dart` | New | `ReportUser(repo).call({...})` → `Future<Either<Failure, void>>` (~35 LOC) |
| `lib/features/messaging/domain/usecases/pin_conversation.dart` | New | `PinConversation(repo).call(id, pin, isBuilder)` (~25 LOC) |
| `lib/features/messaging/domain/usecases/mute_conversation.dart` | New | `MuteConversation(repo).call(id, mute, isBuilder)` (~25 LOC) |
| `lib/features/messaging/domain/usecases/mark_conversation_unread.dart` | New | `MarkConversationUnread(repo).call(id, isBuilder)` (~25 LOC) |
| `lib/features/messaging/presentation/providers/messaging_provider.dart` | Modify | Add `setSearchQuery`, `pinConversation`, `muteConversation`, `markConversationUnread`, `blockUser`, `reportUser` (+~80 LOC; currently 452 LOC → **~532 — CEILING BREACH RISK**; see note) |
| `lib/features/messaging/presentation/providers/inbox_safety_provider.dart` | New (if needed) | **Split target** if `messaging_provider.dart` exceeds 500 LOC after additions: extract block/report controller methods + their use-case providers into a separate `InboxSafetyController` + `inboxSafetyControllerProvider`. The two controllers share state via `ref.read`. |
| `lib/features/messaging/presentation/pages/messages_page.dart` | Modify | Add search bar toggle, revised `startActionPane`, revised `endActionPane`, pin/mute row glyphs (+~80 LOC; currently 369 LOC → ~449; within target) |
| `lib/features/messaging/presentation/widgets/inbox_search_bar.dart` | New | Animated search field (~60 LOC) |
| `lib/features/messaging/presentation/widgets/block_confirmation_sheet.dart` | New | Block confirmation + "also report" offer (~80 LOC) |
| `lib/features/messaging/presentation/widgets/report_sheet.dart` | New | Reason picker + optional detail field (~120 LOC) |
| `test/features/messaging/inbox_search_test.dart` | New | See Testing section |
| `test/features/messaging/pin_mute_test.dart` | New | See Testing section |
| `test/features/messaging/mark_unread_test.dart` | New | See Testing section |
| `test/features/messaging/block_report_test.dart` | New | See Testing section |

**`messaging_provider.dart` ceiling note:** At 452 LOC (post Phase A), adding ~80 LOC would reach ~532 LOC — over the 500 hard ceiling. The split plan is:
- Keep search, pin, mute, mark-unread in `MessagingController` (they mutate `MessagingState.conversations`).
- Extract block + report (they operate on separate tables and do not mutate `conversations` directly — they trigger a realtime refresh) into `InboxSafetyController` in `inbox_safety_provider.dart`.
- `MessagingController` remains the source of truth for `conversations`; `InboxSafetyController` calls `ref.invalidate(messagingControllerProvider)` (or a targeted refresh) after a successful block.

---

## Testing (TDD — controller and value-object level, no live Supabase)

All tests use `mocktail` to mock `MessageRepository` (or the datasource). No `ProviderScope` with real Supabase.

### `test/features/messaging/inbox_search_test.dart`

- `setSearchQuery('')` → `filteredConversations == conversations` (no filter).
- `setSearchQuery('alice')` → returns only conversations where `otherUserDisplayName` contains "alice" (case-insensitive).
- `setSearchQuery('last message')` → returns only conversations where `lastMessagePreview` contains "last message".
- Query with no matches → `filteredConversations` is empty list (not null).
- Query is debounce-state-agnostic (controller stores the final value; debounce is UI-side).

### `test/features/messaging/pin_mute_test.dart`

- `pinConversation(id, pin: true)` → optimistic: conversation moves to front of `conversations` list; `isPinnedFor(userId)` is true.
- `pinConversation(id, pin: false)` → conversation returns to recency order; `isPinnedFor` is false.
- Repo failure on pin → state rolls back to pre-optimistic order; `error` is set.
- `muteConversation(id, mute: true)` → `isMutedFor(userId)` is true on the conversation.
- `muteConversation(id, mute: false)` → `isMutedFor` is false.
- Mute does NOT affect `filteredConversations` ordering (muted conversations remain in the list — just silenced for push).

### `test/features/messaging/mark_unread_test.dart`

- `markConversationUnread(id)` → `unreadCountFor(userId)` on that conversation becomes 1 (sentinel).
- The inbox row for that conversation is returned by `filteredConversations` with `unreadCount > 0`.
- Repo failure → `error` is set; unread count does not change.

### `test/features/messaging/block_report_test.dart`

- `blockUser(blockerId, blockedId, conversationId)`:
  - Success → conversation `status` in state flips to `ConversationStatus.blocked`; `error` is null.
  - Repo failure → `error` is set; status does not change.
  - Calling `blockUser` triggers a `_refreshInbox` (verify the repo's `getConversations` is called once after).
- `reportUser({...reason: 'harassment'})`:
  - Success → returns `Right(unit)`; no state mutation (report is fire-and-forget for the controller).
  - `reason: ''` (empty) → validation in the use case returns `Left(ValidationFailure(...))` before hitting the repo.
  - Repo failure → use case propagates `Left(ServerFailure(...))`.
- `BlockUser` use case unit tests (no controller):
  - Calls `repo.blockUser` exactly once with the correct params.
  - Propagates repo failure as `Left`.
- `ReportUser` use case unit tests:
  - Rejects `reason = ''` with `ValidationFailure` before calling repo.
  - Rejects `details.length > 500` with `ValidationFailure`.
  - Calls `repo.reportUser` exactly once on valid input.

---

## Risks / Open Questions

### Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `messaging_provider.dart` LOC ceiling breach | High | Planned split into `InboxSafetyController` (see module plan); resolve during implementation |
| `messages_insert` RLS policy amend breaks existing tests | Medium | Existing test suite mocks the repo; RLS policy tests should run against a local Supabase instance |
| `get_inbox` return type change (new columns) breaks `ConversationModel.fromInboxRow` | Medium | `fromInboxRow` must be updated atomically with the migration; the `is_pinned`/`is_muted` booleans are `NOT NULL` (computed CASE) so they will never be absent |
| Blocked user UX confusion ("did it work?") | Low | App gives no confirmation to the blocked user; they see a generic send failure — per-spec and standard practice |
| `get_or_create_conversation` SECURITY DEFINER now checks `blocks` table | Low | `blocks` table is created in the same migration batch; if the table doesn't exist the function fails gracefully (raises an exception rather than silently passing) |

### Open Questions (repeated from the Decisions table for Ken's attention)

- **OQ-1 (critical):** Confirm user-level `blocks` table vs conversation-level `status=blocked`. Affects migration 3 scope.
- **OQ-2:** Confirm that the existing thread is frozen (read-only) but not deleted or hidden on block.
- **OQ-3:** Approve or amend the 5-reason report taxonomy (`harassment`, `spam_or_scam`, `fake_profile`, `inappropriate_content`, `other`).
- **OQ-4:** Confirm search v1 is name+preview only (no message body). Body search deferred to Phase D v2.
- **OQ-5:** Confirm permanent mute toggle for v1 (not "mute for X hours").
- **OQ-6:** Confirm no pin limit for v1.

---

## Out-of-Scope Reminder

Phase B (photo/file), Phase C (reply/react/unsend), push notifications (cross-cutting), offline send queue (cross-cutting), admin UI for report review (admin web app), unblock flow (future profile-settings page), body search RPC, "mute for X hours" incremental flow.
