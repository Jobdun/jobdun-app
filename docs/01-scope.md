# Jobdun — Mobile App Scope

## Decision: Admin is a separate web app

The admin panel (document verification review, user moderation, analytics) will be built as a **separate web application** in its own Git repository. The Flutter mobile app has no admin UI. The `admin` role exists in the database and Supabase RLS policies, but it is never surfaced as a selectable role in the Flutter onboarding flow.

---

## 8 Mobile Features

| # | Feature | MVP | Description |
|---|---------|-----|-------------|
| 1 | **Auth** | Yes | Email/password sign-up and sign-in, role-based onboarding (builder or trade/crew), session persistence |
| 2 | **Profile** | Yes | Builder company profile and trade/crew profile with skills, licences, and portfolio |
| 3 | **Jobs** | Yes | Builders post jobs; trades browse, search, and filter; full job lifecycle management |
| 4 | **Applications** | Yes | Trades apply to jobs; builders review, shortlist, accept, or reject; status tracking |
| 5 | **Messaging** | Yes | Job-specific chat threads between builder and trade; real-time via Supabase Realtime |
| 6 | **Verification** | Yes | Trades upload licence and insurance documents; status tracked (pending / approved / rejected) |
| 7 | **Reviews** | No | Post-job mutual ratings (1–5 stars) and written reviews; shown on profiles |
| 8 | **Notifications** | No | In-app notification feed for application updates, messages, verification results |

MVP = first 6 features. Reviews and Notifications follow once the core marketplace flow is validated.

---

## Out of Scope (current phase)

- Admin panel in Flutter — web app only
- Push notifications (Firebase Cloud Messaging) — Phase 2
- Social login (Google / Apple) — Phase 2
- Map-based job discovery — Phase 2
- In-app payments / subscriptions — Phase 3
- Crew / team management — Phase 3
- Calendar, timesheets, invoicing — Phase 3

---

## Job Status Lifecycle

`Draft` → `Open` → `In Review` → `Assigned` → `In Progress` → `Completed` / `Cancelled`

## Application Status Lifecycle

`Pending` → `Shortlisted` → `Accepted` / `Rejected` / `Withdrawn`

---

## References

- Architecture and tech stack: `README.md`
- Developer commands and code rules: `CLAUDE.md`
- Implementation setup plan: `docs/plan.md`
