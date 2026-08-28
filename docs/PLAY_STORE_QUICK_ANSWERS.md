# Play Console — copy/paste answers (v1.0 submission)

Pure copy-paste sheet, ordered the way Play Console's own "1 of 11 complete"
checklist presents it. Full reasoning/audit lives in `PLAY_STORE_METADATA.md`
— this file is just the fast version to keep open next to the browser tab.

---

## ✅ Already done — skip these

- Privacy policy set
- Package `au.com.jobdun.app` registered + verified (Android developer verification)
- AAB built: `build/app/outputs/bundle/release/app-release.aab` (versionCode 5, signed)
- 512 icon: `docs/store-assets/play-store-icon-512.png`
- Feature graphic: `docs/store-assets/play-feature-graphic-1024x500.png`
- Demo account password rotated + verified live (2026-07-21)

## 🔴 Still open

- Phone screenshots (need a real Android device reconnected — 2 minimum)
- App-signing SHA-1 → Firebase (separate flow, see bottom of this doc — confirm this got saved)

---

## 1. Sign in details

**Is any part of your app restricted?** → **Yes**

| Field | Value |
|---|---|
| Name | `Trade demo account` |
| Username / email / phone | `appreview@jobdun.com.au` |
| Password | `JdDamFUp3Qtq2g!` |

**Any other information required for access** (500-char box):
```
Job browsing needs no account. On the last intro screen tap 'BROWSE OPEN JOBS' (or 'Browse open jobs' on the log-in screen) for the public job board — live jobs, search, filters, full details, no sign-in. Sign in above only for gated actions: apply, post a job, message. Demo account is Trade role, pre-onboarded, lands on home feed. For Builder, register free — no payment anywhere.
```

Bottom checkbox ("provides full access... including premium or paid content") → **check it**.

---

## 2. Ads

→ **No** — the app contains no ads and no ad SDKs.

---

## 3. Content rating

**Category:** All Other App Types

**Questionnaire** (current Play Console flow — verified live 2026-07-22,
supersedes the older classic-IARC layout):

| Question | Answer |
|---|---|
| Ratings-relevant content shipped in the app package (code/assets) | No |
| User Content Sharing — voice/text/image/audio exchange between users | **Yes** — job-scoped messaging, profile + portfolio photos, in-app report/block + staff moderation |
| Online Content — content not in the download, fetched from the app (like Netflix/Spotify's examples) | **Yes** — job listings, profiles, messages are all live Supabase data |
| Promotion/sale of age-restricted products (cigarettes, alcohol, firearms, gambling) | No |
| Shares user's precise physical location with other users | No — job site locations are builder-entered suburbs, never the user's live device location |
| Allows purchase of digital goods | No |
| Cash rewards / gift cards / play-to-earn / crypto / NFTs | No |
| Web browser or search engine | No |
| Primarily news or educational product | No |

**Sub-branch after "User Content Sharing → Yes"** (verified live 2026-07-23):

| Question | Answer |
|---|---|
| Is user-generated content the primary source of content in the app? | **Yes** — job listings, profiles, portfolio photos, and messages are all user-created; Jobdun supplies no editorial content itself |
| Permits public sharing of nudity | No |
| Permits public sharing of real-world graphic violence outside newsworthy context | No |
| Ability to block users or user-generated content | **Yes** — messaging inbox block/report/mute |
| Ability to report users or user-generated content | **Yes** — feeds the staff moderation console |
| Chat moderation | **Yes** — staff moderation console reviews reported content |
| Interactions limited to invited-friends-only | No — no "friends" concept; any tradie can apply to any open job |

Email for the rating certificate: `ken@jobdun.com.au`

Expected outcome: low rating with a "Users Interact" / "Shares Location"-style
notice from the Online Content + User Content Sharing answers.

---

## 4. Target audience

→ **18 and over** only. Do **not** tick any age group under 18 — this keeps
the Families policy requirements from activating.

---

## 5. Data safety

**Overview screen:** data **is collected**; nothing is **shared** (Supabase,
Firebase FCM, Sentry are service providers under Play's definition, not
"sharing"). All transfers encrypted in transit. Users can request deletion.

**Account creation methods** (multi-select): check **Username and password**
(email sign-up), **Username and other authentication** (SMS/phone + OTP, no
password), **OAuth** (Google + Apple Sign-In). Leave "Username, password,
and other authentication" and "Other" unchecked.

### Full data-type checklist (every category walked + verified in code, 2026-07-23)

Play asks each collected type through a few sub-screens in this order:
**Collected? → Shared? → Purpose → Optional/Required.** Every row below that's
collected gets **Shared = No** — either it's shown to other app users (core
functionality, not "third-party sharing" under Play's definition) or it goes
to Supabase/Firebase/Sentry as a service provider (also exempt from
"sharing"). No exceptions in this app — nothing goes to an actual third
party like an ad network or data broker.

| Category | Data type | Collected? | Shared? | Optional? | Purpose |
|---|---|---|---|---|---|
| Location | Approximate location | Yes | No | Optional ("jobs near me" map) | App functionality |
| Location | Precise location | Yes | No | Optional ("jobs near me" map) | App functionality |
| Personal info | Name | Yes | No | Required | Account management, App functionality |
| Personal info | Email address | Yes | No | Required | Account management |
| Personal info | User IDs | Yes | No | Required | Account management |
| Personal info | Phone number | Yes | No | Optional (SMS sign-in only) | Account management |
| Personal info | Address, Race/ethnicity, Political/religious beliefs, Sexual orientation, Other info | No | — | — | — |
| Financial info | User payment info, Purchase history, Credit score, Other financial info | No | — | — | — (no payment processing anywhere in the app) |
| Health and fitness | Health info, Fitness info | No | — | — | — |
| Messages | Other in-app messages | Yes | No | Optional | App functionality |
| Messages | Emails, SMS or MMS | No | — | — | — (SMS is used to *deliver* an OTP, app never reads the SMS inbox) |
| Photos and videos | Photos | Yes | No | Optional (avatar, portfolio, credential docs) | App functionality |
| Photos and videos | Videos | No | — | — | — (no video feature exists) |
| Audio files | Voice recordings, Music files, Other audio | No | — | — | — |
| Files and docs | Files and docs | No | — | — | — (`file_picker` is an unused dependency; verification docs go through the same image pipeline as photos, `ImageAspect.free`) |
| Calendar | Calendar events | No | — | — | — (`table_calendar` is a UI date-grid widget only, no device calendar sync; revisit if a real calendar-sync feature ships later) |
| Contacts | Contacts | No | — | — | — (no contacts package in the app at all) |
| App activity | App interactions | No | — | — | — (no analytics SDK; Sentry's `breadcrumb()` helper is defined but never actually called anywhere) |
| App activity | In-app search history | No | — | — | — (search queries fetch results and are discarded, never persisted) |
| App activity | Installed apps | No | — | — | — |
| App activity | Other user-generated content | **Yes** | No | Optional | App functionality — job posts + reviews (text content) |
| App activity | Other actions | No | — | — | — |
| App info & performance | Crash logs | Yes | No | Required | Analytics (Sentry) |
| App info & performance | Diagnostics | Yes | No | Required | Analytics (Sentry) |
| App info & performance | Other app performance data | **Yes** | No | Required | Analytics — Sentry performance tracing is enabled (`tracesSampleRate` in `main.dart`, 10% sample in release) |
| Device or other IDs | Device or other IDs | Yes | No | Required | App functionality (FCM push token) |

Everything marked No above (financial, health, contacts, calendar, audio,
files, installed apps, advertising ID, emails/SMS content) → **Not collected**.

| Question | Answer |
|---|---|
| Encrypted in transit | Yes |
| Deletion mechanism | Yes — in-app: Profile → Settings → Delete account |
| Data deletion URL | `https://www.jobdun.com.au/delete-account` (canonical — `200` direct; non-www 308-redirects to this) |
| Partial data deletion without full account deletion | **No** — the in-app feature is real (`removeAvatar()` / `removePortfolioImage()`), but no public page documents steps/retention for *partial* deletion specifically (checked the live delete-account page content — it's full-account-only), and Play requires a qualifying URL for "Yes". Revisit once `jobdun-web` has a dedicated page. |

---

## 6. Government apps / Financial features / Health

| Question | Answer |
|---|---|
| News app | No |
| COVID-19 app | No |
| Government app | No |
| Financial features | None of the above |
| Health features | No health features |

---

## 7. App category + contact details

| Field | Value |
|---|---|
| App category | **Business** |
| Tags (if prompted) | Business, Productivity, or "Jobs/Employment" if offered |
| Email (public) | `support@jobdun.com.au` — recommended over `ken@jobdun.com.au` for consistency with the privacy policy, which now routes everything to this one monitored address |
| Phone (optional) | a number you actually answer |
| Website | `https://jobdun.com.au` |

---

## 8. Store listing

**App name:**
```
Jobdun
```

**Short description** (≤80 chars):
```
Jobs for tradies. Crews for builders. Post work or land it.
```

**Full description** (≤4000 chars):
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

**Graphics:**
| Asset | File |
|---|---|
| App icon (512×512) | `docs/store-assets/play-store-icon-512.png` |
| Feature graphic (1024×500) | `docs/store-assets/play-feature-graphic-1024x500.png` |
| Phone screenshots (2–8) | 🔴 not yet captured — reconnect the device |

---

## 9. Countries

→ **Australia only**.

---

## 10. App signing → Firebase (do this before testing Google Sign-In)

1. Play Console → **Test and release → Setup → App signing** (or under
   **App integrity** on some layouts) → copy the **App signing key
   certificate SHA-1** (a *different* box from "Upload key certificate" —
   don't grab that one).
2. Firebase console → project `jobdun-627d2` → Android app
   `au.com.jobdun.app` → **Add fingerprint** → paste it → Save.

---

## 11. Release + submit

1. **Test and release → Production → Create new release.**
2. Upload `build/app/outputs/bundle/release/app-release.aab`.
3. Add release notes, e.g.:
   ```
   Guest job browsing, Sign in with Apple fixes, and general improvements.
   ```
4. Review release → confirm no warnings → **Send for review** (or **Start
   rollout to Production** depending on the exact button wording on your
   screen).

That last step is what starts Google's review clock.
