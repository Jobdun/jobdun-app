---
name: play-review-check
description: Use when preparing an Android/Flutter app for Google Play submission, before a release build, when asked "are we store-ready", or after changing applicationId, icons, permissions, or target SDK. Audits against real Play policy gates (target API, package identity, adaptive icons, permissions, data safety, account deletion) and Android core app quality.
---

# Google Play Review Check

## Overview
Pre-submission audit against the gates Google Play actually enforces (policy + core app quality), not generic lint. Run every check; report PASS/FAIL/BLOCKER with the fix. A BLOCKER = Play will reject or policy-flag the app.

## When to Use
- Before first store upload or any release candidate
- After touching `android/`, launcher icons, permissions, or auth/account flows
- NOT for in-app design-system rules — `scripts/validate.sh` owns those (run it too)

## The Gates (June 2026)

| # | Gate | Requirement | Check |
|---|------|-------------|-------|
| 1 | **Package identity** | `applicationId` must NOT be `com.example.*` (hard rejection); renaming later orphans installs + Firebase | `grep applicationId android/app/build.gradle*` |
| 2 | **Target API** | New apps/updates: API 35 now; **API 36 from 2026-08-31**. Flutter: `targetSdk = flutter.targetSdkVersion` resolves from the SDK — verify resolved value | `cd android && ./gradlew :app:properties \| grep -i targetSdk` or check `flutter.targetSdkVersion` |
| 3 | **Adaptive icon** | `mipmap-anydpi-v26/ic_launcher.xml` with fore/background layers; `monochrome` layer for Android 13+ themed icons; no legacy-only PNG | `ls android/app/src/main/res/mipmap-anydpi-v26/` |
| 4 | **Permissions** | Manifest carries only used permissions; dangerous ones (location, camera, media) each need an in-context rationale + Play Console declaration | `grep uses-permission android/app/src/main/AndroidManifest.xml` — justify each |
| 5 | **Edge-to-edge** | Targeting 35+ enforces edge-to-edge: every screen must handle insets (`SafeArea`/`MediaQuery.padding`); no `setStatusBarColor` reliance | spot-check Scaffolds; test on Android 15 device |
| 6 | **Account deletion** | Apps with account creation MUST offer in-app deletion AND a web deletion URL (declared in Play Console Data safety) | find delete-account flow in app + URL |
| 7 | **Data safety form** | Every collected data type (email, phone, location, photos) declared; privacy policy URL live | inventory collection points vs Console form |
| 8 | **Release artifact** | AAB (not APK) for Play; release signing config not `debug`; R8/shrink enabled | `grep -A5 buildTypes android/app/build.gradle*` |
| 9 | **Core quality** | 48dp touch targets, content labels on icon-only buttons, OS back works everywhere, state survives rotation/process-death on critical forms | house: `validate.sh` + manual pass |
| 10 | **Pre-launch report** | Upload to internal track first; fix every crash + accessibility flag in Play's pre-launch report before promoting | Play Console → Internal testing |

## Output Format
One line per gate: `PASS / FAIL / BLOCKER — evidence — fix`. BLOCKERs first. Never claim store-ready with an open BLOCKER.

## Common Mistakes
- Shipping `com.example.*` because "it installs fine locally" — Play rejects at upload; rename BEFORE first release (after release it's permanent).
- Assuming Flutter defaults pass gate 2 — pin/verify the resolved targetSdk, don't trust memory.
- Declaring zero data collection while using Supabase auth (email/phone = collected data).
- Treating this as one-time — re-run on every release branch.

## Sources
[Target API policy](https://developer.android.com/google/play/requirements/target-sdk) · [Play target API help](https://support.google.com/googleplay/android-developer/answer/11926878) · Core app quality: developer.android.com/docs/quality-guidelines/core-app-quality · Account deletion policy: support.google.com/googleplay/android-developer/answer/13327111
