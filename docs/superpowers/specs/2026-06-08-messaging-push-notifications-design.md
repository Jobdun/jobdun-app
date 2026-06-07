# Messaging — Push Notifications (Design Spec)

- **Date:** 2026-06-08
- **Status:** Draft — pending Ken's review of open questions
- **Branch:** `feat/messaging-push-notifications` (to be cut from `feat/messaging-reliability-core`)
- **Author:** Ken Garcia (with Claude)
- **Phase:** Cross-cutting — part of the messaging-upgrade program alongside Phase A (Reliability Core)

---

## Context

The messaging feature is end-to-end functional (Phase A shipped): inbox via
`get_inbox()`, live thread over Supabase Realtime, optimistic send with
`client_tag` dedup, "Seen" receipts, and pagination. The single most impactful
real-world gap remaining: **when the app is backgrounded, the recipient gets no
notification of a new message**. A message sent while the other party isn't
looking is silently unacknowledged until they next open the app.

Firebase is already in the project for Android test distribution
(`firebase appdistribution:distribute` in `scripts/ship-to-boss.sh`, project
`jobdun-627d2`). No new Firebase project is required for FCM — the same project
provides an FCM sender key.

The `notifications` table already exists (schema in
`supabase/migrations/20260511000005_social.sql`), has RLS, is in the realtime
publication, and already carries a `new_message` type in the client-side enum.
The `NotificationType.newMessage` value and `NotificationModel` are already wired
in `lib/features/notifications/`.

---

## Problem

1. **No device token registry.** There is nowhere to store FCM tokens per user per
   device.
2. **No server-side send path.** Nothing calls FCM when a message is inserted.
3. **No client FCM integration.** `firebase_messaging` is not a dependency; the
   app does not request `POST_NOTIFICATIONS` permission (Android 13+) or handle
   incoming FCM payloads.
4. **No deep link from notification tap.** Tapping a hypothetical notification
   would not open `/messages/:conversationId`.

---

## Goals

- A device-token registry table with RLS; register on login, refresh on rotation,
  delete on logout.
- On every `messages` INSERT, send a push notification to the recipient's active
  devices via FCM HTTP v1, skipping when: recipient has the thread open / is
  online, or has already read beyond that message, or has muted the conversation.
- Android (FCM) first. iOS deferred (see Prerequisites below).
- Android 13+ `POST_NOTIFICATIONS` runtime permission with a custom in-app
  priming sheet that explains the value before the OS prompt fires.
- Foreground and background FCM payload handling in the Flutter client.
- Tapping a notification deep-links to `/messages/:conversationId` via GoRouter.
- Message body preview in the notification (opt-in default; configurable in a
  future "hide preview" setting).
- FCM service-account key stored only in Edge Function secrets — never in the app
  or in source control.

---

## Non-goals (explicitly deferred)

- iOS APNs integration — requires an Apple Developer account, APNs certificate,
  and a bundle-ID rename. Documented as prerequisites; not designed here.
- Quiet-hours / do-not-disturb. Recommended defer to v2 (see Open Questions).
- Per-message delivery receipts at the FCM layer.
- Notification grouping / summary ("3 new messages from Brendan").
- Admin-triggered broadcast notifications.
- Email / SMS fallback.

---

## Decisions (locked)

| # | Decision | Choice | Rationale |
|---|---|---|---|
| D-1 | FCM project | Reuse `jobdun-627d2` | Already exists, saves a new Firebase project, can be confirmed by Ken (see OQ-1) |
| D-2 | Send path | DB trigger → Supabase Edge Function → FCM HTTP v1 | Keeps send logic server-side; no pg_net HTTPS call from within the trigger itself (trigger calls a helper that enqueues/invokes the function) |
| D-3 | Trigger mechanism | `pg_net.http_post` from inside an `AFTER INSERT` trigger function | pg_net is available on all Supabase projects and is the canonical lightweight way to call an Edge Function from a DB trigger; avoids polling/queue infra |
| D-4 | Token storage | New `device_tokens` table, not the `notifications` table | `notifications` is per-event, not per-device; mixing concerns would break RLS reasoning |
| D-5 | Skip logic location | Edge Function, not DB trigger | DB triggers should be thin; skip rules (online, read-ahead, mute) require JOINs best done in TypeScript where they can be unit-tested |
| D-6 | Notification content | Sender display name + first 140 chars of body | Matches `last_message_preview` pattern already used in inbox |
| D-7 | Preview default | Show preview by default | Tradies expect SMS-like previews; a "hide preview" toggle is the future escape hatch |
| D-8 | in-app notification row | Insert a row into `notifications` on send | Gives the in-app bell a record of the event, consistent with existing types |
| D-9 | Android permission timing | Prime before opening `/messages` the first time AND after the user sends their first message | Two natural moments of high motivation — not on cold start |

---

## Architecture

### Overview

```
Flutter client
  └─ sendMessage()
       └─ messages.upsert(...)
            └─ DB trigger: notify_message_push()
                 └─ pg_net.http_post → Edge Function: send-message-push
                       ├─ resolve recipient from conversations
                       ├─ check online/read/mute guards
                       ├─ SELECT device_tokens WHERE user_id = recipient
                       ├─ POST → FCM HTTP v1 (per token, batched)
                       ├─ INSERT notifications row (type=new_message)
                       └─ return 200

FCM → Android device
  └─ FirebaseMessagingService (background handler)
       └─ GoRouter.go('/messages/:conversationId')
```

### Trigger → Edge Function → FCM data flow (detailed)

```
1. INSERT INTO messages (conversation_id, sender_id, body, client_tag, ...)

2. AFTER INSERT trigger: notify_message_push()
   - Reads NEW.conversation_id, NEW.sender_id, NEW.id, NEW.body
   - Resolves recipient_id:
       SELECT (CASE WHEN builder_id = NEW.sender_id THEN trade_id ELSE builder_id END)
       FROM conversations WHERE id = NEW.conversation_id
   - Calls pg_net.http_post(
       url  => '<SUPABASE_URL>/functions/v1/send-message-push',
       body => json_build_object(
                 'message_id',       NEW.id,
                 'conversation_id',  NEW.conversation_id,
                 'sender_id',        NEW.sender_id,
                 'recipient_id',     recipient_id,
                 'body_preview',     left(NEW.body, 140)
               ),
       headers => '{"Authorization": "Bearer <SUPABASE_ANON_KEY>",
                    "X-Push-Secret": "<PUSH_WEBHOOK_SECRET>"}'
     )
   - Fire-and-forget: trigger does NOT await response

3. Edge Function: send-message-push
   a. Verify X-Push-Secret header (rejects spoofed calls)
   b. WITH serviceClient():
      - Resolve sender display_name + avatar_url FROM profiles
      - Check online guard: is recipient_id in a presence channel?
          → skip if the presence API shows them subscribed to this conversation
            (Supabase doesn't expose presence server-side; use a heuristic:
             check conversations.{builder|trade}_last_read_at
             — if last_read_at > message.created_at - 5s, skip)
      - Check mute guard: check conversations.{builder|trade}_muted_until
          → skip if muted_until IS NOT NULL AND muted_until > now()
      - Fetch tokens: SELECT token FROM device_tokens
          WHERE user_id = recipient_id AND platform = 'android'
   c. For each token, POST to FCM HTTP v1:
        POST https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send
        Authorization: Bearer <FCM_ACCESS_TOKEN>    ← obtained via service-account JWT
        {
          "message": {
            "token": "<device_token>",
            "notification": {
              "title": "<sender_display_name>",
              "body":  "<body_preview>"
            },
            "data": {
              "type":            "new_message",
              "conversation_id": "<conversation_id>",
              "sender_id":       "<sender_id>"
            },
            "android": {
              "priority": "high",
              "notification": { "channel_id": "messages" }
            }
          }
        }
   d. On token-not-registered (FCM 404 / UNREGISTERED):
        DELETE FROM device_tokens WHERE token = <stale_token>
   e. INSERT INTO notifications (user_id, type, title, body, data):
        type  = 'new_message'
        title = sender_display_name
        body  = body_preview
        data  = { conversation_id, sender_id }
   f. Return 200 { sent: N, skipped: reason | null }

4. Flutter client receives FCM payload
   a. Foreground (app open):
      - If thread for conversation_id is active → suppress system notification,
        let the live realtime update handle it
      - Else → show a local notification using flutter_local_notifications
        OR increment the badge counter (v2)
   b. Background / terminated:
      - FCM delivers as system notification
      - User taps → FirebaseMessaging.onMessageOpenedApp or
        getInitialMessage() → extract conversation_id from data payload
        → router.go('/messages/$conversationId', extra: ConversationArgs(...))
```

### Online / read guard heuristic

A true "is recipient viewing this thread right now?" check would require querying
Supabase Presence server-side, which is not exposed via the REST API. Instead, the
Edge Function uses a **read-recency heuristic**:

- Compute `recipient_last_read_at` = `builder_last_read_at` or `trade_last_read_at`
  from `conversations` depending on role.
- If `recipient_last_read_at >= message.created_at - interval '10 seconds'`:
  the recipient's client already marked this thread read within 10 seconds of the
  message being inserted — they are almost certainly viewing the thread. Skip.
- This has false-positive edge cases (fast reader who read and closed) but is
  acceptably conservative for v1.

**Future improvement (v2):** Write a "thread open" heartbeat from the Flutter
client into a `presence` channel or a small `thread_viewers(conversation_id,
user_id, last_seen_at)` table, and query that in the Edge Function.

---

## Schema

### `device_tokens`

```sql
-- supabase/migrations/<ts>_device_tokens.sql

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token       text        NOT NULL,
  platform    text        NOT NULL CHECK (platform IN ('android', 'ios')),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),

  -- One row per (user, token) — upsert on conflict keeps updated_at fresh.
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx
  ON public.device_tokens (user_id);

-- Auto-update updated_at on upsert
DROP TRIGGER IF EXISTS device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

-- Users may only read/write their own tokens.
DO $$ BEGIN
  CREATE POLICY "device_tokens_select_own"
    ON public.device_tokens FOR SELECT
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "device_tokens_insert_own"
    ON public.device_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "device_tokens_update_own"
    ON public.device_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "device_tokens_delete_own"
    ON public.device_tokens FOR DELETE
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
```

### DB trigger function

```sql
-- supabase/migrations/<ts>_message_push_trigger.sql

-- Resolve recipient and fire the Edge Function via pg_net (fire-and-forget).
-- The trigger body is intentionally thin — all skip logic lives in the function.
CREATE OR REPLACE FUNCTION public.notify_message_push()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_recipient_id uuid;
  v_push_url     text := current_setting('app.push_function_url', true);
  v_anon_key     text := current_setting('app.supabase_anon_key',  true);
  v_secret       text := current_setting('app.push_webhook_secret', true);
BEGIN
  -- Resolve who should receive the notification (the non-sender participant).
  SELECT CASE
           WHEN c.builder_id = NEW.sender_id THEN c.trade_id
           ELSE c.builder_id
         END
    INTO v_recipient_id
    FROM public.conversations c
   WHERE c.id = NEW.conversation_id;

  IF v_recipient_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fire-and-forget HTTP call to the Edge Function.
  -- pg_net is available on all Supabase projects (extensions schema).
  PERFORM extensions.http_post(
    url     := v_push_url,
    body    := json_build_object(
                 'message_id',       NEW.id,
                 'conversation_id',  NEW.conversation_id,
                 'sender_id',        NEW.sender_id,
                 'recipient_id',     v_recipient_id,
                 'body_preview',     left(NEW.body, 140),
                 'created_at',       NEW.created_at
               )::text,
    headers := json_build_object(
                 'Content-Type',  'application/json',
                 'Authorization', 'Bearer ' || v_anon_key,
                 'X-Push-Secret', v_secret
               )::text
  );

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never let a push failure break the message insert.
  RAISE WARNING 'notify_message_push: %', SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS messages_notify_push ON public.messages;
CREATE TRIGGER messages_notify_push
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_message_push();
```

> **Note on DB settings:** `app.push_function_url`, `app.supabase_anon_key`, and
> `app.push_webhook_secret` are database-level settings set via the Supabase
> Dashboard → SQL editor: `ALTER DATABASE postgres SET app.push_function_url = '...'`.
> They are NOT in source code. The `SUPABASE_SERVICE_ROLE_KEY` and FCM credentials
> stay exclusively in Edge Function secrets.

---

## Secrets and Security

| Secret | Where stored | Notes |
|---|---|---|
| `FCM_SERVICE_ACCOUNT_JSON` | Supabase Edge Function secret | Full service-account JSON (not the legacy server key). Used to mint short-lived access tokens for FCM HTTP v1. Never shipped to the client. |
| `PUSH_WEBHOOK_SECRET` | Edge Function secret + DB setting `app.push_webhook_secret` | Shared symmetric secret; the trigger sends it, the function checks it. Prevents arbitrary POSTs to the function URL. Min 32 random bytes. |
| `app.push_function_url` | DB setting (Supabase Dashboard) | `https://<ref>.supabase.co/functions/v1/send-message-push`. Set once; readable by SECURITY DEFINER trigger only. |
| `app.supabase_anon_key` | DB setting (Supabase Dashboard) | The public anon key. Used only to authorize the trigger's HTTP call to the function (the function then uses the service-role key internally). |
| FCM token (device) | `device_tokens` table + app RAM | Token is a device identifier, not a secret per se, but should be treated as PII. RLS ensures only the owning user's app can read/write it. Never logged. |

**What is never in the app bundle:**
- FCM service-account JSON
- `PUSH_WEBHOOK_SECRET`
- `SUPABASE_SERVICE_ROLE_KEY`

The Flutter app only ever holds its own FCM token (obtained from
`FirebaseMessaging.instance.getToken()`), which it writes to `device_tokens` via
the authenticated Supabase client under RLS.

---

## iOS-deferred prerequisites

The following must be completed before iOS push can be enabled. They are not
blocked by this phase.

| Prerequisite | Owner | Notes |
|---|---|---|
| Apple Developer Program membership | Ken | $99 USD/yr; required for APNs |
| Bundle-ID rename to production value | Ken | Currently a placeholder — must match App Store Connect |
| APNs Auth Key (`.p8`) generated in App Store Connect | Ken | Upload to Firebase project settings (FCM uses it) |
| `firebase_options.dart` regenerated with `flutterfire configure` | Dev | After iOS app is added to Firebase project |
| `ios/Runner/GoogleService-Info.plist` added | Dev | From Firebase console |
| `UNUserNotificationCenter` delegate wired in `AppDelegate.swift` | Dev | Standard FlutterFire setup |
| `NSUserNotificationsUsageDescription` in `Info.plist` | Dev | App Store review requirement |

---

## Permission-priming UI (Android 13+, in-app sheet)

Android 13 (API 33+) requires an explicit `POST_NOTIFICATIONS` runtime permission.
The OS shows its own prompt; what we control is the in-app priming sheet shown
**before** the OS prompt — it explains the value and dramatically improves
acceptance rates.

### When to prime

Two trigger points (whichever comes first):

1. **First time the user opens the Messages tab** and has never been primed.
2. **Immediately after the user successfully sends their first message** (they just
   took an action that proves intent).

Do not prime on cold start or on the home screen.

### Sheet design (Jobdun design system)

Uses `showJSheet` (the project's `lib/core/design/widgets/j_bottom_sheet.dart` wrapper).

**Structure (top to bottom):**

```
┌─────────────────────────────────────────────────────┐
│  ▓▓▓▓▓▓▓▓  drag handle (Surface Raised)             │
│                                                      │
│  [PhosphorIcon: bell-ringing, Fill, 40dp, #F97316]  │
│                                                      │
│  DON'T MISS A JOB                                    │
│  [Oswald SemiBold 22sp, #F1F5F9, all-caps]          │
│                                                      │
│  Get notified when builders reply to your quote      │
│  or tradies accept your offer — even when            │
│  Jobdun is closed.                                   │
│  [Open Sans 15sp, #94A3B8, centre-aligned]           │
│                                                      │
│  ┌───────────────────────────────────────────────┐  │
│  │  TURN ON NOTIFICATIONS  [#F97316 filled btn]  │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  No thanks   [#94A3B8 text-only, 14sp, centred]     │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Design tokens:**
- Background: `surface` (`#1E293B`) — standard sheet background
- Icon: `AppIcons.bellRinging` (Fill weight) at 40dp, color `actionInk`
- Heading: Oswald SemiBold, 22sp, `text1`, ALL CAPS
- Body: Open Sans Regular, 15sp, `text2`, max 2 lines
- CTA: full-width `JButton` primary, "TURN ON NOTIFICATIONS", `#F97316` fill,
  `onAction` (`#0F172A`) text — no ghost/outline
- Secondary: bare text link "No thanks", `text2`, 14sp, min 44dp tap target
- No gradient, no illustration, no emoji
- Animation: `flutter_animate` — sheet slides up 200ms ease, icon
  `.animate().scale(begin: 0.7, end: 1, duration: 200ms)`

**Behaviour:**
- "TURN ON NOTIFICATIONS" → call `Permission.notification.request()` from
  `permission_handler`, then dismiss sheet. If granted, call
  `FirebaseMessaging.instance.getToken()` and register.
- "No thanks" → dismiss sheet, set a SharedPreferences flag
  `push_priming_dismissed_at` so we don't show again for 14 days.
- If permission is already granted when the sheet would show → skip it entirely.
- Sheet file: `lib/features/notifications/presentation/widgets/push_priming_sheet.dart`

---

## Module / file plan

### New files

| Path | Purpose | Est. LOC |
|---|---|---|
| `supabase/migrations/<ts>_device_tokens.sql` | `device_tokens` table + RLS + trigger | 60 |
| `supabase/migrations/<ts>_message_push_trigger.sql` | `notify_message_push()` trigger | 50 |
| `supabase/functions/send-message-push/index.ts` | FCM send Edge Function | ~200 |
| `lib/features/notifications/data/datasources/device_token_datasource.dart` | Supabase CRUD for `device_tokens` | ~80 |
| `lib/features/notifications/data/repositories/device_token_repository_impl.dart` | Repo impl | ~50 |
| `lib/features/notifications/domain/repositories/device_token_repository.dart` | Contract | ~20 |
| `lib/features/notifications/domain/usecases/register_device_token.dart` | Register / upsert on login | ~30 |
| `lib/features/notifications/domain/usecases/delete_device_token.dart` | Delete on logout | ~20 |
| `lib/features/notifications/presentation/providers/device_token_provider.dart` | Riverpod wiring + controller | ~80 |
| `lib/features/notifications/presentation/widgets/push_priming_sheet.dart` | In-app permission priming UI | ~120 |
| `lib/core/services/push_notification_service.dart` | FCM init, token lifecycle, foreground/background handlers, deep-link routing | ~150 |
| `test/features/notifications/device_token_service_test.dart` | Token register/delete/rotation unit tests | ~80 |
| `test/features/notifications/push_notification_service_test.dart` | Handler routing tests (mocktail) | ~80 |
| `supabase/rollbacks/<ts>_device_tokens_down.sql` | Down-migration | 10 |
| `supabase/rollbacks/<ts>_message_push_trigger_down.sql` | Down-migration | 10 |

### Modified files

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `firebase_core`, `firebase_messaging`, `permission_handler`, `flutter_local_notifications` |
| `android/app/build.gradle` | `google-services` plugin |
| `android/build.gradle` | `google-services` classpath |
| `android/app/google-services.json` | Firebase config (from Firebase console, gitignored) |
| `android/app/src/main/AndroidManifest.xml` | `POST_NOTIFICATIONS` permission, FCM service declaration, notification channel |
| `lib/main.dart` | Init `PushNotificationService` after `SupabaseConfig.initialize()` |
| `lib/app/router/app_router.dart` | Handle `getInitialMessage()` + `onMessageOpenedApp` deep-link routing |
| `lib/features/auth/presentation/providers/auth_provider.dart` | Call `registerDeviceToken` on login, `deleteDeviceToken` on logout |
| `scripts/.ship-env.example` | Add `FIREBASE_APP_ID` documentation note (already present; verify) |
| `supabase/functions/.env.example` | Add `FCM_SERVICE_ACCOUNT_JSON`, `PUSH_WEBHOOK_SECRET` |

---

## Testing strategy

### Edge Function (Deno, unit)

- Mock `serviceClient()` to return a fake Supabase client.
- Test: recipient resolved correctly for builder-initiated vs trade-initiated send.
- Test: skip when `muted_until > now()`.
- Test: skip when `last_read_at` heuristic fires.
- Test: stale token triggers DELETE.
- Test: `X-Push-Secret` mismatch returns 401.
- Test: FCM HTTP v1 payload shape (title, body, data fields, android priority).

### Token service (Flutter, mocktail)

- `registerDeviceToken`: upserts with correct `user_id`, `platform`, `token`.
- `deleteDeviceToken`: removes all rows for `user_id` on logout.
- Token rotation: when `onTokenRefresh` fires, the old row is replaced (unique
  constraint + upsert).
- Permission-denied path: no upsert attempt when `Permission.notification.isDenied`.

### Push notification service (Flutter, mocktail)

- `onMessageOpenedApp` with `conversation_id` in data → `router.go('/messages/$id')`.
- `getInitialMessage()` non-null (app launched from terminated state) → same route.
- Foreground message with thread active → no system notification shown.
- Foreground message with thread inactive → local notification shown.

### Manual on-device

1. Build debug APK via `scripts/ship-to-boss.sh`.
2. User A sends a message while User B's app is backgrounded.
3. User B receives a system notification within ~3s.
4. Tapping the notification opens the correct thread.
5. Muting the conversation (Phase D groundwork: `muted_until` column already
   exists in `20260520000004_swipe_actions.sql`) → no notification received.
6. User B already viewing the thread → no notification fired (read-recency guard).

---

## Risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| pg_net not enabled on project | Low | High | Check `SELECT * FROM pg_extension WHERE extname = 'pg_net'` before migration; enable via Dashboard if missing |
| FCM HTTP v1 token minting complexity | Medium | Medium | Use a small `jsonwebtoken`-style JWT library in Deno (or `google-auth-library` via esm.sh) to sign the service-account JWT; well-documented pattern |
| DB trigger breaks message insert on Edge Function error | Low | Critical | Trigger is wrapped in `EXCEPTION WHEN OTHERS` — push failure can never roll back the message row |
| Token flooding: same user, many devices | Low | Low | `UNIQUE (user_id, token)` + upsert; only active devices accumulate rows; logout purges all |
| Stale tokens accumulate | Medium | Low | Edge Function deletes UNREGISTERED tokens on FCM error response |
| iOS deep-link on cold start missed | N/A (iOS deferred) | — | Documented in prerequisites |
| Android notification channel not created | Medium | Medium | Create channel in `PushNotificationService.init()` using `FlutterLocalNotificationsPlugin` before any notification can arrive |
| `google-services.json` accidentally committed | Low | High | Add to `.gitignore`; confirm before first commit |

---

## Open Questions (needs Ken)

| # | Question | Recommendation |
|---|---|---|
| OQ-1 | **Reuse Firebase project `jobdun-627d2`?** The App Distribution project should have an Android app registered. Check if there is already an FCM-capable app entry (the same Firebase project works for both App Distribution and FCM). If not, add the Android app to the same project in the Firebase console — no new project needed. | **Recommendation: reuse** — no reason to split. Confirm by opening Firebase console → `jobdun-627d2` → check if the Android app (`com.jobdun.*`) is listed with `google-services.json` available. |
| OQ-2 | **Notification preview privacy default?** Show `"<sender>: <message preview>"` vs `"<sender> sent you a message"` (no body). | **Recommendation: show preview by default.** Tradies' workflows are SMS-like; they need the preview to decide whether to act now. Add a "Hide message preview" toggle in profile settings in a later sprint. |
| OQ-3 | **Quiet hours support in v1?** Suppress notifications between, e.g., 10pm–7am user local time. | **Recommendation: defer to v2.** Requires storing user timezone and scheduling logic in the Edge Function. The benefit in v1 is marginal compared to complexity; muting a conversation covers the most common case. |
| OQ-4 | **`permission_handler` package already in pubspec?** Not currently listed. Needs to be added. Confirm no version conflict with `geolocator` (which bundles its own location-permission handling). | Likely no conflict — `permission_handler` covers `POST_NOTIFICATIONS`; `geolocator` handles location. Add `permission_handler: ^11.x`. |
