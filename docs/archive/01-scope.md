# Jobdun — Application Scope

> **Purpose of this doc:** Single source of truth for *what Jobdun is and what it ships*. Fed to Claude Code so it has full context on the product surface before generating any code. This is **scope**, not architecture — the architecture/engineering rules live in the project's Custom Instructions and `docs/02-architecture.md`.

---

## 0. TL;DR

Jobdun is a **mobile-first job-matching marketplace for the Australian construction trades**. Three roles: **Builders** (post jobs), **Trades/Crews** (apply for jobs), **Admins** (verify users, moderate content, run ops).

| Surface | Audience | Tech |
|---|---|---|
| **Mobile app (iOS + Android)** | Builders + Trades/Crews | Flutter + Supabase |
| **Admin web app** | Internal admins only | Flutter Web *or* Next.js — TBD in architecture doc |
| **Backend** | All clients | Supabase (Postgres, Auth, Storage, Realtime, Edge Functions, RLS) |

Launch market: **Australia**. Target: **25,000 active users, ~5k MAU, ~500 DAU at peak.**

---

## 1. Roles & Personas

### 1.1 Builder (mobile)
A construction company, principal contractor, or site manager who needs to hire trades or crews for a job. Posts jobs, reviews applications, hires, pays (off-platform for now), reviews trades after job completion.

### 1.2 Trade / Crew (mobile)
A licensed tradesperson (electrician, plumber, carpenter, etc.) or a small crew. Browses jobs, applies, chats with builders, manages their availability, gets reviewed.

> **Note:** "Trade" and "Crew" are functionally the same role at MVP. A "Crew" is just a Trade profile with a `crew_size > 1` flag and optional team member listing. Don't build them as separate roles in v1.

### 1.3 Admin (web)
Internal Jobdun staff. Verifies licences/insurance, reviews reports, suspends users, monitors queues, runs platform ops.

---

## 2. Feature Inventory — Mobile App (Builders + Trades)

Organized by phase per the 12-week roadmap. Every feature lists: **what it is**, **who it's for**, and **MVP cut line**.

### Phase 0 — Foundation (Weeks 1–4)

#### F0.1 — Auth & Onboarding
- Email + password sign-up and sign-in (Supabase Auth)
- Email verification (magic link or OTP)
- Password reset
- Phone number capture (AU format `+61`) — verified via SMS OTP at MVP only for Trades; Builders can verify later
- Role selection on first launch: **Builder** or **Trade/Crew**
- Onboarding wizard per role (3–5 screens, skippable where possible)
- Logout, delete account (Privacy Act compliance — must work end-to-end)
- Session persistence + silent token refresh

#### F0.2 — Builder Profile
- Company name, ABN (validated against AU ABN format, *not* live-checked at MVP)
- Contact name, contact phone
- Logo upload (resized client-side to ≤1024px, ≤500KB)
- Service location (suburb + state, geocoded to lat/lng via Google Places)
- Short bio / about
- Public profile view (what trades see when reviewing a builder)

#### F0.3 — Trade/Crew Profile
- Full name, trade type (enum: electrician, plumber, carpenter, concreter, painter, tiler, plasterer, roofer, landscaper, labourer, other — extend list before launch)
- Crew size (1 = solo, 2+ = crew)
- Years of experience
- Service radius (km from base suburb)
- Base location (suburb + state, geocoded)
- Hourly rate range (optional, builder visibility toggle)
- Short bio
- Avatar upload (resized client-side)
- Public profile view (what builders see)

#### F0.4 — Photo & File Uploads (shared infra)
- Image picker (camera + gallery)
- Client-side resize and compress (sharp ratio, ≤1024px long edge, JPEG q=80)
- Upload to Supabase Storage with progress indicator
- Retry on failure with exponential backoff
- Two bucket types:
  - **Public** — avatars, logos, portfolio photos
  - **Private** — verification docs (licences, insurance, ID), accessed only via signed URLs from Edge Functions

#### F0.5 — Verification Submission + Expiry Reminders
- Trade uploads: trade licence (per state — NSW, VIC, QLD, WA, SA, TAS, ACT, NT all differ), public liability insurance, white card, photo ID
- Each doc has: `type`, `issuer`, `licence_number`, `issued_date`, `expiry_date`, `file_url` (private bucket)
- Status enum: `pending`, `approved`, `rejected`, `expired`
- Reminder notifications at 30 / 14 / 7 / 1 days before expiry
- A trade with no approved licence cannot apply to jobs that require verification (gating enforced server-side via RLS or Edge Function)

#### F0.6 — Ratings & Reviews (foundation only — UI ships in Phase 2)
- Schema in place: `reviews` table, 1–5 star + text, `reviewer_id`, `reviewee_id`, `job_id`, `role` (builder-rates-trade or trade-rates-builder)
- Aggregate average + count cached on profile
- One review per job per direction
- Moderation flag field present from day 1

---

### Phase 1 — Core Marketplace (Weeks 4–8) → MVP Release end of W8

#### F1.1 — Job Posting (Builder)
- Create job: title, description, trade type required, location (suburb + lat/lng), start date, estimated duration, budget range (optional), urgency flag (Standard / Urgent), required certifications
- Save as draft / publish
- Edit job (only while status = `open`)
- Close job (status: `closed`, `filled`, `cancelled`)
- Soft-delete (set `deleted_at`, keep for dispute history)
- Photos attachable (up to 5, same image pipeline as F0.4)
- "Urgent" badge highlighted in feed

#### F1.2 — Job Browse & Discovery (Trade)
- Feed of open jobs, default sort: newest
- Filter: trade type, distance from me (using my service radius), budget range, urgency, posted-within (24h / 7d / 30d)
- Sort: newest, nearest, highest budget
- Job detail screen with builder profile preview
- Save / bookmark job
- "Apply" CTA (gated on verification status)

#### F1.3 — Applications
- Trade submits application: optional cover note, proposed rate (optional), availability date
- Builder sees applications list per job, sorted by newest or "best match" (best match = verified + closest + highest rated; simple weighted score, not ML)
- Builder actions: shortlist, message, reject, hire
- Trade sees status of their applications (pending / shortlisted / messaged / hired / rejected)
- Application withdrawn by trade
- Rate-limited: max 20 applications per trade per 24h (anti-spam)

#### F1.4 — Accept / Decline / Schedule
- Builder "hires" a trade → job status becomes `filled`, all other applications auto-rejected with notification
- Trade can accept or decline the hire
- Agreed start date locked in
- Calendar entry created for both parties (in-app, not synced to phone calendar at MVP)

#### F1.5 — Push Notifications
- FCM (Firebase Cloud Messaging) for both iOS and Android
- Notification types at MVP: new application received, application status changed, new message, hire confirmation, licence expiry warning
- User notification preferences screen (opt out per category)
- Server-side fan-out via Edge Function to keep secrets out of client

#### F1.6 — Search & Discovery
- Full-text search on jobs (title + description) using Postgres `pg_trgm` + GIN index
- Trade search by trade type, location, verified status (for builders to proactively browse trades)
- Search history (local, last 10)

#### F1.7 — GPS / Map View
- Map view of jobs around me (Google Maps SDK for Flutter)
- PostGIS-backed `ST_DWithin` query on the server, never load all jobs and filter client-side
- Job pins clustered when zoomed out
- Tap pin → mini job card → tap → full job detail
- Builder map view of trade base locations (only for verified trades, privacy-aware — show suburb-level pin, not exact address)

#### F1.8 — Availability Calendar (Trade)
- Trade marks days as available / unavailable / booked
- Builder sees a trade's next-available date on their profile
- No conflict detection at MVP — just a visual calendar
- Defer recurring availability to Phase 2

#### F1.9 — In-App Messaging (1:1)
- Conversation per (builder × trade × job) tuple — message context is always tied to a job
- Text only at MVP. Photo attachments deferred to Phase 2.
- Read receipts (debounced, batched)
- Typing indicator (optional, only if it's free with Realtime — don't burn extra subscriptions)
- Subscribe per-thread on screen entry, unsubscribe on exit (per project rules — don't subscribe-all on app open)
- Pagination: load 30 messages, infinite scroll up
- Fallback poll path if Realtime disconnects > 10s
- Mute conversation
- Block user (creates a `blocks` row, hides messages bidirectionally)

#### F1.10 — Verification Admin Hooks (mobile-side)
- Trade sees verification status: not submitted / pending review / approved / rejected (with reason) / expired
- Resubmit flow on rejection
- "Verified" badge on profile when approved

#### **🚩 MVP Release at end of W8** — App Store + Play Store submission

---

### Phase 2 — Operations & Admin Surface for Mobile (Weeks 8–12)

#### F2.1 — Timesheets / Check-in / Check-out
- Trade clocks in at job site (GPS-stamped, ±100m of job location)
- Clocks out at end of day
- Generates a daily timesheet entry
- Builder approves or disputes timesheet
- Hours summed per job
- Foundation for future paid tier (payments)

#### F2.2 — Earnings Dashboard (Trade)
- Lifetime earnings (calculated from approved timesheets × agreed rate)
- This week / month / year breakdowns
- Per-job breakdown
- Export to CSV (email it, don't try to render PDFs in v1)

#### F2.3 — Quote Request System
- Builder can request a quote from a trade *without* posting a public job (private invite)
- Trade receives quote request, can accept/decline/counter
- Becomes a private job thread if accepted
- Useful for repeat business — a major retention lever

#### F2.4 — Loyalty & Referrals
- Referral code per user
- Reward (TBD — credit toward featured job post, or just badge) when referred user completes first job
- "Verified Pro" tier for trades with 10+ completed jobs and 4.5+ rating
- Leaderboards deferred — too gameable

#### F2.5 — Reports & Moderation (mobile-facing parts)
- "Report" button on every job, message, and profile
- Categorized reasons (scam, abuse, fake licence, off-platform solicitation, other)
- User sees confirmation their report was received
- Suspended users see a clear "account suspended" screen with appeal email

#### F2.6 — Reviews UI (full)
- Post-job review prompt for both parties
- Star + text + tags ("on time", "good comms", "clean site", etc.)
- Aggregated on profile
- Reviewer can edit within 24h, then locked
- Reviewee can flag a review for admin moderation

#### F2.7 — QA, Hardening, Launch Prep
- Crash-free rate target: ≥99.5%
- Cold-start time target: ≤2.5s on mid-range Android
- Memory + battery audit
- Accessibility pass (TalkBack/VoiceOver, contrast, tap targets ≥44pt)
- Localization scaffold (English-AU only at launch, but i18n keys in place)

---

## 3. Feature Inventory — Admin Web App

The admin web app is **internal only**, behind SSO or hard-gated email allow-list. It is NOT shipped via app stores. Hosted on a subdomain (e.g. `admin.jobdun.com.au`).

### A1 — Admin Auth & RBAC
- Email + password (Supabase Auth) restricted to allow-listed `@jobdun.com.au` (or whatever domain) addresses
- Role enum within admin: `super_admin`, `verifier`, `moderator`, `support`
- All admin actions logged to an `admin_audit_log` table (who did what to whom, when, why) — non-negotiable for trust

### A2 — Verification Queue
- List of pending verification submissions, sorted oldest-first
- Filters: state, trade type, days waiting
- Doc viewer: secure signed URLs to private bucket, watermarked preview
- Side panel: trade profile, prior submissions, prior rejections
- Actions: approve, reject (with reason from enum + free text), request resubmission
- SLA target: ≤48h. Alert fires when queue has items >48h old.

### A3 — Reports & Moderation Queue
- List of open reports, sorted by severity then age
- Per-report view: reported entity (job/message/profile), reporter, reason, history of reports against same user
- Actions: dismiss, warn user, remove content, suspend user (24h / 7d / 30d / permanent)
- Bulk actions for spam patterns

### A4 — User Management
- Search users by email, phone, name, ABN, licence number
- View full user record: profile, jobs, applications, messages metadata (counts only — admin should NOT routinely read message contents; gated behind a "view content" action that is itself audit-logged)
- Manual verification override (super_admin only)
- Suspend / unsuspend
- Force password reset
- GDPR-style data export (Privacy Act request fulfilment)
- Account deletion (hard delete with retention rules — keep financial/dispute records per AU law)

### A5 — Job Management
- Search and filter all jobs across the platform
- View job detail with full application history
- Force-close a job (with reason, notifies builder)
- Pin / feature a job (for ops experiments)

### A6 — Dispute Resolution
- Disputes raised from timesheets, reviews, or messages
- Case file view: all relevant messages, timesheets, job context
- Admin notes (internal only)
- Resolution outcomes: refund-style credit, warning, suspension, no action
- Resolution is logged and visible to both parties (outcome only, not internal notes)

### A7 — Analytics Dashboard
- DAU / WAU / MAU
- Sign-ups per day, by role, by state
- Jobs posted / day, applications / day, messages sent / day
- Verification queue depth + age
- Conversion funnel: signup → profile complete → first action (post or apply) → first match
- Cohort retention (D1, D7, D30)
- p95 query latency, error rate, message send success rate
- *Build this on top of Supabase + PostHog. Don't roll your own analytics DB.*

### A8 — Feature Flags & Config
- Toggle features on/off per role / per state / per cohort
- Backed by a `feature_flags` table read on session start + cached
- Used for risky launches (e.g., turn timesheets on for VIC only first)

### A9 — Notification Templates
- Edit copy for system notifications, emails, SMS, push
- Preview before save
- Versioned (rollback if a template breaks)

### A10 — Platform Health
- Live counters: active sessions, in-flight requests, queue depths
- Recent error sample (Sentry feed embedded or linked)
- Manual "broadcast" tool for platform-wide announcements (e.g., scheduled maintenance)

---

## 4. Cross-Cutting Concerns (Both Surfaces)

These aren't features — they're product-shaped requirements that touch every feature.

- **Privacy Act 1988 / APP compliance:** every PII-touching feature has a documented data flow, retention rule, and deletion path
- **Accessibility:** WCAG 2.1 AA target on web; platform a11y APIs respected on mobile
- **i18n scaffold:** English-AU at launch, structured for future expansion (don't hardcode strings)
- **Time zones:** AU has 5 of them; store UTC, render local; never assume server tz
- **Currency:** AUD only at launch
- **Offline behavior:** mobile app degrades gracefully — read-from-cache where possible, queued writes with retry
- **Empty states + error states:** every list, every form, every screen — designed, not default-Flutter-grey

---

## 5. Explicitly Out of Scope (v1)

Listing these so Claude Code doesn't accidentally build them:

- ❌ In-app payments / escrow (off-platform handshake only at MVP; revisit Phase 4)
- ❌ Video calls or voice messages
- ❌ AI matching, AI profile suggestions, AI chat assist (reserved for Phase 4, post-PMF)
- ❌ Multi-language support beyond English-AU
- ❌ Public web app for builders/trades (mobile only for them)
- ❌ Calendar sync to Google/Apple Calendar
- ❌ Invoicing / tax document generation
- ❌ Background checks beyond licence verification
- ❌ Insurance products / financial services
- ❌ Marketplace for materials or equipment
- ❌ Subcontractor chains (a trade hiring another trade through the platform)

---

## 6. Open Questions to Resolve Before Build

> Claude Code: surface these to Ken if a feature touches them and they're still unanswered.

1. Admin web app — Flutter Web (single codebase) or Next.js (better web ergonomics, separate deploy)? *Default assumption: Flutter Web for MVP, revisit if it bites.*
2. Push notifications via FCM only, or APNs direct on iOS for reliability?
3. Does the "Verified" badge require ALL doc types (licence + insurance + ID + white card) or just a primary licence?
4. Crew profiles — list individual member names + their licences, or just a headcount + the lead's licence?
5. Job categories — flat enum (~12 trades) or hierarchical (Electrical → Domestic / Commercial / Solar)?
6. Post-MVP business model — featured listings, subscription for builders, transaction fee on quotes? Affects schema choices made *now*.

---

## 7. How To Use This Doc

- This is **scope only**. For *how* to build each feature (schema, RLS, indexes, Riverpod providers, Edge Functions), see `docs/02-architecture.md` and per-feature design docs in `docs/features/`.
- When implementing a feature, reference its ID (e.g., `F1.9`) in the PR title and commit messages so we can trace code → product.
- If a feature isn't listed here, it doesn't get built. Add it to this doc first via PR.