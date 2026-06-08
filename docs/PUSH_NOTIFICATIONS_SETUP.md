# Push Notifications (#8) — setup & status

**Date:** 2026-06-09

## What's done (no Firebase needed)
- **In-app fan-out** (`20260609000004_new_job_notifications.sql`, **live**): posting a job (`status = open`) inserts an in-app `notifications` row for every available trade whose `primary_trade` matches the job's `trade_type_required`. Shows in the existing notification centre immediately — no FCM required. *(Geo-radius narrowing is a follow-up; today it's trade-type match.)*
- **`device_tokens` table** (same migration): `(user_id, token, platform, updated_at)`, owner-only RLS — ready to receive FCM/APNs tokens.

## What's left for real *push delivery* (needs your Firebase project)
You're already on Firebase (`jobdun-627d2`, App Distribution) — the same project hosts FCM.

1. **`google-services.json`** → drop into `android/app/` (Firebase console → Project settings → Android app → download), or run `flutterfire configure`. *Until this exists, do **not** add `firebase_messaging` to `pubspec.yaml` — the Android build will fail without it.*
2. **Packages:** add `firebase_core` + `firebase_messaging`; `Firebase.initializeApp()` in `main.dart`.
3. **Token registration:** on login, `FirebaseMessaging.instance.getToken()` → upsert into `device_tokens` (owner RLS already allows it). Refresh on `onTokenRefresh`.
4. **`push-send` edge function** (service-role) wrapping the **FCM HTTP v1** API — mirror the `verify-*` structure (`_shared` client, audit, error envelope). Needs a **Firebase service-account JSON** in the function env (`FIREBASE_SERVICE_ACCOUNT`).
5. **Wire delivery:** call `push-send` from `notify_trades_on_new_job()` (via `pg_net`) or a small scheduled drain that pushes un-delivered `new_job` notifications to each recipient's `device_tokens`.

## Why split this way
The marketplace feels live **today** (tradies get in-app alerts on new jobs) without blocking on Firebase. FCM delivery layers on top whenever the `google-services.json` + service account land — no rework, since the recipients + tokens are already modelled.
