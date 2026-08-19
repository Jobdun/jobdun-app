# iOS + Web App — Parity & Release Audit (2026-08-19)

Companion to `docs/BUG_AUDIT_2026-08-18.md`. That audit was run and fixed
against the **Android** build; this one asks the follow-up question: *do the
same 20 fix commits land correctly on iOS and on the web app, and what does
each platform still need before it ships?*

Scope: `ios/`, `web/`, and the shared code where a fix is platform-sensitive.
Backend, design system and feature behaviour are out of scope — they were
covered by the 2026-08-18 audit and are genuinely shared.

**Method:** static review + four live checks — a real `flutter build web
--release`, a headless-Chromium probe of the built bundle, `codesign
-d --entitlements` on the last exported IPA, and a `dart compile js` experiment
to settle what `dart:io` actually does in a browser. Every finding below was
confirmed, not inferred.

---

## Headline

**The 20 bug-fix commits are genuinely shared.** There is one entrypoint
(`lib/main.dart` — `main_web.dart` was folded back into it), so iOS and web
already carry every fix at source level. Nothing had to be ported.

What was *not* shared is everything that lives outside Dart: the iOS plist,
the web shell, the host headers, and the version number. Those had drifted,
and three of the Aug-19 fixes behaved differently or wrongly off-Android.

| Platform | Verdict |
|---|---|
| **iOS** | All 10 App Store gates PASS. Blocked only on the build number — 1.0 (5) is already live, so the current pubspec could not be uploaded. Fixed. |
| **Web** | Builds and boots clean (0 console errors, first frame at 1.3 s). Three Aug-19 fixes misbehaved in a browser; camera + geolocation are **blocked in production today** by a header policy. Fixed in the repo — but see the correction box: the live app is still `1.0.0+1` and its deploy pipeline is untracked, so none of it is deployable until that is reconciled. |

---

## iOS — App Store gates (`app-store-review-check`)

| # | Gate | Verdict | Evidence |
|---|---|---|---|
| 1 | Bundle identifier | **PASS** | `au.com.jobdun.app` in all three build configs; matches the shipped IPA's `application-identifier 3Q4P2CVMJK.au.com.jobdun.app` |
| 2 | SDK baseline | **PASS** | Xcode 26.6 (17F113), iOS 26.5 SDK — clears the 2026-04-28 Xcode 26 mandate |
| 3 | Purpose strings | **PASS** | Camera, photo library and when-in-use location all present and feature-specific. No background-location key, correctly |
| 4 | Privacy manifest | **PASS** | `PrivacyInfo.xcprivacy` present **and** wired into the Runner target's Resources build phase (`pbxproj:278`) — presence alone would not bundle it |
| 5 | Sign in with Apple (4.8) | **PASS** | Entitlement present in the exported IPA; the tile renders on **both** login and register under `if (kIsWeb \|\| defaultTargetPlatform == TargetPlatform.iOS)`. The Aug-19 "Android tile" fix correctly narrowed it *without* removing it from iOS |
| 6 | Account deletion (5.1.1(v)) | **PASS** | `delete_my_account` RPC via `account_deletion_service.dart` |
| 7 | Encryption export | **PASS** | `ITSAppUsesNonExemptEncryption = false` |
| 8 | App icon | **PASS** | Full appiconset; 1024×1024 verified `hasAlpha: no` |
| 9 | Signing | **PASS** | See note below |
| 10 | Review metadata | **READY** | `docs/APP_STORE_METADATA.md`; demo account rotated + sign-in verified 2026-07-21 |

**Gate 9 note — the `aps-environment` false alarm.** `ios/Runner/Runner.entitlements`
declares `aps-environment: development`, which normally means push is dead on a
store build. It is **not** a problem here, and I checked rather than guessed:
`codesign -d --entitlements` on `build/ios/ipa/Jobdun.ipa` (the 1.0 (5) upload)
shows `aps-environment: production`, `beta-reports-active: true`,
`get-task-allow: false`. Xcode substitutes the distribution profile's value at
export. Leave the file as `development` so debug device builds keep working.

### iOS findings

**iOS-1 — Build number already consumed. (was a hard upload blocker) — FIXED**
`pubspec.yaml` was `1.0.0+5`. 1.0 build 5 is live on the App Store, so that
build number cannot be uploaded again; separately, Apple will not attach a new
build to an already-released version, so the version *name* had to move too.
Fixed as part of the version alignment below.

**iOS-2 — Portrait lock was only half-applied. — FIXED**
Commit `5c98dc7` locked the app to portrait with
`SystemChrome.setPreferredOrientations` because landscape blew every ScreenUtil
`.w` dimension up ~2.16×. But `Info.plist` still listed
`UIInterfaceOrientationLandscapeLeft/Right`. iOS **intersects** the Dart mask
with the plist, so the running app was fine — the gap is the window that exists
*before* the Dart VM starts: a device held sideways launched the storyboard in
landscape and snapped to portrait once the engine came up.
`Info.plist` is now portrait-only (both the phone and the inert `~ipad` array).

**iOS-3 — The fix's own comment was wrong. — FIXED**
`main.dart` justified the lock as "matching `android:screenOrientation="portrait"`
in the manifest". `AndroidManifest.xml` has no such attribute on `MainActivity`
— the only `screenOrientation` in the file is on uCrop's activity. Nothing is
broken by this, but the comment sends the next reader looking for a guarantee
that does not exist. Comment corrected to describe what actually enforces the
lock on each platform.

> Not changed, flagged for a decision: adding `android:screenOrientation="portrait"`
> to `MainActivity` would give Android the same pre-engine guarantee iOS now has.
> Left alone because the Android build is the one already signed off.

---

## Web app — app.jobdun.com.au

Live checks first, because two plausible-sounding failures turned out to be
non-issues and it matters that they were tested:

- **The build compiles.** `flutter build web --release` → exit 0, 5.8 MB
  `main.dart.js`. The 26 unconditional `import 'dart:io'` statements do **not**
  break the web build — dart2js maps `dart:io` for web targets.
- **The app boots clean.** Headless Chromium against the built bundle:
  `flutter-view` mounted at **1299 ms**, **0 console errors**, FTUE rendered and
  interactive. Screenshot captured.
- **The new portrait lock does not crash it.** Flutter's web
  `ScreenOrientation.setPreferredOrientation` wraps `screen.orientation.lock()`
  in a `try/catch` that returns `false` on desktop Chrome, so the `await` in
  `main()` resolves rather than throwing. Confirmed in the engine source *and*
  by the zero-error boot.

### Web findings

> ## ⚠️ Correction (2026-08-19, after checking the live host)
>
> The web section below was written from this checkout alone. Curling
> app.jobdun.com.au and finding the real deploy pipeline changed three
> findings. **The corrections are worse news, not better:**
>
> 1. **The live web app is `1.0.0+1`.** `curl https://app.jobdun.com.au/version.json`
>    → `{"version":"1.0.0","build_number":"1"}`. That is the *first ever* build.
>    It predates the guest-browsing App Review work, the 20 bug fixes,
>    everything. The web app is not "one release behind" — it has never been
>    redeployed.
> 2. **W-2 is LIVE, not latent.** I wrote that `_headers` is ignored on Vercel
>    so the app was serving no headers. Wrong — it serves a full set, including
>    `permissions-policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()`.
>    **Camera and geolocation are blocked on app.jobdun.com.au right now**, for
>    real users, today. The severity goes up, not down.
> 3. **W-1 does not describe what is deployed.** The live shell is already
>    app-correct (`<title>Jobdun — the app for Australian builders and trades</title>`,
>    `og:url = https://app.jobdun.com.au`). The marketing shell is what sits in
>    `web/` on `main` and on this branch.
>
> **Why the divergence:** the web app is deployed by
> `scripts/deploy-app-vercel.sh` from the `feature/web-app-desktop-responsive`
> worktree, and that script is **untracked** — it exists only in
> `.claude/worktrees/feature+web-app-flutter/`. It keeps the app-specific shell
> in a separate `web-app/` directory and does `cp -r web-app/. web/` **over**
> the repo's `web/` immediately before building. So my `web/index.html` and
> `web/vercel.json` fixes would be **overwritten at deploy time** and never
> reach production. It also builds `-t lib/main_web.dart`, an entrypoint that
> no longer exists on this branch — the script cannot run here as written.
>
> Net effect: the `web/` fixes below are correct but **not yet deployable**.
> Reconciling the pipeline is Phase 1 of
> `docs/superpowers/plans/2026-08-19-ios-web-release-verification.md`.
>
> Also corrected: `/assets/*` is already `max-age=3600, must-revalidate` in the
> live config (only `/canvaskit/*` still carries the year-long `immutable`), and
> a `rewrites` SPA fallback **is** present live — harmless under hash routing.

**W-1 — The web app was serving the marketing site's HTML shell. (P1) — FIXED IN REPO, NOT YET DEPLOYABLE**
`web/index.html` still carried jobdun.com.au's `<title>`, description, and
Open Graph/Twitter cards, with `og:url` pointing at the **marketing homepage**,
plus a header comment claiming it was built from
`lib/website/main_website.dart`. It is built from `lib/main.dart`. Effects at
app.jobdun.com.au: every shared link previewed as the marketing site, and the
browser tab read as marketing copy until Flutter booted and
`MaterialApp.title` took over. `web/manifest.json` had the same marketing
string as its PWA install name. Both rewritten for the app, plus `noindex` so
the app stops competing with the real marketing site in search results.

**W-2 — `Permissions-Policy` switched off camera and geolocation. (P1) — FIXED**
`web/_headers` was the marketing site's policy: `camera=(), microphone=(),
geolocation=(), payment=(), usb=()`. Those are two features the consumer app
depends on — document/portfolio/avatar capture, and "use my current location" +
the nearby-jobs map. An empty allowlist blocks them for *every* origin
including self. Now `camera=(self), geolocation=(self)`, with microphone,
payment and usb still off.

> **Corrected:** I first assessed this as latent, reasoning that `_headers` is
> a Cloudflare/Netlify convention that Vercel ignores. The reasoning was right
> but the conclusion was wrong — the policy reaches production through a
> *different* file (`web-app/vercel.json` in the deploy worktree), so it is
> **live today**. Verified:
>
> ```
> $ curl -sSD - -o /dev/null https://app.jobdun.com.au/
> permissions-policy: camera=(), microphone=(), geolocation=(), payment=(), usb=()
> ```
>
> An empty allowlist blocks the feature for every origin including self, so on
> the web app the camera button and "use my current location" cannot work at
> all. Fixed here in `web/_headers` + `web/vercel.json`, but see the correction
> box above: the deploy pipeline stages `web-app/` over `web/`, so
> **`web-app/vercel.json` is the copy that has to change** for this to reach
> production.
>
> No SPA rewrite is needed on the app's own account — nothing in `lib/` calls
> `usePathUrlStrategy`, so GoRouter is on the default **hash** strategy and deep
> links (`/#/jobs/123`) never reach the server as a path. The live config
> carries one anyway; it is harmless and worth keeping.

**W-3 — Aug-19's new PDF picker silently swallows the file on web. (P1) — FIXED**
The PDF pick path added in `5c1d976` does:
```dart
final path = result?.files.single.path;
if (!mounted || path == null) return;
```
`path` is **always null on web** — `file_picker` returns `bytes` there, because a
browser has no filesystem. So a web user taps PDF, picks a document, and gets
nothing: no file, no error, no spinner. That is precisely the silent-failure
class the 2026-08-18 audit set out to kill, reintroduced on a platform the fix
wasn't tested on. Now separates "user cancelled" (stay quiet) from "no readable
path" (say so, with browser-specific copy).

**W-4 — Image upload dies with a raw `UnsupportedError` on web. (P1) — FIXED**
`ImageUploadService.pickCropCompress` is the single entry point for avatars,
portfolio shots, chat photos and verification docs. On web the whole chain is
unsurvivable: `image_cropper` needs `cropper.js` injected into `index.html`
(it isn't), `FlutterImageCompress.compressAndGetFile` has no web
implementation, and the returned `dart:io` `File` is the sharpest edge —

```
$ dart compile js  &&  node main.js
CONSTRUCT_OK path=/tmp/nope.txt
LENGTH_THREW: UnsupportedError: Unsupported operation: _Namespace
```

`File()` **constructs** fine on web and only throws when something reads it.
And `UnsupportedError` is an `Error`, not an `Exception` — so it slipped past
both the service's own `on Exception` fallback and every call site's
`on UploadGuardException`, surfacing as a red error screen or a dead button.
Now fails fast with `UploadGuardException` and copy the user can act on.

**W-5 — Portrait lock ran on web too. (P2) — FIXED**
Harmless in practice (see above) but wrong in intent: app.jobdun.com.au is a
responsive **desktop** surface — collapsible sidebar, master-detail splits —
and ScreenUtil's proportional scaling is already disabled there, so the
rationale for the lock does not apply. It could also genuinely pin a
fullscreen mobile browser to portrait. Now guarded with `if (!kIsWeb)`.

**W-6 — Dead splash overlay. (P2) — FIXED**
`index.html` waited for `window.removeSplash()` to be called from
`lib/website/app/website_app.dart` — a file the app entrypoint never loads.
Nothing called it; `grep` finds zero callers in `lib/`. Verified in-browser:
the `#splash` node stayed in the DOM with `opacity: 1` for the full **8 seconds**
until the failsafe timer removed it. Users never *saw* it, purely because
Flutter appends `<flutter-view>` later in DOM order and so paints on top — an
accident of ordering, not a design. Replaced with a `MutationObserver` that
removes the splash the moment `flutter-view` mounts, keeping the 8 s timer as a
genuine failsafe. No Dart-side hook needed.

**W-7 — Year-long `immutable` cache on non-hashed assets. (P2) — FIXED**
`_headers` set `Cache-Control: public, max-age=31536000, immutable` on
`/assets/*` and `/canvaskit/*`, with a comment asserting "main.dart.js is
content-hashed by the Flutter build". It is not — Flutter web asset URLs are
stable across releases — and the service worker that would otherwise handle
versioning is, in Flutter 3.41, a **self-unregistering stub** (it calls
`registration.unregister()` on activate). A returning user could therefore be
pinned to a year-old bundle. Now short-TTL + `must-revalidate`, with `no-cache`
on the entry document and loader.

> **Corrected:** the deployed config is already ahead of the repo here —
> `/assets/*` is live as `max-age=3600, must-revalidate`. Only `/canvaskit/*`
> still carries the year-long `immutable` in `web-app/vercel.json`. That one is
> the least dangerous of the three (CanvasKit changes only with the Flutter
> engine) but it is still a non-hashed URL, so it should come down to the same
> short TTL when the pipeline is reconciled.

**W-8 — Bundled `.env` is a public URL on web. (P3, accepted) — DOCUMENTED**
`.env` is a pubspec asset, so on web it is fetchable:
`GET /assets/.env → 200`. Contents were reviewed and are client-safe by design
(Supabase URL + **anon** key, public Google client ids, MapTiler key, Sentry
DSN) — the same values that are already extractable from any APK/IPA, so this
is not a leak. Two follow-ups, neither blocking:
- Domain-restrict the MapTiler key to `app.jobdun.com.au` + `jobdun.com.au` in
  the MapTiler console. On mobile the key is at least buried in a binary; on
  web it is one `curl` away and trivially reusable against the quota.
- `/assets/.env` is now `no-store` so a rotation takes effect immediately
  instead of being cached.

---

## Cross-platform finding surfaced by this audit

**X-1 — Every shipped build reports to Sentry as `development`. — FIXED**
Not iOS- or web-specific, but it was found here and it degrades exactly the
signal you'd want after a bug-fix release. `.env` contains
`SENTRY_ENVIRONMENT=development`, and `AppEnv` read `.env` **before**
`String.fromEnvironment`:

```dart
dotenv.env['SENTRY_ENVIRONMENT'] ?? const String.fromEnvironment(...)
```

Since `.env` is a single asset bundled into *every* build, that line wins
unconditionally — a `--dart-define` cannot override it. The live App Store
build, the Play build and the web app have all been tagging real user crashes
as `development`. `sentryEnvironment` now derives from `kReleaseMode`, with a
`--dart-define` escape hatch for release-mode staging builds.

> The same `.env`-beats-dart-define precedence applies to `SUPABASE_URL`,
> `SUPABASE_ANON_KEY` and the rest of `AppEnv`. That is currently harmless (one
> project, one set of keys) but it means CI cannot point a build at staging via
> `--dart-define`. Left alone — it deserves its own change.

---

## Version alignment — what "match the Android update" meant

The Android update was `worktree-play-versioncode-6` (`9424517`): a one-line
bump to `1.0.0+6` after Play rejected the versionCode 5 bundle as "already
used". That branch is **based on `main`, not on the bug-fix branch** — it
carries the version bump but none of the 20 fixes, while the fix branch carried
the fixes and no bump. Neither is shippable alone.

`pubspec.yaml` is the single source for all three targets — Android reads it via
`flutter.versionCode`, iOS via `$(FLUTTER_BUILD_NUMBER)` → `CFBundleVersion`,
web via `version.json` — so one bump on the fix branch aligns all of them.

**`1.0.0+5` → `1.0.1+7`.**

- **Name → 1.0.1**: 1.0 is already released on the App Store, and Apple won't
  attach a build to a shipped version. A new version record is required either
  way, so the name should reflect that this is the bug-fix release.
- **Build → 7, not 6**: build 5 is live on the App Store and was uploaded to
  Play; 6 was already minted for a Play upload on the other branch. Both stores
  require strictly-increasing build numbers and both allow gaps, so 7 is the
  first value that is unambiguously free on **both**, regardless of whether
  that 6 bundle was ever accepted by Play. Confirming 6's fate is not needed.

---

## Changed files

| File | Change |
|---|---|
| `pubspec.yaml` | `1.0.0+5` → `1.0.1+7` (iOS-1) |
| `ios/Runner/Info.plist` | Portrait-only orientations (iOS-2) |
| `lib/main.dart` | `!kIsWeb` guard + corrected comment (W-5, iOS-3) |
| `lib/core/config/env.dart` | Sentry env from build mode (X-1) |
| `lib/core/services/image_upload_service.dart` | Honest web bail-out (W-4) |
| `lib/features/verification/.../manual_upload_sheet.dart` | Honest null-path failure (W-3) |
| `web/index.html` | App shell + working splash removal (W-1, W-6) |
| `web/manifest.json` | App PWA identity (W-1) |
| `web/_headers` | Camera/geolocation restored, cache corrected, noindex (W-2, W-7) |
| `web/vercel.json` | **New** — the headers the actual host reads (W-2) |
| `web/_redirects` | Comment corrected to match hash routing |

---

## Still owed before either store upload

Not blockers found in code — these need a device, a console, or a decision.

1. **iOS device pass on the 20 fixes.** The keyboard-dismissal fix (`337dba7`)
   was written for an "iOS-heavy" bug (§S3) and has never been exercised on the
   iPhone. `bash scripts/deploy-iphone.sh` is the one-command path.
2. **Merge the two branches.** `fix/live-bug-audit-2026-08-18` (fixes, now with
   the bump) and `worktree-play-versioncode-6` (bump only) both need to reach
   `develop`/`main`. The +7 chosen here supersedes the +6 branch, which can be
   retired rather than merged.
3. **Reconcile the web deploy pipeline, then redeploy.** app.jobdun.com.au is
   serving **`1.0.0+1`** — the first build ever cut. Its deploy script,
   `web-app/` template and `vercel.json` are untracked files living in the
   `feature/web-app-desktop-responsive` worktree, and the script targets a
   `lib/main_web.dart` that no longer exists. Until those come into the repo,
   the `web/` fixes above cannot ship. Phase 1 of
   `docs/superpowers/plans/2026-08-19-ios-web-release-verification.md`.
4. **App Store Connect**: create the 1.0.1 version record; the metadata pack is
   ready in `docs/APP_STORE_METADATA.md`.
5. **Domain-restrict the MapTiler key** (W-8).
6. **Decide on Android's `screenOrientation`** (iOS-3 note).
