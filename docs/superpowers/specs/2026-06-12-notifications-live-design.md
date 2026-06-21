# Live Notifications Feature — Design

**Date:** 2026-06-12 · **Branch:** `feat/notifications-live` · **Status:** approved

## Problem

The push rail (DB producers → central `notifications_push_fanout` trigger →
`push-send` edge fn → FCM) is live, and a complete realtime-synced data pipeline
exists in `lib/features/notifications/` — but the presentation layer was never
built. `notifications_page.dart` is a static placeholder, the home bell has no
unread signal, a tapped push opens the app at home, pushes show nothing while
the app is foregrounded, and `device_tokens` rows survive sign-out.

## Scope

**In:** real notifications page, unread badge on the home bell, push-tap
deep-linking, foreground banners (`flutter_local_notifications`), sign-out
token cleanup.

**Out (explicitly excluded by the user):** the anon-key hardening of
`push-send` (shared secret / DB webhook) — tracked separately in
`docs/PUSH_NOTIFICATIONS_SETUP.md` § Hardening. Also out: pagination, geo
fan-out, iOS/APNs.

## Approach

Reuse the existing `NotificationsController` (realtime `.stream()` on
`notifications`, account-scoped, optimistic mark-read) as the single source of
truth. The badge watches `unreadCount` via `.select()`; the page watches the
full state. One subscription serves both, and the always-alive badge keeps the
page warm. Scale guard: fetch and stream capped at 100 rows (`.limit(100)`).

Rejected: a separate unread-count provider + `infinite_scroll_pagination`
(double machinery for a list mark-all-read naturally trims); FCM-event-driven
badge (push is delivery, realtime is sync — badge would drift on missed pushes).

## Components

### 1. Notifications page (`presentation/pages/notifications_page.dart`)

`ConsumerWidget` on `notificationsControllerProvider`:

- **Grouped:** `NEW` (unread, orange `c.action` accent strip per row) then
  `EARLIER` (read, muted). Oswald all-caps section eyebrows.
- **Row:** leading type icon in a surface circle, title (`titleSmall`, w600
  unread), body (`bodyMedium`, `c.text2`, 2-line ellipsis), relative time
  (`bodySmall`). ≥ 48dp target.
- **Tap:** optimistic `markRead` + navigate via the route resolver.
- **App bar:** `MARK ALL READ` action, visible only when `unreadCount > 0`.
- **States:** `JSkeletonList` loading; existing placeholder retained as empty
  state; error + tap-to-retry; `RefreshIndicator` → `load()`; `JStaggeredList`.
- Tile + section header live in `presentation/widgets/` (file budget ≤ 400 LOC).

Type → icon: `new_job`/`quote_*` → job glyph, `message_*` → chat,
`application_*` → checklist, `*verif*`/`document_*` → shield, fallback bell —
all via `AppIcons.*`.

### 2. Bell badge

`JTopBar` + `HomeStatusBar` gain an optional `notificationCount` (design
widgets stay provider-free). Home passes
`ref.watch(notificationsControllerProvider.select((s) => s.unreadCount))`.
Orange badge, dark `onAction` text, `9+` cap, hidden at zero.

### 3. Route resolver (`features/notifications/domain/notification_route.dart`)

Pure function `resolveNotificationRoute(String? type, Map<String, dynamic> data)`:

| Signal | Route |
|---|---|
| `message_*` type or `conversation_id` key | `/messages/:conversationId` |
| `application_*` type | `/applications` |
| `new_job` / `quote_*` type or `job_id` key | `/jobs/:jobId` |
| anything else | `/notifications` |

Checked in that order. Unit-tested in isolation; shared by in-app row taps,
push taps, and banner taps.

### 4. Push handlers (`core/services/push_notifications.dart`)

- `FirebaseMessaging.onMessageOpenedApp` + `getInitialMessage()` → resolver →
  GoRouter `push`. Router auth redirect guards logged-out cold starts.
- Foreground: `flutter_local_notifications`, one Android channel
  (`jobdun_default`, high importance); `onMessage` shows a banner carrying the
  `data` payload; banner tap routes through the same resolver.
- All best-effort guarded — CI builds without `google-services.json` stay green.

### 5. Sign-out cleanup

`PushNotifications.unregister()` deletes this device's `device_tokens` row
(matched on `user_id` + current token) **before** `auth.signOut()` so RLS still
has the session. Called at every sign-out site; failures never block sign-out.

## Testing

TDD: resolver unit tests first; page widget tests (grouping, mark-all-read
visibility, empty state); badge rendering test. Gate: `bash scripts/validate.sh`.
