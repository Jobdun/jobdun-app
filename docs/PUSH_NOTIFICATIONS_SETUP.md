# Push Notifications (#8) — setup & status

**Updated:** 2026-06-09

## ✅ Done
- **In-app fan-out** (`20260609000004`, live): posting a job notifies matching available trades in the notification centre — no FCM needed.
- **`device_tokens` table** (live): `(user_id, token, platform, updated_at)`, owner-only RLS.
- **Client FCM wired** (this session):
  - `android/app/google-services.json` (fetched from Firebase `jobdun-627d2`; gitignored — re-fetch with `firebase apps:sdkconfig ANDROID 1:960216655470:android:ce72573aa8fa31d80ce87f`).
  - `firebase_core` + `firebase_messaging` in `pubspec.yaml`; `com.google.gms.google-services` gradle plugin.
  - `Firebase.initializeApp()` in `main.dart` (fail-safe) + `lib/core/services/push_notifications.dart` — requests permission, registers the device's FCM token into `device_tokens` on sign-in + refresh.
- **`push-send` edge function written** (`supabase/functions/push-send/index.ts`): FCM HTTP v1 sender, reads `device_tokens` for target users.

## ⏳ Left — needs the Firebase *service account* (the one file the CLI can't mint)
`gcloud` isn't installed locally, so this is yours:

1. **Generate the key:** Firebase console → ⚙ Project settings → **Service accounts** → *Generate new private key* → a JSON.
2. **Set secrets + deploy:**
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)" FIREBASE_PROJECT_ID=jobdun-627d2
   supabase functions deploy push-send
   ```
3. **Wire delivery** (last step): call `push-send` from the new-job path — either `pg_net` from `notify_trades_on_new_job()`, or a small scheduled drain that pushes recent `new_job` notifications to each recipient's tokens.

Once those land, posting a job → in-app notification **and** a real push to matching tradies' devices.

## Note
- Package is still the default **`com.example.jobdun`** — if you rename before launch, re-fetch `google-services.json` (it's package-name-keyed) and re-register the Firebase Android app.
- iOS push is separate (real Firebase iOS config + APNs) and stays deferred.
