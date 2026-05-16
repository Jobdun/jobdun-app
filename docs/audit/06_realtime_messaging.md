# Realtime & Messaging Audit — Jobdun Backend

**Auditor:** realtime-messaging-auditor
**Date:** 2026-05-16

## Scope

Supabase Realtime channel subscriptions in the Flutter app: subscription scope (per-thread vs per-user), lifecycle/leak behaviour, message pagination strategy (keyset vs offset vs unbounded), mark-as-read debouncing/batching, reconnect/backoff after rural-AU 3G flaps, poll-fallback when Realtime is down or quota-exhausted, soft-delete of messages for disputes, presence (typing/online) cost, and the cost model at 25k AU accounts on Supabase Pro with one engineer under the Privacy Act 1988.

## Files reviewed

- `docs/audit/00_SCOPE.md` (ground truth)
- `supabase/migrations/20260511000004_messaging.sql`
- `supabase/migrations/20260511000006_rls.sql` (lines 215–284, conversations/messages RLS)
- `lib/features/messaging/data/datasources/message_remote_datasource.dart`
- `lib/features/messaging/data/models/conversation_model.dart`
- `lib/features/messaging/data/models/message_model.dart`
- `lib/features/messaging/presentation/providers/messaging_provider.dart`
- `lib/features/messaging/presentation/pages/messages_page.dart`
- `lib/features/messaging/presentation/pages/message_thread_page.dart`
- `supabase/config.toml` (`[realtime]` block)
- `pubspec.yaml` (push/FCM package check)
- All 17 migrations grepped for read/unread/status/deleted_at/replica-identity/publication

## Summary

| Severity | Count |
|---|---|
| P0 | 2 |
| P1 | 4 |
| P2 | 3 |
| P3 | 1 |

**Overall: RED.**

The messaging feature does not function against the deployed schema. The data layer (`message_remote_datasource.dart`, `conversation_model.dart`) queries and writes ~8 columns plus a `profiles_public` relationship that exist in **no migration**: `conversations.status`, `conversations.builder_unread_count`, `conversations.trade_unread_count`, `conversations.last_message_preview`, `conversations.last_message_sender_id`, `conversations.builder_last_read_at`, `conversations.trade_last_read_at`, and `messages.deleted_at`. Every conversation list query and every mark-as-read write will throw a PostgREST `42703 column does not exist` at runtime. Separately, the thread UI page (`message_thread_page.dart`) is still hardwired to mock data and never calls the controller, so real-time message delivery is not wired end-to-end at all. On top of the schema mismatch, the realtime architecture has the classic cost/scale problems: full-table conversation stream with client-side filtering, no keyset pagination, no mark-as-read debounce, no reconnect backoff, no poll fallback, and no push for out-of-app delivery.

## Findings

### F-RT-01 — Messaging data layer queries 8 columns + a join that do not exist in the schema

- **Severity:** P0
- **Status:** BROKEN
- **Evidence:**
  - `lib/features/messaging/data/datasources/message_remote_datasource.dart:35` — `.neq('status', 'blocked')` and `:34` `.select('*, jobs(title)')`; `:51-52` `.eq('conversation_id', …).isFilter('deleted_at', null)`; `:86-92` writes `builder_last_read_at`/`trade_last_read_at` + `builder_unread_count`/`trade_unread_count`; `:124` `.where((r) => r['deleted_at'] == null)`.
  - `lib/features/messaging/data/models/conversation_model.dart:22` reads `json['profiles_public']`; `:33-37` reads `last_message_preview`, `last_message_sender_id`, `builder_unread_count`, `trade_unread_count`, `status`.
  - `supabase/migrations/20260511000004_messaging.sql:5-29` — `conversations` has only `id, job_id, builder_id, trade_id, last_message_at, created_at`; `messages` has only `id, conversation_id, sender_id, body, read_at, created_at`. No `status`, no unread counts, no `last_message_preview`, no `*_last_read_at`, no `messages.deleted_at`.
  - Grep of all 17 migrations: 0 hits for `builder_last_read_at|trade_last_read_at|builder_unread_count|trade_unread_count` and no `ALTER TABLE … messages ADD … deleted_at`. Confirmed by `00_SCOPE.md:88-89` ("No `deleted_at` on … `messages`").
  - There is no `profiles_public` view/table anywhere in `supabase/migrations/`.
- **Why it matters at 25k AU users:** This is not a scale issue — it is a "messaging is dead on arrival" issue. Every `getConversations()` call sends `status=neq.blocked` against a non-existent column; PostgREST returns `42703` and the repository converts it to a `ServerException`, so the inbox shows the mock fallback (`messages_page.dart:44-45`, `useReal` is never true). `markConversationRead()` writes four non-existent columns and silently fails. At 25k AU tradies who expect a builder to reply about Monday's start time, the core comms channel of the marketplace never works. One engineer will burn days chasing "why is the inbox always showing Pinnacle Construct".
- **Fix (concrete):** Add the missing schema. New migration `supabase/migrations/20260516000001_messaging_state_columns.sql`:
  ```sql
  ALTER TABLE public.conversations
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active'
      CHECK (status IN ('active','blocked','archived')),
    ADD COLUMN IF NOT EXISTS builder_unread_count int NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS trade_unread_count   int NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS builder_last_read_at timestamptz,
    ADD COLUMN IF NOT EXISTS trade_last_read_at   timestamptz,
    ADD COLUMN IF NOT EXISTS last_message_preview    text,
    ADD COLUMN IF NOT EXISTS last_message_sender_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

  ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
  ```
  Extend `update_conversation_last_message()` (migration `…000004:32-40`) to also set `last_message_preview = left(NEW.body, 140)`, `last_message_sender_id = NEW.sender_id`, and `+1` the recipient's unread count in the same trigger (atomic, server-side — see F-RT-04). Replace the `profiles_public` join: either create a `profiles_public` view exposing only `id, display_name, avatar_url` (RLS `security_invoker=on`) or change `.select()` in `getConversations` to embed the real `profiles` relationship for `builder_id`/`trade_id`. Until this lands, messaging cannot be marked working.
- **Effort:** M
- **Phase:** 0
- **Layman's:** The app's chat code is asking the database for columns that were never created, so the inbox silently breaks and always shows fake sample chats.

### F-RT-02 — Thread page is hardwired to mock data; real-time message delivery is not wired end-to-end

- **Severity:** P0
- **Status:** BROKEN
- **Evidence:** `lib/features/messaging/presentation/pages/message_thread_page.dart` is a `StatefulWidget` (not a `ConsumerWidget`), imports no provider, and renders `final allMessages = [..._mockThread, ..._localMessages]` (`:110`). `_send()` (`:82-102`) only does `setState` on a local list — it never calls `MessagingController.sendMessage`. The controller has working `loadMessages`/`_subscribeToMessages`/`watchMessages` plumbing (`messaging_provider.dart:67-90`) but **no page ever calls it**: grep shows `loadMessages`/`unsubscribeMessages` have zero call sites outside the provider.
- **Why it matters at 25k AU users:** Even after F-RT-01's schema is fixed, opening a conversation shows the same five canned "EL 123456 NSW" messages to every user, typed messages vanish on navigation, and the realtime subscription that *does* exist in the controller is never activated. There is no real chat. At marketplace scale this means builders and tradies cannot actually coordinate jobs in-app — the entire messaging value proposition is absent in the shipped UI.
- **Fix (concrete):** Rebuild `MessageThreadPage` as a `ConsumerStatefulWidget`. In `initState`, `ref.read(messagingControllerProvider.notifier).loadMessages(args.conversationId)` then `markConversationRead(...)`; in `dispose`, call `unsubscribeMessages(args.conversationId)` (the controller currently never tears a single thread sub down — see F-RT-05). Render from `ref.watch(messagingControllerProvider).messagesFor(args.conversationId)`; route `_send()` to `sendMessage`. Delete `_mockThread`/`_localMessages`. Gate the mock path in `messages_page.dart:44` behind a debug-only flag so a real empty inbox is not masked.
- **Effort:** M
- **Phase:** 0
- **Layman's:** The chat screen still shows fake demo messages and never talks to the server, so nobody can actually message anyone.

### F-RT-03 — Conversation list streams the entire `conversations` table and filters client-side

- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `message_remote_datasource.dart:100-113` — `watchConversations` does `_client.from('conversations').stream(primaryKey: ['id']).order(...).map((rows) => rows.where((r) => r['builder_id'] == userId || r['trade_id'] == userId)…)`. The Supabase Flutter `.stream()` builder only supports a single `.eq()` server-side filter; an `.or()` is not expressible, so the code subscribes to **all** conversation changes and filters in Dart.
- **Why it matters at 25k AU users:** Supabase Realtime applies RLS to broadcast rows, so a user will not *see* other people's conversations — but the client still opens a postgres-changes subscription on the whole `conversations` table and the server still evaluates RLS per change for this subscriber. With 25k accounts and a busy marketplace, every conversation insert/update anywhere fans out an RLS check against every connected inbox subscriber. At the brief's cost model (~5k MAU, inbox often open), this is the most expensive subscription in the app and scales with *global* write rate, not the user's own threads. Question 1 answer: the chat list correctly uses one inbox-scoped subscription (not one channel per thread) — that part is right — but the filter is client-side, not server-side, which is the cost problem.
- **Fix (concrete):** Make subscription scope explicit and cheap. Preferred: replace the table stream with a postgres-changes channel filtered to the two columns via two `.eq` subscriptions (one on `builder_id=eq.$uid`, one on `trade_id=eq.$uid`) on a dedicated channel, or expose a `my_conversations` security-invoker view and stream that. Then drive inbox refresh from the server-maintained `last_message_at`/unread counts (F-RT-04) so a single conversation `UPDATE` per new message refreshes the list — see F-RT-06. Add `ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations, public.messages;` in a migration so the realtime publication is explicit and reviewable (currently no publication statement exists in any migration — implicit/dashboard-managed).
- **Effort:** M
- **Phase:** 1
- **Layman's:** The inbox listens to every chat in the whole app and throws away the ones that aren't yours, which gets expensive as the user base grows.

### F-RT-04 — Mark-as-read has no debounce/batch and recomputes unread client-side

- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `messaging_provider.dart:106-115` `markConversationRead` issues one `conversations` UPDATE per call with no batching; `message_remote_datasource.dart:80-97` writes `*_last_read_at` + sets the unread count to `0` from the client. Unread totals are computed client-side in `_computeUnread` (`messaging_provider.dart:117-123`) by summing `builderUnreadCount`/`tradeUnreadCount` columns the server never increments (F-RT-01). There is no per-message `read_at` batching despite `messages.read_at` existing in the schema (`…000004:24`).
- **Why it matters at 25k AU users:** Question 3 scenario: a tradie returning from a weekend on-site opens an inbox with 12 unread threads. Today each thread open fires an independent conversation UPDATE; there is no coalescing, and because the server never increments the counts, the displayed unread badge is permanently wrong (always shows the stale value or 0). The "opening a 50-unread chat fires 50 updates" risk is latent: once F-RT-02 wires per-message `read_at`, the naive fix would be 50 row updates per thread open. Correctly designed now, this is one UPDATE per thread open with server-authoritative counts.
- **Fix (concrete):** Make unread counts server-authoritative. In the `update_conversation_last_message()` trigger, increment the *recipient's* `*_unread_count` on message INSERT. Add a `mark_conversation_read(p_conversation_id uuid)` SECURITY DEFINER RPC that, in one statement, sets the caller's `*_last_read_at = now()`, zeroes the caller's `*_unread_count`, and `UPDATE messages SET read_at = now() WHERE conversation_id = p_conversation_id AND read_at IS NULL AND sender_id <> auth.uid()` — one round-trip regardless of unread count, no client-side count math. Debounce the call in the controller with a 400 ms timer keyed by conversation so rapid open/close does not spam. Migration: `20260516000002_unread_counts_and_mark_read_rpc.sql`.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Marking chats as read is unbatched and the unread badge number is computed wrong, so the count is always stale and bulk-opening chats will hammer the database.

### F-RT-05 — Realtime subscription lifecycle leaks per-thread channels

- **Severity:** P1
- **Status:** RISKY
- **Evidence:** `messaging_provider.dart:77-90` — `_subscribeToMessages` adds a `StreamSubscription` to `_messageSubs` keyed by conversation and guards re-subscription, but `unsubscribeMessages` (`:88-90`) is **never called by any page** (F-RT-02; grep shows zero call sites). Subs are only torn down on full provider dispose (`_cancelAllSubscriptions`, `:125-131`). Because `messagingControllerProvider` is a non-autodispose `NotifierProvider` (`:21-24`), it lives for the whole app session.
- **Why it matters at 25k AU users:** Once F-RT-02 wires the thread page, a user who taps through 15 conversations in a session accumulates 15 live `messages` postgres-changes subscriptions that never close until app kill, because nothing calls `unsubscribeMessages` on screen exit. The brief's cost model (subscriber-hours/day) is driven precisely by leaked open channels. On rural-AU 3G with frequent app backgrounding, leaked channels also pile up reconnect attempts (F-RT-07). Question (lifecycle): subscribe-on-entry exists; unsubscribe-on-exit does not — this is a leak.
- **Fix (concrete):** In the rebuilt `MessageThreadPage.dispose()` (F-RT-02), call `ref.read(messagingControllerProvider.notifier).unsubscribeMessages(args.conversationId)`. Better: keep at most one active thread subscription — when `loadMessages` is called for a new conversation, cancel the previous thread sub before opening a new one (the inbox stream stays as the always-on channel). Add an assertion/log if `_messageSubs.length > 1` to catch regressions.
- **Effort:** S
- **Phase:** 1
- **Layman's:** Every chat you open opens a live server connection that is never closed until the app is killed, so they pile up and cost money.

### F-RT-06 — Inbox does not reliably refresh on a new message in a non-open thread

- **Severity:** P2
- **Status:** RISKY
- **Evidence:** `watchConversations` (`message_remote_datasource.dart:100-113`) streams the `conversations` table. A new message inserts into `messages`, and the trigger `update_conversation_last_message` (`…000004:32-45`) does `UPDATE conversations SET last_message_at = NEW.created_at`. That UPDATE *is* a realtime change on `conversations`, so in principle the inbox stream fires. But: (a) it only carries `last_message_at`, not preview/unread (those columns don't exist — F-RT-01), so the row reorders but shows no new-message indication; (b) `.stream()` requires the table to have REPLICA IDENTITY for UPDATE payloads — no `REPLICA IDENTITY FULL` / publication statement exists in any migration, so UPDATE old-record/column fidelity is dashboard-dependent and unverifiable from the repo.
- **Why it matters at 25k AU users:** Question 2: a builder messages a tradie whose inbox is open but that thread is not. The row should jump to the top with a bold unread badge. Today, at best the row reorders silently; the unread badge is driven by the broken count columns so it never lights up. Tradies will miss job offers because the inbox gives no visible signal of a new message.
- **Fix (concrete):** After F-RT-01/F-RT-04 (server-maintained `last_message_preview` + recipient unread increment in the trigger), the single conversation UPDATE per new message carries everything the inbox row needs and the existing inbox stream will correctly resurface + badge it. Add `ALTER TABLE public.conversations REPLICA IDENTITY FULL;` (or default + ensure PK in publication) and an explicit `ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;` in the F-RT-03 migration so UPDATE payloads are guaranteed and the realtime surface is code-reviewed, not console-managed.
- **Effort:** S (rides on F-RT-01/04)
- **Phase:** 1
- **Layman's:** When a message arrives in a chat you don't have open, the inbox doesn't visibly tell you — fixing the unread columns also fixes this.

### F-RT-07 — No reconnect backoff/jitter and no poll fallback for rural-AU 3G

- **Severity:** P1
- **Status:** MISSING
- **Evidence:** No reconnect, backoff, jitter, retry-count, or polling-fallback logic anywhere in `lib/features/messaging/`. The controller's stream `onError` handlers (`messaging_provider.dart:64`, `:85`) only write `state.error` and never re-subscribe or degrade. No use of `connectivity_plus` (in `pubspec.yaml` per CLAUDE.md) in the messaging feature. `supabase/config.toml` `[realtime]` block is local-dev defaults only; production realtime quota behaviour is not handled in-app. There is no "after N failed joins, switch to `getMessages` polling" path.
- **Why it matters at 25k AU users:** The brief explicitly calls out rural-AU 3G that flaps. The Supabase Realtime client auto-reconnects, but a flapping link plus the leaked per-thread channels (F-RT-05) produces a reconnect storm: many channels each retrying without jittered backoff hammer the socket on a marginal link, draining battery and worsening the outage. If Realtime is down or the project hits its concurrent-connection quota at scale, there is no fallback — chat simply stops with a red error string and never recovers without an app restart. For a marketplace where a missed "can you start Monday?" loses a job, silent permanent chat failure on bad reception is a P1.
- **Fix (concrete):** Add a `RealtimeHealth` wrapper in `lib/features/messaging/data/`: subscribe to channel state callbacks, on `CHANNEL_ERROR`/`TIMED_OUT`/`CLOSED` retry with exponential backoff + full jitter (`min(maxDelay, base * 2^attempt) * random(0.5,1.0)`, cap ~30 s). After 3 consecutive failed joins, flip the conversation/thread providers to a polling source that calls `getConversations`/`getMessages` every 15–30 s (keyset, F-RT-08) until a join succeeds, then resume realtime. Listen to `connectivity_plus` to pause retries while offline and trigger one immediate join on reconnect. Surface a non-blocking "reconnecting…" banner instead of the dead red error.
- **Effort:** L
- **Phase:** 1
- **Layman's:** On bad rural reception the chat just dies with no retry strategy and no offline fallback, so a flaky signal permanently breaks messaging until the app is restarted.

### F-RT-08 — Message history is fetched unbounded with no keyset pagination

- **Severity:** P2
- **Status:** MISSING
- **Evidence:** `message_remote_datasource.dart:46-60` `getMessages` does `.eq('conversation_id', id).isFilter('deleted_at', null).order('created_at')` with **no `.limit()` and no range/cursor**; it loads the entire thread. `watchMessages` (`:116-128`) likewise streams all rows for the conversation. No `created_at,id` keyset cursor anywhere. The only index is single-column `messages_conversation_id_idx` (`…000004:28`); there is **no `(conversation_id, created_at)` / `(conversation_id, created_at DESC, id)` composite** (confirmed `00_SCOPE.md:137`).
- **Why it matters at 25k AU users:** Question 7: at 200k+ messages, an active builder↔tradie thread can hold thousands of rows. `getMessages` pulls the whole thread into memory on every open over rural 3G, and Postgres must filter `conversation_id` then sort `created_at` with no index support for the ordering — a per-open seq-ish sort that gets slower as the table grows. The realtime stream replays the full history too. This degrades exactly as message volume scales (the brief's 200k+ target).
- **Fix (concrete):** Add composite index in migration `20260516000003_messages_keyset_index.sql`:
  ```sql
  CREATE INDEX IF NOT EXISTS messages_conversation_created_id_idx
    ON public.messages (conversation_id, created_at DESC, id DESC);
  ```
  (Optionally `WHERE deleted_at IS NULL` as a partial index once F-RT-09 lands.) Change `getMessages` to keyset pagination: newest page `… .order('created_at', ascending:false).order('id', ascending:false).limit(30)`; older pages `.lt('created_at', cursorTs)` (with `id` tiebreak) — never `.range()`/offset. Keep the realtime stream scoped to messages newer than the loaded window so it does not replay full history.
- **Effort:** M
- **Phase:** 1
- **Layman's:** Opening a chat downloads the entire message history every time with no index to sort it, which gets slow and data-heavy as chats grow.

### F-RT-09 — Message soft-delete (disputes) referenced in code but absent from schema and RLS

- **Severity:** P2
- **Status:** BROKEN
- **Evidence:** `message_remote_datasource.dart:52` `.isFilter('deleted_at', null)` and `:124` `.where((r) => r['deleted_at'] == null)` both assume a `messages.deleted_at`. No such column exists (`…000004:19-26`; `00_SCOPE.md:88-89`). RLS `messages_select` (`…000006:246-256`) has no `deleted_at IS NULL` clause and there is no UPDATE policy permitting a soft-delete (`messages_update_read` only covers read state). So: the filter throws today (part of F-RT-01), and even once the column is added, deletion is enforced only by a client-side `.where()` — a soft-deleted message would still be returned by the realtime stream and any direct query, and there is no policy controlling *who* may set `deleted_at` (disputes/moderation).
- **Why it matters at 25k AU users:** For an AU marketplace, disputes and moderation will require hiding abusive/erroneous messages while retaining them for the record (Privacy Act 1988 — you generally must not silently destroy records that may be subject to a complaint, but you also must not keep displaying harmful content). Relying on a client-side filter means a soft-deleted message is still broadcast over Realtime to the other party's open thread and is fully readable by anyone bypassing the app. That is a data-integrity and trust-and-safety hole at scale.
- **Fix (concrete):** Add `messages.deleted_at` (in the F-RT-01 migration). Enforce in RLS, not the client: replace `messages_select` USING with `… AND deleted_at IS NULL` for normal members, and add a separate moderator/admin path if required. Add a constrained UPDATE policy so only an authorised actor (or a SECURITY DEFINER `soft_delete_message(p_id uuid, p_reason text)` RPC) can set `deleted_at`. Keep the client `.isFilter`/`.where` as defence-in-depth but treat RLS as the source of truth so the realtime stream cannot leak deleted content. Document a retention rule (how long soft-deleted dispute messages are kept before purge) — currently none exists (`00_SCOPE.md:84`).
- **Effort:** M
- **Phase:** 2
- **Layman's:** The code tries to hide deleted messages but the database has no concept of a deleted message and no rule for who can delete one, so deleted content would still leak over the live feed.

### F-RT-10 — No presence (typing/online) — correctly deferred, but document the decision and the cost ceiling

- **Severity:** P3
- **Status:** PASS-WITH-NOTE
- **Evidence:** No `RealtimeChannel` presence (`track`/`presenceState`) or broadcast usage anywhere in `lib/features/messaging/`. The thread header shows a static avatar with no online/typing indicator (`message_thread_page.dart:146-171`).
- **Why it matters at 25k AU users:** This is the *right* default for MVP. Presence is a multiplicative cost: typing/online broadcasts run at keystroke/heartbeat frequency and, at the brief's ~180k subscriber-hours/day model, presence would dominate Realtime spend for marginal product value to a tradie deciding whether to take a job. Flagging only so it is a conscious, documented deferral rather than an accidental omission someone "fixes" later without modelling cost.
- **Fix (concrete):** No code change. Record in messaging design docs: "Presence (typing/online) intentionally deferred until post-PMF; revisit only with a per-region cost model and ideally throttled broadcast, not per-keystroke." Revisit alongside F-RT-07's connection budget.
- **Effort:** XS
- **Phase:** 3
- **Layman's:** There's no "typing…"/online dot — that's the correct cheap choice for now; just write the decision down so nobody adds it blindly later.

### F-RT-11 — No push notifications: out-of-app message delivery is impossible (Realtime is in-app only)

- **Severity:** P0
- **Status:** MISSING
- **Evidence:** No `firebase_messaging` / `flutter_local_notifications` / OneSignal / any push package in `pubspec.yaml` (grep: "NO push packages in pubspec"). No `send-push` Edge Function (`00_SCOPE.md:92` lists it MISSING; `supabase/functions/` does not exist per `00_SCOPE.md:33`). Supabase Realtime only delivers while the app is foregrounded with a live socket.
- **Why it matters at 25k AU users:** A tradie on-site does not sit in the Jobdun inbox. A builder messages "can you start Monday 7am, Surry Hills?"; with Realtime-only there is **zero delivery** unless the tradie happens to have the app open. For a job marketplace this is a P0 product/operational failure: time-sensitive hiring messages are silently undelivered, jobs are lost, and the marketplace's core loop breaks at any scale. Realtime is explicitly in-app only — push is the out-of-app channel and it does not exist.
- **Fix (concrete):** Add `firebase_messaging` (Android/iOS) + token storage (`profiles.fcm_tokens text[]` or a `device_tokens` table with RLS). Create a `send-push` Edge Function triggered by a DB webhook on `messages` INSERT (or pg_net from the `update_conversation_last_message` trigger) that looks up the recipient's tokens and sends an FCM data+notification payload with the conversation deep-link. Respect a quiet-hours/notification-preference column for Privacy/UX. This is a cross-cutting dependency with the edge-functions audit (no functions exist yet). Track as a Phase-0/1 blocker for any messaging GA.
- **Effort:** L
- **Phase:** 1
- **Layman's:** If the app isn't open the user never finds out they got a message, because there are no push notifications at all — so urgent job messages just don't arrive.

## Cross-cutting recommendations

1. **Schema-first unblock (Phase 0):** F-RT-01 + F-RT-02 + F-RT-11 are hard blockers — messaging is non-functional and undeliverable today. One migration (`20260516000001_messaging_state_columns.sql`) plus rebuilding `MessageThreadPage` plus a push path are prerequisites for any "messaging works" claim.
2. **Make the server authoritative for state.** Unread counts, last-message preview/sender, and read state must be maintained in the `update_conversation_last_message` trigger and a `mark_conversation_read` RPC — never computed/zeroed client-side. This collapses F-RT-04/F-RT-06 into one cheap conversation UPDATE per message.
3. **One always-on inbox channel + one transient thread channel.** Inbox subscription scoped server-side (F-RT-03), thread subscription opened on entry and closed on exit (F-RT-05). Cap concurrent message subscriptions at 1. This is the single biggest lever on the brief's subscriber-hour cost model.
4. **Resilience layer (F-RT-07):** exponential backoff + full jitter, `connectivity_plus`-driven pause/resume, and a 3-failed-join → polling fallback are mandatory for rural-AU 3G; without them a flaky signal permanently kills chat.
5. **Keyset everywhere (F-RT-08):** composite `(conversation_id, created_at DESC, id DESC)` index + cursor pagination; ban `.range()`/offset in messaging. Aligns with the performance-audit's "no keyset primitives" finding.
6. **Make the Realtime surface code-reviewed:** add explicit `ALTER PUBLICATION supabase_realtime ADD TABLE …` and `REPLICA IDENTITY` statements in migrations. Today the realtime publication is implicit/console-managed and cannot be audited from the repo.
7. **Trust-and-safety enforcement in RLS, not the client (F-RT-09):** soft-delete and conversation `status='blocked'` must be enforced by policy so deleted/blocked content cannot leak over the realtime stream; pair with a documented retention rule for Privacy Act 1988.

## Open questions for Ken

1. Was a `messaging_state_columns` / `profiles_public` migration written and lost, or did the data layer get ahead of the schema? (Determines whether F-RT-01 is "restore" vs "design from scratch".)
2. Push provider preference — FCM (free, needs APNs config for iOS) vs a paid provider (OneSignal)? Affects F-RT-11 effort and the edge-functions audit.
3. Confirm the Supabase project's Realtime publication and `REPLICA IDENTITY` settings in the dashboard (not determinable from the repo) so F-RT-06's inbox-refresh behaviour can be verified rather than assumed.
4. Dispute/moderation message retention: how long must soft-deleted messages be retained before purge, and who (admin web app role?) is authorised to soft-delete? Needed to finalise F-RT-09 RLS.
5. Confirm Supabase region is `ap-southeast-2` (Sydney) — shared with storage-privacy audit; affects whether message content/realtime traffic stays onshore (APP 8).
