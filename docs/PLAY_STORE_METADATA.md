# Google Play Console — v1.0 submission pack

Copy-paste content for every Play Console form, in the order the console
asks for them. Verified against the live site/DB/artifact on 2026-07-10.
Companion audit: `.claude/skills/play-review-check` — gates 1–9 PASS at
commit `20fa1fe` (evidence below); gate 10 is the pre-launch report, which
only exists after the first internal-track upload.

Sibling doc: `docs/APP_STORE_METADATA.md` (iOS). The review demo account and
most listing copy are shared between the two.

---

## Audit result (2026-07-10)

| # | Gate | Verdict | Evidence |
|---|------|---------|----------|
| 1 | Package identity | PASS | `au.com.jobdun.app` in gradle namespace+appId, MainActivity, deep link, google-services.json |
| 2 | Target API | PASS | resolves to **36** (Flutter 3.41.7) — already meets the 2026-08-31 API-36 mandate |
| 3 | Adaptive icon | PASS | `mipmap-anydpi-v26` with background + foreground + monochrome layers |
| 4 | Permissions | PASS | merged release manifest: INTERNET, fine/coarse location (foreground only), POST_NOTIFICATIONS, NETWORK_STATE, VIBRATE, WAKE_LOCK, biometric (secure-storage lib). No background location, no CAMERA |
| 5 | Edge-to-edge | PASS (static) | targetSdk 36 enforces; transparent-status-bar baseline in `main.dart` + 65 `SafeArea` uses. One manual device sweep still owed — see QA section |
| 6 | Account deletion | PASS | in-app: Profile → Settings → Delete account (`delete_my_account` RPC). Web: `https://jobdun.com.au/delete-account` → 200 |
| 7 | Data safety | READY | full form answers below; privacy policy `https://jobdun.com.au/privacy` → 200 |
| 8 | Release artifact | PASS (proven) | `flutter build appbundle --release` → 58.8 MB AAB, R8+shrink on, signer SHA1 == upload-keystore SHA1 (`B7:A8:8A:86:63:35:6C:C4:79:FA:69:8D:01:9B:26:27:16:F1:8E:2D`) |
| 9 | Core quality | PASS | `scripts/validate.sh` + CI green on develop (clean, pushed) |
| 10 | Pre-launch report | PENDING | run after first internal upload — fix every crash + accessibility flag before production |

---

## Session update (2026-07-21)

- **AAB rebuilt at versionCode 5** (`1.0.0+5`) from branch
  `fix/appstore-guest-browse-siwa` — includes the guest-browsing +
  Sign-in-with-Apple fixes built for the Apple 5.1.1(v) rejection (see
  `docs/APP_REVIEW_REPLY_1.0-5.md`). Same guest-browse code now ships on
  Android too. Re-verified: signer SHA1 == upload-keystore SHA1
  (`B7:A8:8A:86:...:8E:2D`), `flutter analyze` clean, 58.9 MB —
  `build/app/outputs/bundle/release/app-release.aab`.
- **Feature graphic generated** — `docs/store-assets/play-feature-graphic-1024x500.png`
  (composited from the real `jobdun-icon-foreground.png` mark + wordmark on
  `#0F172A`, deterministic not AI-generated). Closes the Graphics TODO below;
  swap for a hand-designed version later if wanted, not required to submit.
- **512 store icon generated** — `docs/store-assets/play-store-icon-512.png`
  (`sips -z 512 512` from the real launcher icon, 19 KB).
- **Phone screenshots still open** — needs a real Android device reconnected
  (it dropped off adb mid-session); none captured yet.
- **Demo account password rotated + verified live** (2026-07-21): reset via
  Supabase Admin API (`auth/v1/admin/users/{id}`) and confirmed with an
  actual password-grant sign-in (access token issued). Closes the "signs in
  on the release build" QA item below — same account on iOS, one rotation
  covers both. Value intentionally not written here, same redaction policy
  as the rest of this doc — rotate again the same way if it's lost.
- **"App access" is now called "Sign in details"** in the current Play
  Console UI — section below renamed and its instructions updated to
  disclose guest browsing (the old copy undersold the app as fully
  login-gated, which stopped being true this session).

---

## Step 0 — Developer account (do this first; verification takes days)

- Register at play.google.com/console as an **Organization**: JOBDUN PTY LTD.
  One-time US$25 fee. You'll need the **D-U-N-S number** — the same one used
  for the Apple Developer org enrollment.
- Identity verification for org accounts is measured in days, not minutes —
  kick it off before preparing anything else.
- Console will publicly display a developer email (and website) on the
  listing. Use `ken@jobdun.com.au` / `https://jobdun.com.au`.
- ⚠️ While you wait: **back up `android/upload-keystore.jks` +
  `android/key.properties`** somewhere off this Mac (password manager +
  encrypted drive). They exist only on this machine.

## Step 1 — Create app

| Field | Value |
|---|---|
| App name | `Jobdun` (matches iOS) — or `Jobdun: Tradie Jobs & Crews` (27/30 chars) if you want search keywords in the title; changeable later |
| Default language | English (Australia) — en-AU |
| App or game | App |
| Free or paid | Free (permanent once published) |
| Declarations | tick Developer Program Policies + US export laws |

## Step 2 — First upload (internal testing track)

The store artifact is already proven from this repo:

```bash
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

1. **Testing → Internal testing → Create new release.**
2. Accept **Play App Signing** when prompted (Google holds the app key; our
   `.jks` becomes the upload key). Console will show the upload key
   fingerprint — it must match `B7:A8:8A:86:...:8E:2D` above.
3. Upload the AAB, name the release `1.0.0 (1)`, save + roll out to internal.
4. Add testers (your gmail + the boss) via an email list; share the opt-in
   link; install from Play.
5. Every later upload needs a **versionCode bump**: edit `pubspec.yaml`
   `version: 1.0.0+2`, `+3`, … and rebuild.

Because this is an **organization** account, the 12-testers-for-14-days
closed-testing requirement does **not** apply (personal accounts only) —
internal → production is allowed as soon as the forms are done.

## Step 3 — ⚠️ Google Sign-In will break on Play builds until you do this

Play re-signs the app with the **app signing key**, whose SHA-1 differs from
the upload/debug keys already registered. Google SSO then fails only on
Play-delivered installs — the classic silent production breakage.

Right after the first upload:

1. Play Console → **Test and release → Setup → App integrity → App signing**
   → copy the **App signing key certificate SHA-1**.
2. Firebase console → project `jobdun-627d2` → Android app `au.com.jobdun.app`
   → **Add fingerprint** → paste it. (Android OAuth clients are console-only;
   they live in the same GCP project as the web client — same gotcha as the
   2026-06-11 rename.)
3. Optionally re-download `google-services.json` (tidy, not required — SHA
   lookup happens server-side).
4. **Smoke test Google sign-in from the internal-track install** — this is
   the outstanding item from the June audit. Apple/email/SMS sign-in are
   unaffected by signing.

## Store listing (Grow → Store presence → Main store listing)

### Short description (≤80 chars)

```
Jobs for tradies. Crews for builders. Post work or land it.
```
(59 chars. Alternative, 78 chars: `Tradie jobs & crews for builders. Real quotes, verified profiles, direct chat.`)

### Full description (≤4000 chars — same copy as iOS)

```
Jobdun connects Australian builders with the tradies and crews they need — and gives tradies a straight line to real, local work.

FOR TRADIES & CREWS
• Browse open jobs — carpentry, electrical, plumbing, bricklaying, landscaping and more
• Quote your own price. No bidding wars, no lead fees
• Build a profile that proves your work: credentials, portfolio photos, and reviews from real jobs
• Chat directly with builders once you've applied
• Track every application from pending to hired

FOR BUILDERS
• Post a job in minutes — set your budget, timeframe and site location
• See credentials before you shortlist: licences and insurance reviewed by the Jobdun team
• Compare quotes, shortlist, and hire without the phone tag
• Message applicants and manage the whole job from your phone

BUILT FOR THE AUSSIE INDUSTRY
• Credential documents reviewed by our team
• Local suburbs, local rates, local trades
• Straightforward sign-in: Apple, Google, email or SMS

Your next job — or your next crew — is already on Jobdun.

Questions? We're at jobdun.com.au/contact
```

### Graphics

| Asset | Spec | Status / how |
|---|---|---|
| App icon | 512×512 PNG ≤1 MB | DONE — `docs/store-assets/play-store-icon-512.png` |
| Feature graphic | 1024×500 PNG/JPEG, **required** | DONE — `docs/store-assets/play-feature-graphic-1024x500.png` (real icon mark + wordmark, flat `#0F172A`, no screenshot collage) |
| Phone screenshots | 2–8, PNG/JPEG, sides 320–3840 px | Capture on a **real Android device post-rebrand** — no AVD exists on this Mac and `docs/verification/` PNGs (June 15–19) predate the final logo. Same shot list as iOS: feed, job detail + APPLY WITH QUOTE, applications, messages, profile. First 3 matter most |
| Video | optional | skip for v1.0 |

House rule applies: real app screenshots only — no mockups.

## App content (Policy → App content) — every questionnaire

### Privacy policy
`https://jobdun.com.au/privacy` (verified 200)

### Sign in details (formerly "App access") — "Is any part of your app restricted?" → **Yes**
Same demo account as iOS review. Play's current form asks for these exact
fields:

- Name: `Trade demo account`
- Username/email/phone: `appreview@jobdun.com.au`
- Password: rotated + verified live 2026-07-21 (Supabase Admin API reset +
  password-grant sign-in test, access token issued). Not written here —
  redacted like the rest of this doc; rotate again the same way if lost.
- "Any other information required for access" (500-char field):
  ```
  Job browsing needs no account. On the last intro screen tap 'BROWSE OPEN
  JOBS' (or 'Browse open jobs' on the log-in screen) for the public job
  board — live jobs, search, filters, full details, no sign-in. Sign in
  above only for gated actions: apply, post a job, message. Demo account is
  Trade role, pre-onboarded, lands on home feed. For Builder, register free
  — no payment anywhere.
  ```
- Bottom checkbox ("provide full access to all features... including
  premium or paid content"): **check it** — no paid tiers exist, and the
  Builder side is reachable via free self-registration per the notes above.

### Ads
**No** — the app contains no ads and no ad SDKs.

### Content rating
Category: **All Other App Types**. Play's current questionnaire (verified
live 2026-07-22 — this replaced the older classic-IARC violence/sexuality/
language/gambling layout shown in earlier drafts of this doc):

- Ratings-relevant content shipped in the app package (code/assets): **No**
- User Content Sharing (voice/text/image/audio exchange between users):
  **Yes** — job-scoped messaging, profile + portfolio photos, in-app
  report/block + staff moderation console
- Online Content (content not in the download, fetched from the app —
  Play's own examples are Netflix movies / Spotify songs / news articles):
  **Yes** — job listings, profiles, messages are all live Supabase data
- Promotion/sale of age-restricted products (cigarettes, alcohol, firearms,
  gambling): **No**
- Shares user's precise physical location with other users: **No** (job
  locations are builder-entered site suburbs, never the user's device
  location)
- Digital purchases: **No**
- Cash rewards / gift cards / play-to-earn / crypto / NFTs: **No**
- Web browser or search engine: **No**
- Primarily news or educational product: **No**
- Email for the rating certificate: `ken@jobdun.com.au`
- Expected outcome: low rating with a "Users Interact"-style notice.

### Target audience
Age groups: **18 and over** only. App does not appeal to children →
Families policy requirements never activate.

### News app: **No** · COVID-19 app: **No** · Government app: **No** ·
Financial features: **None of the above** · Health: **No health features**

### Data safety (exact answers)

Overview: data **is collected**, nothing is **shared** (Supabase, Firebase
FCM and Sentry process it on our behalf = service providers, not "sharing"
under Play's definition). All transfers encrypted in transit. Users can
request deletion.

| Data type | Collected? | Optional? | Purpose |
|---|---|---|---|
| Personal info → Name | Yes | Required | Account management, App functionality |
| Personal info → Email address | Yes | Required | Account management |
| Personal info → Phone number | Yes | Optional (only SMS sign-in) | Account management |
| Personal info → User IDs | Yes | Required | Account management |
| Photos and videos → Photos | Yes | Optional (avatar, portfolio, credential docs) | App functionality |
| Location → Approximate + Precise | Yes | Optional ("jobs near me" map) | App functionality |
| Messages → Other in-app messages | Yes | Optional | App functionality |
| App info & performance → Crash logs | Yes | Required | Analytics (crash reporting — Sentry) |
| App info & performance → Diagnostics | Yes | Required | Analytics (Sentry) |
| Device or other IDs | Yes | Required | App functionality (FCM push token) |

Everything else (financial, health, browsing history, contacts, calendar,
audio, files, installed apps, advertising ID): **Not collected**.

- Encrypted in transit: **Yes**
- Deletion mechanism: **Yes** — in-app (Profile → Settings → Delete account)
- Data deletion URL: `https://jobdun.com.au/delete-account` (verified 200)

## Countries

**Australia only** (Grow → Countries/regions). Reversible any time —
availability is a toggle, not part of app identity.

## Release path

1. Internal testing (Step 2) → install on a real device.
2. Manual QA on the internal build (below) + Google SSO smoke (Step 3).
3. **Check the pre-launch report** (Test and release → Pre-launch report):
   fix every crash and accessibility flag — gate 10.
4. Promote the same release to **Production** → staged rollout (start 20%,
   bump to 100% after a quiet day or two).
5. First production release goes into Google review — typically hours to a
   few days for a new developer account.

## Manual QA owed before production (from the audit)

- [ ] **Edge-to-edge sweep on an Android 15/16 device** (targetSdk 36
      enforces it): FTUE, login, home, jobs feed + detail, create-job form
      with keyboard open, messages thread with keyboard, profile, settings,
      map. Look for content hidden under the status bar / gesture bar /
      cutout. `adjustResize` is set; baseline overlay style is in `main.dart`.
- [ ] Google sign-in from a Play-delivered internal build (Step 3.4).
- [x] `appreview@jobdun.com.au` signs in on the release build — verified
      2026-07-21 via a live password-grant sign-in against the prod
      Supabase project (not just set-and-hope).
- [ ] Feed has 2–3 realistic open jobs so reviewers/first users see a live
      marketplace.

## Pre-submit checklist

- [ ] Play org account verified (Step 0) + keystore backed up off-machine
- [ ] App created (Step 1) + AAB uploaded to internal (Step 2)
- [ ] App-signing SHA-1 added to Firebase + SSO smoke passed (Step 3)
- [x] Store listing copy + 512 icon + feature graphic ready (`docs/store-assets/`)
- [ ] ≥4 real Android screenshots (post-rebrand) — still open, needs a
      reconnected device
- [ ] All App content questionnaires answered (this doc, section by section)
- [ ] Countries = Australia
- [ ] Pre-launch report clean
- [ ] Promote to Production (staged rollout)

## Housekeeping (non-blocking)

- `android/app/google-services.json` still contains the dead
  `com.example.jobdun` client entry — inert (plugin selects by
  applicationId), delete the old Firebase Android app + re-download the
  json whenever next in the Firebase console.
- Old debug/pre-split Android builds leaked the service-role + Twilio keys
  (2026-06-18 finding) — rotate them before public launch if not already done.
