# Push Notifications Program — Implementation Plan

> **For agentic workers:** built via superpowers:subagent-driven-development. A shared **foundation** is built first (sequential, on `main`), then **three independent streams** run as parallel subagents in **isolated worktrees**, then integrated.

**Goal:** make any notification deliver as in-app + push via one shared trigger, cover the P1 use-case gaps, add per-user preferences, and give admins a broadcast console.

**Architecture:** one `AFTER INSERT` trigger on `public.notifications` → `pg_net` → the deployed `push-send` edge fn, gated by a `notification_preferences` table. Every producer (features, admin) only inserts a notification row. Spec: `docs/superpowers/specs/2026-06-09-push-notifications-program-design.md`.

**Tech:** Supabase (Postgres triggers, pg_net, edge fn), Flutter (mobile `/settings`, `lib/admin/`), Riverpod, Jobdun design system.

**Decisions (from spec §8 — confirmed defaults):** order M1→M2→M4→M3; `announcements` user-mutable; 4 simple audiences; Database Webhook hardening (dashboard, flagged); message copy = "New message from <name>".

---

## Phase 0 — Foundation (built by me on `main`, FIRST; everything depends on it)

**Files:**
- Create: `supabase/migrations/20260609000006_notification_preferences.sql`
- Create: `supabase/migrations/20260609000007_central_push_trigger.sql`
- Modify: `supabase/functions/push-send/index.ts` (prune stale tokens on 404/410)
- Modify: `supabase/migrations/20260609000005` is NOT edited; the new central trigger supersedes the inline push in `notify_trades_on_new_job` (that fn reverts to in-app-only via the new migration).

**Deliverables:**
1. `notification_preferences (user_id uuid, category text, push_enabled bool default true, in_app_enabled bool default true, primary key (user_id, category))` + owner-RLS + a `notification_category(type text)` helper mapping `new_job→jobs`, `application_*→applications`, `message*→messages`, `review*→reviews`, `*verif*→verification`, `announcement→announcements`.
2. `notifications_push_fanout()` trigger (AFTER INSERT): if `push_enabled` for `(NEW.user_id, category(NEW.type))` (default true when no row), `pg_net` POST to push-send with `{user_ids:[NEW.user_id], title, body, data}`. Revert `notify_trades_on_new_job` to insert-only (drop its inline pg_net block).
3. push-send: on FCM 404/410, `delete from device_tokens where token=...`.

**Verify:** insert a test notification row per category → push fires once; opt-out row suppresses push, keeps in-app. Push migrations. `validate.sh` (no Dart change here) + manual send.

---

## Stream A — Admin broadcast (subagent, worktree) — *spec §5*
**Files:** `supabase/migrations/20260609000008_admin_broadcast.sql` (RPC `admin_broadcast(p_title,p_body,p_audience,p_data)` — admin-gated like `admin_set_user_status`, resolves audience → inserts `announcement` notification rows → `log_admin_action('broadcast',…)`); `lib/admin/features/admin_broadcast/` (data repo `.rpc`, provider, compose page: audience dropdown + live recipient count + title/body + preview card + confirm dialog + SEND). Wire into the admin shell nav (replace the `admin_reports` slot). Use **ui-ux-pro-max** + the admin design system (`AdminText`, `JButton`/`JButton.danger`, Form+validate, loading→success).
**Done when:** an admin composes → confirms → rows inserted + audited; analyze clean.

## Stream B — Use-case producers (subagent, worktree) — *spec §2 P1*
**Files:** `supabase/migrations/20260609000009_message_notifications.sql` (AFTER INSERT on `messages` → insert a `message_received` notification for the OTHER party in the conversation, body "New message from <sender display name>", data `{conversation_id}`; skip if sender==recipient); `supabase/migrations/20260609000010_application_status_notifications.sql` (on `job_applications` INSERT → `application_received` to the builder; on status UPDATE to shortlisted/hired/rejected → `application_status` to the tradie). No app code needed — the central trigger delivers push.
**Done when:** inserting a message / changing an application status creates the right notification row (→ auto-push via foundation).

## Stream C — Mobile notification preferences (subagent, worktree) — *spec §4*
**Files:** `lib/features/profile/presentation/pages/notification_settings_page.dart` (a `/settings/notifications` route; one `JSwitch` row per category reading/writing `notification_preferences` via a small repo/provider), entry row in `settings_page.dart`, `app_router.dart` route. Reuse the settings row style. TDD the toggle logic.
**Done when:** toggles persist per category; analyze clean; a muted category suppresses push (integrates with foundation).

---

## Integration (me)
Pull each worktree, assign non-colliding migration timestamps (already distinct above), push migrations in order (6→10), run `bash scripts/validate.sh`, commit per stream. Manual e2e: message → push; broadcast → push.

## Hardening (flagged, not auto)
Replace the central trigger's anon-key `pg_net` call with a **Supabase Database Webhook** (service-role, dashboard) on `notifications` INSERT — removes the public-callable exposure. Documented in `docs/PUSH_NOTIFICATIONS_SETUP.md`.

## Self-review
Spec coverage: §2 use-cases→Stream B + foundation; §3 rail→Phase 0; §4 prefs→Stream C + Phase 0 gate; §5 admin→Stream A; §6 hardening→flagged + token-prune in Phase 0. No placeholders; migration timestamps 6–10 distinct; `notification_category()` defined in Phase 0 and used by the trigger + Stream C categories match.
