# Jobdun — Screen Orchestration & Real-Data Wiring Guide

> **Agent Orchestration Document** — Drop this in every AI session that touches the nav screens. It contains the full audit of what is real vs. mock, what schema columns each screen needs, the correct provider shape, and the complete state matrix for each tab. Always read this before generating any screen, provider, or datasource code.
>
> **Last updated:** 2026-05-08
> **Status:** Implementation in progress — see § Execution Status at bottom.

---

## 0. Reading Order for a New AI Session

1. `docs/JOBDUN_AI_HANDOFF.md` — architecture, hard rules, RBAC patterns
2. `docs/JOBDUN_SCHEMA.md` — canonical table definitions and enums
3. This file — screen-by-screen data mapping and state matrices
4. Inspect current screen files before writing any code

---

## 1. Navigation Structure

**Shell file:** `lib/features/home/presentation/pages/home_shell_page.dart`
**Router:** `lib/app/router/app_router.dart` — `StatefulShellRoute.indexedStack`

| Tab | Index | Route | Screen file | Icon |
|-----|-------|-------|-------------|------|
| Home | 0 | `/home` | `lib/features/home/presentation/pages/home_page.dart` | Iconsax.home_2 / home_25 |
| Jobs | 1 | `/jobs` | `lib/features/jobs/presentation/pages/jobs_page.dart` | Iconsax.briefcase / briefcase5 |
| Applications | 2 | `/applications` | `lib/features/applications/presentation/pages/applications_page.dart` | Iconsax.document_text / document_text1 |
| Messages | 3 | `/messages` | `lib/features/messaging/presentation/pages/messages_page.dart` | Iconsax.message / message5 |
| Profile | 4 | `/profile` | `lib/features/profile/presentation/pages/profile_page.dart` | Iconsax.user / user5 |

**Nav badge wiring needed (home_shell_page.dart `_BottomNav`):**
- Tab 3 (Messages): unread count from `messagingControllerProvider.totalUnread`
- Tab 2 (Applications): pending count for builders

---

## 2. Critical Schema Mismatches Found in Codebase

These must be fixed before wiring any real data. The **schema is ground truth** — fix the code, not the schema.

### 2.1 Auth / Profiles
| Current code | Schema truth | Fix location |
|---|---|---|
| `profiles.role` column query | Role in `user_roles` table, exposed via JWT claim `user_role` | `auth_provider.dart` `_loadProfileForCurrentUser()` |
| `profiles.is_onboarding_complete` | `profiles.onboarding_completed_at IS NOT NULL` | `auth_provider.dart` `_fetchOnboardingStatus()` |
| `profiles.full_name` | `profiles.display_name` | `user_profile_model.dart` `fromJson` |
| `builder_profiles.profile_id` (insert key) | `builder_profiles.id` (PK = `profiles.id`) | `auth_provider.dart` `completeOnboarding()` |
| `trade_profiles.profile_id` (insert key) | `trade_profiles.id` (PK = `profiles.id`) | `auth_provider.dart` `completeOnboarding()` |
| `trade_profiles.trade_category` | `trade_profiles.primary_trade` | `trade_profile_model.dart` |
| `builder_profiles.business_type` | Does not exist in schema | Remove |

### 2.2 Applications
| Current code | Schema truth | Fix location |
|---|---|---|
| Table `job_applications` | Table `applications` | `application_remote_datasource.dart` |
| `applications.cover_message` | `applications.cover_note` | `job_application_model.dart` |
| `ApplicationStatus.accepted` | `ApplicationStatus.hired` | `job_application.dart` entity + model |
| Missing `builder_id` field | `applications.builder_id` exists | `job_application.dart` entity + model |

### 2.3 Jobs
| Current code | Schema truth | Fix location |
|---|---|---|
| `jobs.trade_category` | `jobs.trade_type_required` | `job_remote_datasource.dart`, `job_model.dart` |
| `jobs.budget` (single value) | `jobs.budget_min + budget_max` | `job.dart` entity, `job_model.dart` |
| `jobs.location` (String) | `jobs.suburb + state + postcode + location (geography)` | `job.dart` entity, `job_model.dart` |
| `jobs.required_skills` | Does not exist in schema | Remove |
| `jobs.required_licences` | `jobs.required_certifications` | `job_model.dart` |
| `JobStatus.inReview/assigned/inProgress/completed` | Schema: `draft/open/filled/closed/cancelled` | `job.dart` entity |
| Hard delete `from('jobs').delete()` | Schema: soft delete via `deleted_at` | `job_remote_datasource.dart` |

### 2.4 Messaging
| Current code | Schema truth | Fix location |
|---|---|---|
| `Conversation` entity derived from messages (no DB row) | `conversations` is a real table | `conversation.dart` entity |
| `messages.job_id + receiver_id` | `messages.conversation_id` only | `message.dart` entity, `message_model.dart` |
| `messages.is_read` (bool) | `messages.read_at` (timestamptz, null = unread) | `message_model.dart`, `message_remote_datasource.dart` |

### 2.5 Verification
| Current code | Schema truth | Fix location |
|---|---|---|
| `verification_documents.user_id` | `verification_documents.trade_id` | `verification_remote_datasource.dart`, `verification_document_model.dart` |
| Storage bucket `verification-documents` | Bucket `private-docs` | `verification_remote_datasource.dart` |
| Storage path `verification-documents/{userId}/{file}` | `private-docs/{trade_id}/verification/{doc_type}/{file}` | `verification_remote_datasource.dart` |
| Hard delete `from('verification_documents').delete()` | Soft delete — set `deleted_at = now()` | `verification_remote_datasource.dart` |
| `DocumentType.licence/insurance/identity` | `doc_type` enum: `trade_licence/public_liability/workers_compensation/white_card/photo_id/abn_certificate/other` | `verification_document.dart` entity |
| `verification_documents.document_type` | `verification_documents.doc_type` | model + datasource |
| `verification_documents.file_url` | `verification_documents.file_path` | model + datasource |
| `verification_documents.expires_at` | `verification_documents.expiry_date` (date, not timestamptz) | model + datasource |
| Signed URLs from client | **NEVER from client** — route through Edge Function `generate-signed-doc-url` | HANDOFF rule #7 |

### 2.6 Notifications
| Current code | Schema truth | Fix location |
|---|---|---|
| `notifications.is_read` (bool) | `notifications.read_at` (timestamptz null = unread) | `notification_model.dart`, `notification_remote_datasource.dart` |
| `markAsRead` sets `is_read = true` | Set `read_at = now()` | `notification_remote_datasource.dart` |
| `markAllAsRead` filters `eq('is_read', false)` | Filter `isNull('read_at')` | `notification_remote_datasource.dart` |
| `NotificationType.newJob` | Not in schema; use schema enum values | `app_notification.dart` entity |

### 2.7 Profile Storage
| Current code | Schema truth | Fix location |
|---|---|---|
| Storage bucket `avatars` | Bucket `public-media` | `profile_remote_datasource.dart` |
| Path `avatars/{userId}/{filename}` | Path `public-media/{userId}/avatar.jpg` | `profile_remote_datasource.dart` |

---

## 3. Per-Screen Audit

---

### TAB 0 — Home (`/home`)

**File:** `lib/features/home/presentation/pages/home_page.dart`
**Provider watched:** `authControllerProvider` only
**Current status:** Role + email = real. Stats, jobs list, tradies list = MOCK const data.

#### Supabase sources needed

| Data | Table | Columns | RLS context |
|---|---|---|---|
| Profile name + location | `profiles` | `display_name`, `avatar_url` | `id = auth.uid()` |
| Builder location | `builder_profiles` | `service_suburb, service_state` | `id = auth.uid()` |
| Trade location | `trade_profiles` | `base_suburb, base_state` | `id = auth.uid()` |
| Builder stats | `builder_profiles` | `total_jobs_posted, active_jobs_count, hire_count` | `id = auth.uid()` |
| Trade stats | `trade_profiles` | `total_applications, hire_count, average_rating` | `id = auth.uid()` |
| Builder home feed | `applications` JOIN `trade_profiles` | `a.status, a.created_at, tp.full_name, tp.primary_trade` | `builder_id = auth.uid()`, limit 3 |
| Trade home feed | `jobs` | `title, suburb, state, trade_type_required, budget_min, budget_max, budget_type, urgency, status` | `status = 'open'`, `deleted_at IS NULL`, limit 3 |

#### Provider required
- `profileControllerProvider` (add `loadProfile()` method)
- `jobsControllerProvider` (add `loadFeed()` for trade)
- `applicationsControllerProvider` (add `loadIncomingApplications()` for builder)

#### State matrix
| State | UI |
|---|---|
| Loading | `Skeletonizer` on stats row + list cards |
| Loaded — builder, has jobs | Stats (real counts) + recent applicants list |
| Loaded — builder, no jobs | Stats + "POST YOUR FIRST JOB" orange CTA card |
| Loaded — trade, has nearby jobs | Stats + 3 job cards |
| Loaded — trade, no nearby jobs | Stats + "No jobs near you." hint + "BROWSE ALL JOBS" secondary CTA |
| Error | Error snackbar + retry icon button top right |

#### Active / Disabled states
- **Stats row:** Numbers animate count-up on first load (600ms). Show `—` during loading.
- **"POST A JOB" button:** Always active for builders.
- **"BROWSE OPEN JOBS" button:** Always active for trades.
- **Job / tradie cards:** Tappable — navigate to `/jobs/:id` or show applicant detail.
- **Location badge:** Shows real suburb + state. Tappable → future map view.
- **Notifications bell:** Always active, badge shows unread count from `notifications` table.

---

### TAB 1 — Jobs (`/jobs`)

**File:** `lib/features/jobs/presentation/pages/jobs_page.dart`
**Provider watched:** `authControllerProvider`
**Current status:** Role = real. 6 job listings = MOCK. Search bar = non-functional. Filters = locally filtered mock data.

#### Supabase sources needed

**Trade view (job feed):**
| Data | Table | Columns | Filter |
|---|---|---|---|
| Job feed | `jobs` | `id, builder_id, title, suburb, state, trade_type_required, budget_min, budget_max, budget_type, urgency, requires_verified, application_count, published_at, status` | `status = 'open'`, `deleted_at IS NULL` |
| Full-text search | `jobs` | same | `search_vector @@ websearch_to_tsquery('english', query)` |
| Trade type filter | `jobs` | same | `trade_type_required = $filter` |

**Builder view (own jobs):**
| Data | Table | Columns | Filter |
|---|---|---|---|
| My jobs | `jobs` | all above + `application_count, filled_at, closed_at` | `builder_id = auth.uid()`, `deleted_at IS NULL` |

#### Provider shape
```dart
class JobsState {
  final AsyncValue<List<Job>> jobs;
  final String? activeFilter; // trade_type_required value
  final String? searchQuery;
  final bool isSearching;
}

// Methods to add:
Future<void> loadFeed();        // trade: open jobs; builder: own jobs
void applyFilter(String? tradeType);
Future<void> search(String query); // debounce 400ms in UI
Future<void> refresh();
Stream<List<Job>> watchBuilderJobs(); // builder only
```

#### State matrix
| State | UI |
|---|---|
| Loading | `Skeletonizer` wrapping 6 skeleton job cards |
| Loaded — results | `PagedListView` with staggered animation (50ms delay per card) |
| Loaded — empty, filtered | Lottie + "NO JOBS FOUND." + "CLEAR FILTERS" orange button |
| Loaded — empty, no jobs exist | Lottie + "NO OPEN JOBS NEARBY." + expand radius hint |
| Error | Error banner (orange left border) with "RETRY" button |
| Search active | Show "X results for 'query'" counter below search bar |

#### Active / Disabled states
- **Search bar:** Active always. Clear button appears when query non-empty.
- **Filter chips:** Tap = active (orange fill). Tap again = deactivate (back to border).
- **Job card:** Fully tappable → `/jobs/:id`. Swipeable left=Save, right=Hide.
- **Requires-verified jobs (unverified trade):** Grey overlay card + "VERIFICATION REQUIRED" badge. Not tappable for apply action but still visible.
- **"POST JOB" FAB / button (builder only):** Always active → `/jobs/create`.
- **Apply button per card:** Disabled if already applied (show "APPLIED" grey badge instead).

#### SQL recipe (trade feed)
```sql
select id, builder_id, title, suburb, state,
       trade_type_required, budget_min, budget_max, budget_type,
       urgency, requires_verified, application_count, published_at
from public.jobs
where status = 'open'
  and deleted_at is null
  -- optionally: and trade_type_required = $filter
order by urgency desc, published_at desc
limit 30;
```
*Uses `jobs_feed_idx` — (trade_type_required, published_at desc) where status = 'open' and deleted_at is null.*

---

### TAB 2 — Applications (`/applications`)

**File:** `lib/features/applications/presentation/pages/applications_page.dart`
**Provider watched:** None (pure placeholder `FeatureScaffoldPage`)
**Current status:** FULL PLACEHOLDER — generic scaffold only.

#### Supabase sources needed

**Trade view (my applications):**
| Data | Table | Join | Columns | Filter |
|---|---|---|---|---|
| My applications | `applications` | JOIN `jobs(title, suburb, state, status)` | `a.id, a.job_id, a.status, a.cover_note, a.proposed_rate, a.created_at`, `j.title, j.suburb, j.state, j.status` | `a.trade_id = auth.uid()` |
| Job builder name | `applications` JOIN `builder_profiles(company_name)` | | `bp.company_name` | via `a.builder_id` |

**Builder view (incoming applications):**
| Data | Table | Join | Columns | Filter |
|---|---|---|---|---|
| Incoming applications | `applications` | JOIN `trade_profiles(full_name, primary_trade, is_verified)` | `a.id, a.trade_id, a.status, a.cover_note, a.proposed_rate, a.created_at`, `tp.full_name, tp.primary_trade, tp.is_verified` | `a.builder_id = auth.uid()` |
| Per-job grouping | `jobs` | | `title` | via `a.job_id` |

#### Provider shape
```dart
class ApplicationsState {
  final AsyncValue<List<Application>> myApplications;        // trade
  final AsyncValue<List<Application>> incomingApplications;  // builder
  final ApplicationStatus? activeStatusFilter;
  final bool isLoading;
  final String? error;
}

// Methods to add:
Future<void> loadMyApplications();            // trade role
Future<void> loadIncomingApplications();      // builder role
Future<void> updateStatus(String id, ApplicationStatus newStatus); // builder
Future<void> withdraw(String id);             // trade
```

#### State matrix

**Trade tabs:** All | Pending | Shortlisted | Hired | Withdrawn

| State | UI |
|---|---|
| Loading | `Skeletonizer` on application rows |
| Loaded — Pending | Application card with job title, company, submitted date, "PENDING" chip |
| Loaded — Shortlisted | Card with orange border highlight + "SHORTLISTED" chip |
| Loaded — Hired | Card with green "HIRED" badge + confetti (once on first render) |
| Loaded — Withdrawn | Greyed out card, no action buttons |
| Empty tab | Lottie animation + tab-specific message + CTA |
| Error | Error banner + retry |

**Builder tabs:** All | Pending | Shortlisted | Hired | Rejected

| State | UI |
|---|---|
| Loading | Skeleton applicant rows |
| Pending applicant card | Trade name, trade type, is_verified badge, cover note preview, "SHORTLIST" + "REJECT" buttons |
| Shortlisted | Orange border, "HIRE" (green) + "REJECT" (red outline) buttons |
| Hired | Green "HIRED" badge, no action buttons |
| Rejected | Greyed card, no action buttons |
| Empty | "No applicants yet. Your job is live — applicants will appear here." |

#### Active / Disabled states
- **"SHORTLIST" button:** Active when `status = pending`. Disabled when `status` is any other value.
- **"HIRE" button:** Active when `status = shortlisted`. Disabled otherwise.
- **"REJECT" button:** Active when `status in (pending, shortlisted)`. Disabled otherwise.
- **"WITHDRAW" button (trade):** Active when `status in (pending, shortlisted)`. Not shown for hired/rejected.
- **Status chip:** Color-coded — `pending` = amber, `shortlisted` = orange, `hired` = green, `rejected` = red, `withdrawn` = grey.

#### ApplicationStatus enum (must match schema)
```dart
enum ApplicationStatus {
  pending,       // 'pending'
  shortlisted,   // 'shortlisted'
  rejected,      // 'rejected'
  withdrawn,     // 'withdrawn'
  hired,         // 'hired'         ← was 'accepted' — rename
  declinedByTrade // 'declined_by_trade'  ← new
}
```

---

### TAB 3 — Messages (`/messages`)

**File:** `lib/features/messaging/presentation/pages/messages_page.dart`
**Provider watched:** None (pure placeholder `FeatureScaffoldPage`)
**Current status:** FULL PLACEHOLDER — generic scaffold only.

#### Supabase sources needed

**Conversations list:**
| Data | Table | Join | Columns |
|---|---|---|---|
| Conversations | `conversations` | JOIN `profiles_public` (other user) | `c.id, c.job_id, c.builder_id, c.trade_id, c.last_message_at, c.last_message_preview, c.builder_unread_count, c.trade_unread_count, c.status` |
| Other user name | `profiles_public` | via `builder_id` or `trade_id` | `display_name, avatar_url` |
| Job title | `jobs` | via `job_id` | `title` |

**Filter:** `builder_id = auth.uid() OR trade_id = auth.uid()`, `status != 'blocked'`
**Order:** `last_message_at desc nulls last`

**Messages in thread:**
| Data | Table | Columns |
|---|---|---|
| Messages | `messages` | `id, conversation_id, sender_id, body, read_at, deleted_at, created_at` |
| Filter | | `conversation_id = $convId`, `deleted_at IS NULL` |
| Order | | `created_at asc` |

#### Realtime rules (HANDOFF §9 — CRITICAL)
- Subscribe to `conversations` stream on messages list screen entry.
- Subscribe to `messages WHERE conversation_id = X` on thread screen entry.
- **Cancel both on screen dispose.** Never leave subscriptions open.
- Mark-read debounce: 2s per conversation (no per-message mark-read on render).
- Fallback poll if WS disconnects > 10s.

#### Provider shape
```dart
class MessagingState {
  final AsyncValue<List<Conversation>> conversations;
  final int totalUnread;          // sum of my unread across all conversations
  final bool isLoading;
  final String? error;
}

// Methods to add:
Future<void> loadConversations();
void startConversationsStream();
void stopConversationsStream();
Future<void> sendMessage(String conversationId, String body);
Future<void> markConversationRead(String conversationId); // debounced 2s
```

**Thread screen** has its own provider (per-conversation):
```dart
// AutoDispose provider — cancelled when thread screen disposes
final messageThreadProvider = AutoDisposeAsyncNotifierProvider
  .family<MessageThreadNotifier, List<Message>, String>(...)
```

#### State matrix — Conversations list

| State | UI |
|---|---|
| Loading | Skeleton conversation rows (avatar circle + 2 text lines) |
| Loaded — has conversations | List sorted by `last_message_at desc` |
| Loaded — empty | Lottie + "NO MESSAGES YET." + "BROWSE JOBS" (trade) or "POST A JOB" (builder) |
| Error | Error banner + retry |

#### State matrix — Conversation row

| State | UI |
|---|---|
| Has unread | Bold preview text + orange unread count badge |
| No unread | Normal weight preview text, no badge |
| Blocked | "(Blocked)" preview text, greyed row, not tappable |
| Archived | Not shown in default list |
| Last message deleted | "(Message deleted)" preview text in italic |

#### State matrix — Message thread

| State | UI |
|---|---|
| Loading | Skeleton message bubbles (alternating sides) |
| Loaded | Chat bubbles: sender right (orange), receiver left (surface `#1E293B`) |
| Error sending | Red tint bubble + retry icon |
| Deleted message | "(Message deleted)" italic text, no bubble background |
| Blocked conversation | Banner at top "THIS CONVERSATION IS BLOCKED. You cannot send new messages." |

#### Active / Disabled states
- **Send button:** Disabled when text field empty. Active when text non-empty.
- **Text field:** Disabled when conversation status = `blocked` or `archived`.
- **Conversation row swipe (left):** Archive action. Only for `active` conversations.

#### Conversation entity (must match schema table)
```dart
class Conversation extends Equatable {
  final String id;
  final String? jobId;
  final String builderId;
  final String tradeId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int builderUnreadCount;
  final int tradeUnreadCount;
  final ConversationStatus status;   // active | archived | blocked
  final DateTime createdAt;
  // Joined fields (from profiles_public + jobs):
  final String? otherUserDisplayName;
  final String? otherUserAvatarUrl;
  final String? jobTitle;
}
```

#### Message entity (must match schema table)
```dart
class Message extends Equatable {
  final String id;
  final String conversationId;  // was jobId — BREAKING CHANGE
  final String senderId;
  // NO receiverId — schema doesn't have it
  final String body;
  final DateTime? readAt;       // was isRead bool
  final DateTime? deletedAt;
  final DateTime createdAt;
}
```

---

### TAB 4 — Profile (`/profile`)

**File:** `lib/features/profile/presentation/pages/profile_page.dart`
**Provider watched:** `authControllerProvider`
**Current status:** Email + role = real. All profile details (company name, ABN, trade details, stats, verification) = MOCK const data.

#### Supabase sources needed

| Data | Table | Columns |
|---|---|---|
| Base profile | `profiles` | `id, display_name, email, phone, avatar_url, bio, onboarding_completed_at` |
| Builder data | `builder_profiles` | `company_name, abn, contact_name, contact_phone, logo_url, about, website, service_suburb, service_state, total_jobs_posted, active_jobs_count, hire_count, average_rating, rating_count` |
| Trade data | `trade_profiles` | `full_name, primary_trade, crew_size, years_experience, base_suburb, base_state, service_radius_km, is_verified, verified_at, total_applications, hire_count, jobs_completed, average_rating, rating_count, about` |
| Verification status | `verification_documents` | `doc_type, status, expiry_date` | `trade_id = auth.uid()`, `deleted_at IS NULL` |
| Recent reviews | `reviews` | `rating, body, reviewer_id, created_at` | `reviewee_id = auth.uid()`, limit 5 |

#### Provider shape
```dart
class ProfileState {
  final AsyncValue<UserProfile?> profile;
  final AsyncValue<BuilderProfile?> builderProfile;
  final AsyncValue<TradeProfile?> tradeProfile;
  final AsyncValue<List<VerificationDocument>> documents;
  final AsyncValue<List<Review>> reviews;
  final bool isAvatarUploading;
  final String? error;
}

// Methods to add:
Future<void> loadProfile();
Future<void> updateProfile(Map<String, dynamic> fields);
Future<void> uploadAvatar(File file);
Future<void> loadReviews();
```

#### State matrix

| State | UI |
|---|---|
| Loading | `Skeletonizer` wrapping entire profile layout |
| Loaded — complete builder | Company logo/name, ABN, location, stats row (posted/hired/rating), About, Edit button |
| Loaded — complete trade | Avatar, full_name, primary_trade chip, is_verified badge, stats row (applied/hired/rating), About |
| Loaded — incomplete profile | Orange warning banner "YOUR PROFILE IS INCOMPLETE." + list of missing fields + "ADD NOW" inline button |
| Unverified trade | Greyed verification badges (ID, Licence, Insurance) + "UPLOAD DOCS" CTA |
| Verified trade | Green border on avatar, "VERIFIED" badge below name |
| Avatar uploading | `CircularProgressIndicator` overlay on avatar circle |
| Edit mode | Navigate to `/profile/edit` → `ProfileEditPage` (TODO file) |
| Error | Error snackbar + cached state remains visible |

#### Active / Disabled states
- **Edit button:** Always active (top right, `#334155` fill, Iconsax.edit).
- **Verification badges:** Tappable → `/verification` screen. Green border = approved, amber = pending, grey = not uploaded, red = rejected/expired.
- **Stats numbers:** Count-up animation 600ms on first render (flutter_animate).
- **Reviews section:** Expandable (expandable package). "SEE ALL REVIEWS" link at bottom if > 5.
- **Sign-out button:** Always active. Triggers `authControllerProvider.notifier.signOut()`.

#### UserProfile entity (must match schema)
```dart
class UserProfile extends Equatable {
  final String id;
  final String? displayName;   // was fullName — maps to profiles.display_name
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  // role comes from JWT via authControllerProvider — NOT from this entity
}
```

#### BuilderProfile entity (must match schema)
```dart
class BuilderProfile extends Equatable {
  final String id;
  final String companyName;
  final String? abn;
  final String? contactName;
  final String? contactPhone;
  final String? logoUrl;
  final String? about;
  final String? website;
  final int? yearsInBusiness;
  final String? serviceSuburb;
  final String? serviceState;
  final int totalJobsPosted;
  final int activeJobsCount;
  final int hireCount;
  final double? averageRating;
  final int ratingCount;
}
```

#### TradeProfile entity (must match schema)
```dart
class TradeProfile extends Equatable {
  final String id;
  final String fullName;
  final String primaryTrade;    // was tradeCategory
  final int crewSize;
  final int? yearsExperience;
  final String? baseSuburb;     // was serviceArea
  final String? baseState;
  final int serviceRadiusKm;
  final String? about;          // was bio
  final bool isVerified;
  final DateTime? verifiedAt;
  final int totalApplications;
  final int hireCount;
  final int jobsCompleted;
  final double? averageRating;
  final int ratingCount;
}
```

---

## 4. Nav Bar Badges (home_shell_page.dart)

Make `_BottomNav` a `ConsumerWidget` and read:

```dart
// Messages badge
final totalUnread = ref.watch(
  messagingControllerProvider.select((s) => s.totalUnread)
);

// Applications badge (builder only)
final pendingCount = ref.watch(
  applicationsControllerProvider.select(
    (s) => s.incomingApplications.valueOrNull
        ?.where((a) => a.status == ApplicationStatus.pending)
        .length ?? 0
  )
);
```

Use `badges` package `Badge` widget overlaid on the `Iconsax.message5` / `Iconsax.document_text1` icons.

---

## 5. New Files to Create

| File | Purpose |
|---|---|
| `lib/features/messaging/presentation/pages/message_thread_page.dart` | Per-conversation chat screen |
| `lib/features/messaging/data/models/conversation_model.dart` | Conversation DB model |
| `lib/features/applications/presentation/widgets/application_card.dart` | Application list item (trade view) |
| `lib/features/applications/presentation/widgets/applicant_card.dart` | Applicant list item (builder view) |
| `lib/features/profile/presentation/pages/profile_edit_page.dart` | Profile edit screen |

---

## 6. Execution Status

Track progress here after each session.

| Step | Status | Notes |
|---|---|---|
| 0. Create this orchestration doc | ✅ DONE | |
| 1. Fix auth provider (JWT role + onboarding_completed_at) | ⏳ TODO | |
| 2. Fix applications datasource (table rename + cover_note) | ⏳ TODO | |
| 3. Fix messaging datasource (conversations model) | ⏳ TODO | |
| 4. Fix verification datasource (trade_id + private-docs bucket) | ⏳ TODO | |
| 5. Fix notifications datasource (read_at) | ⏳ TODO | |
| 6. Fix profile datasource (public-media bucket) | ⏳ TODO | |
| 7. Align domain entities with schema | ⏳ TODO | Job, Application, Message, Conversation, UserProfile, BuilderProfile, TradeProfile, VerificationDocument, enums |
| 8. Wire JobsController provider | ⏳ TODO | |
| 9. Wire ApplicationsController provider | ⏳ TODO | |
| 10. Wire MessagingController provider | ⏳ TODO | |
| 11. Wire ProfileController provider | ⏳ TODO | |
| 12. Update Home screen (replace mock) | ⏳ TODO | |
| 13. Update Jobs screen (real search/filter) | ⏳ TODO | |
| 14. Build Applications screen (from scratch) | ⏳ TODO | |
| 15. Build Messages screen (from scratch) | ⏳ TODO | |
| 16. Update Profile screen (replace mock) | ⏳ TODO | |
| 17. Wire nav bar badges | ⏳ TODO | |
| 18. flutter analyze — zero errors | ⏳ TODO | |
| 19. Manual smoke test (builder role) | ⏳ TODO | |
| 20. Manual smoke test (trade role) | ⏳ TODO | |

---

## 7. Quick Reference: Design Tokens for State UIs

From `design-system/jobdun/MASTER.md` and page overrides:

| Token | Value | Use |
|---|---|---|
| Background | `#0F172A` | Screen backgrounds |
| Surface | `#1E293B` | Cards, inputs, skeleton base |
| Surface Raised | `#334155` | Elevated cards, secondary buttons, inactive chips |
| Action / CTA | `#F97316` | Primary buttons, active states, unread badges |
| Primary text | `#F1F5F9` | Main content |
| Secondary text | `#94A3B8` | Labels, hints, metadata |
| Success / Verified | `#22C55E` | Hired badge, verified badge |
| Error / Urgent | `#EF4444` | Rejected badge, error states |
| Star / Rating | `#F59E0B` | Stars |
| Border | `#334155` | Card borders, dividers |

**Loading:** `Skeletonizer(child: ...)` — auto-generates skeleton from real widget tree
**Empty state pattern:** Lottie animation + uppercase Display headline + secondary body text + orange CTA button
**Error pattern:** Container with `#EF4444` left border 4dp + error message + "RETRY" TextButton
**Animations:** `flutter_staggered_animations` on lists, `flutter_animate` for micro-interactions, 150–200ms ease

---

*End of SCREENS_ORCHESTRATION.md — update the Execution Status table after each session.*
