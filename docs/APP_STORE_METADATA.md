# App Store Connect — v1.0 submission pack

Copy-paste content for every field on the iOS App Version page, plus the
App Information answers. Verified against the live site/DB on 2026-07-10.
Companion audit: `.claude/skills/app-store-review-check` (gates 1–9 PASS as of
commit `d75e880`; this file covers gate 10 — review metadata).

---

## Version page fields

### Promotional Text (≤170 chars — can be changed anytime without review)

```
Jobs for tradies. Crews for builders. Post work or land it — verified profiles, real quotes, and direct messaging. Built for Aussie job sites.
```

### Description (≤4000 chars)

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

### Keywords (≤100 chars, comma-separated, no spaces needed)

```
tradie,trades,construction,jobs,builder,labour hire,carpenter,electrician,plumber,quotes
```

(87 chars. "Jobdun" is excluded on purpose — the app name is already indexed.)

### URLs

| Field | Value | Status |
|---|---|---|
| Support URL | `https://jobdun.com.au/contact` | verified 200 |
| Marketing URL | `https://jobdun.com.au` | verified 200 |

(`/support` and `/terms` are 404 — do not use.)

### Version / Copyright

- Version: `1.0`
- Copyright: `2026 JOBDUN PTY LTD`

### Routing App Coverage File / App Clip / iMessage / Game Center

Skip all four — not applicable.

---

## App Review Information

### Sign-In Information — toggle "Sign-in required" ON

- User name: `appreview@jobdun.com.au`
- Password: *(the password set for this account on 2026-07-09 — verify it signs
  in on a production build before submitting)*

Account state (verified in prod DB): display name "App Review Tester",
Trade role, onboarding complete, active.

### Contact Information

- First/Last: Ken Garcia
- Phone: *(a number you actually answer — App Review does call)*
- Email: `ken@jobdun.com.au`

### Notes (≤4000 chars)

```
Jobdun is a two-sided job marketplace for the Australian construction industry. BUILDERS post jobs; TRADIES (trade contractors and crews) browse jobs and apply with a quoted price.

DEMO ACCOUNT (Trade role): sign in with the provided email + password using the email sign-in option. The account is pre-onboarded and lands on the home feed.

Quick tour:
1. Jobs tab — live job listings (real marketplace content, Australia-based; a small number of open listings is expected at this stage)
2. Open a job → APPLY WITH QUOTE to see the application flow
3. Applications tab — track application status
4. Messages — chat threads exist between a builder and a tradie in the context of a job application; blocking and reporting are built in
5. Profile — portfolio, credentials, reviews. Account deletion is in Profile → Settings → Delete account (Guideline 5.1.1(v))

Notes for review:
• To see the Builder side, register a fresh account with any email and choose the Builder role — there is no payment anywhere in the app
• Credential verification (licence/insurance uploads) is reviewed manually by our staff, so documents submitted during review will remain "pending" — expected behaviour
• Location permission is optional; all content is browsable without granting it
• Sign in with Apple, Google, email and SMS OTP are all supported; the demo credentials use the email option
```

### App Store Version Release

Choose **"Manually release this version"** — you control launch timing after
approval (flip to automatic on later releases if you prefer).

---

## Screenshots (6.5" slot: 1242×2688 or 1284×2778 px)

House rule applies: REAL app screenshots only (no mockups). Fastest path:

1. On the iPhone 17 Pro Max, screenshot these screens (side button + volume up),
   signed in as your own account so there's real content:
   1. Jobs feed (lead with core value — not the splash)
   2. Job detail with APPLY WITH QUOTE visible
   3. Applications tracker
   4. Messages thread
   5. Profile with portfolio/credentials
   6. FTUE/brand screen (new logo) — optional closer
2. AirDrop to the Mac. Native size is 1320×2868; resize to the accepted
   6.5" size with:
   ```bash
   mkdir -p appstore-shots && for f in IMG_*.PNG; do sips -z 2778 1284 "$f" --out "appstore-shots/$f" >/dev/null; done
   ```
   (0.4% aspect squeeze — visually undetectable.)
3. Upload in ASC; only the first 3 show on the install sheet, so order 1–3 above.

---

## App Information section (separate page — do this too)

- **Privacy Policy URL**: `https://jobdun.com.au/privacy` (verified 200)
- **Category**: Primary **Business**; Secondary **Productivity** (optional)
- **Age Rating — new social-media questions (deadline 2026-09-07)**, answer:
  - User-to-user communication: **Yes** — messaging between builder and tradie,
    tied to job applications (not open/anonymous chat)
  - User-generated content: **Yes** — profiles, portfolio photos, reviews,
    messages. Moderation in place: in-app reporting, user blocking, and a
    staff moderation console
  - Public sharing/social feed, follows/friends, live streaming, dating: **No**
  - Anonymous interaction: **No** — accounts are required
  - Expected outcome: low age rating with moderated-UGC declarations; the
    report + block + moderation trio satisfies Guideline 1.2
- **App Privacy (data collection)** — declare consistently with
  `PrivacyInfo.xcprivacy`: contact info (email, phone), user content (photos,
  messages), identifiers, coarse location (suburb) — all "linked to you",
  none used for tracking; no third-party ads

---

## Build upload

`flutter build ipa --release` produces `build/ios/archive/Runner.xcarchive`
and `build/ios/ipa/*.ipa`. Upload with either:

- **Xcode Organizer**: `open build/ios/archive/Runner.xcarchive` → Distribute
  App → App Store Connect → Upload (signed in as ken@jobdun.com.au), or
- **Transporter.app**: drag the `.ipa` in and Deliver.

`ITSAppUsesNonExemptEncryption=false` is already in Info.plist, so no export
compliance questions appear. After upload, the build shows on the version page
(~15–30 min processing) — select it under **Build**, then **Add for Review**.

## Pre-submit checklist

- [ ] Add 1–2 extra realistic open jobs from your builder account so the feed looks alive
- [ ] Confirm `appreview@jobdun.com.au` password signs in on the release build
- [ ] Screenshots uploaded (first 3 = feed, job detail, applications)
- [ ] App Information: privacy URL, category, age rating (incl. social questions)
- [ ] App Privacy questionnaire completed
- [ ] Build selected on the version page
- [ ] Contact phone/email filled → **Add for Review**
