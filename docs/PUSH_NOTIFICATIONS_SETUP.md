# Push Notifications (#8) — LIVE

**Updated:** 2026-06-09 · **Status: full program live on `zethpanvkfyijislxesn` + Firebase `jobdun-627d2`.**

## Program (2026-06-09) — all live
- **Central rail** (`20260609000006/000007`): one trigger on `notifications` INSERT → push, gated by `notification_preferences` (per-user, per-category). Any feature/admin just inserts a row.
- **Producers** (`20260609000009/000010`): new **message** → push to the other party (verified e2e); **application received** → builder; **application status** (shortlisted/hired/rejected) → tradie.
- **Admin broadcast** (`20260609000008` + `lib/admin/features/admin_broadcast/`): admin RPC `admin_broadcast(title,body,audience,data)` (All/builders/trades/single, audited) + a compose console. **Needs an admin redeploy** (`bash scripts/deploy-admin.sh`) to appear on jobdun-admin.pages.dev.
- **Preferences** (`lib/features/profile/.../notification_settings_page.dart`, route `/settings/notifications`): per-category toggles.

**Two follow-ups:** (1) `deploy-admin.sh` to publish the broadcast console; (2) the hardening below.

## ✅ What's live
- **Client (Android, on the phone):** `firebase_core` + `firebase_messaging`, `google-services` gradle plugin, `android/app/google-services.json` (gitignored — re-fetch: `firebase apps:sdkconfig ANDROID 1:960216655470:android:ce72573aa8fa31d80ce87f`), `Firebase.initializeApp()`, and `lib/core/services/push_notifications.dart` registering the device's FCM token into `device_tokens` on sign-in/refresh.
- **Send:** `push-send` edge function (FCM HTTP v1) deployed; secrets set (`FIREBASE_SERVICE_ACCOUNT`, `FIREBASE_PROJECT_ID`). Verified: `{"sent":2,"total":2}`.
- **Auto-delivery:** `20260609000005` — posting a job fires an in-app notification **and** an FCM push (via `pg_net` → `push-send`) to matching available trades. Verified end-to-end with a test electrician job.

## 🔐 Hardening before production (one item)
`push-send` is called with the **public anon key**, so the endpoint is callable by anyone with that key — i.e. arbitrary pushes are possible. Pick one:
- **Recommended:** replace the in-trigger `pg_net` call with a **Supabase Database Webhook** on `jobs` INSERT (auto-authed with the service-role key, configured server-side — no key in git).
- Or add a shared-secret header (`PUSH_SEND_SECRET` env + `x-push-secret` check in the function) distributed to the trigger via Vault.

## Secrets / files (not in git)
- Service account: `jobdun-627d2-firebase-adminsdk-*.json` (gitignored). It's set as the `FIREBASE_SERVICE_ACCOUNT` Supabase secret — to rotate, regenerate in Firebase console → Service accounts and re-run `supabase secrets set`.
- `google-services.json` (gitignored). CI release builds need it injected (re-fetch via the CLI command above).
- Package is still `com.example.jobdun` (default) — rename before launch re-fetches `google-services.json`.

## Geo
Fan-out currently matches on **trade type** only; narrowing to the job's geo radius (`search_trades`-style) is a follow-up.
