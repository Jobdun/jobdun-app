# Supabase + Realtime Backend Audit

**Date:** 2026-06-03
**Branch:** `fix/core-job-loop`
**Author:** Senior architecture review (Claude)
**Scope:** Is the *real* (non-mock) backend actually wired and working end-to-end — data layer, Supabase schema/RLS, and **realtime** — for Home (jobs), Messaging (inbox + thread), Notifications, and Verification?
**Method:** Read the Dart data layer (datasources / repos / use cases / controllers), all 47 SQL migrations, and RLS policies; cross-checked the realtime requirement against Supabase's official docs (publication + replica identity).

---

## TL;DR — the verdict

> **The code is wired far better than the UI suggests, but the *real setup is NOT working end-to-end yet.* Three things block it: (1) realtime is not enabled at the database level for ANY table, (2) the app has no way to *create* a conversation, and (3) one query (`markConversationRead`) targets columns that don't exist and will throw.**

- ✅ **Jobs** read real data today (one-shot loads). The feed works.
- 🟠 **Messaging** has a *complete* data layer + controller (load / send / archive / realtime-subscribe all implemented and Supabase-backed) — but it can't function end-to-end because **no conversation is ever created** and the **thread screen is still a mock**.
- 🔴 **Realtime** (live updates) is dead for all 4 features that use it, because the tables were never added to the `supabase_realtime` publication.
- Several smaller bugs (below) will surface the moment the thread screen is wired.

**You are NOT far away.** The data layer is the hard part and it's done. The remaining work is one DB migration, one "start conversation" entry point, a query fix, and connecting the thread UI.

---

## Feature readiness matrix

| Feature | Tables | Data layer | Controller wired | UI reads real data | Realtime live-updates | End-to-end working? |
|---|---|---|---|---|---|---|
| **Jobs feed (home + `/jobs`)** | ✅ | ✅ | ✅ `loadFeed()` | ✅ (mock is just a fallback) | 🔴 stream defined, **publication missing** | ⚠️ Works on load/refresh; no live updates |
| **Home map pins** | ✅ | ✅ | ✅ same controller | ✅ | 🔴 (same) | ⚠️ Works on load |
| **Messaging — inbox list** | ✅ | ✅ | ✅ `loadConversations()` | ✅ (mock fallback) | 🔴 publication missing | 🔴 No conversations exist to list (see F-1) |
| **Messaging — thread** | ✅ | ✅ `getMessages`/`sendMessage`/`watchMessages` | ✅ on controller | 🔴 **page ignores controller, renders `_mockThread`** | 🔴 publication missing | 🔴 Mock only; send doesn't persist |
| **Notifications** | ✅ | ✅ | ✅ | ✅ | 🔴 publication missing | ⚠️ Loads; no live updates |
| **Verification status** | ✅ | ✅ | ✅ | ✅ | 🔴 publication missing | ⚠️ Loads; no live status push |
| **Builder "Available now" tradies** | ❌ none | ❌ no query exists | ❌ | ❌ pure mock | — | 🔴 No backend at all (you chose to hide it) |

---

## Findings by severity

### 🔴 CRITICAL — blocks "real setup working"

#### F-1. There is no way to *create* a conversation
**Evidence:** No `conversations` INSERT exists anywhere in `lib/` (only the RLS *policy* that would permit one — `20260511000006_rls.sql:231`). No trigger or RPC auto-creates a conversation when an application is submitted/shortlisted/accepted (`20260511000003_applications.sql` has none). The only conversation-related function in the schema is `update_conversation_last_message()` (a message-insert trigger).

**Impact:** Even with everything else perfect, **a user can never start a chat from the app.** The inbox will always be empty in real use; the thread has nothing to open. Messaging is unreachable end-to-end.

**Fix (decision needed — where does a chat begin?):** Add a `getOrCreateConversation(jobId, builderId, tradeId)` repo method (upsert honoring the unique indexes `conversations_uniq_with_job` / `conversations_uniq_no_job` from `20260516000001`), and a **"Message" entry point** in the UI. Natural options:
- Builder taps "Message" on an **applicant card** (`/applications` incoming view), or
- Conversation auto-created when a builder **shortlists/accepts** an application (DB trigger on `applications.status` change), or
- Tradie taps "Message builder" on **job detail** after applying.

This is the single biggest remaining piece of *new* work.

#### F-2. Realtime is not enabled at the database level (app-wide)
**Evidence:** Five `.stream()` subscriptions exist —
`jobs` (`job_remote_datasource.dart:140`), `messages` & `conversations` (`message_remote_datasource.dart:129,155`), `notifications` (`notification_remote_datasource.dart:62`), `verification_documents` (`verification_remote_datasource.dart:131`) — but **no migration runs `ALTER PUBLICATION supabase_realtime ADD TABLE …`** and **no table is set to `REPLICA IDENTITY FULL`**. (Migration comments reference "F-RT" realtime tasks as *planned*, but the publication step was never committed.)

**Grounded in Supabase docs (Context7):** Postgres Changes / `.stream()` only deliver events for tables that are members of the `supabase_realtime` publication; `REPLICA IDENTITY FULL` is the recommended setting so RLS-scoped UPDATE/DELETE events carry the old row. Without the publication, subscriptions connect but receive **zero** change events.

**Impact:** No live updates anywhere — new messages don't appear without a manual reload, the inbox doesn't reorder, notification badges don't move, verification status doesn't push. Initial loads still work for features that fetch via REST first (messaging, jobs), so this is "stale until refresh," not "blank" — **except** any consumer that relies on the stream for its *first* paint.

**Fix:** One migration (see Appendix A) adds the 4–5 tables to the publication and sets replica identity. Then toggle is durable in source control, not Dashboard-only.

#### F-3. The message thread screen is not connected to the backend
**Evidence:** `message_thread_page.dart` is a plain `StatefulWidget` (not a `ConsumerStatefulWidget`). It prepends `_mockThread` (line 33) to a local `_localMessages` list (line 73); `_send()` (line 82) only appends locally and **never calls `sendMessage`**. It never calls `loadMessages`, never reads `messagesFor(...)`, never subscribes.

**Impact:** The whole messaging controller (`loadMessages`, `sendMessage`, realtime `watchMessages`, `markConversationRead`) is implemented and Supabase-backed — and **completely unused**. The thread shows fake history and silently drops anything you type.

**Fix:** Rewrite the page as a `ConsumerStatefulWidget`: `loadMessages(id)` + `markConversationRead(id)` on open, render `messagesFor(id)` (`isMine = senderId == currentUserId`, time from `createdAt`), `sendMessage(...)` on send, `unsubscribeMessages(id)` on dispose. **No new backend needed — only wiring.** (This is the task we paused.)

---

### 🟠 HIGH — real bugs that throw or show wrong data once messaging is live

#### F-4. `markConversationRead` targets columns that don't exist
**Evidence:** `message_remote_datasource.dart:90-107` runs
`UPDATE conversations SET builder_last_read_at = …` / `trade_last_read_at = …`.
**Neither column exists in any migration** (`grep last_read_at supabase/migrations` → nothing). The `*_unread_count` columns exist (`20260516000001:80-81`); the `*_last_read_at` columns were never added.

**Impact:** The moment the thread screen calls `markConversationRead` (which it should, on open), Postgres returns **`column "builder_last_read_at" does not exist`** and the call fails.

**Fix:** Either add `builder_last_read_at` / `trade_last_read_at timestamptz` to `conversations` (Appendix A), or drop them from the UPDATE and only reset the unread counter. Recommend adding the columns — they're the natural "read receipt" anchor.

#### F-5. The inbox can't show who you're talking to
**Evidence:** `ConversationModel.fromJson` reads `json['profiles_public']` for the counterparty name/avatar (`conversation_model.dart:22,39-40`), but `getConversations` selects only `'*, jobs(title)'` (`message_remote_datasource.dart:38`) — **`profiles_public` is never joined.** The `profiles_public` view *does* exist (`20260516000001:101`), it's just not used. Also, a conversation has *both* `builder_id` and `trade_id`; resolving "the other person" depends on the viewer's role, which a single static embed can't express.

**Impact:** `otherUserDisplayName` / `otherUserAvatarUrl` are always null → every inbox row renders **"Unknown" / "?"**.

**Fix:** Either (a) embed both participants and pick the other side client-side, or (b) — cleaner — back the inbox with a **DB view or RPC** that returns rows already shaped for the viewer (counterparty name/avatar, preview, unread-for-me). Option (b) also fixes F-6 cleanly.

#### F-6. Inbox preview + unread counters are never maintained
**Evidence:** The only message-insert trigger, `update_conversation_last_message()` (`20260511000004:32-45`), sets **`last_message_at` only**. It does not set `last_message_preview` / `last_message_sender_id` (columns added in `20260516000001:82-83`) and does not increment `builder_unread_count` / `trade_unread_count`.

**Impact:** Inbox previews are always blank; unread badges never rise. `_computeUnread()` (`messaging_provider.dart:173`) sums columns that stay at 0.

**Fix:** Extend the trigger to also set preview + sender and `+1` the *recipient's* unread counter (Appendix A).

---

### 🟡 MEDIUM / context (not blockers)

- **F-7. Builder "Available now" has no backend.** No `trade_profiles` search/nearby query exists. You chose to **hide** the section — correct for now. A real version is a separate feature (availability + geo-radius query).
- **F-8. Jobs realtime is optional by design.** A job board is fine on pull-to-refresh; live job streaming is a nice-to-have, not a correctness issue. (It's still subject to F-2 if you want it live.)

---

## What's already solid (don't touch)

- **Schema:** `conversations` / `messages` tables, FKs, indexes are correct. `20260516000001_schema_reconciliation.sql` already closed the earlier column drift (`messages.deleted_at`/`edited_at`, `conversations.status`/`*_unread_count`/`last_message_preview`/`last_message_sender_id`).
- **RLS:** Messaging policies are correct and participant-scoped — `conversations` select/insert (`rls.sql:216-239`), `messages` select/insert/update (`rls.sql:241-281`), plus the `conversations_update_participant` policy from `20260520000004`. RLS will correctly gate realtime too once the publication is on.
- **Data layer + controller:** `MessagingController` (`messaging_provider.dart:52-188`) fully implements load/send/archive/realtime-subscribe through use cases → repo → Supabase. Repo/datasource providers are public and override-friendly (good for tests). This is the expensive part and it's done well.
- **Jobs / applications / profile** data layers are wired and read real data.

---

## Recommended next steps — in order

> Ordered so each step unblocks the next. Steps 1–2 are mine to implement; step 3 needs **one product decision from you** (where chat begins).

1. **DB migration — make the backend correct** (Appendix A, one new file):
   - Add `messages`, `conversations`, `notifications`, `verification_documents` (and optionally `jobs`) to `supabase_realtime`; set `REPLICA IDENTITY FULL`. → fixes **F-2**.
   - Add `conversations.builder_last_read_at` / `trade_last_read_at`. → fixes **F-4**.
   - Rewrite `update_conversation_last_message()` to also set preview/sender + increment recipient unread. → fixes **F-6**.
2. **Wire the message thread page** to the existing controller (**F-3**). Add a widget test (loads on open, sends through the controller). No backend changes.
3. **Add a "start conversation" entry point** (**F-1**) — *your call on placement* (applicant card "Message", or auto-create on shortlist/accept, or job-detail "Message builder"). I'll add `getOrCreateConversation` + the CTA once you pick.
4. **Fix the inbox counterparty query** (**F-5**) — embed both participants or add an inbox view/RPC.
5. **Then remove the mock** (the original task): `_mockJobs` / `_sampleJobsAround` / `_mockConvos` / `_mockThread`, hide builder "Available now", fall back to real empty states.

**If you only want to manually test what exists right now,** see Appendix B — you can seed a conversation + messages by hand and (after step 1's publication change) watch it work, even before step 3 gives the app its own "start chat" button.

---

## Appendix A — corrective migration (proposed `20260603000001_messaging_realtime_fixes.sql`)

```sql
-- 1. F-4: read-receipt columns the datasource already writes
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS builder_last_read_at timestamptz,
  ADD COLUMN IF NOT EXISTS trade_last_read_at   timestamptz;

-- 2. F-6: maintain preview + unread on every new message
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
-- trigger from 20260511000004 already calls this AFTER INSERT — no re-create needed.

-- 3. F-2: enable realtime delivery (publication + old-row identity for RLS)
ALTER TABLE public.messages              REPLICA IDENTITY FULL;
ALTER TABLE public.conversations         REPLICA IDENTITY FULL;
ALTER TABLE public.notifications         REPLICA IDENTITY FULL;
ALTER TABLE public.verification_documents REPLICA IDENTITY FULL;

ALTER PUBLICATION supabase_realtime ADD TABLE
  public.messages,
  public.conversations,
  public.notifications,
  public.verification_documents;
  -- add public.jobs here too if you want a live job feed (F-8).
```

> Note: `ALTER PUBLICATION … ADD TABLE` errors if a table is already a member. If realtime was ever toggled on in the Dashboard, wrap each add in a `DO $$ … EXCEPTION WHEN duplicate_object THEN NULL; END $$;` guard, matching this repo's idempotent-migration style.

## Appendix B — seed real data to test *right now*

Run in the Supabase SQL editor (replace the UUIDs). This lets you verify the inbox + (once F-3 is wired) the thread against real rows before the app can originate chats itself:

```sql
-- Use YOUR builder profile id + any trade profile id (both must exist in profiles)
insert into public.conversations (job_id, builder_id, trade_id)
values (null, '<YOUR_BUILDER_PROFILE_ID>', '<A_TRADE_PROFILE_ID>')
returning id;  -- note the conversation id

insert into public.messages (conversation_id, sender_id, body) values
  ('<CONVERSATION_ID>', '<A_TRADE_PROFILE_ID>',   'Hi, I saw your job and I''m keen.'),
  ('<CONVERSATION_ID>', '<YOUR_BUILDER_PROFILE_ID>', 'Great — can you start Monday 7am?');
```

After Appendix A's migration, watch a second message inserted from SQL appear live in the open thread (realtime working), and confirm the inbox preview + unread badge update (trigger working).

---

*Generated as part of the "wire the real backend before removing mock data" review. Findings reference exact `file:line` and migration ids so each is independently verifiable.*
