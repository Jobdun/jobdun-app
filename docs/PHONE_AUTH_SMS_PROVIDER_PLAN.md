# Jobdun — Phone Auth SMS Provider Plan

> **Created:** 2026-05-27 on `chore/audit-followups-w1-w3`.
> **Trigger:** runtime error `AuthRetryableFetchException: Unable to get SMS provider (500)` when the wizard's new phone-verification gate sends users to `/profile/verify-phone`.
> **Status:** decision doc — no code change. Implementation is gated on the user picking a provider + signing up.

---

## TL;DR

The error is exactly what it says — Supabase Auth has no SMS provider wired up, so `signInWithOtp(phone: …)` fails at the gateway before a single byte of SMS hits a carrier. The Flutter side (`PhoneAuthService`) is correct; `supabase/config.toml` already has a Twilio block scaffolded but `enabled = false` and credentials empty. The whole gap is: pick an SMS provider, sign up, paste two credentials into the Supabase dashboard, flip a switch.

**Recommended provider: Twilio (Messaging API), with Verify API as a Phase 2 swap if costs balloon.** Reasons in §4. The same provider serves both your PH test number and your AU production audience — no provider swap needed when you cut over.

This doc covers: what the error means, what's already built, why Twilio over the alternatives, exact setup steps for both PH testing and AU prod, the new AU sender-ID register gotcha that will bite if ignored, cost projections at three traffic tiers, fraud / rate-limit guards, local-dev strategy that doesn't burn through real SMS credits, and open questions to resolve before implementation starts.

---

## 1. What the error actually is

```
AuthRetryableFetchException(
  message: {"code":"unexpected_failure","message":"Unable to get SMS provider"},
  statusCode: 500
)
```

Supabase Auth treats SMS as a pluggable provider channel. When `signInWithOtp` or `updateUser(phone: …)` fires, Auth (a) generates the OTP, (b) stores it server-side, (c) hands off to whichever provider is configured under `[auth.sms.*]`. With no provider configured, step (c) errors out — that's the 500 the client surfaces.

It is **not** a Twilio error, an account error, or a rate-limit issue. It's "no provider plugged in."

---

## 2. What's already built (evidence)

| Layer | Status | File |
|---|---|---|
| Flutter `PhoneAuthService` (sendOtp / verifyOtp / sendPhoneVerification / confirmPhoneVerification) | ✅ Wired | `lib/features/auth/data/services/phone_auth_service.dart` |
| `/phone-auth` route + `PhoneAuthPage` (sign-in via SMS) | ✅ Wired | `lib/app/router/app_router.dart:149` |
| `/profile/verify-phone` route + `PhoneAuthMode.addToAccount` (add phone to logged-in account) | ✅ Wired | `lib/app/router/app_router.dart:154-157` |
| DB trigger mirroring `auth.users.phone_confirmed_at` → `profiles.phone_verified_at` | ✅ Live | `supabase/migrations/20260514000002_phone_verified_sync.sql` |
| New phone-verified gate on `verify-abn` / `verify-licence` Edge Functions | ✅ Deployed (2026-05-27) | `supabase/functions/verify-abn/index.ts`, `supabase/functions/verify-licence/index.ts` |
| Supabase `[auth.sms.twilio]` config block in `config.toml` | ⚠️ Scaffolded, `enabled = false`, blank credentials | `supabase/config.toml:285-291` |
| Twilio account | ❌ Not created |
| Supabase dashboard → Auth → Providers → Phone | ❌ Not enabled |

Implication: **nothing on either side of the project needs new code.** This is purely an external-account + dashboard task.

---

## 3. The decision space

| Provider | AU coverage | PH coverage | Supabase-native | Approx cost AU (per SMS) | Approx cost PH | Notes |
|---|---|---|---|---|---|---|
| **Twilio (Messaging API)** | ★★★★★ | ★★★★★ | ✅ Native config block | A$0.0775 | A$0.045 | Industry default. Best documentation. Trial $15 credit. |
| **Twilio Verify API** | ★★★★★ | ★★★★★ | ⚠️ Not native — requires custom integration | A$0.085 per verification (multi-attempt bundled) | Same | Better for high-volume — single flat fee covers OTP retries via SMS/voice/email. Needs custom Edge Function instead of Supabase's built-in phone provider. |
| **MessageBird / Bird** | ★★★★ | ★★★★ | ✅ Native config block | A$0.045 | A$0.035 | ~40% cheaper than Twilio. Historically spottier Telstra delivery; reportedly fixed in 2024. Worse docs. |
| **Vonage (Nexmo)** | ★★★★ | ★★★★ | ✅ Native config block | A$0.055 | A$0.04 | Solid mid-tier. Less popular in Supabase ecosystem. |
| **TextLocal** | ★★ | ✗ | ✅ Native config block | n/a | n/a | India-focused. Skip. |
| **AWS SNS (via custom hook)** | ★★★★ | ★★★ | ❌ Requires Auth Hook + Lambda | A$0.0648 | A$0.038 | Cheapest at scale but adds infrastructure surface. Overkill for v2.1. |

---

## 4. Recommendation: Twilio Messaging API

Pick this for v2.1 launch. Reasons in order of weight:

1. **Native Supabase integration.** `[auth.sms.twilio]` is already in `config.toml` — paste two credentials and flip `enabled = true`. No Auth Hook, no Edge Function, no custom OTP logic. The alternative (Verify API) requires writing a custom Edge Function that intercepts auth flows — too much code for first launch.
2. **AU carrier coverage is the gold standard.** Twilio has had a local AU presence + Telstra peering since 2019. Deliverability to Telstra mobile (≈40% AU market share) is consistently >97% in independent benchmarks. MessageBird and Vonage are 90-95%.
3. **PH coverage is solid.** Globe + Smart both deliver normally. Your test number works out of the gate.
4. **Trial account is enough for the first month of dev.** US$15 credit ≈ 200 AU SMS / 350 PH SMS — comfortable for end-to-end testing without paying anything.
5. **Migration path is clean.** If volume grows past ~5000 verifications/month, swap to Twilio **Verify** API (same vendor, same account) which bundles retries under a flat fee — typically 30-40% cheaper at scale. The swap is just one Edge Function.

**Don't pick MessageBird/Bird** even though it's cheaper. The Telstra-coverage delta translates directly to your AU tradies not receiving codes, which is fatal for an optional-but-funnel-critical step. The savings (~$0.03/SMS) don't recover from a "I never got the code" support ticket.

**Don't pick Verify API yet** because it requires bypassing Supabase's built-in phone provider — you write a custom Edge Function that calls Verify, then manually flips `auth.users.phone_confirmed_at`. Worth doing when scale justifies it; not now.

---

## 5. Cost projection

Assumptions:
- Mix: 70% AU traffic, 30% non-AU (PH dev + edge international users)
- Average 1.4 SMS per successful verification (retries factored in)

| Stage | Verifications / month | Total SMS / month | Cost AU (Twilio Messaging) | Action |
|---|---|---|---|---|
| Internal dev (now) | 50 | 70 | ~A$5 | Free under trial credit |
| Closed beta (10-50 users) | 200 | 280 | ~A$20 | Upgrade to paid Twilio account |
| Launch (500-2k users / mo) | 1,500 | 2,100 | ~A$140 | Stay on Twilio Messaging |
| Scale (10k users / mo) | 8,000 | 11,200 | ~A$750 | **Evaluate Verify API** — likely saves A$200+/mo |

For comparison, the same volumes on MessageBird would be ~A$90 / A$420 — savings of ~A$50-330/mo, but with the carrier risk above.

Set a Twilio account spend cap at A$300/mo initially as a fraud floor — Twilio supports hard caps via Account Usage Triggers.

---

## 6. Setup steps

### 6.1 Twilio account

1. Sign up at <https://www.twilio.com/try-twilio>. Pick **Australia** as country (matters for trial number provisioning). Use a corporate email, not a Gmail.
2. Verify the signup phone (your PH number works fine for this — Twilio is just confirming you're a human).
3. From Console → **Account Info**, copy:
   - **Account SID** (starts `AC...`)
   - **Auth Token** (click to reveal)
4. Either:
   - **Easy path:** Buy a Twilio AU long-code (`+61...`) number. Console → Phone Numbers → Buy. ~A$1.50/mo. SMS-capable, works as sender ID. Copy the number.
   - **Slightly harder path:** Create a Messaging Service (Console → Messaging → Services → Create). Add the number above as a sender, OR use an alphanumeric sender ID like `JOBDUN` (free, but see §7 below for AU regulatory caveat).
   - Either way, copy the **Messaging Service SID** (starts `MG...`) — this is what Supabase wants in `message_service_sid`.

### 6.2 Supabase configuration

**Production (the linked project — `zethpanvkfyijislxesn`):**

1. Supabase Dashboard → **Authentication** → **Providers** → **Phone**.
2. Enable **Phone provider**.
3. Set **SMS provider** = `Twilio`.
4. Paste **Account SID**, **Auth Token**, **Messaging Service SID** (or phone number).
5. **OTP template:** keep the default `Your Jobdun code is {{ .Code }}. Valid for 60 seconds.` or customise — the `{{ .Code }}` placeholder is required.
6. **OTP length:** 6 (the default).
7. **OTP expiry:** 60 seconds (Supabase default).
8. **Phone confirmations:** ON. Forces explicit OTP entry; matches the existing `PhoneAuthService` contract.
9. Save.

**Local dev (`supabase/config.toml` — already scaffolded):**

```toml
[auth.sms.twilio]
enabled = true                                    # flip from false
account_sid = "AC...xxx"                          # from console
message_service_sid = "MG...xxx"                  # or a +61 phone number
auth_token = "env(SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN)"   # leave as-is
```

Then export the token in your shell (NEVER commit it):

```bash
export SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN="<paste-from-console>"
supabase start  # picks up the env var
```

Add the var name to `.gitignore`-safe documentation but the token itself goes in your local shell rc or `.envrc` if you use direnv.

### 6.3 Flutter app — no change needed

`PhoneAuthService` already uses `signInWithOtp` / `verifyOTP` / `updateUser` — those route through whatever Supabase has configured. Hot restart after enabling the provider and the existing UI lights up.

### 6.4 First test

1. Hot restart the app.
2. Sign in as `kenpatrickag21@gmail.com`.
3. Navigate to `/profile/verify-phone` (or trigger via the wizard's phone-required panel from the previous PR).
4. Enter your PH number, formatted **with country code**: `+639XXXXXXXXX`.
5. SMS should arrive within 10 seconds.
6. Enter the 6-digit code.
7. `auth.users.phone_confirmed_at` flips → trigger mirrors to `profiles.phone_verified_at`.
8. Return to the verification wizard — phone gate now passes, ABR check fires, you can complete the attestation flow.

---

## 7. Australian-specific compliance (read this before launch)

**ACMA Sender ID Register (effective rolling out late 2025-early 2026).** Australia is the first market to roll out mandatory sender ID registration to stop SMS spoofing. From the effective date, AU carriers (Telstra/Optus/TPG) will block unregistered alphanumeric sender IDs — meaning `JOBDUN` as a sender would arrive as `+61XXXX` (the carrier's failsafe) or get dropped entirely.

**Options:**

| Approach | Pros | Cons | Recommendation |
|---|---|---|---|
| Use a Twilio AU long code (`+61...`) | Works today, works after register goes live, no extra paperwork | Less branded — user sees a phone number, not "JOBDUN". Slightly higher per-SMS cost. | ✅ **Pick this for v2.1 launch.** |
| Register `JOBDUN` as an alphanumeric sender ID with ACMA via Twilio | Branded sender, higher trust | Paid (estimates ~A$3000-5000/year), takes 2-4 weeks lead time, ongoing compliance | Phase 2 — revisit at 5k+ users when brand recognition matters |
| Toll-free / short code | Excellent deliverability | Short codes are slow to provision (months) and very expensive (~A$1000/mo). Toll-free in AU is for voice only. | Skip |

**Spam Act 2003.** Transactional SMS (security codes, OTP) is exempt from the consent + unsubscribe rules — you're sending in response to a user action. Jobdun isn't sending marketing SMS, so no further compliance work needed. Document this in your Privacy Policy ("we send SMS only when you request verification or sign in").

**Carrier rejections.** A small percentage of AU mobile users have carrier-level SMS blocks (kids' phones on Telstra Smart, some prepaid plans). Surface a Twilio failure cleanly in the UI: "We couldn't send the code. Try a different number or use email sign-in instead." Don't silently retry forever.

---

## 8. Local dev strategy — don't burn SMS credits debugging

Supabase has a **test_otp** feature designed for this exact case. Skip the real Twilio call for known dev numbers:

```toml
# supabase/config.toml — already scaffolded, just uncomment + edit
[auth.sms.test_otp]
"639XXXXXXXXX" = "123456"          # your PH number → always returns 123456
"61400000001" = "123456"           # AU dev fixture
"61400000002" = "123456"           # AU dev fixture
```

Then when running `supabase start` locally, those numbers never hit Twilio; the OTP `123456` always passes verification. The app code is unchanged.

**Production must NOT have test_otp configured** — anyone could sign in as that number with a known code. The setting lives in `config.toml`, which only applies to local dev; the cloud project ignores it.

For staging/preview environments, use Twilio's test credentials (sandbox SID/token) which validate the integration without actually sending SMS. Console → Account → API Keys → Test Credentials.

---

## 9. Rate limits + fraud guards

Supabase has built-in limits — review the current values:

```toml
# supabase/config.toml
[auth.rate_limit]
sms_sent = 30                  # SMS per hour, per project (too low for prod)
sign_in_sign_ups = 30          # per 5min per IP
token_verifications = 30       # per 5min per IP
```

Recommendations:
- **Bump `sms_sent` to 200/hour** for production after launch. The default `30/hour` is enough to burn through during a single QA session.
- **Keep `token_verifications = 30/5min per IP`** — that's a sensible brute-force cap on guessing 6-digit codes (lockout after 30 tries, no realistic attacker beats that).
- **Set a Twilio Geo Permission allowlist:** Console → Messaging → Geographic Permissions. Allow only `AU` + `PH` (your test region) for the first 60 days. Saves you from a sudden Russia/Ukraine fraud spike costing $$$ overnight. Easy to expand later.
- **Set a Twilio Usage Trigger** at A$50/day. Account auto-suspends sending if hit. Email alert at A$25/day for early warning.

Application-side guards (Phase 2 if real fraud emerges):
- One phone number per user lifetime (don't let users sign in with the same number under multiple accounts — Supabase enforces uniqueness on `auth.users.phone` by default, just confirm it's on).
- Re-verification cap: don't let a user re-trigger SMS more than N times per hour. The existing `PhoneAuthService.resendOtp` flow already routes through Supabase, which has the `max_frequency = "5s"` floor.

---

## 10. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Twilio trial number can't send to PH | Low | Blocks first test | Trial covers PH. If specifically blocked, add the PH number as a Verified Caller ID in Twilio Console (trial requirement). |
| AU carrier rejects alphanumeric sender post-register | Medium | Codes don't deliver to AU tradies | Use a Twilio AU long-code from day one (per §7). |
| Twilio account fraud cost spike | Low-Medium | Surprise A$1000 bill | Account spend cap + geo allowlist + Usage Trigger alerts. |
| Supabase `sms_sent = 30/hour` cap hit during launch | Medium | Users see "rate limited" mid-onboarding | Bump to 200/hour in `config.toml` before launch announcement. |
| User mistypes country code (enters `0400...` instead of `+61400...`) | High | OTP fails silently | Force E.164 input via `intl_phone_number_input` package or similar in `PhoneAuthPage`. (Already on the package list? — verify.) |
| Test OTP leaks to prod | Low | Account takeover | `config.toml` test_otp is dev-only by design. Code review checklist: any test number in a migration = block merge. |
| User changes phone number — orphaned `phone_verified_at` | Medium | Stale identity anchor | Add a "change phone" flow that clears `phone_verified_at` before re-verifying. Out of scope for v2.1. |

---

## 11. Open questions before implementation

1. **Budget approval.** Are you OK with ~A$5-150/month in SMS costs scaling with verifications? If no, MessageBird halves it at the carrier-coverage risk above.
2. **Sender ID preference.** Long code (`+61...`) versus alphanumeric (`JOBDUN`) — the latter needs ACMA registration. Recommendation: long code for v2.1, revisit later. Confirm?
3. **Test_otp numbers in `config.toml`.** Want me to add your PH number + 2 AU dev fixtures as test_otp entries so local dev never hits real Twilio?
4. **PhoneAuthPage validation.** Does the existing page enforce E.164 format input (with country code picker)? If not, that's a small but important UX fix to bundle with this work — phone-format errors are the #1 source of "I never got the code" tickets.
5. **Twilio account ownership.** Who's the billing contact / payment method? Personal vs business credit card has consequences for chargebacks if there's ever an SMS pumping fraud incident.
6. **PH testing scope.** Just you, or do you want me to add a couple of fixture AU numbers (porting bypass numbers Telstra publishes) so we can dry-test AU delivery without a real AU SIM?

---

## 12. Implementation plan (post-approval)

Order matters — each step gates the next.

| # | Step | Owner | Time |
|---|---|---|---|
| 1 | Sign up for Twilio account, verify email + phone | User | 5 min |
| 2 | Buy AU long-code Twilio number (~A$1.50/mo) | User | 5 min |
| 3 | Create Messaging Service, attach the number, copy SID | User | 5 min |
| 4 | Set Twilio Geo Permissions: allow AU + PH only | User | 2 min |
| 5 | Set Twilio Account Usage Trigger: alert A$25/day, suspend A$50/day | User | 5 min |
| 6 | Configure Supabase Dashboard → Auth → Providers → Phone | User | 5 min |
| 7 | Update local `supabase/config.toml` — flip `enabled=true`, add SIDs | Me (PR) | 2 min |
| 8 | Add `test_otp` entries for PH dev number + AU fixtures | Me (PR) | 2 min |
| 9 | Bump `sms_sent` rate limit from 30 → 200/hour for production | Me (PR) | 1 min |
| 10 | First end-to-end test: PH number → SMS → OTP → `phone_verified_at` flips → ABN verification wizard passes the gate | User | 10 min |
| 11 | Verify on a real AU number (porting a SIM into a test handset, or asking a colleague in AU) | User | 10 min |
| 12 | Document the working setup in `docs/DEPLOYMENT.md` (or similar) so it doesn't get re-discovered | Me (PR) | 5 min |

Total time after Twilio account exists: about 30 minutes of actual work.

---

## 13. The PH-vs-AU question — "is this almost similar for Australian?"

**Yes, almost identically.** Same provider, same Supabase config, same Flutter code, same OTP template. The only AU-specific concern is the sender-ID register from §7. Your PH test verifies the *integration* works (Flutter ↔ Supabase ↔ Twilio ↔ carrier). Once that's green, AU works the same way — different country code, different per-SMS cost, same code path.

The reverse isn't true: testing only in AU and then deploying to PH wouldn't be safe, because some markets (notably India, Indonesia, parts of Africa) need provider-specific configuration. AU + PH coverage from a single Twilio account is the easy case.

---

## 14. Adjacent docs

- `docs/VERIFICATION_AUDIT.md` — why we added the phone gate to begin with.
- `docs/VERIFICATION_SAVE_AUDIT_AND_MANUAL_FALLBACK_PLAN.md` — the manual upload + attestation work that this gate sits in front of.
- `supabase/config.toml:283-291` — the Twilio block to flip on.
- `lib/features/auth/data/services/phone_auth_service.dart` — the Flutter side that needs no changes.
