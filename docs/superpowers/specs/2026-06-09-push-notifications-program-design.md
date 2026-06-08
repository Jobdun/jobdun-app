# Push Notifications Program — Design Spec

**Date:** 2026-06-09
**Status:** Proposal for review (brainstorming output → next step is `writing-plans`)
**Builds on:** the live #8 rail — `device_tokens`, `push-send` edge fn (FCM v1), client token registration, and the `notify_trades_on_new_job` → push path. See `docs/PUSH_NOTIFICATIONS_SETUP.md`.

---

## 1. Problem & thesis

Push is live for exactly **one** event (a job is posted), wired *into that one trigger*. Two things are missing:

1. **Reuse** — every other meaningful event (someone applied, you were hired, a new message, a review, a verification result) should be push-capable *without* re-plumbing FCM each time.
2. **Admin control** — admins need to send updates/announcements to users from the console.

**Thesis:** notifications and *delivery* are different concerns. Features should only ever **"insert a notification row"**; a single shared mechanism turns any such row into an in-app entry **and** a push. The admin broadcast then becomes a thin producer of those rows. This is the whole architecture.

---

## 2. Use cases — what should push (the taxonomy)

| Event | Recipient | Category | Today | Priority |
|-------|-----------|----------|-------|----------|
| Job posted | matching trades | `jobs` | ✅ in-app + push | done |
| **Application received** | builder | `applications` | in-app row exists, no push | **P1** |
| **Application status** (shortlisted / hired / rejected) | tradie | `applications` | ❌ none | **P1** (the "did I get it?" moment) |
| **New message** | the other party | `messages` | ❌ **none at all** | **P1** (table stakes for chat) |
| Review received | reviewee | `reviews` | in-app row exists, no push | P2 |
| Verification result / expiring / expired | user | `verification` | in-app rows exist, partial | P2 |
| **Admin announcement** | targeted segment | `announcements` | ❌ none | **this request** |

Anti-goal: don't push low-signal events (e.g. your own actions). Respect quiet preferences (§4).

---

## 3. Architecture — the reusable rail (recommended)

**One trigger on `public.notifications` (AFTER INSERT) → `push-send`.** Every producer (existing migrations, future features, the admin broadcast) just inserts a notification row; delivery is automatic and uniform.

```
feature / admin / trigger  ──INSERT──▶  notifications row
                                            │ AFTER INSERT trigger
                                            ▼
                                   push enabled for (user, category)?
                                            │ yes
                                            ▼
                                   pg_net → push-send (FCM v1) → device
```

- **Replaces** the bolted-on push in `notify_trades_on_new_job` (that function goes back to *only* inserting in-app rows; the new central trigger delivers the push). Removes per-feature FCM duplication.
- `push-send` is unchanged (already deployed); the row carries `user_id`, `title`, `body`, `data`.
- **Batching:** a per-row trigger is simplest and fine at this scale. If a broadcast inserts thousands of rows, switch the trigger to enqueue + a scheduled drain (noted as a scale follow-up, not built now — YAGNI).

### Considered alternatives
- **(A) Per-feature push calls** (today's `new_job` pattern) — rejected: duplicated FCM wiring in every feature, easy to forget, inconsistent.
- **(B) Central trigger on `notifications`** — **chosen**: one place, every event covered, admin broadcast is free.
- **(C) Edge-function-per-event** — rejected: heavier, and still needs each event to call it.

---

## 4. Notification preferences (per-user control)

Best practice + app-store expectation. Users opt out by **category**, not per-event.

- **Data:** `notification_preferences (user_id, category text, push_enabled bool, in_app_enabled bool)` — categories from §2 (`jobs`, `applications`, `messages`, `reviews`, `verification`, `announcements`). Default all on. (Alternative: a JSONB column on `profiles` — rejected for queryability in the trigger.)
- **Mobile UI:** a "Notifications" section under the existing `/settings` route — one `JSwitch` row per category (reuse the settings rows). `announcements` is **not** user-disablable for critical admin messages (or a separate "critical" flag — open decision §8).
- **Trigger respects it:** the §3 trigger skips push when `push_enabled = false` for that `(user, category)`. In-app row still created.

---

## 5. Admin broadcast (the requested control)

A new admin-web feature: **`lib/admin/features/admin_broadcast/`** (repurposes the `admin_reports` placeholder slot in the shell nav).

### Flow
1. **Compose** — title, body, audience, optional deep-link target.
2. **Audience** — `All users` · `All builders` · `All trades` · `Single user` (by id/email). Resolves to a recipient count shown live ("→ 142 recipients").
3. **Preview** — render the exact notification card the user will see.
4. **Confirm + send** — a confirm dialog (high-impact, like a destructive action) → audited RPC.

### Backend
`admin_broadcast(p_title, p_body, p_audience, p_data jsonb)` — SECURITY DEFINER, admin-gated (same `user_roles` check as `admin_set_user_status`), which:
- resolves the audience to user_ids,
- inserts `notifications` rows (`type = 'announcement'`, category `announcements`) → **auto-pushed by the §3 trigger**,
- writes a `log_admin_action('broadcast', …, {audience, count})` audit row,
- returns the recipient count.

Governance: confirm dialog, a soft cap warning over N recipients, full audit trail, and (open decision) an optional rate-limit.

### UI (Jobdun admin design system — `AdminText`, `JButton`, `JButton.danger`, form + validate + loading→success)
```
┌─ BROADCAST ─────────────────────────────────────────────┐
│ Send a push + in-app update to your users.              │
│                                                          │
│ AUDIENCE   [ All ▾ ]  → 142 recipients                  │
│ TITLE      [_______________________________]            │
│ MESSAGE    [                               ]            │
│            [                               ]            │
│ LINK (opt) [ /jobs  ▾ ]                                  │
│ ─────────────────────────────────────────────           │
│ PREVIEW   ┌───────────────────────────────┐             │
│           │ 🔔 New from Jobdun            │             │
│           │ <title>                        │             │
│           │ <message>                      │             │
│           └───────────────────────────────┘             │
│                              [ CANCEL ]  [ SEND ▸ ]      │
└──────────────────────────────────────────────────────────┘
```
UX rules applied: validate on submit (`Form` + key), disable SEND while in-flight, confirm before send, success toast after (`ui-ux-pro-max`: submit feedback / confirmation messages). Admin redeploys via `scripts/deploy-admin.sh`.

---

## 6. Hardening (carried from the current rail)

1. **`push-send` auth** — today it's called with the public anon key (callable by anyone). Replace the in-trigger `pg_net` call with a **Supabase Database Webhook** (service-role auth, configured server-side) on `notifications` INSERT, *or* a shared-secret header. **Do this as part of M1** since M1 already touches that path.
2. **Stale-token pruning** — on FCM `404/410`, delete the token from `device_tokens` (small addition to `push-send`).

---

## 7. Milestones (the plan shape)

| M | Delivers | Notes |
|---|----------|-------|
| **M1** | Central `notifications` → push trigger (replaces `new_job` bolt-on) + webhook auth + token pruning | the reusable rail + hardening |
| **M2** | Producers for the P1 gaps: application-received, application-status, **new-message** | each just inserts a notification row |
| **M3** | Notification preferences (table + `/settings` UI + trigger respects them) | per-user control |
| **M4** | Admin broadcast (feature module + `admin_broadcast` RPC + compose UI) + admin redeploy | the requested control |
| **M5** | (scale, later) enqueue + drain if broadcast volume needs it | YAGNI until needed |

Each milestone is independently shippable and testable. Suggested order M1 → M2 → M4 → M3 (admin control is high-value; prefs can follow), but M3 before M4 if you want opt-out guaranteed before broadcasts.

---

## 8. Open decisions (your call — defaults proposed)

1. **Order:** M1→M2→M4→M3 (ship admin control sooner), or M1→M2→M3→M4 (opt-out before any broadcast)? *Default: M1→M2→M4→M3.*
2. **Announcements opt-out:** can users disable admin announcements, or are they always-on (with a separate "critical" tier)? *Default: a single `announcements` toggle users CAN disable; truly critical messages are rare and out of scope.*
3. **Broadcast audience v1:** All / Builders / Trades / Single user enough, or do you want saved segments (e.g. "verified trades in NSW")? *Default: the four simple audiences; segments later.*
4. **Hardening method:** Database Webhook (recommended, dashboard step) vs shared-secret-in-Vault (all-SQL)? *Default: Database Webhook.*
5. **Messaging push copy:** show message preview text, or just "New message from <name>" (privacy)? *Default: "New message from <name>" + open the thread on tap.*

---

## 9. Testing

- Trigger: insert a notification row per category → assert a `device_tokens` lookup + (mock) push call; assert pref opt-out suppresses push but keeps in-app.
- Admin broadcast RPC: admin-gated (non-admin → `not_admin`), inserts N rows, writes audit; recipient-count correctness per audience.
- Admin UI: compose widget test (validate, disabled-while-sending, success state).
- E2E (manual, as done for #8): real send to a device.

---

*Grounded in the live 2026-06-09 push rail + the Jobdun admin design system. Decisions in §8 are proposed defaults; change any and I'll revise before the implementation plan.*
