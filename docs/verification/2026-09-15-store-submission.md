# Store submission — 1.0.3 (9)

The user explicitly authorized App Store and Google Play release submission.
No additional release approval is needed; store access and review requirements
still apply. No source changes or git push are part of this store submission.

## Artifacts

- Android: `build/app/outputs/bundle/release/app-release.aab`, verified package
  `au.com.jobdun.app`, version `1.0.3 (9)`, target API 36, configured upload key.
  SHA-256: `e8ced1cd840f12a53449b2bd3c2b8eef0ed6f8399f4a20615ba79f5e7a31ecd4`.
- iOS: `build/ios/ipa/Jobdun.ipa`, verified bundle `au.com.jobdun.app`, version
  `1.0.3 (9)`, arm64, iPhoneOS 26.5 SDK from Xcode 26.6, Cloud Managed Apple
  Distribution. IPA export succeeded.
  SHA-256: `1c49859486f31de31942a07d4f08415512a767e6e155a1b7c2dee64a2a3ac72b`.
- Release notes: `docs/releases/1.0.3-store-notes.txt`.
- Shared-code verification: `2026-09-15-apprenticeship-release.md` and
  `2026-09-15-apprenticeship-validation.txt`. No app code changed afterward.

## Access

Brave AppleScript execution returns: “Executing JavaScript through AppleScript
is turned off.” System Events reports UI elements disabled. Workspace sandbox
permissions do not change either macOS/browser setting. Both store consoles
were opened in Brave. User was asked to enable View → Developer → Allow
JavaScript from Apple Events and sign in to both consoles. No browser security
setting was bypassed, and no session cookies or unrelated credentials were read.
No configured Google Play publisher or App Store Connect API credentials were
found in the project's release configuration or standard API-key directories.
Xcode's existing signed-in account is used for the supported iOS upload path.

## Submission audit

### Google Play

- BLOCKER — Console Data safety and permission declarations cannot be inspected
  until browser access is enabled; confirm against app collection behavior.
- BLOCKER — AAB upload/pre-launch report and production review submission pending.
- PASS — package identity matches `au.com.jobdun.app`.
- PASS — target API 36 verified in signed bundle manifest.
- PASS — existing adaptive foreground/background/monochrome icon configuration.
- PASS in code — permissions serve existing app capabilities; Console declaration
  remains unverified.
- PASS for inspected screens — Android API 36 screenshots captured and inspected;
  this is not an exhaustive device/accessibility certification.
- PASS in code — in-app deletion and configured web deletion route unchanged.
- PASS — signed AAB, upload certificate match, R8/resource shrinking enabled.
- PASS automated — full repository validation plus live guest browse and fixture
  flow tests; pre-launch report remains outstanding.

### Apple

- BLOCKER — App Store Connect metadata, reviewer account, screenshots, age-rating
  answers and final review submission cannot be inspected through the console.
- PASS — correct bundle identifier and `1.0.3 (9)` version.
- PASS — Xcode 26.6 / iOS 26.5 SDK, arm64.
- PASS — specific camera, photos and optional location purpose strings.
- PASS — app privacy manifest present in exported IPA.
- PASS in code/config — Sign in with Apple and shared in-app account deletion
  unchanged; new physical-device interaction tests were not run this turn.
- PASS — non-exempt-encryption flag is false, matching existing configuration.
- PASS — existing AppIcon included; IPA export validation passed.
- PASS — Cloud Managed Apple Distribution signing and IPA export.

References checked:
[Apple upload workflow](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds),
[Apple review submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app),
[Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/),
[Google Play upload workflow](https://developer.android.com/studio/publish/upload-bundle),
[Google Play target requirements](https://support.google.com/googleplay/android-developer/answer/11926878).


## Build 9 delivery result and Apple follow-up

Xcode upload completed successfully (`Upload succeeded`, `Uploaded Runner`,
`EXPORT SUCCEEDED`). Apple subsequently emailed ITMS-90683: the exported app
referenced always-location APIs without an always-location purpose string.
Delivery succeeded, but build 9 is superseded by the corrective build below.

The exported build 9 IPA reproduced this exact mismatch in
`geolocator_apple.framework`. Jobdun requests foreground location only; no
background location mode is configured. The plugin's documented
`BYPASS_PERMISSION_LOCATION_ALWAYS=1` compiler flag was missing from the Podfile.
The fix compiles out the unused API in all geolocator_apple configurations,
retains the truthful foreground purpose string and existing preprocessor flags,
and increments the app build to 10.

`scripts/check_ios_location_permissions.py` scans Mach-O binaries in the actual
IPA and checks the corresponding Info.plist declarations. It fails on the
original build 9 with the framework name and missing-key error. Corrected build 10 passed the same scan: foreground location declared,
always-location API references = 0. The compiled plugin retains
`requestWhenInUseAuthorization`. No background location mode was added.

Build 10 IPA export succeeded with Cloud Managed Apple Distribution signing.
SHA-256: `10a0c7b5f4161d2907d2391d3a1f204c2aa1f26f286ae114b17542d47d4e6fb8`.
Source version is now `1.0.3+10`; the existing Android artifact remains build 9
because this correction changes only iOS native compilation. Full `bash scripts/validate.sh` completed with exit 0, all checks passed.
Summary: `2026-09-15-ios-location-validation.txt`.

**Build 10 upload succeeded.** Xcode completed with exit 0 and reported
`Uploaded package is processing`, `Upload succeeded`, `Uploaded Runner` and
`EXPORT SUCCEEDED` at 11:53:42 on September 15. Apple processing and App Review
submission are not yet confirmed complete. Select iOS `1.0.3 (10)` for the
review submission instead of build 9.

Upload command:

```bash
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist /private/tmp/jobdun-1.0.3-upload.plist \
  -exportPath /private/tmp/jobdun-1.0.3-10-upload \
  -allowProvisioningUpdates
```

The export options use `destination=upload`, `method=app-store-connect`, team
`3Q4P2CVMJK`, automatic signing and `manageAppVersionAndBuildNumber=false`.
The browser-access blocker for final store-console submission remains unchanged.

Reference: [Geolocator iOS configuration](https://pub.dev/packages/geolocator).
