# Copy-paste prompt — add Jobdun to kenbuilds.tech resume

**How to use:** open the `kenbuilds.tech` repo in Claude Code (or your editor's AI),
paste everything inside the fenced block below, send. Everything the agent needs is
already in it — it does not have to invent any facts.

**Before you send it:** pick your role/company line in `STEP 1` (marked `<<CHOOSE>>`).
That is the only thing I can't decide for you.

---

````text
Add a new work entry for Jobdun to my online resume, and update the skills section to match.

Match the exact markup, component, class names, and ordering conventions already used by the
other experience entries on the resume page — do not invent a new layout or restyle anything.
Also update the PDF/print version so it stays in sync with the web version.

## STEP 1 — Header line

<<CHOOSE ONE — delete the other two before sending>>
  A) JOBDUN PTY LTD · Lead Full-Stack & Mobile Engineer (Contract)
  B) JOBDUN PTY LTD · Founding Engineer (Full-Time)
  C) Jobdun · Lead Full-Stack & Mobile Engineer (Freelance)

Dates:    May 2026 – Present
Location: Sydney, Australia (Remote)

## STEP 2 — Placement

Place this entry FIRST in the Experience list, above "Romega Solutions".
Reason: the list is ordered by start date descending, and Jobdun (May 2026) is the most
recent start. Both are current roles, so both keep "Present".

## STEP 3 — Bullets (use verbatim, 4 bullets)

- Built and shipped Jobdun, a two-sided job marketplace for the Australian construction trades,
  from empty repo to live on the Apple App Store (AU) and Google Play — ~70K lines of Dart across
  566 files, one Flutter codebase serving iOS, Android, and web.
- Designed the Supabase backend end to end: 32 Postgres tables under row-level security,
  88 migrations, and 5 Deno edge functions covering the jobs feed, push delivery, and
  ABN / trade-licence verification against Australian regulator APIs.
- Cut jobs-feed latency with an Upstash Redis read-through cache (45s TTL, write invalidation,
  kill switch) in front of the feed edge function, backed by an encrypted on-device Hive cache
  for stale-while-revalidate reads and offline browsing.
- Shipped the platform around the app: a Next.js admin console on Vercel with an SSR admin-role
  gate (verification queue, user/job moderation, audit feed, broadcast), the marketing site at
  jobdun.com.au, FCM push on both platforms, Twilio SMS OTP, Google/Apple sign-in, Sentry, and a
  GitHub Actions + pre-push gate enforcing format, lint, tests, and Clean Architecture boundaries.

## STEP 4 — Skills section updates (edit in place, keep existing order)

- Frontend & Mobile — after "Flutter" add: Riverpod, GoRouter
- Backend & DB — add: Supabase Edge Functions (Deno), Upstash Redis
- DevOps & Cloud — change "Firebase (Auth · Firestore · Hosting)" to
  "Firebase (Auth · Firestore · Hosting · Cloud Messaging)"; add: Sentry
- Specialized — add: Offline-first Caching, App Store & Google Play Release Management

## STEP 5 — If the site has a Projects / Work grid, add this card too

  Title:  Jobdun
  Blurb:  Job marketplace for the Australian construction trades. One Flutter codebase across
          iOS, Android and web, on a Supabase backend with a Next.js admin console.
  Stack:  Flutter · Dart · Riverpod · Supabase · PostgreSQL (RLS) · Deno Edge Functions ·
          Next.js · Redis · Firebase
  Status: Live — Apple App Store (AU) & Google Play
  Link:   https://jobdun.com.au

## Guardrails — do NOT add any of these

Do not write user counts, downloads, revenue, retention, "X% faster", team size, or any other
metric that is not stated above. Do not write "solo" or "sole engineer" — it was led by me with
one other contributor. Do not add logos or images unless the other entries have them.
````

---

## Where every number came from (so you can defend it in an interview)

| Claim | Source |
|---|---|
| Started May 2026 | first commit `feat: init`, 2026-05-04 |
| ~70K lines of Dart, 566 files | `lib/**.dart`, generated files excluded — 70,494 LOC |
| 486 commits (453 mine) | `git shortlog -sne --all` |
| 32 Postgres tables, 88 migrations | `supabase/migrations/` |
| 5 edge functions | `jobs-feed`, `push-send`, `verify-abn`, `verify-licence`, `_shared` |
| Tests | 149 test files, ~14.4K LOC |
| Live on App Store AU | id6781716111, confirmed live 2026-08-12 |
| Shipping version | `pubspec.yaml` → 1.0.1+7 |
| 15 feature modules | auth, jobs, applications, messaging, notifications, profile, verification, reviews, quotes, scheduling, timesheets, discovery, home, ftue, legal |

## One thing to decide yourself

The header line. I don't know how you're engaged with JOBDUN PTY LTD — contractor, founding
engineer, or freelance — and that's a claim only you can make. Option A is the safest default
if money changes hands and you're not an owner.
