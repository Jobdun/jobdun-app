# Jobdun — Database Context for AI Assistant (Claude Code)

> **Audience:** Claude Code (and any other AI coding assistant working on Jobdun).
> **Purpose:** Give the AI everything it needs to *correctly* read, query, mutate, and extend the Jobdun database without breaking RLS, RBAC, indexes, or audit guarantees.
> **Read this BEFORE generating any database code, Riverpod provider, Edge Function, or RLS policy.**

---

## 1. TL;DR for the AI

You are working on **Jobdun**, an Australian construction-trades job marketplace. The backend is **Supabase (Postgres + Auth + Storage + Realtime + Edge Functions)**. The mobile app is **Flutter + Riverpod**. The admin web app uses the same backend.

**Hard rules — break these and the build is wrong:**

1. **Never write a table without RLS.** `enable row level security` on every public table.
2. **Never check role using a `role` column.** Use `(select public.authorize('permission_name'))` or `(select public.is_admin())`. The role lives in the JWT claim `user_role`, populated by the `custom_access_token_hook`.
3. **Never query without an index.** If you propose a new query path, propose its index in the same diff.
4. **Never expose the `service_role` key to the Flutter client.** Privileged ops route through Edge Functions.
5. **Never hard-delete.** Use `deleted_at`. Filter `where deleted_at is null` everywhere.
6. **Never use the Supabase default email sender in production code paths.** Use Resend/Postmark via SMTP config.
7. **Never download verification docs directly from the client.** Generate signed URLs via an Edge Function that records access in `admin_audit_log`.
8. **Never subscribe a user to all conversations on app open.** Subscribe per-thread on screen entry; unsubscribe on exit.
9. **Never edit `auth.users` directly.** Use Supabase Auth APIs.
10. **Never guess a table name.** They're listed in §3 of this doc.

---

## 2. Architecture in One Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                       Flutter Mobile App                             │
│   (Builders + Trades only — admins use a separate web client)        │
│                                                                      │
│  presentation/  ──>  domain/  ──>  data/                            │
│  (Widgets +         (Use cases,    (Repositories,                    │
│   Riverpod)          entities)      Supabase client)                 │
└────────────────────────────┬─────────────────────────────────────────┘
                             │
                             │ Supabase JS-style RPCs over HTTPS + WS
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       Supabase Backend                               │
│                                                                      │
│   Auth (GoTrue)  ──>  custom_access_token_hook  ──>  JWT             │
│       │                       │                         │            │
│       │                       └── adds user_role        │            │
│       ▼                                                 ▼            │
│   auth.users  ───trigger──>  public.profiles      Postgres + RLS     │
│                                                                      │
│   Postgres (RLS) ── PostGIS ── pg_trgm ── pgcrypto                   │
│   Storage (public-media + private-docs buckets)                      │
│   Edge Functions (Deno; for privileged + 3rd-party ops)              │
│   Realtime (per-thread subscriptions only)                           │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Table Map

This is the canonical list. If a table isn't here, it doesn't exist yet — either propose adding it (with a migration) or you're imagining it.

### Identity & RBAC
| Table | Purpose | Key columns |
|---|---|---|
| `auth.users` | Supabase managed | `id`, `email`, `email_confirmed_at` |
| `public.profiles` | Base profile, 1:1 with auth.users | `id`, `display_name`, `email`, `phone`, `avatar_url`, `deleted_at` |
| `public.builder_profiles` | Builder-specific extension | `id` (=profiles.id), `company_name`, `abn`, `service_location` |
| `public.trade_profiles` | Trade-specific extension | `id`, `primary_trade`, `base_location`, `is_verified`, `service_radius_km` |
| `public.trade_specializations` | M2M trade ↔ trade_type | `trade_id`, `trade_type` |
| `public.user_roles` | RBAC role assignment (one role per user MVP) | `user_id`, `role` |
| `public.role_permissions` | Permissions per role | `role`, `permission` |

### Marketplace Core
| Table | Purpose |
|---|---|
| `public.jobs` | Job posts; PostGIS location, full-text search |
| `public.job_photos` | Attachments for jobs |
| `public.saved_jobs` | Trade bookmarks |
| `public.applications` | Trade applies to job; rate-limited 20/24h |

### Verification
| Table | Purpose |
|---|---|
| `public.verification_documents` | Licences, insurance, ID; private bucket |

### Messaging
| Table | Purpose |
|---|---|
| `public.conversations` | One per (job × builder × trade) |
| `public.messages` | Text only at MVP; soft-deletable |
| `public.blocks` | User-to-user blocks |

### Engagement
| Table | Purpose |
|---|---|
| `public.reviews` | Bidirectional; tied to a filled job; 24h edit window |
| `public.notifications` | In-app inbox |
| `public.notification_preferences` | Per-user channel opt-outs |
| `public.fcm_tokens` | Push notification tokens |

### Trust & Safety (Phase 2)
| Table | Purpose |
|---|---|
| `public.reports` | User-submitted abuse/scam reports |
| `public.user_suspensions` | Active and historical suspensions |

### Ops & Admin
| Table | Purpose |
|---|---|
| `public.admin_audit_log` | Append-only log of every privileged action |
| `public.feature_flags` | Safe-launch toggles |

### Phase 2 (apply when building those features)
| Table | Purpose |
|---|---|
| `public.timesheets` | Check-in / check-out per work day |
| `public.quote_requests` | Builder-initiated private quote invitations |

### Views
| View | Purpose |
|---|---|
| `public.profiles_public` | Safe projection of profile (no email, no phone). Use this when reading "other people's" profiles. |

---

## 4. Enums (Source of Truth for All Status Fields)

When generating Dart enums, mirror these exactly. Names must match strings in DB.

- `app_role`: `builder | trade | admin | super_admin | verifier | moderator | support`
- `app_permission`: see migration `20260505000002_enums.sql` for full list
- `au_state`: `NSW | VIC | QLD | WA | SA | TAS | ACT | NT`
- `trade_type`: `electrician | plumber | carpenter | concreter | painter | tiler | plasterer | roofer | landscaper | bricklayer | glazier | hvac | flooring | demolition | scaffolder | crane_operator | labourer | project_manager | other`
- `doc_type`: `trade_licence | public_liability | workers_compensation | white_card | photo_id | abn_certificate | other`
- `verification_status`: `pending | approved | rejected | expired`
- `job_status`: `draft | open | filled | closed | cancelled`
- `urgency`: `standard | urgent`
- `budget_type`: `hourly | daily | fixed | negotiable`
- `application_status`: `pending | shortlisted | rejected | withdrawn | hired | declined_by_trade`
- `conversation_status`: `active | archived | blocked`
- `notification_type`: `application_received | application_status_changed | new_message | hire_confirmed | hire_declined | verification_approved | verification_rejected | document_expiring | document_expired | review_received | job_filled | system_announcement`

**Adding a new enum value requires a migration.** Don't propose `case 'foo':` defaults that imply unlisted values.

---

## 5. The RBAC Pattern (Use This Every Time)

Roles live in `user_roles`. Permissions live in `role_permissions`. The auth hook injects `user_role` into the JWT.

### Reading the role in SQL/RLS:
```sql
-- Correct
using ((select public.authorize('jobs.delete_any')))
using ((select public.is_admin()))
using ((select public.current_role_name()) = 'trade')

-- WRONG — do not query user_roles in RLS, that defeats the JWT cache
using (exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin'))
```

### Reading the role in Dart:
```dart
// In a Riverpod provider
final session = Supabase.instance.client.auth.currentSession;
final jwt = JwtDecoder.decode(session!.accessToken); // package:jwt_decoder
final role = jwt['user_role'] as String?;
```

### Adding a new permission:
1. Add value to `app_permission` enum (migration).
2. Insert into `role_permissions` for the roles that should have it (migration).
3. Use it in RLS via `(select public.authorize('your.new.permission'))`.

---

## 6. RLS Policy Patterns to Reuse

When writing a new RLS policy, copy from these patterns. Don't invent new ones.

**Owner-only read/write (e.g., my profile):**
```sql
create policy "owner reads own"
  on public.<table> for select to authenticated
  using (user_id = auth.uid());
```

**Public-read, owner-write (e.g., job posts):**
```sql
create policy "anyone authenticated reads"
  on public.<table> for select to authenticated
  using (deleted_at is null);

create policy "owner inserts own"
  on public.<table> for insert to authenticated
  with check (user_id = auth.uid() and (select public.authorize('<perm>')));
```

**Permission-gated (e.g., admin-only):**
```sql
create policy "admin reads all"
  on public.<table> for select to authenticated
  using ((select public.authorize('<perm>')));
```

**Participant-only (messaging pattern):**
```sql
create policy "participant reads"
  on public.messages for select to authenticated
  using (exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (c.builder_id = auth.uid() or c.trade_id = auth.uid())
  ));
```

**Always wrap function calls in subqueries:** `(select public.authorize(...))` not `public.authorize(...)`. Postgres caches the result per row when wrapped in a subselect — this is a 10×+ performance win on large tables. *Source: Supabase RLS performance docs.*

---

## 7. Index Conventions

When you propose a new table or query, propose the index inline. Naming:

```
<table>_<col1>_<col2>_idx
```

- Sort indexes use `<col> desc` order to match the query.
- Filtered indexes use `where <condition>` to keep them small (e.g., `where deleted_at is null`).
- Trigram search uses `using gin (<col> gin_trgm_ops)`.
- Geo uses `using gist (<col>)`.
- Full-text search uses `using gin (search_vector)`.

**If a query has no supporting index, the AI must say so explicitly and propose one** — don't ship a query and hope Postgres figures it out.

---

## 8. Storage Patterns

### Two buckets:
- `public-media` — avatars, logos, job photos. Public read.
- `private-docs` — verification docs. Private. Signed URLs only.

### Path conventions (REQUIRED — RLS depends on them):
- `public-media/{user_id}/avatar.jpg`
- `public-media/{user_id}/jobs/{job_id}/{photo_n}.jpg`
- `private-docs/{user_id}/verification/{doc_type}/{filename}`

The first folder segment must be the `user_id` because RLS uses `(storage.foldername(name))[1] = auth.uid()::text` to enforce ownership.

### Image upload:
- Resize client-side to ≤1024px long edge before upload (use `image` Dart package).
- JPEG quality 80.
- Max 5MB on `public-media`, max 10MB on `private-docs`.

---

## 9. Realtime Rules

| Don't | Do |
|---|---|
| Subscribe to all `messages` on app open | Subscribe to `messages WHERE conversation_id = X` on conversation screen entry |
| Leave subscriptions running across screens | Cancel subscription in widget `dispose()` |
| Trust Realtime alone | Implement a fallback poll (`select * from messages where conversation_id = ? and created_at > ?`) that runs if WS disconnects > 10s |
| Mark-as-read on every render | Debounce mark-as-read to once per 2s per conversation |

---

## 10. Edge Function Triggers (Use These for Privileged Ops)

The Flutter client should NEVER do these directly. Route through Edge Functions:

| Operation | Why Edge Function |
|---|---|
| Generate signed URL for verification doc | Audit log; permission check |
| Approve / reject verification | Mutates other user's data; audit log |
| Suspend a user | Privileged write; audit log |
| Send push notification fan-out | Needs FCM server key (secret) |
| Force-close a job (admin) | Audit log; cascades |
| Delete account (Privacy Act request) | Coordinates Auth + Storage + DB + retention rules |
| Issue refund / credit | Touches financial data |

Pattern: every Edge Function that performs an admin action must call `public.log_admin_action(...)` before returning success.

---

## 11. How to Extend the Schema Safely

When adding a new feature:

1. **Write a migration file** with timestamp prefix in `supabase/migrations/`.
2. **Add `enable row level security` immediately after `create table`.** Don't ship without it.
3. **Add policies for every operation** (select, insert, update, delete) that should be allowed. Default deny.
4. **Add `created_at`, `updated_at` columns** with the `set_updated_at` trigger.
5. **Add `deleted_at` if the entity is sensitive** (anything user-generated, anything financial, anything moderation-relevant).
6. **List all expected query patterns and add an index per pattern.**
7. **Add `comment on table` and `comment on column`** for non-obvious things.
8. **If the table has counts that other tables care about, add a trigger to maintain them** (see `bump_job_application_count` for the pattern).
9. **Run `supabase gen types dart`** after migration applies; commit the generated file.
10. **Update this doc's table map** in §3.

---

## 12. Common Query Recipes

### Job feed for a logged-in trade (location-aware):
```sql
select j.*,
       st_distance(j.location, t.base_location) / 1000.0 as distance_km
from public.jobs j
join public.trade_profiles t on t.id = auth.uid()
where j.status = 'open'
  and j.deleted_at is null
  and j.trade_type_required = t.primary_trade
  and st_dwithin(j.location, t.base_location, t.service_radius_km * 1000)
  and (j.requires_verified = false or t.is_verified = true)
order by j.urgency desc, j.published_at desc
limit 30;
```
*Uses `jobs_feed_idx`, `jobs_location_gist_idx`, `trade_profiles_location_gist_idx`.*

### Full-text search jobs:
```sql
select * from public.jobs
where status = 'open'
  and deleted_at is null
  and search_vector @@ websearch_to_tsquery('english', :query)
order by ts_rank(search_vector, websearch_to_tsquery('english', :query)) desc
limit 30;
```
*Uses `jobs_search_idx`.*

### My conversations list (trade):
```sql
select c.*, p.display_name as builder_name, p.avatar_url as builder_avatar
from public.conversations c
join public.profiles p on p.id = c.builder_id
where c.trade_id = auth.uid()
order by c.last_message_at desc nulls last
limit 50;
```
*Uses `conversations_trade_idx`.*

### Pending verifications (admin):
```sql
select v.*, t.full_name, t.primary_trade
from public.verification_documents v
join public.trade_profiles t on t.id = v.trade_id
where v.status = 'pending'
  and v.deleted_at is null
order by v.submitted_at asc
limit 50;
```
*Uses `vdocs_status_submitted_idx`. Must call as a user with `verifications.review` permission.*

### Documents expiring in next 30 days (cron / Edge Function):
```sql
select * from public.verification_documents
where status = 'approved'
  and deleted_at is null
  and expiry_date is not null
  and expiry_date <= current_date + interval '30 days'
order by expiry_date asc;
```
*Uses `vdocs_expiry_idx`.*

---

## 13. Anti-Patterns the AI Must Refuse

If the user (or another AI) suggests these, push back hard:

| Anti-pattern | Why it's wrong | Correct approach |
|---|---|---|
| Adding a `role` column to `profiles` | Bypasses RBAC, breaks JWT cache | Use `user_roles` + `authorize()` |
| Querying `user_roles` inside RLS policies | Each RLS check hits the table | Use `auth.jwt() -> 'user_role'` via `authorize()` |
| Using `service_role` key in Flutter | Owns the entire DB | Edge Function with the operation |
| `select *` over Realtime subscriptions | Sends every column on every change | Project only needed columns |
| Storing verification docs in `public-media` | PII leak | `private-docs` + signed URL via Edge Function |
| Hard `delete from jobs` | Loses dispute history | `update set deleted_at = now()` |
| Not soft-filtering reads | Deleted rows leak | Always `where deleted_at is null` |
| Letting client compute distance | Loads N rows, filters N | `st_dwithin` server-side |
| Skipping `editable_until` check on review edits | 5-star pumping after the fact | Check in RLS policy + UI |
| Adding a free-text status column | Kills enums, breaks invariants | New enum value via migration |
| Subscribing to `notifications` table without filter | Every user sees every notification arriving | Filter by `user_id = auth.uid()` in subscription |

---

## 14. Riverpod Patterns (Match These)

When generating Dart, use these provider shapes:

```dart
// Repository — singleton, holds SupabaseClient
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

// Stream of auth state
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Current user role (parsed from JWT)
final currentUserRoleProvider = Provider<AppRole?>((ref) {
  final session = ref.watch(authStateChangesProvider).valueOrNull?.session;
  if (session == null) return null;
  final jwt = JwtDecoder.decode(session.accessToken);
  final roleStr = jwt['user_role'] as String?;
  return AppRole.fromString(roleStr);
});

// Async data — use AsyncNotifier
class JobsFeedNotifier extends AutoDisposeAsyncNotifier<List<Job>> {
  @override
  Future<List<Job>> build() async {
    final repo = ref.read(jobsRepositoryProvider);
    return repo.fetchFeed();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(jobsRepositoryProvider);
      return repo.fetchFeed();
    });
  }
}

final jobsFeedProvider =
    AutoDisposeAsyncNotifierProvider<JobsFeedNotifier, List<Job>>(
  JobsFeedNotifier.new,
);
```

**Rules:**
- Use `AutoDispose` for screen-scoped providers.
- Don't use `FutureProvider.family` for paginated lists — use `AsyncNotifier` with internal state.
- Keep Supabase calls inside `data/` layer repositories. Providers compose, repositories execute.

---

## 15. Folder Layout (where each thing lives)

```
lib/
├── core/
│   ├── supabase/
│   │   ├── supabase_client.dart        # SupabaseClient init
│   │   └── database_types.dart         # generated by `supabase gen types dart`
│   ├── auth/
│   │   └── jwt_helpers.dart            # decode user_role from JWT
│   ├── error/
│   │   └── failure.dart                # sealed class hierarchy
│   ├── theme/
│   └── routing/
│       └── app_router.dart             # GoRouter config
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── auth_repository.dart
    │   │   └── auth_remote_datasource.dart
    │   ├── domain/
    │   │   ├── entities/
    │   │   │   └── auth_user.dart
    │   │   └── usecases/
    │   └── presentation/
    │       ├── providers/
    │       └── screens/
    ├── profile/
    ├── jobs/
    ├── applications/
    ├── messaging/
    ├── verification/
    ├── reviews/
    └── notifications/
```

Each feature is independent. Cross-feature imports go through `domain/entities` only — never reach into another feature's `data` or `presentation`.

---

## 16. When the AI Is Stuck

If you (the AI) are about to:

- **Read data and you're not sure which RLS will apply** → assume nothing; check the policy file for that table.
- **Write a query and you don't know the index** → propose both the query and the index in the same diff. State the trade-off.
- **Add a feature that touches another feature** → call it out explicitly. Don't silently couple `messaging` to `jobs`.
- **Touch verification, suspensions, or admin actions** → require an Edge Function path. Refuse to do it from the client.
- **Add a new table** → also update §3 of this doc in the same PR.
- **Encounter a column or behavior not in this doc** → ask the human. Don't guess.

---

## 17. Layman's Term Explanation (for the human reading this over the AI's shoulder)

This doc is a **manual you give to a smart but new contractor on day one of a job site.** It says: here's where the toolbox is, here's the safety protocol, here's the lockbox combination, here's the foreman's name, here's what to do if you find asbestos. With this in hand, the contractor can be useful immediately. Without it, they'll do something dangerous within an hour.

Claude Code is that contractor. Drop this file in your repo at `docs/01-database-context.md`, and reference it in your `CLAUDE.md` (or equivalent) as required reading. Every code generation that touches the DB should start with: *"reading the database context doc..."* — if it doesn't, stop and tell it to.

---

## 18. How to Keep This Doc Truthful

Every time the schema changes:

1. Update the migration file in `supabase/migrations/`.
2. Run `supabase gen types dart` and commit.
3. Update §3 (Table Map) and §4 (Enums) in this doc.
4. If a new RBAC permission was added, update §5.
5. If a new common query emerged, add it to §12.

If this doc and the actual schema disagree, **the schema is right and this doc is wrong** — fix the doc, then re-feed it to the AI before continuing.
