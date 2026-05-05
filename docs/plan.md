# Jobdun — Setup Plan (Pre-Design-System)

**Goal**: Scaffold the full feature architecture so that UI development is unblocked when the design system arrives. No new UI screens are built here — only contracts, entities, data layers, and infrastructure.

---

## What is already done

- Auth flow (splash, login, register, onboarding) with real Supabase wiring
- GoRouter with auth-aware redirects
- Riverpod `NotifierProvider` pattern established in `auth_provider.dart`
- Material 3 theme with design-system-ready token files (`app_colors.dart`)
- Core infrastructure: `failures.dart`, `exceptions.dart`, `validators.dart`, `app_date_utils.dart`, `network_info.dart`, `loading_view.dart`, `error_view.dart`
- Full domain + data + provider scaffolding for all 8 features
- Placeholder pages for all 8 features (applications, reviews, notifications are new)
- All routes wired in GoRouter (nested for `/jobs` and `/messages`)
- `UserRole` moved to domain layer (`lib/features/auth/domain/entities/user_role.dart`)
- Admin removed from Flutter; admin is a separate web application

---

## Design system integration

All color and spacing tokens live in `lib/app/theme/app_colors.dart`:
- `AppColors` — brand and surface colors
- `AppSpacing` — spacing scale
- `AppRadius` — border radius scale

`app_theme.dart` references these tokens only. Widgets use `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*`. To apply a design system: update `app_colors.dart` and the `ThemeData` in `app_theme.dart` — no widget code needs to change.

---

## Feature architecture pattern

Every feature follows this structure:

```
lib/features/<feature>/
  data/
    datasources/<feature>_remote_datasource.dart   # abstract + Supabase impl
    models/<entity>_model.dart                     # fromJson/toJson
    repositories/<feature>_repository_impl.dart    # Either<Failure, T> returns
  domain/
    entities/<entity>.dart                         # pure Dart, Equatable
    repositories/<feature>_repository.dart         # abstract interface
    usecases/<usecase>.dart                        # single call() method
  presentation/
    providers/<feature>_provider.dart              # NotifierProvider
    pages/                                         # placeholder pages
```

Use cases return `Future<Either<Failure, T>>` using `fpdart`.

---

## Feature scaffold status

| Feature | Domain | Data | Provider | Page |
|---------|--------|------|----------|------|
| auth | ✅ | ✅ | existing | existing |
| profile | ✅ | ✅ | ✅ | existing |
| jobs | ✅ | ✅ | ✅ | existing |
| applications | ✅ | ✅ | ✅ | ✅ new |
| messaging | ✅ | ✅ | ✅ | existing |
| verification | ✅ | ✅ | ✅ | existing |
| reviews | ✅ | ✅ | ✅ | ✅ new |
| notifications | ✅ | ✅ | ✅ | ✅ new |

---

## Packages added

```yaml
# Production
equatable: ^2.0.7
fpdart: ^1.1.0
json_annotation: ^4.9.0
intl: ^0.20.2
connectivity_plus: ^6.1.4
image_picker: ^1.1.2
file_picker: ^8.1.6
cached_network_image: ^3.4.1
url_launcher: ^6.3.1

# Dev
build_runner: ^2.4.15
json_serializable: ^6.9.4
mocktail: ^1.0.4
```

**Note on freezed**: `freezed` 2.x conflicts with `flutter_riverpod` 3.x due to analyzer version mismatch. Add `freezed` back once a version compatible with Riverpod 3.x is released, or when migrating to Riverpod 2.x.

---

## Supabase setup checklist (manual — run in Supabase SQL editor)

### Table creation order

1. `profiles` — add `is_onboarding_complete bool default false`, `is_active bool default true`
2. `builder_profiles`
3. `trade_profiles`
4. `jobs` — add `required_licences text[]`, `budget_type text default 'fixed'`
5. `job_applications`
6. `messages` — add `updated_at`
7. `verification_documents`
8. `reviews`
9. `notifications` — add `data jsonb`

### Required triggers

```sql
-- Auto-create profile on auth.users insert
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', 'trade');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;
-- Apply to: profiles, jobs, job_applications
```

### RLS summary

Enable on all tables. Key policies:
- `profiles`: public read, own-only write
- `jobs`: open jobs public read; builders manage own
- `job_applications`: trade + job's builder can read; trade can apply; both can update status
- `messages`: sender/receiver only
- `verification_documents`: own-only; status updates via Edge Function only (service-role key)
- `reviews`: public read; reviewer must be involved in the job
- `notifications`: own-only

### Storage buckets

| Bucket | Access |
|--------|--------|
| `avatars` | Public read, own-folder write |
| `company-logos` | Public read, own-folder write |
| `portfolio-images` | Public read, own-folder write |
| `verification-documents` | **Private** — signed URLs only |
| `job-attachments` | Public read |

### Realtime

Enable on: `messages`, `notifications`

---

## Routes

```
/splash → /login → /register → /onboarding → /home
/jobs
  /jobs/create      (placeholder — JobsPage)
  /jobs/:id         (placeholder — JobsPage)
/applications
/messages
  /messages/:conversationId  (placeholder — MessagesPage)
/profile
  /profile/edit     (placeholder — ProfilePage)
/verification
/reviews
/notifications
```

---

## Next steps (when design system arrives)

1. Update `AppColors`, `AppSpacing`, `AppRadius` in `app_colors.dart`
2. Extend `AppTheme.light()` with new `TextTheme` and component styles
3. Replace placeholder pages one feature at a time, starting with auth
4. Wire providers to real repositories (inject via Riverpod `Provider`)
5. Add `freezed` once compatible with Riverpod 3.x for immutable model pattern
