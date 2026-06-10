---
name: app-store-review-check
description: Use when preparing the iOS app for App Store / TestFlight submission, before an iOS release build, when asked about Apple deployment readiness, or after changing the bundle identifier, Info.plist, entitlements, sign-in providers, or privacy manifest. Audits against real App Review gates (bundle id, SDK baseline, purpose strings, privacy manifest, Sign in with Apple, account deletion) — the Apple counterpart to play-review-check.
---

# App Store Review Check

## Overview
Pre-submission audit against the gates Apple actually enforces (App Review Guidelines + upload validation), not generic lint. Report PASS/FAIL/BLOCKER per gate with the fix. BLOCKER = upload rejection or guaranteed App Review rejection. Companion: `play-review-check` (run both before any release).

## When to Use
- Before first TestFlight/App Store upload or any iOS release candidate
- After touching `ios/`, sign-in providers, permissions usage, or privacy surface
- NOT for in-app design rules — `scripts/validate.sh` owns those

## The Gates (June 2026)

| # | Gate | Requirement | Check |
|---|------|-------------|-------|
| 1 | **Bundle identifier** | Real reverse-DNS id (no `com.example.*`); permanent after first upload; must match the App ID in the paid Apple Developer account | `grep PRODUCT_BUNDLE_IDENTIFIER ios/Runner.xcodeproj/project.pbxproj` |
| 2 | **SDK baseline** | Since **2026-04-28**: built with **Xcode 26 / iOS 26 SDK** or rejected at upload; arm64-only (no 32-bit slices) | `xcodebuild -version` on the build machine |
| 3 | **Purpose strings** | Every accessed capability needs an Info.plist usage description — for this app: `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`. Missing = instant rejection (ITMS-90683). Strings must say WHY, specifically | `grep UsageDescription ios/Runner/Info.plist` |
| 4 | **Privacy manifest** | `PrivacyInfo.xcprivacy` required: declared data collection (email, phone, location, photos via Supabase) + required-reason APIs (UserDefaults etc.). Flutter + plugins ship their own; the APP needs one too | `find ios -name "PrivacyInfo.xcprivacy"` |
| 5 | **Sign in with Apple** | MANDATORY (guideline 4.8) because the app offers Google Sign-In — must be wired AND visually equivalent on the login screen; needs the entitlement | `ls ios/Runner/*.entitlements` + login screen has both buttons |
| 6 | **Account deletion** | Guideline 5.1.1(v): in-app account deletion required (same flow as Play; already shared) | Settings → DELETE ACCOUNT exists |
| 7 | **Encryption export** | `ITSAppUsesNonExemptEncryption` key in Info.plist (`false` for HTTPS-only) or answer per-build in App Store Connect | `grep ITSAppUsesNonExemptEncryption ios/Runner/Info.plist` |
| 8 | **App icon** | Full AppIcon set + 1024×1024 marketing icon, **no alpha channel**, not the Flutter default | `ls ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| 9 | **Signing & account** | Paid Apple Developer Program membership, distribution certificate + provisioning profile (or Xcode-managed signing) | Apple Developer portal |
| 10 | **Review metadata** | Demo account credentials for App Review (app requires login), privacy policy URL, support URL, screenshots per device class | App Store Connect |

## Output Format
One line per gate: `PASS / FAIL / BLOCKER — evidence — fix`. BLOCKERs first. Never claim store-ready with an open BLOCKER.

## Common Mistakes
- Shipping Google Sign-In without Sign in with Apple — the single most common rejection for marketplace apps (4.8).
- Generic purpose strings ("This app needs your location") — App Review rejects vague strings; name the feature ("to show jobs near you").
- Forgetting the bundle-id rename must be coordinated with Android's applicationId rename + Firebase re-registration — do both renames in ONE pass.
- Testing only on Android and assuming Flutter parity — keyboard insets, safe areas, and the back-swipe gesture all need an iOS device pass.

## Sources
[Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/) · [App Review Guidelines 4.8 / 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/) · [Privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files) · Xcode 26 mandate (Apr 28 2026)
