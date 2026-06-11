# Android Release Signing — Runbook

**Created:** 2026-06-11 (store-blocker fixes; see `docs/BACKEND_FULL_AUDIT_2026-06-11.md` sibling work)

## What exists

| File | Committed? | Purpose |
|---|---|---|
| `android/upload-keystore.jks` | **NO — gitignored** | Upload key (RSA-4096, alias `upload`, valid ~30 yrs) |
| `android/key.properties` | **NO — gitignored** | Passwords + alias + path consumed by `android/app/build.gradle.kts` |

`build.gradle.kts` signs `release` builds with the upload key **when
`android/key.properties` exists**, and falls back to debug signing otherwise so
`flutter run --release` works on a fresh clone. R8 + resource shrinking are on
for release (`proguard-rules.pro` carries plugin keep rules).

## ⚠️ BACK THESE UP NOW

Copy `android/upload-keystore.jks` **and** `android/key.properties` to a
password manager / encrypted drive. They exist only on this machine. Losing
them before first Play upload = regenerate (fine). Losing them after = upload-key
reset request through Play support (days of friction).

Use **Play App Signing** at first upload (default): Google holds the app
signing key; this keystore is only the *upload* key, which Play can reset if
ever lost or leaked.

## Build the store artifact

```bash
flutter build appbundle --release --dart-define-from-file=.env
# → build/app/outputs/bundle/release/app-release.aab
```

Play accepts AABs only. The package identity is `au.com.jobdun.app`
(reverse-DNS of jobdun.com.au) — **permanent once the first build is uploaded.**

## Related store-gate facts (2026-06-11)

- Firebase Android app for the new id: `1:960216655470:android:d1b7bb280cc9e7f80ce87f`
  (project `jobdun-627d2`); `google-services.json` replaced; `scripts/.ship-env`
  FIREBASE_APP_ID updated so `ship-to-boss.sh` distributes the new app.
- OAuth deep-link scheme is `au.com.jobdun.app://login-callback/` (manifest +
  `supabase_config.dart` + the project's auth `uri_allow_list`).
- Account-deletion URL for the Play Data-safety form:
  **https://jobdun-site.pages.dev/delete-account/** (Cloudflare Pages project
  `jobdun-site`, deployed from `site/`).
- Adaptive icon: `mipmap-anydpi-v26/ic_launcher.xml` with background (#F97316),
  transparent hammer-J foreground, and monochrome layer. Regenerate via
  `dart run flutter_launcher_icons` (config in `pubspec.yaml`).
- iOS bundle id rename is **deferred** until the Apple Developer account exists.
