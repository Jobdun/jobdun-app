# Apprentice Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let apprentices build a profile that fits them (apprenticeship target, stage, description, resume, self-declared site tickets, photos) and let builders find them.

**Architecture:** Apprentice is a *mode* of the existing `trade` role, not a new auth role. Five new columns on `trade_profiles`, one new reference table `site_tickets`, one new column on `jobs`, one additive storage RLS policy, and a `search_trades` signature bump. No change to auth, the JWT `user_role` claim, the router, or account deletion. Feature-first Clean Architecture throughout: `presentation/` imports `domain/` only; the provider file is the sole seam wiring `data/` in.

**Tech Stack:** Flutter 3.41.7 / Dart ^3.11.5, Supabase (Postgres + Storage + RLS), Riverpod 3 (`Notifier`/`AsyncNotifier` only), fpdart `Either`/`Option`, `flutter_form_builder`, `file_picker ^8.1.6`, `flutter_test` + `mocktail`.

**Spec:** `docs/superpowers/specs/2026-08-30-apprentice-profiles-design.md`

---

## Ground rules for every task

Re-read these before each task. They are enforced by `scripts/validate.sh` and
`scripts/check-architecture.sh`, which run on pre-push.

- **No hardcoded hex, no `Colors.white`, no `AppColors.*`, no gradients, no `GoogleFonts.*`** anywhere in `lib/features/`. Read colour via `context.c.<token>`.
- **No raw `SizedBox(height:/width:)` for spacing** — use `Gap(n)`. `SizedBox(width: double.infinity)` for a button wrapper is fine (no height/width *spacing* value).
- **Sizes** use `flutter_screenutil`: `.w` `.h` `.r`. **Never `.sp` on `fontSize`.**
- **Text** routes through `Theme.of(context).textTheme.<role>!.copyWith(...)`. No detached `TextStyle(fontSize: ...)`.
- **Icons** from `AppIcons.*`, sized with `AppIconSize.*.r`. Never import `phosphor_flutter` in feature code.
- **One widget per file.** Private helper widgets allowed only with a single caller in the same file. **No methods returning `Widget`.**
- **File size:** target ≤ 400 LOC, hard ceiling 500.
- **`c.surfaceRaised` carries `c.text1` only** (`app_colors.dart:105,110` — `text2` is 4.04:1 and `text3` is 3.54:1 on it, both below the 4.5 floor).
- Run `dart format .` before every commit or the format check fails.

---

## File structure

| File | Responsibility |
|---|---|
| `supabase/migrations/20260831000001_apprentice_columns.sql` | 5 columns + CHECK + partial index on `trade_profiles` |
| `supabase/migrations/20260831000002_site_tickets.sql` | `site_tickets` reference table, RLS, 9-row seed |
| `supabase/migrations/20260831000003_resume_storage_access.sql` | Additive `storage.objects` SELECT policy for applied-to builders |
| `supabase/migrations/20260831000004_search_trades_apprentices.sql` | DROP + recreate `search_trades` with `p_apprentice` |
| `supabase/migrations/20260831000005_jobs_open_to_apprentices.sql` | `jobs.open_to_apprentices` |
| `supabase/migrations/20260831000006_profile_completeness_apprentice.sql` | Apprentice-aware completeness slots |
| `supabase/rollbacks/20260831000001..6_*_down.sql` | One down script per migration |
| `lib/features/profile/domain/entities/apprenticeship_stage.dart` | Stage enum + exhaustive `dbValue`/`label` |
| `lib/features/profile/domain/entities/site_ticket.dart` | `SiteTicket` entity + `SiteTicketCategory` enum |
| `lib/features/profile/data/models/site_ticket_model.dart` | `site_tickets` row → entity |
| `lib/features/profile/presentation/providers/site_tickets_provider.dart` | Reference-data `FutureProvider` (mirrors `trade_categories_provider`) |
| `lib/features/profile/domain/usecases/upload_resume.dart` | Upload + stamp `resume_path` |
| `lib/features/profile/domain/usecases/delete_resume.dart` | Delete object + clear column |
| `lib/features/profile/domain/usecases/get_resume_url.dart` | Mint a 60-min signed URL |
| `lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet.dart` | Sheet shell + save |
| `lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet_rows.dart` | Grouped rows + tick box (split up front to stay under 400 LOC) |
| `lib/features/profile/presentation/widgets/edit_sheets/resume_sheet.dart` | Pick / replace / remove |
| `lib/features/profile/presentation/widgets/ticket_chip.dart` | One two-tier chip |
| `lib/features/profile/presentation/widgets/ticket_chip_wall.dart` | Wrap of chips + builder disclaimer |
| `lib/features/profile/presentation/widgets/resume_row.dart` | Filename / date / actions / locked state |
| `lib/features/profile/presentation/widgets/apprentice_header_chip.dart` | `2ND-YEAR CARPENTRY APPRENTICE` |
| `lib/features/discovery/presentation/widgets/discovery_mode_toggle.dart` | TRADES / APPRENTICES segmented control |

Modified: `trade_profile.dart`, `trade_profile_model.dart`, `profile_patches.dart`, `profile_patch_mappers.dart`, `profile_repository.dart`, `profile_repository_impl.dart`, `profile_remote_datasource.dart`, `profile_provider.dart`, `trade_details_sheet.dart`, `profile_edit_hub_page.dart`, `trade_public_profile_page.dart`, `profile_page_trade.dart`, `trade_search_filter.dart`, `trade_search_result.dart`, `trade_search_remote_datasource.dart`, `discovery_page.dart`, `discovery_tradie_tile.dart`, `job.dart`, `job_model.dart`, `job_remote_datasource.dart`, `job_create_page.dart`.

---

## Task 1: Database migrations

**Files:**
- Create: `supabase/migrations/20260831000001_apprentice_columns.sql`
- Create: `supabase/migrations/20260831000002_site_tickets.sql`
- Create: `supabase/migrations/20260831000003_resume_storage_access.sql`
- Create: `supabase/migrations/20260831000005_jobs_open_to_apprentices.sql`
- Create: matching `supabase/rollbacks/*_down.sql`

(`...000004` search_trades is Task 13; `...000006` completeness is Task 15. They are numbered now so the sequence is stable.)

- [ ] **Step 1: Write `20260831000001_apprentice_columns.sql`**

```sql
-- supabase/migrations/20260831000001_apprentice_columns.sql
--
-- Apprentice mode on the existing trade role. An apprentice IS a trade row:
-- primary_trade carries the apprenticeship they want (same trade_categories
-- picker every tradie uses), about carries the description, portfolio_urls
-- carries the photos. Only these five columns are new.
--
-- Deliberately NOT a third auth role: that would touch the JWT user_role
-- claim, RLS across every table, the router, and delete_my_account.
--
-- Reversibility: SAFE — additive columns with defaults; no data is rewritten.

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS is_apprentice        boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS apprenticeship_stage text,
  ADD COLUMN IF NOT EXISTS site_tickets         text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS resume_path          text,
  ADD COLUMN IF NOT EXISTS resume_uploaded_at   timestamptz;

-- Stage stays nullable even when is_apprentice is true: "not sure yet" is a
-- real answer for a school leaver and NOT NULL would force a bad default.
DO $$ BEGIN
  ALTER TABLE public.trade_profiles
    ADD CONSTRAINT trade_profiles_apprenticeship_stage_valid
    CHECK (apprenticeship_stage IS NULL OR apprenticeship_stage IN
      ('pre_apprentice','year_1','year_2','year_3','year_4'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE INDEX IF NOT EXISTS trade_profiles_is_apprentice_idx
  ON public.trade_profiles (is_apprentice) WHERE deleted_at IS NULL;

COMMENT ON COLUMN public.trade_profiles.is_apprentice IS
  'True when this trade is seeking an apprenticeship. Flips the profile to the '
  'apprentice layout (no rates, no insurance) and moves the row into the '
  'APPRENTICES side of search_trades.';
COMMENT ON COLUMN public.trade_profiles.site_tickets IS
  'SELF-DECLARED site ticket slugs (FK-by-convention to site_tickets.slug). '
  'A tick is a claim, NOT proof — verified credentials live in '
  'verification_documents and surface via get_trade_public_credentials.';
```

- [ ] **Step 2: Write the rollback**

```sql
-- supabase/rollbacks/20260831000001_apprentice_columns_down.sql
DROP INDEX IF EXISTS public.trade_profiles_is_apprentice_idx;
ALTER TABLE public.trade_profiles
  DROP CONSTRAINT IF EXISTS trade_profiles_apprenticeship_stage_valid;
ALTER TABLE public.trade_profiles
  DROP COLUMN IF EXISTS is_apprentice,
  DROP COLUMN IF EXISTS apprenticeship_stage,
  DROP COLUMN IF EXISTS site_tickets,
  DROP COLUMN IF EXISTS resume_path,
  DROP COLUMN IF EXISTS resume_uploaded_at;
```

- [ ] **Step 3: Write `20260831000002_site_tickets.sql`**

```sql
-- supabase/migrations/20260831000002_site_tickets.sql
--
-- Reference table for site tickets / tucket licences, modelled on
-- trade_categories so the list is editable without an app release.
--
-- doc_type maps a ticket to the verification_documents review path. Only
-- white_card has one today — it is the single ticket with a working
-- end-to-end flow (ManualDocKind.whiteCard → admin review →
-- get_trade_public_credentials). The other eight are self-declared only and
-- the "upload to verify" nudge renders solely where doc_type IS NOT NULL.
--
-- Reversibility: SAFE — new table only.

CREATE TABLE IF NOT EXISTS public.site_tickets (
  slug         text PRIMARY KEY,
  display_name text NOT NULL,
  short_name   text NOT NULL,
  category     text NOT NULL
                 CHECK (category IN ('induction','safety','licence','transport')),
  doc_type     text,
  sort_order   int  NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.site_tickets ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "site_tickets_select_all"
    ON public.site_tickets FOR SELECT
    TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- EWP is split into the two real Australian tickets: the Yellow Card covers
-- boom lifts under 11m (industry VOC card), the WP high risk work licence
-- covers 11m and above. Sites ask for them separately.
INSERT INTO public.site_tickets
  (slug, short_name, display_name, category, doc_type, sort_order) VALUES
  ('white_card',         'White Card',        'White Card (Construction Induction, CPCCWHS1001)', 'induction', 'white_card', 10),
  ('first_aid',          'First Aid',         'First Aid (HLTAID011)',                            'safety',    NULL,         10),
  ('working_at_heights', 'Working at Heights','Working at Heights (RIIWHS204E)',                  'safety',    NULL,         20),
  ('confined_space',     'Confined Space',    'Confined Space (RIIWHS202E)',                      'safety',    NULL,         30),
  ('ewp_yellow_card',    'EWP Yellow Card',   'EWP Yellow Card (boom under 11m)',                 'licence',   NULL,         10),
  ('ewp_wp_licence',     'EWP Licence (WP)',  'EWP High Risk Work Licence (WP, boom 11m+)',       'licence',   NULL,         20),
  ('dogging',            'Dogging',           'Dogging Licence (DG)',                             'licence',   NULL,         30),
  ('rigging',            'Rigging',           'Rigging Licence (RB / RI / RA)',                   'licence',   NULL,         40),
  ('drivers_licence',    'Driver Licence',    'Australian Driver Licence',                        'transport', NULL,         10)
ON CONFLICT (slug) DO NOTHING;
```

- [ ] **Step 4: Write the rollback**

```sql
-- supabase/rollbacks/20260831000002_site_tickets_down.sql
DROP POLICY IF EXISTS "site_tickets_select_all" ON public.site_tickets;
DROP TABLE IF EXISTS public.site_tickets;
```

- [ ] **Step 5: Write `20260831000003_resume_storage_access.sql`**

```sql
-- supabase/migrations/20260831000003_resume_storage_access.sql
--
-- Apprentice resumes live at private-docs/{uid}/resume/{epoch}.{ext}.
-- The owner already has full CRUD via private_docs_owner_* (20260511000006),
-- which keys on (storage.foldername(name))[1] = auth.uid().
--
-- This ADDS a second SELECT policy so a builder can open the resume of an
-- apprentice who has applied to one of their jobs. Postgres OR-s policies, so
-- the owner-only rule is untouched — this only widens read.
--
-- Why no Edge Function: Storage RLS is plain RLS on storage.objects, so the
-- client can call createSignedUrl with the anon key and the policy is
-- enforced. A function would add a deploy surface for nothing.
--
-- A resume carries a home address, phone number and school, and many of these
-- users are minors. Relationship-gated is the floor, not a nicety.
--
-- Reversibility: SAFE — additive policy.

DO $$ BEGIN
  CREATE POLICY "private_docs_resume_applied_builder_select"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'private-docs'
      AND (storage.foldername(name))[2] = 'resume'
      AND EXISTS (
        SELECT 1
        FROM public.applications a
        WHERE a.trade_id::text = (storage.foldername(name))[1]
          AND a.builder_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

- [ ] **Step 6: Write the rollback**

```sql
-- supabase/rollbacks/20260831000003_resume_storage_access_down.sql
DROP POLICY IF EXISTS "private_docs_resume_applied_builder_select" ON storage.objects;
```

- [ ] **Step 7: Write `20260831000005_jobs_open_to_apprentices.sql`**

```sql
-- supabase/migrations/20260831000005_jobs_open_to_apprentices.sql
--
-- "Open to apprentices" is an INVITATION SIGNAL, not a gate waiver.
--
-- requires_verified and requires_public_liability are stored and rendered on
-- the job card but never enforced at apply time (verified 2026-08-30: no
-- apply-path check exists in lib/features/applications or
-- lib/features/jobs/presentation). There is no gate to waive. This flag drives
-- an OPEN TO APPRENTICES chip and an apprentice-side feed filter.
--
-- Matches the platform's stated posture: trust signals, never gates
-- (see 20260610000006_trade_public_credentials.sql).
--
-- Reversibility: SAFE — additive column with a default.

ALTER TABLE public.jobs
  ADD COLUMN IF NOT EXISTS open_to_apprentices boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.jobs.open_to_apprentices IS
  'Builder invites apprentice applicants. A signal on the job card and an '
  'apprentice-side filter — it gates nothing.';
```

- [ ] **Step 8: Write the rollback**

```sql
-- supabase/rollbacks/20260831000005_jobs_open_to_apprentices_down.sql
ALTER TABLE public.jobs DROP COLUMN IF EXISTS open_to_apprentices;
```

- [ ] **Step 9: Commit**

```bash
git add supabase/migrations/2026083100000{1,2,3,5}_*.sql supabase/rollbacks/2026083100000{1,2,3,5}_*.sql
git commit -m "feat(db): apprentice columns, site_tickets, resume access, job flag"
```

---

## Task 2: ApprenticeshipStage enum

**Files:**
- Create: `lib/features/profile/domain/entities/apprenticeship_stage.dart`
- Test: `test/features/profile/apprenticeship_stage_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/apprenticeship_stage_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';

void main() {
  group('ApprenticeshipStage', () {
    test('every value round-trips through dbValue', () {
      for (final s in ApprenticeshipStage.values) {
        expect(ApprenticeshipStage.fromDb(s.dbValue), s);
      }
    });

    test('unknown / null db values resolve to null', () {
      expect(ApprenticeshipStage.fromDb(null), isNull);
      expect(ApprenticeshipStage.fromDb('year_9'), isNull);
      expect(ApprenticeshipStage.fromDb(''), isNull);
    });

    test('db values match the CHECK constraint exactly', () {
      expect(ApprenticeshipStage.values.map((s) => s.dbValue).toList(), [
        'pre_apprentice',
        'year_1',
        'year_2',
        'year_3',
        'year_4',
      ]);
    });

    test('labels are human-readable and non-empty', () {
      expect(ApprenticeshipStage.preApprentice.label, 'Pre-apprentice');
      expect(ApprenticeshipStage.year2.label, '2nd year');
      for (final s in ApprenticeshipStage.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('headline renders the profile chip text', () {
      expect(
        ApprenticeshipStage.year2.headline('Carpentry'),
        '2ND-YEAR CARPENTRY APPRENTICE',
      );
      expect(
        ApprenticeshipStage.preApprentice.headline('Electrical'),
        'PRE-APPRENTICE ELECTRICAL',
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/apprenticeship_stage_test.dart`
Expected: FAIL — `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/profile/domain/entities/apprenticeship_stage.dart

/// How far through an apprenticeship someone is.
///
/// `dbValue` is pinned to the CHECK constraint in
/// `20260831000001_apprentice_columns.sql`. Adding a value here without adding
/// it there writes a row Postgres rejects, so the round-trip test above is the
/// guard: keep both lists in lockstep.
enum ApprenticeshipStage { preApprentice, year1, year2, year3, year4 }

extension ApprenticeshipStageX on ApprenticeshipStage {
  String get dbValue => switch (this) {
    ApprenticeshipStage.preApprentice => 'pre_apprentice',
    ApprenticeshipStage.year1 => 'year_1',
    ApprenticeshipStage.year2 => 'year_2',
    ApprenticeshipStage.year3 => 'year_3',
    ApprenticeshipStage.year4 => 'year_4',
  };

  String get label => switch (this) {
    ApprenticeshipStage.preApprentice => 'Pre-apprentice',
    ApprenticeshipStage.year1 => '1st year',
    ApprenticeshipStage.year2 => '2nd year',
    ApprenticeshipStage.year3 => '3rd year',
    ApprenticeshipStage.year4 => '4th year',
  };

  /// Ordinal used in the profile chip: "2ND-YEAR CARPENTRY APPRENTICE".
  /// Pre-apprentice has no year, so it reads "PRE-APPRENTICE CARPENTRY".
  String headline(String trade) {
    final t = trade.trim().toUpperCase();
    return switch (this) {
      ApprenticeshipStage.preApprentice => 'PRE-APPRENTICE $t',
      ApprenticeshipStage.year1 => '1ST-YEAR $t APPRENTICE',
      ApprenticeshipStage.year2 => '2ND-YEAR $t APPRENTICE',
      ApprenticeshipStage.year3 => '3RD-YEAR $t APPRENTICE',
      ApprenticeshipStage.year4 => '4TH-YEAR $t APPRENTICE',
    };
  }

  static ApprenticeshipStage? fromDb(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final s in ApprenticeshipStage.values) {
      if (s.dbValue == value) return s;
    }
    return null;
  }
}
```

Note: `fromDb` is a static on the *extension*, called as `ApprenticeshipStage.fromDb(...)` — Dart resolves statics on the extension through the enum name only when the extension is in scope, so the import must be the entity file itself (it is).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/profile/apprenticeship_stage_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/profile/domain/entities/apprenticeship_stage.dart test/features/profile/apprenticeship_stage_test.dart
git add lib/features/profile/domain/entities/apprenticeship_stage.dart test/features/profile/apprenticeship_stage_test.dart
git commit -m "feat(profile): ApprenticeshipStage enum"
```

---

## Task 3: SiteTicket entity + model

**Files:**
- Create: `lib/features/profile/domain/entities/site_ticket.dart`
- Create: `lib/features/profile/data/models/site_ticket_model.dart`
- Test: `test/features/profile/site_ticket_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/site_ticket_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/site_ticket_model.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';

void main() {
  group('SiteTicketModel.fromJson', () {
    test('parses a verifiable ticket (white_card has a doc_type)', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'white_card',
        'short_name': 'White Card',
        'display_name': 'White Card (Construction Induction, CPCCWHS1001)',
        'category': 'induction',
        'doc_type': 'white_card',
        'sort_order': 10,
      });
      expect(t.slug, 'white_card');
      expect(t.shortName, 'White Card');
      expect(t.category, SiteTicketCategory.induction);
      expect(t.docType, 'white_card');
      expect(t.isVerifiable, isTrue);
    });

    test('a null doc_type means self-declared only, no upload nudge', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'dogging',
        'short_name': 'Dogging',
        'display_name': 'Dogging Licence (DG)',
        'category': 'licence',
        'doc_type': null,
        'sort_order': 30,
      });
      expect(t.docType, isNull);
      expect(t.isVerifiable, isFalse);
    });

    test('unknown category falls back to safety rather than throwing', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'mystery',
        'short_name': 'Mystery',
        'display_name': 'Mystery',
        'category': 'not_a_category',
        'sort_order': 0,
      });
      expect(t.category, SiteTicketCategory.safety);
    });

    test('missing sort_order defaults to 0', () {
      final t = SiteTicketModel.fromJson(const {
        'slug': 'first_aid',
        'short_name': 'First Aid',
        'display_name': 'First Aid (HLTAID011)',
        'category': 'safety',
      });
      expect(t.sortOrder, 0);
    });
  });

  group('SiteTicketCategory', () {
    test('every db value round-trips', () {
      const dbValues = ['induction', 'safety', 'licence', 'transport'];
      for (final v in dbValues) {
        expect(SiteTicketCategory.fromDb(v).dbValue, v);
      }
    });

    test('labels are the sheet group headers', () {
      expect(SiteTicketCategory.induction.label, 'Induction');
      expect(SiteTicketCategory.licence.label, 'Licences');
      expect(SiteTicketCategory.transport.label, 'Transport');
      expect(SiteTicketCategory.safety.label, 'Safety');
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/site_ticket_model_test.dart`
Expected: FAIL — URIs don't exist.

- [ ] **Step 3: Write the entity**

```dart
// lib/features/profile/domain/entities/site_ticket.dart
import 'package:equatable/equatable.dart';

/// Grouping used for the section headers in the tickets sheet.
enum SiteTicketCategory {
  induction,
  safety,
  licence,
  transport;

  String get dbValue => switch (this) {
    SiteTicketCategory.induction => 'induction',
    SiteTicketCategory.safety => 'safety',
    SiteTicketCategory.licence => 'licence',
    SiteTicketCategory.transport => 'transport',
  };

  String get label => switch (this) {
    SiteTicketCategory.induction => 'Induction',
    SiteTicketCategory.safety => 'Safety',
    SiteTicketCategory.licence => 'Licences',
    SiteTicketCategory.transport => 'Transport',
  };

  /// Unknown values fall back rather than throw: the table is editable in the
  /// dashboard without an app release, so a new category must not crash a
  /// shipped build. Safety is the conservative bucket.
  static SiteTicketCategory fromDb(String value) => switch (value) {
    'induction' => SiteTicketCategory.induction,
    'safety' => SiteTicketCategory.safety,
    'licence' => SiteTicketCategory.licence,
    'transport' => SiteTicketCategory.transport,
    _ => SiteTicketCategory.safety,
  };
}

/// Reference data — a row in `public.site_tickets`. Read-only on the client.
///
/// [docType] links the ticket to the `verification_documents` review path.
/// Null means there is no review path yet, so the ticket can only ever be
/// self-declared and the "upload to verify" nudge must not render for it.
class SiteTicket extends Equatable {
  const SiteTicket({
    required this.slug,
    required this.shortName,
    required this.displayName,
    required this.category,
    required this.sortOrder,
    this.docType,
  });

  final String slug;
  final String shortName;
  final String displayName;
  final SiteTicketCategory category;
  final int sortOrder;
  final String? docType;

  bool get isVerifiable => docType != null && docType!.isNotEmpty;

  @override
  List<Object?> get props => [
    slug,
    shortName,
    displayName,
    category,
    sortOrder,
    docType,
  ];
}
```

- [ ] **Step 4: Write the model**

```dart
// lib/features/profile/data/models/site_ticket_model.dart
import '../../domain/entities/site_ticket.dart';

class SiteTicketModel extends SiteTicket {
  const SiteTicketModel({
    required super.slug,
    required super.shortName,
    required super.displayName,
    required super.category,
    required super.sortOrder,
    super.docType,
  });

  factory SiteTicketModel.fromJson(Map<String, dynamic> json) =>
      SiteTicketModel(
        slug: json['slug'] as String,
        shortName: json['short_name'] as String,
        displayName: json['display_name'] as String,
        category: SiteTicketCategory.fromDb(json['category'] as String),
        sortOrder: (json['sort_order'] as int?) ?? 0,
        docType: json['doc_type'] as String?,
      );
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/site_ticket_model_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/profile/domain/entities/site_ticket.dart lib/features/profile/data/models/site_ticket_model.dart test/features/profile/site_ticket_model_test.dart
git add lib/features/profile/domain/entities/site_ticket.dart lib/features/profile/data/models/site_ticket_model.dart test/features/profile/site_ticket_model_test.dart
git commit -m "feat(profile): SiteTicket reference entity + model"
```

---

## Task 4: Extend TradeProfile entity and model

**Files:**
- Modify: `lib/features/profile/domain/entities/trade_profile.dart`
- Modify: `lib/features/profile/data/models/trade_profile_model.dart`
- Test: `test/features/profile/apprentice_trade_profile_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/apprentice_trade_profile_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';

Map<String, dynamic> _base() => {
  'id': 'u1',
  'full_name': 'Jake M',
  'primary_trade': 'carpenter',
};

void main() {
  group('TradeProfileModel apprentice fields', () {
    test('defaults are non-apprentice with no tickets and no resume', () {
      final tp = TradeProfileModel.fromJson(_base());
      expect(tp.isApprentice, isFalse);
      expect(tp.apprenticeshipStage, isNull);
      expect(tp.siteTickets, isEmpty);
      expect(tp.resumePath, isNull);
      expect(tp.hasResume, isFalse);
    });

    test('parses a full apprentice row', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_2',
        'site_tickets': ['white_card', 'first_aid'],
        'resume_path': 'u1/resume/1756600000.pdf',
        'resume_uploaded_at': '2026-08-31T02:00:00.000Z',
      });
      expect(tp.isApprentice, isTrue);
      expect(tp.apprenticeshipStage, ApprenticeshipStage.year2);
      expect(tp.siteTickets, ['white_card', 'first_aid']);
      expect(tp.hasResume, isTrue);
      expect(tp.resumeFileName, '1756600000.pdf');
    });

    test('an invalid stage string degrades to null, it does not throw', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_9',
      });
      expect(tp.apprenticeshipStage, isNull);
    });

    test('apprenticeHeadline reads off primary_trade', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_2',
      });
      expect(tp.apprenticeHeadline, '2ND-YEAR CARPENTER APPRENTICE');
    });

    test('apprenticeHeadline is null for a non-apprentice', () {
      expect(TradeProfileModel.fromJson(_base()).apprenticeHeadline, isNull);
    });

    test('toCacheMap round-trips every apprentice field', () {
      final tp = TradeProfileModel.fromJson({
        ..._base(),
        'is_apprentice': true,
        'apprenticeship_stage': 'year_3',
        'site_tickets': ['dogging'],
        'resume_path': 'u1/resume/9.pdf',
        'resume_uploaded_at': '2026-08-31T02:00:00.000Z',
      });
      final back = TradeProfileModel.fromJson(tp.toCacheMap());
      expect(back.isApprentice, isTrue);
      expect(back.apprenticeshipStage, ApprenticeshipStage.year3);
      expect(back.siteTickets, ['dogging']);
      expect(back.resumePath, 'u1/resume/9.pdf');
      expect(back.resumeUploadedAt, isNotNull);
    });

    test('props include the new fields so select() sees a change', () {
      final a = TradeProfileModel.fromJson(_base());
      final b = TradeProfileModel.fromJson({
        ..._base(),
        'site_tickets': ['first_aid'],
      });
      expect(a == b, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/apprentice_trade_profile_test.dart`
Expected: FAIL — `isApprentice` isn't defined.

- [ ] **Step 3: Extend the entity**

Add the import at the top of `lib/features/profile/domain/entities/trade_profile.dart`:

```dart
import 'apprenticeship_stage.dart';
```

Add these five params to the `const TradeProfile({...})` constructor, after `this.unavailableDates = const [],`:

```dart
    this.isApprentice = false,
    this.apprenticeshipStage,
    this.siteTickets = const [],
    this.resumePath,
    this.resumeUploadedAt,
```

Add the fields after `final List<DateTime> unavailableDates;`:

```dart
  // Apprentice mode. When true the profile renders the apprentice layout:
  // no hourly rate, no public liability, no jobs-completed stat. The
  // apprenticeship they want is primary_trade — same picker, same slug — so
  // search, displayTrade and job matching need no new code path.
  final bool isApprentice;
  final ApprenticeshipStage? apprenticeshipStage;

  // SELF-DECLARED ticket slugs. A tick is a claim, never proof. Verified
  // credentials come from get_trade_public_credentials and are a separate,
  // visually distinct tier — never merge these two lists.
  final List<String> siteTickets;

  // private-docs path, `{uid}/resume/{epoch}.{ext}`. Never a public URL:
  // reading it needs a signed URL, gated by the applied-to-builder policy.
  final String? resumePath;
  final DateTime? resumeUploadedAt;
```

Add the getters next to `hasLicence`:

```dart
  bool get hasResume => resumePath != null && resumePath!.isNotEmpty;
  int get ticketCount => siteTickets.length;

  /// Last path segment, for display. Returns null when there is no resume.
  String? get resumeFileName =>
      hasResume ? resumePath!.split('/').last : null;

  /// Profile chip text, e.g. "2ND-YEAR CARPENTER APPRENTICE". Null unless the
  /// profile is an apprentice with a stage set.
  String? get apprenticeHeadline {
    final stage = apprenticeshipStage;
    if (!isApprentice || stage == null) return null;
    return stage.headline(displayTrade);
  }
```

Append the five fields to `props`, after `unavailableDates,`:

```dart
    isApprentice,
    apprenticeshipStage,
    siteTickets,
    resumePath,
    resumeUploadedAt,
```

- [ ] **Step 4: Extend the model**

In `lib/features/profile/data/models/trade_profile_model.dart` add the import:

```dart
import '../../domain/entities/apprenticeship_stage.dart';
```

Add to the constructor after `super.unavailableDates,`:

```dart
    super.isApprentice,
    super.apprenticeshipStage,
    super.siteTickets,
    super.resumePath,
    super.resumeUploadedAt,
```

Add to `fromJson` after `unavailableDates: _parseDates(json['unavailable_dates']),`:

```dart
        isApprentice: json['is_apprentice'] as bool? ?? false,
        apprenticeshipStage: ApprenticeshipStage.fromDb(
          json['apprenticeship_stage'] as String?,
        ),
        siteTickets:
            (json['site_tickets'] as List?)?.cast<String>() ?? const [],
        resumePath: json['resume_path'] as String?,
        resumeUploadedAt: json['resume_uploaded_at'] != null
            ? DateTime.parse(json['resume_uploaded_at'] as String)
            : null,
```

Add to `toCacheMap` after `'unavailable_dates': _encodeDates(unavailableDates),`:

```dart
    'is_apprentice': isApprentice,
    'apprenticeship_stage': apprenticeshipStage?.dbValue,
    'site_tickets': siteTickets,
    'resume_path': resumePath,
    'resume_uploaded_at': resumeUploadedAt?.toIso8601String(),
```

**Do not touch `toJson()`.** It is a write projection used by the legacy full-row save; apprentice fields are written through `TradeProfilePatch` only (Task 5).

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/apprentice_trade_profile_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Run the profile suite to catch regressions**

Run: `flutter test test/features/profile/`
Expected: all PASS. `profile_offline_cache_test.dart` exercises `toCacheMap` and must still pass.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/profile test/features/profile
git add lib/features/profile/domain/entities/trade_profile.dart lib/features/profile/data/models/trade_profile_model.dart test/features/profile/apprentice_trade_profile_test.dart
git commit -m "feat(profile): apprentice fields on TradeProfile"
```

---

## Task 5: Extend TradeProfilePatch + mappers

**Files:**
- Modify: `lib/features/profile/domain/entities/profile_patches.dart`
- Modify: `lib/features/profile/data/models/profile_patch_mappers.dart`
- Test: `test/features/profile/apprentice_patch_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/apprentice_patch_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/features/profile/data/models/profile_patch_mappers.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';

void main() {
  group('TradeProfilePatch apprentice columns', () {
    test('an untouched patch writes no apprentice columns', () {
      final cols = tradeProfilePatchColumns(const TradeProfilePatch());
      expect(cols.containsKey('is_apprentice'), isFalse);
      expect(cols.containsKey('apprenticeship_stage'), isFalse);
      expect(cols.containsKey('site_tickets'), isFalse);
      expect(cols.containsKey('resume_path'), isFalse);
    });

    test('turning apprentice mode on writes the stage as its db value', () {
      final cols = tradeProfilePatchColumns(
        TradeProfilePatch(
          isApprentice: const Some(true),
          apprenticeshipStage: const Some(ApprenticeshipStage.year2),
        ),
      );
      expect(cols['is_apprentice'], true);
      expect(cols['apprenticeship_stage'], 'year_2');
    });

    test('Some(null) stage clears the column', () {
      final cols = tradeProfilePatchColumns(
        const TradeProfilePatch(
          isApprentice: Some(false),
          apprenticeshipStage: Some(null),
        ),
      );
      expect(cols['is_apprentice'], false);
      expect(cols.containsKey('apprenticeship_stage'), isTrue);
      expect(cols['apprenticeship_stage'], isNull);
    });

    test('tickets write as a plain list, empty list included', () {
      final cols = tradeProfilePatchColumns(
        const TradeProfilePatch(siteTickets: Some(['white_card', 'dogging'])),
      );
      expect(cols['site_tickets'], ['white_card', 'dogging']);

      final cleared = tradeProfilePatchColumns(
        const TradeProfilePatch(siteTickets: Some([])),
      );
      expect(cleared['site_tickets'], isEmpty);
      expect(cleared.containsKey('site_tickets'), isTrue);
    });

    test('resume path + timestamp write together, and clear together', () {
      final set = tradeProfilePatchColumns(
        TradeProfilePatch(
          resumePath: const Some('u1/resume/9.pdf'),
          resumeUploadedAt: Some(DateTime.utc(2026, 8, 31, 2)),
        ),
      );
      expect(set['resume_path'], 'u1/resume/9.pdf');
      expect(set['resume_uploaded_at'], '2026-08-31T02:00:00.000Z');

      final cleared = tradeProfilePatchColumns(
        const TradeProfilePatch(
          resumePath: Some(null),
          resumeUploadedAt: Some(null),
        ),
      );
      expect(cleared['resume_path'], isNull);
      expect(cleared['resume_uploaded_at'], isNull);
    });

    test('isEmpty stays true only when no apprentice field is set', () {
      expect(const TradeProfilePatch().isEmpty, isTrue);
      expect(
        const TradeProfilePatch(isApprentice: Some(true)).isEmpty,
        isFalse,
      );
      expect(
        const TradeProfilePatch(siteTickets: Some([])).isEmpty,
        isFalse,
      );
      expect(
        const TradeProfilePatch(resumePath: Some(null)).isEmpty,
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/apprentice_patch_test.dart`
Expected: FAIL — no named parameter `isApprentice`.

- [ ] **Step 3: Extend the patch class**

In `lib/features/profile/domain/entities/profile_patches.dart`, add the import:

```dart
import 'apprenticeship_stage.dart';
```

Add to the `TradeProfilePatch` constructor after `this.about = const None(),`:

```dart
    this.isApprentice = const None(),
    this.apprenticeshipStage = const None(),
    this.siteTickets = const None(),
    this.resumePath = const None(),
    this.resumeUploadedAt = const None(),
```

Add the fields after `final Option<String?> about;`:

```dart
  final Option<bool> isApprentice;
  final Option<ApprenticeshipStage?> apprenticeshipStage;
  final Option<List<String>> siteTickets;
  final Option<String?> resumePath;
  final Option<DateTime?> resumeUploadedAt;
```

Extend `isEmpty` — change the trailing `about.isNone();` to:

```dart
      about.isNone() &&
      isApprentice.isNone() &&
      apprenticeshipStage.isNone() &&
      siteTickets.isNone() &&
      resumePath.isNone() &&
      resumeUploadedAt.isNone();
```

- [ ] **Step 4: Extend the mapper**

In `lib/features/profile/data/models/profile_patch_mappers.dart` add the import:

```dart
import '../../domain/entities/apprenticeship_stage.dart';
```

Add to `tradeProfilePatchColumns`, immediately before `return map;`:

```dart
  _put(map, 'is_apprentice', p.isApprentice);
  // Enum → the CHECK-constrained db string. Some(null) clears the column,
  // which is what flipping apprentice mode off must do so a stale stage can
  // never resurface later.
  p.apprenticeshipStage.match(
    () {},
    (v) => map['apprenticeship_stage'] = v?.dbValue,
  );
  _put(map, 'site_tickets', p.siteTickets);
  _put(map, 'resume_path', p.resumePath);
  p.resumeUploadedAt.match(
    () {},
    (v) => map['resume_uploaded_at'] = v?.toIso8601String(),
  );
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/apprentice_patch_test.dart test/features/profile/profile_patch_mappers_test.dart`
Expected: PASS both files.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/profile test/features/profile
git add lib/features/profile/domain/entities/profile_patches.dart lib/features/profile/data/models/profile_patch_mappers.dart test/features/profile/apprentice_patch_test.dart
git commit -m "feat(profile): apprentice fields on TradeProfilePatch"
```

---

## Task 6: site_tickets provider

**Files:**
- Create: `lib/features/profile/presentation/providers/site_tickets_provider.dart`
- Test: `test/features/profile/site_tickets_provider_test.dart`

Mirrors `trade_categories_provider.dart` exactly: reference data, fetched once per session, read directly from Supabase inside a `FutureProvider`. `scripts/check-architecture.sh` exempts `presentation/providers/` from the Supabase-isolation rule, so no allowlist entry is needed.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/site_tickets_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';
import 'package:jobdun/features/profile/presentation/providers/site_tickets_provider.dart';

void main() {
  test('returns an empty list when Supabase is not initialised', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tickets = await container.read(siteTicketsProvider.future);
    expect(tickets, isEmpty);
  });

  test('is overridable so widget tests can inject fixtures', () async {
    const fixture = SiteTicket(
      slug: 'white_card',
      shortName: 'White Card',
      displayName: 'White Card (Construction Induction, CPCCWHS1001)',
      category: SiteTicketCategory.induction,
      sortOrder: 10,
      docType: 'white_card',
    );
    final container = ProviderContainer(
      overrides: [
        siteTicketsProvider.overrideWith((ref) async => const [fixture]),
      ],
    );
    addTearDown(container.dispose);
    final tickets = await container.read(siteTicketsProvider.future);
    expect(tickets.single.slug, 'white_card');
    expect(tickets.single.isVerifiable, isTrue);
  });

  test('groupByCategory preserves category order then sort_order', () {
    const rows = [
      SiteTicket(slug: 'dogging', shortName: 'Dogging', displayName: 'Dogging Licence (DG)', category: SiteTicketCategory.licence, sortOrder: 30),
      SiteTicket(slug: 'white_card', shortName: 'White Card', displayName: 'White Card', category: SiteTicketCategory.induction, sortOrder: 10),
      SiteTicket(slug: 'ewp_yellow_card', shortName: 'EWP Yellow Card', displayName: 'EWP Yellow Card (boom under 11m)', category: SiteTicketCategory.licence, sortOrder: 10),
    ];
    final grouped = groupTicketsByCategory(rows);
    expect(grouped.keys.first, SiteTicketCategory.induction);
    expect(
      grouped[SiteTicketCategory.licence]!.map((t) => t.slug).toList(),
      ['ewp_yellow_card', 'dogging'],
    );
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/site_tickets_provider_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write the provider**

```dart
// lib/features/profile/presentation/providers/site_tickets_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase_config.dart';
import '../../data/models/site_ticket_model.dart';
import '../../domain/entities/site_ticket.dart';

/// Reference data — `public.site_tickets`. Fetched once per session, cached by
/// Riverpod. Public (no leading underscore) so widget tests can override it
/// via `ProviderScope(overrides: [...])`.
///
/// Reads Supabase directly, exactly as `tradeCategoriesProvider` does. This is
/// allowed: `check-architecture.sh` exempts `presentation/providers/` from the
/// Supabase-isolation rule, and reference data has no repository to route
/// through.
final siteTicketsProvider = FutureProvider<List<SiteTicket>>((ref) async {
  if (!SupabaseConfig.isInitialized) return const [];

  final rows = await SupabaseConfig.client
      .from('site_tickets')
      .select()
      .order('category', ascending: true)
      .order('sort_order', ascending: true);

  return (rows as List<dynamic>)
      .map((row) => SiteTicketModel.fromJson(row as Map<String, dynamic>))
      .toList(growable: false);
});

/// Groups tickets for the sheet's section headers. Category order is the enum
/// declaration order (induction → safety → licence → transport), which reads
/// as "what every site asks for" down to "nice to have"; within a category the
/// rows keep their `sort_order`.
Map<SiteTicketCategory, List<SiteTicket>> groupTicketsByCategory(
  List<SiteTicket> tickets,
) {
  final out = <SiteTicketCategory, List<SiteTicket>>{};
  for (final category in SiteTicketCategory.values) {
    final rows = tickets.where((t) => t.category == category).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (rows.isNotEmpty) out[category] = rows;
  }
  return out;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/profile/site_tickets_provider_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/profile test/features/profile
git add lib/features/profile/presentation/providers/site_tickets_provider.dart test/features/profile/site_tickets_provider_test.dart
git commit -m "feat(profile): site_tickets reference provider"
```

---

## Task 7: Resume repository layer

**Files:**
- Modify: `lib/features/profile/domain/repositories/profile_repository.dart`
- Modify: `lib/features/profile/data/datasources/profile_remote_datasource.dart`
- Modify: `lib/features/profile/data/repositories/profile_repository_impl.dart`
- Create: `lib/features/profile/domain/usecases/upload_resume.dart`
- Create: `lib/features/profile/domain/usecases/delete_resume.dart`
- Create: `lib/features/profile/domain/usecases/get_resume_url.dart`
- Test: `test/features/profile/resume_repository_test.dart`

Read `profile_repository_impl.dart` and `profile_remote_datasource.dart` in full before editing — mirror the existing `uploadTradeLicence` / `addPortfolioImage` error-wrapping style exactly (they already wrap `StorageException` / `PostgrestException` into `Failure`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/resume_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/usecases/upload_resume.dart';

void main() {
  group('resume file validation', () {
    test('accepts pdf, doc and docx regardless of case', () {
      for (final name in ['cv.pdf', 'CV.PDF', 'a.doc', 'a.DOCX']) {
        expect(isAllowedResumeFile(name, 1024), isNull, reason: name);
      }
    });

    test('rejects other extensions with a message naming what is allowed', () {
      final err = isAllowedResumeFile('resume.pages', 1024);
      expect(err, isNotNull);
      expect(err, contains('PDF'));
      expect(err, contains('5 MB'));
    });

    test('rejects a file over 5 MB', () {
      expect(isAllowedResumeFile('cv.pdf', 5 * 1024 * 1024 + 1), isNotNull);
      expect(isAllowedResumeFile('cv.pdf', 5 * 1024 * 1024), isNull);
    });

    test('rejects an empty file', () {
      expect(isAllowedResumeFile('cv.pdf', 0), isNotNull);
    });

    test('builds an owner-scoped storage path the RLS policy accepts', () {
      final path = resumeStoragePath('user-123', 'My CV.pdf', 1756600000);
      expect(path, 'user-123/resume/1756600000.pdf');
      // Policy keys on foldername[1] = uid and foldername[2] = 'resume'.
      final parts = path.split('/');
      expect(parts[0], 'user-123');
      expect(parts[1], 'resume');
    });

    test('path extension is lowercased and falls back to pdf', () {
      expect(
        resumeStoragePath('u', 'CV.PDF', 1),
        'u/resume/1.pdf',
      );
      expect(
        resumeStoragePath('u', 'noextension', 1),
        'u/resume/1.pdf',
      );
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/resume_repository_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write the upload use case with its pure helpers**

```dart
// lib/features/profile/domain/usecases/upload_resume.dart
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

const int kMaxResumeBytes = 5 * 1024 * 1024;
const List<String> kAllowedResumeExtensions = ['pdf', 'doc', 'docx'];

/// Returns null when the file is acceptable, otherwise the user-facing reason.
/// Pure so it can be unit-tested and reused by the sheet before any upload
/// starts — the user should never wait on a network round-trip to be told the
/// file is the wrong type.
String? isAllowedResumeFile(String fileName, int sizeBytes) {
  const limit = 'PDF, DOC or DOCX up to 5 MB.';
  if (sizeBytes <= 0) return 'That file is empty. $limit';
  if (sizeBytes > kMaxResumeBytes) return 'That file is over 5 MB. $limit';
  final ext = fileName.split('.').last.toLowerCase();
  if (!fileName.contains('.') || !kAllowedResumeExtensions.contains(ext)) {
    return "That file type isn't supported. $limit";
  }
  return null;
}

/// `{uid}/resume/{epoch}.{ext}` — the shape both storage policies key on:
/// `foldername[1]` is the owner uid, `foldername[2]` is the literal 'resume'.
/// Changing this shape silently breaks builder access.
String resumeStoragePath(String userId, String fileName, int epochSeconds) {
  final raw = fileName.contains('.') ? fileName.split('.').last : '';
  final ext = raw.toLowerCase();
  final safe = kAllowedResumeExtensions.contains(ext) ? ext : 'pdf';
  return '$userId/resume/$epochSeconds.$safe';
}

/// Uploads the resume to private-docs and stamps `resume_path` +
/// `resume_uploaded_at` on the trade profile. Returns the storage path.
///
/// Takes bytes rather than a File because `file_picker` returns a null `path`
/// on web and only ever guarantees `bytes` (see the comment in
/// manual_upload_sheet.dart:127). Passing bytes keeps one code path.
class UploadResume {
  const UploadResume(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, String>> call(
    String userId,
    Uint8List bytes,
    String fileName,
  ) {
    final problem = isAllowedResumeFile(fileName, bytes.length);
    if (problem != null) {
      return Future.value(Left(ValidationFailure(problem)));
    }
    return _repo.uploadResume(userId, bytes, fileName);
  }
}
```

Check `lib/core/errors/failures.dart` for the exact failure class name before writing `ValidationFailure`. If the project uses a different name (e.g. `InputFailure`), use that one and keep it consistent across all three use cases.

- [ ] **Step 4: Write the delete and signed-URL use cases**

```dart
// lib/features/profile/domain/usecases/delete_resume.dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

/// Deletes the object from private-docs and clears both resume columns.
class DeleteResume {
  const DeleteResume(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, void>> call(String userId) =>
      _repo.deleteResume(userId);
}
```

```dart
// lib/features/profile/domain/usecases/get_resume_url.dart
import 'package:fpdart/fpdart.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/profile_repository.dart';

/// Mints a short-lived signed URL for a resume.
///
/// Authorisation is enforced by Postgres, not here: the caller gets a URL only
/// if `private_docs_owner_select` (they own it) or
/// `private_docs_resume_applied_builder_select` (the apprentice applied to one
/// of their jobs) admits them. A caller with neither gets a Failure.
///
/// The URL expires in 60 minutes, so mint on tap rather than caching it.
class GetResumeUrl {
  const GetResumeUrl(this._repo);
  final ProfileRepository _repo;

  Future<Either<Failure, String>> call(String storagePath) =>
      _repo.getResumeSignedUrl(storagePath);
}
```

- [ ] **Step 5: Add the three repository contract methods**

In `lib/features/profile/domain/repositories/profile_repository.dart` add `import 'dart:typed_data';` and these methods after `removePortfolioImage`:

```dart
  // Uploads a resume (PDF/DOC/DOCX) to private-docs at
  // {uid}/resume/{epoch}.{ext} and stamps resume_path + resume_uploaded_at.
  // Replaces any existing resume — the old object is deleted first so the
  // bucket doesn't accumulate orphans. Returns the new storage path.
  Future<Either<Failure, String>> uploadResume(
    String userId,
    Uint8List bytes,
    String fileName,
  );

  // Deletes the resume object and clears both resume columns.
  Future<Either<Failure, void>> deleteResume(String userId);

  // 60-minute signed URL. Storage RLS decides whether the caller is allowed.
  Future<Either<Failure, String>> getResumeSignedUrl(String storagePath);
```

- [ ] **Step 6: Implement in the datasource and the repository impl**

Follow the existing `uploadTradeLicence` implementation as the template. The datasource methods:

```dart
  Future<String> uploadResume(
    String userId,
    Uint8List bytes,
    String fileName,
  ) async {
    final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final path = resumeStoragePath(userId, fileName, epoch);

    // Remove the previous object first so replacing a resume doesn't leave an
    // orphan in the bucket. Best-effort: a missing old object is not an error.
    final existing = await _client
        .from('trade_profiles')
        .select('resume_path')
        .eq('id', userId)
        .maybeSingle();
    final old = existing?['resume_path'] as String?;
    if (old != null && old.isNotEmpty) {
      try {
        await _client.storage.from('private-docs').remove([old]);
      } on StorageException {
        // Already gone. Nothing to clean up.
      }
    }

    await _client.storage
        .from('private-docs')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await _client
        .from('trade_profiles')
        .update({
          'resume_path': path,
          'resume_uploaded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);

    return path;
  }

  Future<void> deleteResume(String userId) async {
    final row = await _client
        .from('trade_profiles')
        .select('resume_path')
        .eq('id', userId)
        .maybeSingle();
    final path = row?['resume_path'] as String?;
    if (path != null && path.isNotEmpty) {
      try {
        await _client.storage.from('private-docs').remove([path]);
      } on StorageException {
        // Already gone — still clear the columns below.
      }
    }
    await _client
        .from('trade_profiles')
        .update({'resume_path': null, 'resume_uploaded_at': null})
        .eq('id', userId);
  }

  Future<String> getResumeSignedUrl(String storagePath) => _client.storage
      .from('private-docs')
      .createSignedUrl(storagePath, 3600);
```

Import `resumeStoragePath` from the use-case file in the datasource. If that reads as a layer inversion, move `resumeStoragePath` and `isAllowedResumeFile` into `lib/features/profile/domain/entities/resume_rules.dart` and import that from both — `domain/entities` importing nothing but `dart:` is clean, and `data/` importing `domain/` is the correct direction.

The repository impl wraps each datasource call in the project's existing try/catch → `Either` pattern. Copy the shape from `uploadTradeLicence` verbatim.

- [ ] **Step 7: Wire the three use-case providers**

In `lib/features/profile/presentation/providers/profile_provider.dart`, next to the existing use-case providers:

```dart
final uploadResumeUseCaseProvider = Provider<UploadResume>(
  (ref) => UploadResume(ref.watch(profileRepositoryProvider)),
);
final deleteResumeUseCaseProvider = Provider<DeleteResume>(
  (ref) => DeleteResume(ref.watch(profileRepositoryProvider)),
);
final getResumeUrlUseCaseProvider = Provider<GetResumeUrl>(
  (ref) => GetResumeUrl(ref.watch(profileRepositoryProvider)),
);
```

Match the existing provider naming and the exact repository provider name already in that file.

- [ ] **Step 8: Add controller methods**

Add to the profile controller, following the existing `savePatches` shape. Use an explicit
`isLeft()` branch rather than `fold` — the success arm has to `await` a reload, and `fold` is
synchronous, so folding here forces a cast that breaks at runtime:

```dart
  Future<bool> uploadResume(Uint8List bytes, String fileName) async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(isUploadingResume: true, error: null);
    final r = await ref
        .read(uploadResumeUseCaseProvider)
        .call(userId, bytes, fileName);
    if (r.isLeft()) {
      state = state.copyWith(
        isUploadingResume: false,
        error: r.fold((f) => f.message, (_) => null),
      );
      return false;
    }
    await loadProfile();
    state = state.copyWith(isUploadingResume: false);
    return true;
  }

  Future<bool> deleteResume() async {
    final userId = readCurrentUserId(ref);
    if (userId == null) return false;
    state = state.copyWith(error: null);
    final r = await ref.read(deleteResumeUseCaseProvider).call(userId);
    if (r.isLeft()) {
      state = state.copyWith(error: r.fold((f) => f.message, (_) => null));
      return false;
    }
    await loadProfile();
    return true;
  }
```

Add `isUploadingResume` to `ProfileState` (field, constructor param defaulting to `false`, and `copyWith`), mirroring `isUploadingLicence`. Use the exact name `loadProfile` only if that is what the controller's reload method is actually called — check before writing.

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/profile/`
Expected: all PASS.

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/features/profile test/features/profile
git commit -m "feat(profile): resume upload, delete and signed-url plumbing"
```

---

## Task 8: Ticket chip widgets

**Files:**
- Create: `lib/features/profile/presentation/widgets/ticket_chip.dart`
- Create: `lib/features/profile/presentation/widgets/ticket_chip_wall.dart`
- Test: `test/features/profile/ticket_chip_test.dart`

- [ ] **Step 1: Write the failing test**

The critical assertion: verified and self-declared must be distinguishable **without colour**.

```dart
// test/features/profile/ticket_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/presentation/widgets/ticket_chip.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('TicketChip', () {
    testWidgets('a verified chip announces "verified" to screen readers', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TicketChip(label: 'White Card', isVerified: true),
      );
      final semantics = tester.getSemantics(find.byType(TicketChip));
      expect(semantics.label, contains('White Card'));
      expect(semantics.label.toLowerCase(), contains('verified'));
    });

    testWidgets('a self-declared chip says so, not just a grey colour', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TicketChip(label: 'First Aid', isVerified: false),
      );
      final semantics = tester.getSemantics(find.byType(TicketChip));
      expect(semantics.label.toLowerCase(), contains('self-declared'));
    });

    testWidgets('the two tiers use different glyphs, not just colour', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const TicketChip(label: 'White Card', isVerified: true),
      );
      final verifiedIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await pumpApp(
        tester,
        const TicketChip(label: 'White Card', isVerified: false),
      );
      final selfIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      expect(verifiedIcon, isNot(equals(selfIcon)));
    });
  });
}
```

Check `test/helpers/` for the project's existing pump helper and use whatever it is actually called; if none exists, wrap in `ProviderScope(child: MaterialApp(home: ScreenUtilInit(...)))` the way the other widget tests in `test/features/profile/` do (copy from `ticket`-adjacent `profile_rating_block_test.dart`).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/ticket_chip_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write TicketChip**

```dart
// lib/features/profile/presentation/widgets/ticket_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// One site ticket, in one of two trust tiers.
///
/// Verified means a human reviewed an uploaded document. Self-declared means
/// the user ticked a box. These MUST stay visually distinct — collapsing them
/// would let a claim read as a checked credential, which is the one thing the
/// trust layer exists to prevent.
///
/// The tiers differ by glyph AND by semantics label, never by colour alone
/// (MASTER: "never colour alone to convey state").
class TicketChip extends StatelessWidget {
  const TicketChip({
    super.key,
    required this.label,
    required this.isVerified,
  });

  final String label;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // Verified sits on the green tinted pair. Self-declared sits on
    // surfaceRaised, which carries text1 ONLY — text2/text3 fall below 4.5:1
    // there (app_colors.dart:105,110).
    final bg = isVerified ? c.verifiedBg : c.surfaceRaised;
    final fg = isVerified ? c.verifiedTx : c.text1;

    return Semantics(
      container: true,
      label: '$label, ${isVerified ? 'verified' : 'self-declared'}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVerified ? AppIcons.verified : AppIcons.circle,
              size: AppIconSize.micro.r,
              color: fg,
            ),
            Gap(6.w),
            Text(
              label.toUpperCase(),
              style: tt.labelMedium!.copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
```

Before writing, `grep -n "verified\|circle" lib/core/theme/app_icons.dart` and use the entries that actually exist. If there is no hollow-circle entry, add one to `AppIcons` (that is the documented way — "add the entry next time you reach for it") rather than importing `phosphor_flutter` here.

- [ ] **Step 4: Write TicketChipWall**

```dart
// lib/features/profile/presentation/widgets/ticket_chip_wall.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import 'ticket_chip.dart';

/// The tickets block on a profile. Verified chips sort first so the strongest
/// signal is read first.
///
/// [showDisclaimer] is true on builder-facing surfaces only. MASTER bans
/// handholding microcopy; this one line earns its place because a builder
/// acting on a self-declared ticket is a site-safety decision, not a UI
/// preference.
class TicketChipWall extends StatelessWidget {
  const TicketChipWall({
    super.key,
    required this.labelsBySlug,
    required this.selectedSlugs,
    required this.verifiedSlugs,
    this.showDisclaimer = false,
  });

  final Map<String, String> labelsBySlug;
  final List<String> selectedSlugs;
  final Set<String> verifiedSlugs;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final ordered = [...selectedSlugs]
      ..sort((a, b) {
        final av = verifiedSlugs.contains(a) ? 0 : 1;
        final bv = verifiedSlugs.contains(b) ? 0 : 1;
        if (av != bv) return av.compareTo(bv);
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final slug in ordered)
              TicketChip(
                label: labelsBySlug[slug] ?? slug,
                isVerified: verifiedSlugs.contains(slug),
              ),
          ],
        ),
        if (showDisclaimer && ordered.any((s) => !verifiedSlugs.contains(s)))
          ...[
            Gap(AppSpacing.md.h),
            Text(
              'Grey tickets are self-declared. Sight the card before site '
              'induction.',
              style: tt.bodySmall!.copyWith(color: c.text2),
            ),
          ],
      ],
    );
  }
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/ticket_chip_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/profile/presentation/widgets/ticket_chip.dart lib/features/profile/presentation/widgets/ticket_chip_wall.dart test/features/profile/ticket_chip_test.dart
git commit -m "feat(profile): two-tier ticket chips"
```

---

## Task 9: Tickets edit sheet

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet.dart`
- Create: `lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet_rows.dart`
- Test: `test/features/profile/tickets_sheet_test.dart`

Split across two files from the first commit: one sheet with four grouped sections, nine rows, a locked-verified state and a discard-changes guard will not fit under 400 LOC in one file.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/tickets_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';
import 'package:jobdun/features/profile/presentation/providers/site_tickets_provider.dart';
import 'package:jobdun/features/profile/presentation/widgets/edit_sheets/tickets_sheet_rows.dart';

const _tickets = [
  SiteTicket(slug: 'white_card', shortName: 'White Card', displayName: 'White Card (Construction Induction, CPCCWHS1001)', category: SiteTicketCategory.induction, sortOrder: 10, docType: 'white_card'),
  SiteTicket(slug: 'first_aid', shortName: 'First Aid', displayName: 'First Aid (HLTAID011)', category: SiteTicketCategory.safety, sortOrder: 10),
  SiteTicket(slug: 'dogging', shortName: 'Dogging', displayName: 'Dogging Licence (DG)', category: SiteTicketCategory.licence, sortOrder: 30),
];

void main() {
  group('TicketRow', () {
    testWidgets('tapping an unticked row selects it', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            siteTicketsProvider.overrideWith((ref) async => _tickets),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TicketRow(
                ticket: _tickets[1],
                isSelected: false,
                isVerified: false,
                onChanged: (v) => selected = v,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TicketRow));
      await tester.pump();
      expect(selected, isTrue);
    });

    testWidgets('a verified row is locked on and cannot be unticked', (
      tester,
    ) async {
      var changed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketRow(
              ticket: _tickets[0],
              isSelected: true,
              isVerified: true,
              onChanged: (_) => changed = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TicketRow));
      await tester.pump();
      expect(changed, isFalse, reason: 'verified tickets stay ticked');
    });

    testWidgets('every row meets the 48dp minimum touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketRow(
              ticket: _tickets[2],
              isSelected: false,
              isVerified: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TicketRow)).height,
          greaterThanOrEqualTo(48.0));
    });

    testWidgets('the display name and its unit code are both readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketRow(
              ticket: _tickets[1],
              isSelected: false,
              isVerified: false,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('First Aid'), findsOneWidget);
      expect(find.textContaining('HLTAID011'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/tickets_sheet_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write `tickets_sheet_rows.dart`**

Contains `TicketRow` (one 48dp row: sharp tick box, short name, sub-line with the unit code from `displayName`, and a `VERIFIED` chip when locked) and `TicketGroupHeader` (a `labelSmall` / `c.text3` header on the sheet's `c.surface` ground, which is where `text3` is legal).

The tick box is a sharp `AppRadius.badge` (4r) square, `c.borderStrong` when empty and `c.action` filled with a `c.onAction` glyph when ticked. Not Material's rounded `Checkbox`.

Wrap the row in `Semantics(label: '<short name>, <verified|self-declared>, <selected|not selected>')` so screen readers announce the tier.

- [ ] **Step 4: Write `tickets_sheet.dart`**

`showTicketsSheet(BuildContext)` using `showJSheet` (never `showModalBottomSheet`), wrapping `EditSheetScaffold` with `title: 'Tickets & licences'`, a subtitle line "Tick what you hold. Upload to verify.", and grouped `TicketRow`s built from `groupTicketsByCategory`.

State: a local `Set<String> _selected` seeded from `tradeProfile.siteTickets` in `initState`, plus `_dirty`. Verified slugs come from the existing `get_trade_public_credentials` path — reuse whatever provider `trade_credential_badges.dart` already uses rather than adding a second fetch; read that file first.

Save calls:

```dart
await ref.read(profileControllerProvider.notifier).savePatches(
  trade: TradeProfilePatch(siteTickets: Some(_selected.toList()..sort())),
);
```

`EditSheetScaffold` already handles the discard-changes guard from first build; pass `isDirty: _dirty`.

Loading state uses `JSkeletonList`, never a spinner. Reference-fetch failure shows an inline retry row and still renders the already-selected slugs so nothing looks lost.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/tickets_sheet_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Check the file sizes**

Run: `wc -l lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet*.dart`
Expected: both under 400.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet.dart lib/features/profile/presentation/widgets/edit_sheets/tickets_sheet_rows.dart test/features/profile/tickets_sheet_test.dart
git commit -m "feat(profile): tickets and licences edit sheet"
```

---

## Task 10: Resume sheet and row

**Files:**
- Create: `lib/features/profile/presentation/widgets/edit_sheets/resume_sheet.dart`
- Create: `lib/features/profile/presentation/widgets/resume_row.dart`
- Test: `test/features/profile/resume_row_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/resume_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/presentation/widgets/resume_row.dart';

void main() {
  group('ResumeRow', () {
    testWidgets('the locked state offers no way to open the file', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ResumeRow.locked()),
        ),
      );
      expect(
        find.textContaining('after they apply'),
        findsOneWidget,
      );
      expect(find.text('VIEW RESUME'), findsNothing);
    });

    testWidgets('the owner state shows the filename and both actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeRow.owner(
              fileName: 'resume-ken.pdf',
              uploadedAt: DateTime(2026, 8, 31),
              onReplace: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      expect(find.text('resume-ken.pdf'), findsOneWidget);
      expect(find.text('REPLACE'), findsOneWidget);
      expect(find.text('REMOVE'), findsOneWidget);
    });

    testWidgets('the owner empty state states who can see it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResumeRow.empty(onUpload: () {})),
        ),
      );
      expect(find.text('UPLOAD RESUME'), findsOneWidget);
      expect(
        find.textContaining("Only builders you've applied to"),
        findsOneWidget,
      );
    });

    testWidgets('the viewer-with-access state opens the file', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResumeRow.viewer(onView: () => opened = true),
          ),
        ),
      );
      await tester.tap(find.text('VIEW RESUME'));
      await tester.pump();
      expect(opened, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/resume_row_test.dart`
Expected: FAIL — URI doesn't exist.

- [ ] **Step 3: Write ResumeRow**

Four named constructors (`empty`, `owner`, `viewer`, `locked`) on one `StatelessWidget` with a private enum for the mode. One widget per file, no methods returning `Widget` — branch inside `build` with a `switch` that returns different `child:` values into a shared `Container`.

The privacy line ("Only builders you've applied to can open this.") renders in the `empty` and `owner` states. It is required copy: a user uploading a document with their home address must be told who can see it before they tap.

- [ ] **Step 4: Write resume_sheet.dart**

`showResumeSheet(BuildContext)` via `showJSheet`. Picks with:

```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: kAllowedResumeExtensions,
  withData: true, // REQUIRED: `path` is null on web, only `bytes` is guaranteed
);
if (result == null || result.files.isEmpty) return;
final picked = result.files.first;
final bytes = picked.bytes;
if (bytes == null) {
  setState(() => _error = "Couldn't read that file. Try another.");
  return;
}
final problem = isAllowedResumeFile(picked.name, bytes.length);
if (problem != null) {
  setState(() => _error = problem);
  return;
}
await ref
    .read(profileControllerProvider.notifier)
    .uploadResume(bytes, picked.name);
```

`withData: true` is load-bearing — `manual_upload_sheet.dart:127` documents that `path` is null on web by design. Validate before uploading so the user is not made to wait to be told the file is wrong.

Upload progress uses `LinearPercentIndicator` from `percent_indicator`, never a wrapped `LinearProgressIndicator`.

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/features/profile/resume_row_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/profile/presentation/widgets/resume_row.dart lib/features/profile/presentation/widgets/edit_sheets/resume_sheet.dart test/features/profile/resume_row_test.dart
git commit -m "feat(profile): resume upload sheet and row"
```

---

## Task 11: Apprentice toggle in the trade details sheet

**Files:**
- Modify: `lib/features/profile/presentation/widgets/edit_sheets/trade_details_sheet.dart`
- Test: `test/features/profile/apprentice_toggle_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/apprentice_toggle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:jobdun/features/profile/presentation/widgets/edit_sheets/trade_details_sheet.dart';

void main() {
  group('apprenticeshipPatch', () {
    test('turning the toggle on writes the flag and the stage', () {
      final p = apprenticeshipPatch(
        isApprentice: true,
        stage: ApprenticeshipStage.year2,
      );
      expect(p.isApprentice, const Some(true));
      expect(p.apprenticeshipStage, const Some(ApprenticeshipStage.year2));
    });

    test('turning the toggle off clears the stage in the same patch', () {
      final p = apprenticeshipPatch(
        isApprentice: false,
        stage: ApprenticeshipStage.year3,
      );
      expect(p.isApprentice, const Some(false));
      expect(
        p.apprenticeshipStage,
        const Some<ApprenticeshipStage?>(null),
        reason: 'a stale stage must not resurface if they re-enable later',
      );
    });

    test('apprentice on with no stage picked writes null, not a default', () {
      final p = apprenticeshipPatch(isApprentice: true, stage: null);
      expect(p.apprenticeshipStage, const Some<ApprenticeshipStage?>(null));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/apprentice_toggle_test.dart`
Expected: FAIL — `apprenticeshipPatch` isn't defined.

- [ ] **Step 3: Add the pure helper and wire the UI**

Add to `trade_details_sheet.dart` as a top-level function (pure, so it is unit-testable without pumping a sheet):

```dart
/// Builds the apprentice half of the trade patch.
///
/// Flipping the toggle OFF explicitly writes `Some(null)` for the stage. A
/// `None()` would leave the old stage in the row, so re-enabling apprentice
/// mode months later would silently resurface "3rd year".
TradeProfilePatch apprenticeshipPatch({
  required bool isApprentice,
  required ApprenticeshipStage? stage,
}) => TradeProfilePatch(
  isApprentice: Some(isApprentice),
  apprenticeshipStage: Some(isApprentice ? stage : null),
);
```

In the sheet body, after the trade picker and before "YEARS OF EXPERIENCE", add the toggle row (reuse `JSwitch`, matching `_AvailabilityToggleRow`'s container styling) with the label `I'm looking for an apprenticeship`. When on, reveal a `STAGE` `FieldLabel` plus a `Wrap` of five selectable stage pills built from `ApprenticeshipStage.values` and `.label`.

Wrap the reveal in an `AnimatedSize` at 180ms, and skip the animation when `MediaQuery.of(context).disableAnimations` is true.

Extend `_save` to merge the apprentice fields into the existing patch:

```dart
final base = apprenticeshipPatch(
  isApprentice: _isApprentice,
  stage: _stage,
);
```

then pass `isApprentice: base.isApprentice, apprenticeshipStage: base.apprenticeshipStage` alongside the existing named args in the `TradeProfilePatch(...)` already being constructed.

Hide the years-of-experience field when `_isApprentice` is true — a first-year has none, and asking is noise.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/profile/apprentice_toggle_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Check the file size**

Run: `wc -l lib/features/profile/presentation/widgets/edit_sheets/trade_details_sheet.dart`
Expected: under 500. If it crosses, extract the stage picker into `trade_details_stage_picker.dart`.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/profile/presentation/widgets/edit_sheets/trade_details_sheet.dart test/features/profile/apprentice_toggle_test.dart
git commit -m "feat(profile): apprentice toggle and stage picker"
```

---

## Task 12: Profile hub rows and profile view

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_edit_hub_page.dart`
- Modify: `lib/features/profile/presentation/pages/trade_public_profile_page.dart`
- Modify: `lib/features/profile/presentation/pages/profile_page_trade.dart`
- Create: `lib/features/profile/presentation/widgets/apprentice_header_chip.dart`
- Test: `test/features/profile/apprentice_hub_rows_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/profile/apprentice_hub_rows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/presentation/pages/profile_edit_hub_page.dart';

void main() {
  group('hub row visibility', () {
    test('a qualified tradie sees Rates and Tickets, not Resume', () {
      final sections = hubSectionsForTrade(isApprentice: false);
      expect(sections, contains(ProfileSection.rates));
      expect(sections, contains(ProfileSection.tickets));
      expect(sections, isNot(contains(ProfileSection.resume)));
    });

    test('an apprentice sees Tickets and Resume, not Rates', () {
      final sections = hubSectionsForTrade(isApprentice: true);
      expect(sections, isNot(contains(ProfileSection.rates)));
      expect(sections, contains(ProfileSection.tickets));
      expect(sections, contains(ProfileSection.resume));
    });

    test('Tickets shows for every trade, apprentice or not', () {
      for (final v in [true, false]) {
        expect(hubSectionsForTrade(isApprentice: v),
            contains(ProfileSection.tickets));
      }
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/profile/apprentice_hub_rows_test.dart`
Expected: FAIL — `hubSectionsForTrade` isn't defined.

- [ ] **Step 3: Extend the section enum and add the pure selector**

In `profile_edit_hub_page.dart`, extend the enum:

```dart
enum ProfileSection {
  identity,
  tradeDetails,
  rates,
  tickets,
  resume,
  business,
  location,
  about,
}
```

Add the pure selector as a top-level function:

```dart
/// Which hub rows a trade sees.
///
/// Tickets shows for EVERY trade — qualified tradies hold White Cards and
/// rigging licences too, and scoping it to apprentices would be an arbitrary
/// limit. Rates and Resume are the mutually exclusive pair: an apprentice is
/// on award rates and has nothing to quote, a qualified tradie quotes and
/// doesn't submit a resume.
List<ProfileSection> hubSectionsForTrade({required bool isApprentice}) => [
  ProfileSection.identity,
  ProfileSection.tradeDetails,
  if (!isApprentice) ProfileSection.rates,
  ProfileSection.tickets,
  if (isApprentice) ProfileSection.resume,
  ProfileSection.location,
  ProfileSection.about,
];
```

Rebuild the existing `rows` list from this selector, with the ticket row's value line reading `'4 tickets · 1 verified'` (or empty when none) and the resume row's value reading the filename.

- [ ] **Step 4: Write ApprenticeHeaderChip and branch the profile views**

`apprentice_header_chip.dart` renders `tradeProfile.apprenticeHeadline` in `labelMedium` on `c.surfaceRaised` with `c.text1` (the only text token legal on that ground).

In `trade_public_profile_page.dart` and `profile_page_trade.dart`, when `isApprentice`:
- render `ApprenticeHeaderChip` instead of the trade-type chip
- suppress the rate row, the public-liability row, the crew-size row and the jobs-completed stat
- render `TicketChipWall` (with `showDisclaimer: true` on the public/builder-facing page only)
- render `ResumeRow` in the correct mode for the viewer
- keep `PortfolioStrip(readOnly: true)` — the photos need no change

- [ ] **Step 5: Run the suite**

Run: `flutter test test/features/profile/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/profile test/features/profile
git commit -m "feat(profile): apprentice hub rows and profile layout"
```

---

## Task 13: search_trades + Discovery toggle

**Files:**
- Create: `supabase/migrations/20260831000004_search_trades_apprentices.sql`
- Create: `supabase/rollbacks/20260831000004_search_trades_apprentices_down.sql`
- Modify: `lib/features/discovery/domain/entities/trade_search_filter.dart`
- Modify: `lib/features/discovery/domain/entities/trade_search_result.dart`
- Modify: `lib/features/discovery/data/datasources/trade_search_remote_datasource.dart`
- Create: `lib/features/discovery/presentation/widgets/discovery_mode_toggle.dart`
- Modify: `lib/features/discovery/presentation/pages/discovery_page.dart`
- Modify: `lib/features/discovery/presentation/widgets/discovery_tradie_tile.dart`
- Test: `test/features/discovery/apprentice_search_test.dart`

- [ ] **Step 1: Write the migration**

Read `supabase/migrations/20260611000004_pii_visibility_split.sql` lines 116-190 first and copy the existing body verbatim, then add the new filter and columns. The function is `SECURITY DEFINER` with a fixed `RETURNS TABLE`, so a return-type change **cannot** use `CREATE OR REPLACE`:

```sql
-- supabase/migrations/20260831000004_search_trades_apprentices.sql
--
-- Adds apprentice filtering + projection to search_trades.
--
-- DROP + CREATE, not CREATE OR REPLACE: Postgres refuses to replace a function
-- whose RETURNS TABLE shape changes. The DROP takes the GRANT with it, so the
-- GRANT below is required, not optional.
--
-- p_apprentice defaults to FALSE, which filters to is_apprentice = false. That
-- PRESERVES today's Discovery result set exactly — existing callers pass
-- nothing and must keep seeing only qualified trades.

DROP FUNCTION IF EXISTS public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer
);

CREATE FUNCTION public.search_trades(
  p_lat double precision, p_lng double precision, p_radius_km integer,
  p_min_rating numeric DEFAULT NULL::numeric,
  p_available_only boolean DEFAULT false,
  p_query text DEFAULT NULL::text,
  p_limit integer DEFAULT 20, p_offset integer DEFAULT 0,
  p_apprentice boolean DEFAULT false
) RETURNS TABLE(
  -- ... every existing column, unchanged, then:
  is_apprentice boolean, apprenticeship_stage text, site_tickets text[]
)
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
  -- ... existing body, with this added to the WHERE clause:
  --   AND sub.is_apprentice = coalesce(p_apprentice, false)
  -- and the three new columns added to the SELECT list.
$$;

GRANT EXECUTE ON FUNCTION public.search_trades(
  double precision, double precision, integer, numeric, boolean, text,
  integer, integer, boolean
) TO authenticated;
```

Fill in the elided sections from the real 20260611000004 body. Do not guess the column list — copy it.

- [ ] **Step 2: Write the rollback**

The down script drops the 9-arg version and recreates the 8-arg one verbatim from `20260611000004_pii_visibility_split.sql`, then re-grants.

- [ ] **Step 3: Write the failing Dart test**

```dart
// test/features/discovery/apprentice_search_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_filter.dart';

void main() {
  group('TradeSearchFilter.apprenticesOnly', () {
    test('defaults to false so Discovery keeps showing qualified trades', () {
      expect(const TradeSearchFilter().apprenticesOnly, isFalse);
    });

    test('copyWith flips it in both directions', () {
      const base = TradeSearchFilter();
      expect(base.copyWith(apprenticesOnly: true).apprenticesOnly, isTrue);
      expect(
        base
            .copyWith(apprenticesOnly: true)
            .copyWith(apprenticesOnly: false)
            .apprenticesOnly,
        isFalse,
        reason: 'a bool copyWith must not be swallowed by ?? this.x',
      );
    });

    test('it participates in equality so a mode switch refetches', () {
      expect(
        const TradeSearchFilter() ==
            const TradeSearchFilter(apprenticesOnly: true),
        isFalse,
      );
    });
  });
}
```

The second test is the real trap: `apprenticesOnly ?? this.apprenticesOnly` cannot express "set it to false". Implement it the way `clearMinRating` is handled in the existing `copyWith`, or take a nullable param and use an explicit null check.

- [ ] **Step 4: Run to verify it fails**

Run: `flutter test test/features/discovery/apprentice_search_test.dart`
Expected: FAIL — no named parameter `apprenticesOnly`.

- [ ] **Step 5: Implement filter, result, datasource, toggle**

- `TradeSearchFilter`: add `final bool apprenticesOnly;` (default false), to `copyWith` and to `props`.
- `TradeSearchResult`: add `isApprentice`, `apprenticeshipStage` (parsed via `ApprenticeshipStage.fromDb`), `siteTickets`, all in `props`.
- Datasource: pass `'p_apprentice': filter.apprenticesOnly` in the RPC params map.
- `DiscoveryModeToggle`: two-segment control, selected segment `c.action` with `c.onAction` label, unselected `c.surfaceRaised` with `c.text1`. Each segment ≥ 48dp tall. Labels `TRADES` / `APPRENTICES`.
- `discovery_page.dart`: render the toggle above the list, reset pagination on change.
- `discovery_tradie_tile.dart`: when `isApprentice`, show `<Trade> · <stage label>` and a ticket count instead of the rate. Hide the rating filter in apprentice mode.
- Empty state: Lottie + `NO APPRENTICES NEARBY` + `WIDEN SEARCH`.

- [ ] **Step 6: Run to verify it passes**

Run: `flutter test test/features/discovery/`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test supabase
git add supabase/migrations/20260831000004_*.sql supabase/rollbacks/20260831000004_*.sql lib/features/discovery test/features/discovery
git commit -m "feat(discovery): apprentice search filter and mode toggle"
```

---

## Task 14: Jobs — open to apprentices

**Files:**
- Modify: `lib/features/jobs/domain/entities/job.dart`
- Modify: `lib/features/jobs/data/models/job_model.dart`
- Modify: `lib/features/jobs/data/datasources/job_remote_datasource.dart`
- Modify: `lib/features/jobs/presentation/pages/job_create_page.dart`
- Test: `test/features/jobs/open_to_apprentices_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/jobs/open_to_apprentices_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/jobs/data/models/job_model.dart';

void main() {
  group('Job.openToApprentices', () {
    test('defaults to false when the column is absent', () {
      final job = JobModel.fromJson(const {
        'id': 'j1',
        'builder_id': 'b1',
        'title': 'Framing',
        'description': 'Two weeks of framing.',
        'status': 'open',
      });
      expect(job.openToApprentices, isFalse);
    });

    test('parses true and survives a toJson round-trip', () {
      final job = JobModel.fromJson(const {
        'id': 'j1',
        'builder_id': 'b1',
        'title': 'Framing',
        'description': 'Two weeks of framing.',
        'status': 'open',
        'open_to_apprentices': true,
      });
      expect(job.openToApprentices, isTrue);
      expect(job.toJson()['open_to_apprentices'], true);
    });
  });
}
```

Check `JobModel.fromJson`'s actual required keys first and build the fixture to match; the map above is indicative of shape, not verified.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/jobs/open_to_apprentices_test.dart`
Expected: FAIL — `openToApprentices` isn't defined.

- [ ] **Step 3: Implement**

- `job.dart`: `this.openToApprentices = false,` + `final bool openToApprentices;` + add to `props` if the entity has one.
- `job_model.dart`: `openToApprentices: json['open_to_apprentices'] as bool? ?? false,` in `fromJson`, and `'open_to_apprentices': openToApprentices,` in **both** `toJson` maps (there are two — lines ~152 and ~192).
- **`job_remote_datasource.dart:32` hand-writes its column projection.** Add `open_to_apprentices` to that string or `fromJson` silently reads a missing key and every job comes back false. This is the exact bug class already recorded in the jobs field gotchas.
- `job_create_page.dart`: an "Open to apprentices" `JSwitch` in the requirements section, with the sub-line "Invite apprentices to apply. Doesn't change your other requirements."
- Job card: an `OPEN TO APPRENTICES` chip when true, styled as a neutral `c.surfaceRaised` / `c.text1` tag (not orange — orange is reserved for CTAs and critical status, and this is neither).

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/jobs/`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/jobs test/features/jobs
git commit -m "feat(jobs): open to apprentices flag"
```

---

## Task 15: profile_completeness apprentice slots

**Files:**
- Create: `supabase/migrations/20260831000006_profile_completeness_apprentice.sql`
- Create: `supabase/rollbacks/20260831000006_profile_completeness_apprentice_down.sql`
- Test: `test/features/profile/profile_completeness_test.dart` (extend the existing file)

- [ ] **Step 1: Read the current view**

Run: `cat supabase/migrations/20260514000001_profile_completeness.sql`

- [ ] **Step 2: Write the migration**

`CREATE OR REPLACE VIEW public.profile_completeness` with the trade branch made apprentice-aware: when `is_apprentice`, the slots are `about`, `site_tickets <> '{}'`, `resume_path IS NOT NULL`, `portfolio_urls <> '{}'`, and base location; the hourly-rate slot is dropped. Non-apprentice rows keep today's slot list byte-for-byte.

Re-apply the existing `REVOKE ALL ... FROM PUBLIC` / `GRANT SELECT ... TO authenticated` after the replace.

- [ ] **Step 3: Extend the Dart test**

Add a case asserting an apprentice with no rate but a filled about + tickets + resume + photos reads as complete, and that a qualified tradie's completeness is unchanged.

- [ ] **Step 4: Run**

Run: `flutter test test/features/profile/profile_completeness_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260831000006_*.sql supabase/rollbacks/20260831000006_*.sql test/features/profile/profile_completeness_test.dart
git commit -m "feat(db): apprentice-aware profile completeness"
```

---

## Task 16: Apply to staging and verify

**Files:** none (deployment + verification)

- [ ] **Step 1: Confirm staging is awake**

```bash
curl -s -o /dev/null -w "%{http_code}\n" --max-time 15 \
  "https://kqpsceobwtavcxhatxww.supabase.co/rest/v1/trade_categories?select=slug&limit=1" \
  -H "apikey: <staging anon key from docs/STAGING_BACKEND.md>"
```

Expected: `200`. A `000` means the project is still paused or still coming up.

- [ ] **Step 2: Apply the six migrations to staging**

Staging has **no migration history** — it was cloned from the live schema, not replayed
(`docs/STAGING_BACKEND.md:72`). `supabase db push` would try to replay everything from
2026-05-11. Apply these six by hand instead, in numeric order, via `psql` with the
`SUPABASE_STAGING_DB_PASSWORD` from `.env.server`, or by pasting each file into the SQL editor.

Order matters: `...0002` (site_tickets) must land before any client reads it, and `...0004`
(search_trades) must land after `...0001` because it selects `is_apprentice`.

- [ ] **Step 3: Verify each object landed**

```sql
select column_name from information_schema.columns
 where table_name = 'trade_profiles'
   and column_name in ('is_apprentice','apprenticeship_stage','site_tickets',
                       'resume_path','resume_uploaded_at');
-- expect 5 rows

select count(*) from public.site_tickets;              -- expect 9
select count(*) from public.site_tickets where doc_type is not null;  -- expect 1

select polname from pg_policy
 where polname = 'private_docs_resume_applied_builder_select';  -- expect 1 row

select pg_get_function_identity_arguments(oid)
  from pg_proc where proname = 'search_trades';        -- expect the 9-arg signature

select column_name from information_schema.columns
 where table_name = 'jobs' and column_name = 'open_to_apprentices';  -- expect 1 row
```

- [ ] **Step 4: Apply the same six to production**

Only after staging is green and the app has been exercised against it. Every migration in this
set is additive and reversible; the one to watch is `...0004`, which drops and recreates
`search_trades`. Run it in a single transaction during a quiet window.

- [ ] **Step 5: Run full local validation**

```bash
bash scripts/validate.sh
bash scripts/check-architecture.sh
```

Expected: both green. `validate.sh` runs the design-system greps, `dart format --set-exit-if-changed`, `flutter analyze --no-fatal-infos`, and the full test suite.

- [ ] **Step 6: Build and run against staging**

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://kqpsceobwtavcxhatxww.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<staging anon key>
```

Sign in as `qa.trade.test@jobdun.com.au` / `123Jobdun!`, turn on apprentice mode, tick tickets,
upload a resume, add photos, then sign in as `qa.builder.test@jobdun.com.au` and confirm the
apprentice appears under the APPRENTICES toggle and the resume is locked until an application
exists.

- [ ] **Step 7: Capture screenshots**

Per `CLAUDE.md`, a UI change is not done without real screenshots. Run
`bash scripts/capture_app_screenshots.sh` if an emulator is available, otherwise
`bash scripts/deploy-iphone.sh` and capture on device. Commit the PNGs under `docs/verification/`.

- [ ] **Step 8: Ship to testers**

```bash
bash scripts/ship-to-boss.sh "Apprentice profiles: tickets, resume, discovery toggle"
```

This builds a release APK and pushes it to Firebase App Distribution (project `jobdun-627d2`,
group `jobdun-app-team`). Release-signed, so Google SSO works; Play-Store testers must uninstall
the store build first.

---

## Self-review

**Spec coverage.** §4.2 → Task 1. §4.3 → Tasks 1, 3, 6. §4.4 → Tasks 1, 14. §4.5 → Tasks 1, 7, 10. §4.6 → Task 13. §4.7 → Task 15. §6.1 → Task 12. §6.2 → Task 11. §6.3 → Task 9. §6.4 → Task 8. §6.5 → Task 10. §6.6 → Task 12. §6.7 → Task 13. §7 a11y → assertions in Tasks 8, 9. §8 states → Tasks 9, 10, 13. §9 copy → Tasks 8, 10, 11, 14.

**Known gaps, deliberate.** The Task 13 migration body is elided with an instruction to copy the real function from `20260611000004_pii_visibility_split.sql` rather than reproduced. Transcribing ~70 lines of a `SECURITY DEFINER` function from a grep excerpt risks a silent projection error, and that file is the authority. Same for Task 15's view body. Both steps name the exact source file and line range.

**Type consistency.** `ApprenticeshipStage.fromDb` returns nullable everywhere. `siteTickets` is `List<String>` on the entity and `Option<List<String>>` on the patch throughout. `isAllowedResumeFile` returns `String?` (null = OK) in the use case, the test and the sheet. `hubSectionsForTrade` returns `List<ProfileSection>` in both the test and the implementation. `resumeStoragePath(userId, fileName, epochSeconds)` has the same three-arg shape in the test, the use case and the datasource.
