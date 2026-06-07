# Messaging — Push Notifications (Implementation Plan)

- **Date:** 2026-06-08
- **Spec:** `docs/superpowers/specs/2026-06-08-messaging-push-notifications-design.md`
- **Branch:** `feat/messaging-push-notifications`
- **Prerequisite:** `feat/messaging-reliability-core` merged to `develop` first (provides `client_tag`, pagination, and `watchConversation`)

---

## Pre-work checklist (before writing a line of code)

- [ ] Ken confirms OQ-1: reuse Firebase project `jobdun-627d2` (open Firebase console → verify Android app is listed → download fresh `google-services.json`)
- [ ] Ken confirms OQ-2: show message preview by default
- [ ] Ken confirms OQ-3: defer quiet hours to v2
- [ ] Confirm `pg_net` is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_net';` in Supabase SQL editor
- [ ] Confirm `set_updated_at()` trigger function exists (used by new table): `\df public.set_updated_at`
- [ ] Add `android/app/google-services.json` to `.gitignore` (if not already)
- [ ] Generate FCM service-account JSON from Firebase console → Project Settings → Service Accounts → Generate new private key. Store locally; do NOT commit.

---

## Checkpoint 1 — Database: `device_tokens` table + RLS

**Goal:** The registry for device push tokens is live in the database with correct RLS before any Flutter code is written.

### Steps

1. Create migration file:
   `supabase/migrations/20260609000001_device_tokens.sql`

   Content (see spec Schema section for exact SQL):
   - `CREATE TABLE public.device_tokens (id, user_id, token, platform, updated_at, created_at)`
   - `UNIQUE (user_id, token)`
   - `CREATE INDEX device_tokens_user_id_idx`
   - `CREATE TRIGGER device_tokens_updated_at` (reuse `set_updated_at()`)
   - `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`
   - Four RLS policies: `select_own`, `insert_own`, `update_own`, `delete_own` (all scoped to `auth.uid() = user_id`)

2. Create rollback file:
   `supabase/rollbacks/20260609000001_device_tokens_down.sql`
   ```sql
   DROP TABLE IF EXISTS public.device_tokens;
   ```

3. Push migration:
   ```bash
   supabase db push
   ```

4. Verify in Supabase Dashboard → Table Editor → `device_tokens` visible with correct columns and RLS enabled.

**Checkpoint gate:** Table exists, RLS on, can INSERT a test row as an authenticated user and not as anon.

---

## Checkpoint 2 — Database: message push trigger

**Goal:** Every new message INSERT fires `notify_message_push()`, which calls the Edge Function URL via `pg_net`. Safe: trigger never breaks a message insert.

### Steps

1. Set DB-level app settings in Supabase SQL editor (one-time, not in migrations — these hold secrets-adjacent values):
   ```sql
   ALTER DATABASE postgres SET app.push_function_url    = 'https://<ref>.supabase.co/functions/v1/send-message-push';
   ALTER DATABASE postgres SET app.supabase_anon_key    = '<your-anon-key>';
   ALTER DATABASE postgres SET app.push_webhook_secret  = '<32-byte-random-hex>';
   ```
   > Generate the webhook secret: `openssl rand -hex 32`

2. Create migration file:
   `supabase/migrations/20260609000002_message_push_trigger.sql`

   Content (see spec for exact SQL):
   - `CREATE OR REPLACE FUNCTION public.notify_message_push()` — SECURITY DEFINER, reads `current_setting(...)`, resolves recipient from `conversations`, calls `extensions.http_post(...)`, wrapped in `EXCEPTION WHEN OTHERS`
   - `DROP TRIGGER IF EXISTS messages_notify_push ON public.messages`
   - `CREATE TRIGGER messages_notify_push AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.notify_message_push()`

3. Create rollback file:
   `supabase/rollbacks/20260609000002_message_push_trigger_down.sql`
   ```sql
   DROP TRIGGER IF EXISTS messages_notify_push ON public.messages;
   DROP FUNCTION IF EXISTS public.notify_message_push();
   ```

4. Push migration:
   ```bash
   supabase db push
   ```

5. Smoke test: insert a message via Supabase SQL editor (as a participant). Confirm `pg_net` queue has an entry (`SELECT * FROM net._http_response ORDER BY created DESC LIMIT 5`). The Edge Function doesn't exist yet so it will 404 — that is expected and safe.

**Checkpoint gate:** Trigger exists, a test insert does NOT error, `pg_net` shows the outgoing HTTP call.

---

## Checkpoint 3 — Edge Function: `send-message-push`

**Goal:** The Edge Function resolves the recipient, applies skip guards, calls FCM HTTP v1, inserts the `notifications` row, and handles stale tokens. Tested locally with `supabase functions serve` before deploy.

### New files

- `supabase/functions/send-message-push/index.ts`

### New / modified shared files

- `supabase/functions/_shared/fcm.ts` — FCM HTTP v1 token minting + send helper
- `supabase/functions/.env.example` — add `FCM_SERVICE_ACCOUNT_JSON`, `PUSH_WEBHOOK_SECRET`
- `supabase/functions/.env` — add the real values (gitignored, never committed)

### Steps

1. Create `supabase/functions/_shared/fcm.ts`:
   - `getFcmAccessToken(serviceAccountJson: string): Promise<string>` — mints a short-lived OAuth2 access token from the service-account JSON using a Deno-compatible JWT library (`djwt` via `https://deno.land/x/djwt/`). Scope: `https://www.googleapis.com/auth/firebase.messaging`.
   - `sendFcmMessage(accessToken, projectId, token, notification, data, androidConfig): Promise<FcmResult>` — single-message POST to `https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send`.
   - Returns `{ success: true }` or `{ success: false, error: string, isUnregistered: boolean }`.

2. Create `supabase/functions/send-message-push/index.ts`:
   ```
   POST /functions/v1/send-message-push
   Headers: Authorization: Bearer <anon-key>, X-Push-Secret: <secret>
   Body: { message_id, conversation_id, sender_id, recipient_id, body_preview, created_at }
   ```
   Logic sequence:
   a. Preflight CORS (reuse `_shared/cors.ts`)
   b. Verify `X-Push-Secret` header matches `Deno.env.get('PUSH_WEBHOOK_SECRET')` — return 401 if mismatch
   c. Parse + validate body fields; return 400 on missing fields
   d. Init `serviceClient()`
   e. Fetch sender profile: `SELECT display_name FROM profiles WHERE id = sender_id`
   f. Fetch conversation: `SELECT builder_id, trade_id, builder_last_read_at, trade_last_read_at, builder_muted_until, trade_muted_until FROM conversations WHERE id = conversation_id`
   g. Determine `is_builder_recipient = (conversation.trade_id == recipient_id)`; read the correct `last_read_at` and `muted_until` for the recipient side
   h. **Mute guard:** if `muted_until IS NOT NULL AND muted_until > now()` → return `{ skipped: 'muted' }`
   i. **Read-recency guard:** if `last_read_at` is within 10 seconds of `created_at` → return `{ skipped: 'recently_read' }`
   j. Fetch device tokens: `SELECT id, token FROM device_tokens WHERE user_id = recipient_id AND platform = 'android'`
   k. If no tokens → insert `notifications` row, return `{ skipped: 'no_tokens' }`
   l. Get FCM access token via `getFcmAccessToken(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON'))`
   m. For each device token, call `sendFcmMessage(...)` with:
      - `notification.title` = `sender_display_name`
      - `notification.body` = `body_preview`
      - `data` = `{ type: 'new_message', conversation_id, sender_id }`
      - `android.priority` = `'high'`
      - `android.notification.channel_id` = `'messages'`
   n. On FCM UNREGISTERED error for a token: `DELETE FROM device_tokens WHERE id = <row_id>`
   o. Insert into `notifications`: `{ user_id: recipient_id, type: 'new_message', title: sender_display_name, body: body_preview, data: { conversation_id, sender_id } }`
   p. Return `{ sent: N, deleted_stale: M }`

3. Add to `supabase/functions/.env.example`:
   ```
   # FCM service-account JSON (minified). Generate from Firebase console →
   # Project Settings → Service Accounts → Generate new private key.
   # DO NOT commit the real value.
   FCM_SERVICE_ACCOUNT_JSON=

   # Shared secret between DB trigger and this function. 32 random bytes (hex).
   # Generate: openssl rand -hex 32
   # Set both here AND in Supabase: ALTER DATABASE postgres SET app.push_webhook_secret = '...'
   PUSH_WEBHOOK_SECRET=
   ```

4. Local test with `supabase functions serve`:
   ```bash
   supabase functions serve send-message-push --env-file supabase/functions/.env
   ```
   Use `curl` or a test script to POST a synthetic payload with a valid X-Push-Secret.
   Verify:
   - 401 on wrong secret
   - 400 on missing fields
   - `{ skipped: 'muted' }` when muted_until is in the future
   - `{ skipped: 'no_tokens' }` when device_tokens is empty for recipient
   - Actual FCM HTTP v1 call (use FCM dry-run mode or a real test device) on happy path

5. Deploy:
   ```bash
   supabase functions deploy send-message-push
   ```

6. Set secrets in Supabase Dashboard → Edge Functions → `send-message-push` → Secrets:
   - `FCM_SERVICE_ACCOUNT_JSON` = minified JSON string
   - `PUSH_WEBHOOK_SECRET` = same value as the DB setting
   - `SUPABASE_SERVICE_ROLE_KEY` = project service-role key
   - `SUPABASE_URL` = project URL

**Checkpoint gate:** `curl` a test payload → function returns 200 with expected body; stale-token cleanup is observable in `device_tokens`; `notifications` row is inserted.

---

## Checkpoint 4 — Flutter: pubspec + Android native setup

**Goal:** Firebase and FCM packages are integrated; the Android app builds with FCM support; the `messages` notification channel is created on app start.

### pubspec.yaml additions

```yaml
# Push notifications
firebase_core: ^3.6.0
firebase_messaging: ^15.1.3
flutter_local_notifications: ^17.2.3
permission_handler: ^11.3.1
```

Run:
```bash
flutter pub get
```

### Android native changes

1. `android/app/google-services.json` — place file (from Firebase console). Add to `.gitignore`:
   ```
   android/app/google-services.json
   ```

2. `android/build.gradle` — add to `buildscript.dependencies`:
   ```groovy
   classpath 'com.google.gms:google-services:4.4.2'
   ```

3. `android/app/build.gradle` — apply plugin at the bottom:
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   ```

4. `android/app/src/main/AndroidManifest.xml`:
   - Add permission (inside `<manifest>`):
     ```xml
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     ```
   - Add FCM service (inside `<application>`):
     ```xml
     <service
       android:name="com.google.firebase.messaging.FirebaseMessagingService"
       android:exported="false">
       <intent-filter>
         <action android:name="com.google.firebase.MESSAGING_EVENT"/>
       </intent-filter>
     </service>
     ```
   - Add notification channel metadata (inside `<application>`):
     ```xml
     <meta-data
       android:name="com.google.firebase.messaging.default_notification_channel_id"
       android:value="messages"/>
     ```

5. Verify `flutter build apk --debug` succeeds.

**Checkpoint gate:** `flutter analyze` passes; debug APK builds without error; Firebase initializes on app launch (no runtime crash).

---

## Checkpoint 5 — Flutter: `PushNotificationService` + token lifecycle

**Goal:** A clean-architecture service initializes FCM, manages token upsert/rotation/deletion, and is wired into the auth flow.

### New files

**`lib/core/services/push_notification_service.dart`**

Responsibilities:
- `init()`: call `Firebase.initializeApp()`, create the `messages` Android notification channel via `FlutterLocalNotificationsPlugin`, set foreground notification presentation options.
- `registerToken(String userId)`: call `FirebaseMessaging.instance.getToken()` → upsert into `device_tokens` via the token datasource.
- `onTokenRefresh`: subscribe to `FirebaseMessaging.instance.onTokenRefresh` → re-upsert.
- `deleteToken(String userId)`: call `FirebaseMessaging.instance.deleteToken()` → delete all rows for `userId` from `device_tokens`.
- `setupHandlers(GoRouter router)`:
  - `FirebaseMessaging.onMessageOpenedApp` → extract `conversation_id` from `message.data` → `router.go('/messages/$conversationId', extra: ConversationArgs(...))`
  - `FirebaseMessaging.instance.getInitialMessage()` (app-launched-from-terminated) → same route
  - `FirebaseMessaging.onMessage` (foreground) → if thread for `conversation_id` is not open, show a local notification via `FlutterLocalNotificationsPlugin`

**`lib/features/notifications/data/datasources/device_token_datasource.dart`**

```dart
abstract interface class DeviceTokenDataSource {
  Future<void> upsertToken({ required String userId, required String token, required String platform });
  Future<void> deleteAllTokens(String userId);
}
```

Impl: `device_tokens` upsert with `onConflict: 'user_id,token'`.

**`lib/features/notifications/domain/repositories/device_token_repository.dart`**

```dart
abstract interface class DeviceTokenRepository {
  Future<Either<Failure, void>> upsertToken({ required String userId, required String token, required String platform });
  Future<Either<Failure, void>> deleteAllTokens(String userId);
}
```

**`lib/features/notifications/domain/usecases/register_device_token.dart`**

Calls `repository.upsertToken(...)`. Returns `Either<Failure, void>`.

**`lib/features/notifications/domain/usecases/delete_device_token.dart`**

Calls `repository.deleteAllTokens(userId)`.

**`lib/features/notifications/presentation/providers/device_token_provider.dart`**

- `deviceTokenDataSourceProvider` (public, top-level)
- `deviceTokenRepositoryProvider` (public, top-level)
- `registerDeviceTokenUseCaseProvider` (public)
- `deleteDeviceTokenUseCaseProvider` (public)
- `DeviceTokenController extends AsyncNotifier<void>` — exposes `register(String userId)` and `delete(String userId)`

### Modified files

**`lib/main.dart`**

```dart
await PushNotificationService.instance.init();
// After SupabaseConfig.initialize() and before runApp()
```

**`lib/app/router/app_router.dart`**

In the `appRouterProvider`, after the router is constructed:
```dart
// Wire FCM deep-link handlers after router is available
PushNotificationService.instance.setupHandlers(router);
```

**`lib/features/auth/presentation/providers/auth_provider.dart`**

In `AuthController`:
- On login success: `ref.read(deviceTokenControllerProvider.notifier).register(userId)`
- On logout: `ref.read(deviceTokenControllerProvider.notifier).delete(userId)`

**Checkpoint gate:** On fresh login, a row appears in `device_tokens` for the user. On logout, the row is deleted. `flutter analyze` passes.

---

## Checkpoint 6 — Flutter: permission-priming sheet

**Goal:** The in-app permission priming sheet appears at the right moment, requests `POST_NOTIFICATIONS`, and registers the token on grant.

### New file

**`lib/features/notifications/presentation/widgets/push_priming_sheet.dart`**

Implements the sheet as designed in the spec (see Permission-priming UI section):
- Uses `showJSheet` from `lib/core/design/widgets/j_bottom_sheet.dart`
- Bell icon (`AppIcons.bellRinging` Fill), headline "DON'T MISS A JOB", body copy, full-width CTA, bare "No thanks" link
- No raw `SizedBox` spacing — use `Gap(n)`
- No `PhosphorIconsBold.*` / `PhosphorIconsFill.*` directly — use `AppIcons.*`
- On CTA tap: `await Permission.notification.request()` → if granted, call `DeviceTokenController.register(userId)` → dismiss
- On "No thanks": write `prefs.setInt('push_priming_dismissed_at', now.millisecondsSinceEpoch)` → dismiss

**Trigger logic (two places):**

1. `lib/features/messaging/presentation/pages/messages_page.dart` — in `initState` or `build`, check if priming should show:
   ```dart
   // Show if: Android 13+, permission not yet granted, not dismissed in last 14 days
   _maybeShowPushPriming(context, ref);
   ```
   Use `WidgetsBinding.instance.addPostFrameCallback` to defer until after first frame (sheet cannot be shown during build).

2. `lib/features/messaging/presentation/providers/messaging_provider.dart` — after a successful first send (detect via outbox-to-confirmed transition when `state.totalUnread` was previously 0), set a flag so the sheet shows on next frame.

**Shared helper:**
`lib/features/notifications/presentation/providers/push_priming_provider.dart` — a simple `NotifierProvider<bool>` that tracks whether priming has been shown this session.

**Checkpoint gate:** Sheet appears on first Messages tab visit (Android 13+, permission not granted). "TURN ON NOTIFICATIONS" button fires the OS prompt. Token is registered in `device_tokens` after grant. "No thanks" dismisses and does not reshow for 14 days.

---

## Checkpoint 7 — End-to-end test

**Goal:** The full flow works on a real device: message sent → notification received → tap opens thread.

### Steps

1. Build and distribute a test APK:
   ```bash
   bash scripts/ship-to-boss.sh "Push notification test build"
   ```

2. Two-device test:
   - Device A: logged in as User A (builder)
   - Device B: logged in as User B (tradie), app backgrounded
   - User A sends a message
   - Device B receives a system notification within ~3–5 seconds
   - Notification title = User A's display name, body = message preview
   - Tap notification → app opens to the correct thread

3. Guard tests:
   - Mute test: update `conversations.trade_muted_until = now() + interval '1 hour'` directly in DB → User A sends → Device B gets NO notification
   - Read-recency test: User B opens the thread (marks read) → User A sends immediately after → no notification (or acceptable edge: one notification fires before the guard catches up)
   - Stale token test: manually corrupt a token in `device_tokens` → verify the Edge Function deletes it and the `notifications` log still shows the attempt

4. Deep-link terminated-state test:
   - Force-close app on Device B
   - User A sends message
   - Notification arrives
   - Tap notification → app launches directly to thread (not home screen)

**Checkpoint gate:** All four test scenarios pass on a real Android device.

---

## Checkpoint 8 — Cleanup + validation

**Goal:** Code meets all project standards before PR.

### Steps

1. Run full validation:
   ```bash
   bash scripts/validate.sh
   ```
   Fix any `flutter analyze` findings, format issues, or test failures.

2. Run architecture check:
   ```bash
   bash scripts/check-architecture.sh
   ```
   Verify new `device_token_*` files respect Clean Architecture layers. `PushNotificationService` lives in `lib/core/services/` — confirm it does not import from `features/*/domain/` directly (it calls providers via ref, not domain use cases directly).

3. File-size check — none of the new files should exceed 400 LOC target. `push_notification_service.dart` is estimated at 150 LOC; `send-message-push/index.ts` at ~200 lines.

4. Confirm `google-services.json` is in `.gitignore` and not staged:
   ```bash
   git status android/app/google-services.json
   ```

5. Update `supabase/functions/.env.example` with new secret names (already in Checkpoint 3 step 3).

6. Write PR description with:
   - Screenshots: permission priming sheet
   - Manual test steps for the reviewer
   - Note: `google-services.json` not committed; reviewer must obtain from Firebase console

**Checkpoint gate:** `bash scripts/validate.sh` exits 0. Architecture check passes. PR description includes screenshots.

---

## New pubspec dependencies (exact additions)

```yaml
# Push notifications
firebase_core: ^3.6.0
firebase_messaging: ^15.1.3
flutter_local_notifications: ^17.2.3
permission_handler: ^11.3.1
```

> `firebase_core` and `firebase_messaging` are FlutterFire packages.
> `flutter_local_notifications` is for foreground notification display.
> `permission_handler` covers `POST_NOTIFICATIONS` (Android 13+) and does not
> conflict with `geolocator`'s separate location-permission handling.

---

## New Edge Function dependency

`supabase/functions/send-message-push/index.ts` imports:
- `djwt` via `https://deno.land/x/djwt@v3.0.2/` — Deno-native JWT library for minting FCM OAuth2 tokens from the service-account JSON
- `_shared/cors.ts`, `_shared/supabase-client.ts` — existing shared modules

No new npm packages needed in existing functions.

---

## File paths summary

| Type | Path |
|---|---|
| Migration: device_tokens | `supabase/migrations/20260609000001_device_tokens.sql` |
| Migration: push trigger | `supabase/migrations/20260609000002_message_push_trigger.sql` |
| Rollback: device_tokens | `supabase/rollbacks/20260609000001_device_tokens_down.sql` |
| Rollback: push trigger | `supabase/rollbacks/20260609000002_message_push_trigger_down.sql` |
| Edge Function | `supabase/functions/send-message-push/index.ts` |
| Edge shared: FCM helper | `supabase/functions/_shared/fcm.ts` |
| Flutter: push service | `lib/core/services/push_notification_service.dart` |
| Flutter: token datasource | `lib/features/notifications/data/datasources/device_token_datasource.dart` |
| Flutter: token repo impl | `lib/features/notifications/data/repositories/device_token_repository_impl.dart` |
| Flutter: token repo contract | `lib/features/notifications/domain/repositories/device_token_repository.dart` |
| Flutter: register use case | `lib/features/notifications/domain/usecases/register_device_token.dart` |
| Flutter: delete use case | `lib/features/notifications/domain/usecases/delete_device_token.dart` |
| Flutter: token provider | `lib/features/notifications/presentation/providers/device_token_provider.dart` |
| Flutter: priming provider | `lib/features/notifications/presentation/providers/push_priming_provider.dart` |
| Flutter: priming sheet | `lib/features/notifications/presentation/widgets/push_priming_sheet.dart` |
| Test: token service | `test/features/notifications/device_token_service_test.dart` |
| Test: push service | `test/features/notifications/push_notification_service_test.dart` |
