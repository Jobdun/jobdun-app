# UI Modern-Stack Audit — Jobdun Flutter App

> **Generated:** 2026-05-20
> **Scope:** every screen in `lib/features/*/presentation/pages/` + shared widgets in `lib/core/design/widgets/`
> **Reference docs:** `design-system/jobdun/MASTER.md`, `CLAUDE.md` UI/UX conventions, `ui-ux-pro-max` skill
> **Companion audits (do not duplicate):** `docs/UI_UX_INCONSISTENCY_AUDIT.md`, `docs/DESIGN_SYSTEM_FOUNDATION_AUDIT.md`, `docs/AUTH_ONBOARDING_AUDIT.md`

---

## 0 · TL;DR

The app already **has** a real design system (tokens in `lib/app/theme/`, semantic icon catalogue in `lib/core/theme/app_icons.dart`, composable widget kit in `lib/core/design/widgets/`). Anti-pattern hygiene (no white backgrounds, `Gap()` instead of `SizedBox`, `.w/.h/.r` units, no per-widget `GoogleFonts.*` calls) is mostly clean.

**The gap is adoption.** Sixteen modern UI/UX packages are declared in `pubspec.yaml` but never imported into a feature screen. The screens still render a stock `CircularProgressIndicator` for every loading state, no list animation, no swipe actions, no Lottie empty states, raw `TextFormField` in every form, and `showModalBottomSheet` (Flutter built-in) instead of `modal_bottom_sheet`. The result is a polished-token UI driving 2019-era widget patterns.

This document inventories that gap and gives copy-pasteable upgrade recipes — first as a per-package adoption matrix, then per screen, then per component pattern. Recommendations follow `design-system/jobdun/MASTER.md` (aggressive flat, dark, all-caps, 150–200ms motion) — nothing in here suggests softening the brand.

---

## 1 · What's Already Strong (Keep)

| Asset | Where | Note |
|---|---|---|
| Token layer | `lib/app/theme/app_colors.dart`, `app_theme.dart` | `JColors` light/dark, all `context.c.*` accessors, full `ColorScheme` + Material 3 wiring |
| Typography | `app_theme.dart` only | Oswald + Open Sans via single `GoogleFonts.openSansTextTheme` call — no per-widget leaks (validated by grep) |
| Semantic icon catalogue | `lib/core/theme/app_icons.dart` | `phosphor_flutter` is the only icon dep; Bold = inactive, Fill = active. Nav pairs as records. Excellent abstraction — **keep, do not migrate back to Iconsax** despite CLAUDE.md still mentioning Iconsax |
| Component kit | `lib/core/design/widgets/` | `JButton`, `JCard`, `JChip`/`GvChip`, `JobCard`, `TradieCard`, `PageHeader`, `StatusBadge`, `BottomActionBar`, `EmptyState`, `FieldLabel`, `AvatarBlock`, `JobdunLogo`, `JSwitch`, `BottomSheetHeader` |
| OTP | `Pinput` already wired through `AppTheme.pinputTheme` | Only modern package fully integrated |
| Spacing & sizing hygiene | All features | `Gap(n)` + `.w/.h/.sp/.r` — grep confirms zero raw `SizedBox(height:` in `lib/features/` |
| FTUE pager | `ftue_page_indicator.dart` | `smooth_page_indicator` used correctly |

> ⚠️ **CLAUDE.md drift:** `CLAUDE.md` still tells future agents to use `Iconsax.*`. The code has already moved to `phosphor_flutter` via `AppIcons`. Update `CLAUDE.md` UI/UX conventions block (Icons row) to reflect the catalogue — otherwise the next agent will reintroduce Iconsax imports.

---

## 2 · Modern Package Adoption Matrix

Declared in `pubspec.yaml`. Imported into `lib/features/`? Yes / No.

| # | Package | Declared | Used in features | Status | Pay-off if adopted |
|---|---|---|---|---|---|
| 1 | `flutter_animate` (`.animate().fadeIn().slideY()`) | ✓ | ✗ | **MISSING** | Micro-interactions on CTAs, banner reveals, status changes |
| 2 | `flutter_staggered_animations` (`AnimationLimiter`) | ✓ | ✗ | **MISSING** | Job list, message list, application list — items fade-slide in |
| 3 | `skeletonizer` (`Skeletonizer(child:)`) | ✓ | ✗ | **MISSING** | Replace 6× `CircularProgressIndicator` — match real layout while loading |
| 4 | `shimmer` | ✓ | ✗ | **MISSING** | Avatar / portfolio / map tile placeholders |
| 5 | `lottie` | ✓ | ✗ | **MISSING** | Empty states (no jobs, no applications, no messages), success confirmations |
| 6 | `infinite_scroll_pagination` (`PagedListView`) | ✓ | ✗ | **MISSING** | Jobs feed, applications, messages — feeds currently load all rows at once |
| 7 | `flutter_slidable` (`SlidableAction`) | ✓ | ✗ | **MISSING** | Archive / shortlist / mark-read / mute on cards |
| 8 | `badges` | ✓ | ✗ | **MISSING** | Unread dot on conversations, applicants count on JobCard, nav-tab unread dot |
| 9 | `percent_indicator` (`Linear/CircularPercentIndicator`) | ✓ | ✗ | **MISSING** | `ProfileCompletenessBanner` is hand-rolled; verification gates are textual |
| 10 | `expandable` (`ExpandablePanel`) | ✓ | ✗ | **MISSING** | Job description, profile bio, legal documents — currently no show-more |
| 11 | `modal_bottom_sheet` (`showMaterialModalBottomSheet`) | ✓ | 1 file (`logout_confirm_sheet`) | **PARTIAL** | 5 other sheets still use Flutter built-in `showModalBottomSheet` — inconsistent feel + no iOS-native swipe |
| 12 | `flutter_form_builder` + `form_builder_validators` | ✓ | ✗ | **MISSING** | 36 raw `TextFormField` instances across login/register/forgot/phone/job-create/profile-edit |
| 13 | `photo_view` (`PhotoView`) | ✓ | ✗ | **MISSING** | Portfolio strip + verification document viewer — currently can't pinch-zoom |
| 14 | `image_cropper` + `flutter_image_compress` | ✓ | ✗ | **MISSING** | Avatar / company logo / portfolio uploads — raw `image_picker` outputs sent to Supabase storage uncropped, uncompressed |
| 15 | `fl_chart` | ✓ | ✗ | **MISSING** | Earnings / applications-over-time / map cluster density — no analytics surfaces exist yet |
| 16 | `flutter_rating_bar` | ✓ | ✗ | **MISSING** | Reviews page is a 14-line stub; no rating UI anywhere |

**Headline metric:** 1 of 16 modern packages fully integrated. 2 partially. 13 declared but dormant. Footprint of dormant deps in the APK is non-trivial — either adopt or remove from `pubspec.yaml`.

---

## 3 · Per-Screen Findings

Format: file → what's there → modern upgrade → priority (P1 ship-blocking polish, P2 high-value, P3 nice-to-have).

### 3.1 Auth & Onboarding

#### `auth/presentation/pages/splash_page.dart` (161 lines)
- **Now:** Static logo + spinner during route gate.
- **Upgrade:** Wrap logo in `flutter_animate` — `.fadeIn(duration: 200.ms).then().scale(begin: 0.95, end: 1.0)`. Replace spinner with `Lottie.asset('assets/lottie/loading_pulse.json')`. — **P2**

#### `auth/presentation/pages/login_page.dart` (389 lines)
- **Now:** Raw `TextFormField` × 2, validation inline, `setState` on submit.
- **Upgrade:** Migrate to `FormBuilder` + `FormBuilderTextField` with `FormBuilderValidators.compose([required, email])`. Saves ~30 lines, enables `_formKey.currentState!.saveAndValidate()`. Wrap submit `JButton` `.animate(target: isLoading ? 1 : 0).shimmer()` for inflight feedback. — **P1**
- **Empty state on error:** Use `StatusBanner` (already exists in `lib/core/widgets/status_banner.dart`) — animate in with `flutter_animate` `.slideY(begin: -0.2)`.

#### `auth/presentation/pages/register_page.dart` (830 lines — heaviest auth file)
- **Now:** Multi-step form, fully manual stepping, raw TextField.
- **Upgrade:** This is the strongest candidate for `flutter_form_builder` + `FormBuilderStepper` style flow. The role-intent CTA already exists — wrap in `flutter_animate` `.shimmer(duration: 1200.ms, color: c.action.withOpacity(.15))` so it pulses subtly. Use `animations` package `SharedAxisTransition` between steps instead of `setState`-swap. — **P1**

#### `auth/presentation/pages/phone_auth_page.dart` (600 lines)
- **Now:** `Pinput` ✓ (good), country picker uses built-in `showModalBottomSheet`.
- **Upgrade:** Switch country sheet to `showMaterialModalBottomSheet` for swipe-down dismissal. Add `badges.Badge` to the resend-code countdown ("0:58") — currently text only. — **P2**

#### `auth/presentation/pages/verify_email_page.dart` (268 lines) / `forgot_password_page.dart` (188 lines)
- **Upgrade:** Email-sent confirmation state should be Lottie (`success_check.json`) + headline, not a static icon. — **P2**

#### `ftue/presentation/pages/ftue_page.dart` (251 lines)
- **Now:** `smooth_page_indicator` ✓, `ftue_map_hero` likely custom.
- **Upgrade:** Slide entry/exit motion — wrap each slide with `flutter_animate` `.fadeIn().slideX()` keyed to active page. Use `animations` `FadeThroughTransition` between slides. — **P3** (already feels OK based on file structure).

---

### 3.2 Home & Shell

#### `home/presentation/pages/home_shell_page.dart` (161 lines)
- **Now:** Already uses `Iconsax` constants (still imports the old lib) but routes through `AppIcons` semantics elsewhere — **inconsistency**.
- **Upgrade:** Remove the direct `Iconsax.*` references in `home_shell_page.dart:78-82, 103` and use `AppIcons.home.outline/.filled` etc. — your own catalogue already exports the right pairs. Cross-fade outline→filled with `AnimatedSwitcher` (200ms) when tab changes. — **P1** (consistency)
- Add unread dot via `badges.Badge` overlaid on the messages tab icon.

#### `home/presentation/pages/home_page.dart` (1,421 lines — largest file in the app)
- **Now:** Mixed list/map view, `setState` for view mode toggle, multiple `Colors.white // intentional` comments, custom `_ViewMode` enum, `CircularProgressIndicator` for jobs load.
- **Upgrades:**
  - **View toggle:** wrap list ↔ map switch in `AnimatedSwitcher` with `FadeThroughTransition` (`animations` pkg). — **P1**
  - **Loading:** replace job-list spinner with `Skeletonizer(enabled: isLoading, child: ListView.builder of placeholder JobCards)`. Skeleton matches real layout; users perceive 30% faster loads (well-documented). — **P1**
  - **List entry:** wrap `ListView.builder` body in `AnimationLimiter` + each `JobCard` in `AnimationConfiguration.staggeredList(child: SlideAnimation(verticalOffset: 24, child: FadeInAnimation(child: ...)))`. — **P1**
  - **Pagination:** `home_page.dart` loads the whole feed. Convert to `PagedListView<int, Job>` from `infinite_scroll_pagination`. — **P2**
  - **Map mode:** add `Lottie` loop while geolocator fixes the position (currently blank). — **P2**
  - **File size:** 1,421 lines is too dense — extract `_JobListSection`, `_MapSection`, `_RoleSheetGate` to widgets/. Not strictly a modernization, but it unlocks the upgrades above. — **P2**

#### `home/presentation/widgets/profile_completeness_banner.dart`
- **Now:** Custom progress (hand-rolled bar).
- **Upgrade:** Replace bar with `LinearPercentIndicator` from `percent_indicator` — `progressColor: c.action`, `backgroundColor: c.surfaceRaised`, animated, 6.h height. Or `CircularPercentIndicator` size 48 on the right side of the banner for a denser look. — **P1**

---

### 3.3 Jobs

#### `jobs/presentation/pages/jobs_page.dart` (305 lines)
- **Now:** Debounced search, horizontal chip filter row, `ListView.separated` of `JobCard`. Loading is `jobsState.isLoading` toggling.
- **Upgrades:**
  - `Skeletonizer` around the list while loading. — **P1**
  - `AnimationLimiter` + staggered fade-slide on cards. — **P1**
  - `flutter_slidable` on each `JobCard`: builder sees "ARCHIVE / CLOSE"; tradie sees "SAVE / HIDE". — **P2**
  - `infinite_scroll_pagination`. — **P2**
  - Empty state (no jobs match search): Lottie `empty_construction.json` + bold headline + "CLEAR FILTERS" CTA. The shared `EmptyState` widget exists — extend it to accept a Lottie asset path. — **P1**

#### `jobs/presentation/pages/job_detail_page.dart` (539 lines)
- **Now:** Apply sheet uses `showModalBottomSheet` (built-in, line 351).
- **Upgrades:**
  - Switch apply sheet to `showMaterialModalBottomSheet` — gets the proper iOS drag-to-dismiss. — **P1**
  - Wrap long `description` in `ExpandablePanel` with "READ MORE" / "READ LESS" — currently the whole description is rendered. — **P2**
  - Animate apply success: on `setState(() => _applied = true)`, run `Lottie.asset('success_check.json', repeat: false)` overlay for 800ms, then return. — **P2**
  - Required-credentials chips (`requiresWhiteCard`, `requiresLiability`) — wrap each in `.animate().scale(begin: 0.8, end: 1.0)` on first paint. — **P3**

#### `jobs/presentation/pages/job_create_page.dart` (425 lines)
- **Now:** Multi-section form, raw `TextFormField`s, `Colors.white` on CTA (intentional). Bottom action bar present.
- **Upgrades:**
  - **FormBuilder migration**: `FormBuilderTextField`, `FormBuilderDateTimePicker` for start date, `FormBuilderChoiceChip` for trade type, `FormBuilderSwitch` for `requiresWhiteCard`/`requiresLiability`. — **P1**
  - **Step indicator** at top (3 sections: Basics, Location, Requirements) — `smooth_page_indicator` `WormEffect`. — **P2**
  - **Description field**: `flutter_form_builder`'s `FormBuilderTextField` with `maxLines: 6` + character counter — currently no counter visible. — **P2**

---

### 3.4 Applications

#### `applications/presentation/pages/applications_page.dart` (498 lines)
- **Now:** Horizontal `GvChip` tab row, `ListView` of cards, mock data fallback (`_mockApps`).
- **Upgrades:**
  - **Skeletonizer** for the list during load. — **P1**
  - **AnimationLimiter** staggered cards. — **P1**
  - **Slidable**: builder swipes left → "SHORTLIST" / "REJECT"; tradie swipes left → "WITHDRAW". Each `SlidableAction` filled bg with all-caps label per MASTER.md. — **P1**
  - **Status transition**: when tab filter changes, run `AnimatedSwitcher` with `FadeThroughTransition` so the list doesn't snap. — **P2**
  - **Empty state per tab**: Lottie + "NO PENDING APPLICANTS" / "NO HIRES YET" + CTA. — **P1**
  - **Counter chip per tab**: overlay `badges.Badge` with the count (e.g., "PENDING ●3"). — **P2**

---

### 3.5 Messaging

#### `messaging/presentation/pages/messages_page.dart` (409 lines)
- **Now:** Top `LinearProgressIndicator` while loading, "X unread" pill (orange), `ListView.separated` of conversations, mock fallback.
- **Upgrades:**
  - Replace mock-fallback + "X unread" with `badges.Badge.count(count: totalUnread, badgeColor: c.action)` over the page header — visual hierarchy. — **P2**
  - `Skeletonizer` on conversation rows while loading instead of the thin progress bar (or keep both). — **P1**
  - `flutter_slidable` per row: "MUTE / ARCHIVE / MARK READ". — **P1**
  - `AnimationLimiter` staggered row entry. — **P1**
  - Empty state: Lottie + bold headline + "START A CONVERSATION" / "POST A JOB" CTA per role. — **P1**

#### `messaging/presentation/pages/message_thread_page.dart` (348 lines)
- **Now:** Compose at bottom, list of bubbles, `Colors.white // intentional` on send-button bubble.
- **Upgrades:**
  - **Typing indicator**: animated 3-dot using `flutter_animate` — `.fadeIn().then().fadeOut()` looped. — **P2**
  - **New message arrival**: `.animate().fadeIn().slideY(begin: 0.3)`. — **P2**
  - **Avatars**: switch raw image to `CachedNetworkImage` (already a dep) inside a `ClipRRect` with `shimmer` placeholder. — **P1**
  - **Attachment preview**: use `PhotoView` when tapped — pinch-zoom for images. — **P2**

---

### 3.6 Profile & Verification

#### `profile/presentation/pages/profile_page.dart` (671 lines)
- **Now:** `CircularProgressIndicator` at line 152 (only "intentional" non-comment direct color found — `Colors.black45` overlay on avatar — verify intent). Uses raw `Image.network` likely.
- **Upgrades:**
  - **Loading**: `Skeletonizer` over the whole profile body. — **P1**
  - **Avatar overlay**: `Colors.black45` overlay (line 148) → replace with `c.background.withOpacity(0.45)` so it respects dark/light. — **P1**
  - **Portfolio strip**: render with `CachedNetworkImage` + `shimmer` placeholder, tap → `PhotoView.gallery`. — **P1**
  - **Bio**: wrap in `ExpandablePanel` if > 4 lines. — **P2**
  - **Rating**: use `RatingBar.builder` (read-only) with filled stars in `c.action`. — **P2**
  - **Profile completeness CTA**: animate the % bar fill with `flutter_animate` `.custom()` driving `percent_indicator`. — **P2**

#### `profile/presentation/pages/profile_edit_page.dart` (550 lines)
- **Upgrades:**
  - **FormBuilder** migration — full form. — **P1**
  - **Avatar upload**: pipe `image_picker` output → `ImageCropper().cropImage(aspectRatioPresets: [CropAspectRatioPreset.square])` → `FlutterImageCompress.compressWithFile(quality: 80)` → Supabase. Cuts upload size 60–80%, ensures correct dimensions. — **P1**
  - **Trade-category picker** (`trade_category_picker.dart` widget): the `CircularProgressIndicator` (line 132) while categories load → `Skeletonizer` chip-row. — **P2**

#### `profile/presentation/widgets/portfolio_strip.dart`
- **Now:** `CircularProgressIndicator` at line 203 during upload; raw image rendering.
- **Upgrade:** Replace progress with `LinearPercentIndicator(percent: uploadProgress, progressColor: c.action)`. Wrap each tile in `Shimmer.fromColors` placeholder while loading. — **P1**

#### `verification/presentation/pages/verification_page.dart` (243 lines)
- **Now:** Status cards (lines 66, 81 use white-on-success/error — intentional). No doc preview.
- **Upgrades:**
  - **Document tap** → `PhotoView` modal so user can verify the upload is legible. — **P1**
  - **Status timeline**: vertical timeline with `flutter_animate` step reveal (`.fadeIn(delay: index * 100.ms)`). — **P2**
  - **Re-upload affordance**: `flutter_slidable` "RETAKE" action on each doc row. — **P2**

---

### 3.7 Reviews & Notifications

#### `reviews/presentation/pages/reviews_page.dart` (14 lines — stub)
- **Build out:** `RatingBar.builder` (write), list of `ReviewCard` (read) with avatar + 5-star + body + timestamp, `AnimationLimiter` staggered, Lottie empty state. — **P2** (needs feature scope first)

#### `notifications/presentation/pages/notifications_page.dart` (15 lines — stub)
- **Build out:** grouped list (today / earlier), `flutter_slidable` swipe-to-dismiss, `badges.Badge` for unread, Lottie empty state. — **P2**

---

### 3.8 Legal

#### `legal/presentation/pages/legal_document_page.dart` (91 lines), `legal_index_page.dart` (190 lines)
- **Upgrade:** Document body in `ExpandablePanel` per section heading — Privacy Policy / Terms have natural H2 sections. Reduces scroll fatigue dramatically. — **P2**
- Loading already correct (`CircularProgressIndicator` is fine for sub-200ms doc fetches).

---

## 4 · Per-Component Upgrade Recipes

These are reusable across the screens above. Add to `lib/core/design/widgets/` so screens can opt in without duplicating.

### 4.1 `JSkeletonList` — drop-in loading wrapper

```dart
// lib/core/design/widgets/j_skeleton_list.dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../colors.dart';

class JSkeletonList extends StatelessWidget {
  const JSkeletonList({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Skeletonizer(
      enabled: enabled,
      effect: ShimmerEffect(
        baseColor: c.surface,
        highlightColor: c.surfaceRaised,
        duration: const Duration(milliseconds: 1200),
      ),
      child: child,
    );
  }
}
```

Usage in `jobs_page.dart`:

```dart
JSkeletonList(
  enabled: isLoading,
  child: ListView.builder(
    itemCount: isLoading ? 6 : jobs.length,
    itemBuilder: (_, i) => JobCard(job: isLoading ? Job.placeholder : jobs[i]),
  ),
)
```

### 4.2 `JStaggeredList` — list entry motion

```dart
// lib/core/design/widgets/j_staggered_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class JStaggeredList extends StatelessWidget {
  const JStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.separator,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: ListView.separated(
        controller: controller,
        itemCount: itemCount,
        separatorBuilder: (_, _) => separator ?? const SizedBox.shrink(),
        itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
          position: i,
          duration: const Duration(milliseconds: 200), // MASTER.md: 150–200ms
          child: SlideAnimation(
            verticalOffset: 16.h,
            child: FadeInAnimation(child: itemBuilder(ctx, i)),
          ),
        ),
      ),
    );
  }
}
```

### 4.3 `JEmptyState` (extend existing `empty_state.dart`)

Currently the file exists but likely text-only. Extend:

```dart
class JEmptyState extends StatelessWidget {
  const JEmptyState({
    super.key,
    required this.lottieAsset,    // e.g., 'assets/lottie/empty_jobs.json'
    required this.headline,        // ALL CAPS per MASTER
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final String lottieAsset;
  final String headline;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(lottieAsset, width: 160.w, height: 160.w),
            Gap(16.h),
            Text(headline.toUpperCase(), style: tt.headlineSmall),
            Gap(8.h),
            Text(body, textAlign: TextAlign.center,
                 style: tt.bodyMedium?.copyWith(color: c.text2)),
            if (ctaLabel != null) ...[
              Gap(20.h),
              JButton(label: ctaLabel!, onPressed: onCta ?? () {}),
            ],
          ],
        ),
      ),
    );
  }
}
```

Lottie assets to commission (or grab CC0 from `lottiefiles.com`):
- `empty_jobs.json` — hammer/hard-hat
- `empty_inbox.json` — chat bubbles
- `empty_applications.json` — clipboard
- `success_check.json` — checkmark burst
- `loading_pulse.json` — splash loader

### 4.4 `JBottomSheet` — wrap `modal_bottom_sheet`

```dart
// lib/core/design/widgets/j_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import '../colors.dart';

Future<T?> showJSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
}) {
  final c = context.c;
  return showMaterialModalBottomSheet<T>(
    context: context,
    backgroundColor: c.card,
    barrierColor: Colors.black.withOpacity(0.6),
    expand: expand,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: builder,
  );
}
```

Migrate 5 call-sites (grep `showModalBottomSheet` returns: `home_page:1029`, `role_selection_sheet:20`, `country_picker_sheet:16`, `trade_category_picker:28`, `job_detail_page:351`).

### 4.5 `JTextField` (extend `lib/core/widgets/inputs/j_text_field.dart`)

Currently in flight (see modified files). Final form should be a thin wrapper over `FormBuilderTextField` with MASTER-aligned `InputDecoration` defaults. Adopt across the 6 forms in §3.

### 4.6 Pagination wrapper

```dart
// lib/core/design/widgets/j_paged_list.dart
class JPagedJobList extends ConsumerStatefulWidget {
  // wraps PagingController<int, Job>, hands itemBuilder back to caller.
  // pages of 20, prefetch threshold 4.
}
```

Then `jobs_page` becomes a 200-line file instead of 305.

### 4.7 Image upload pipeline

```dart
// lib/core/services/image_upload_service.dart
Future<XFile?> pickCropCompress({
  required ImageSource source,
  required CropAspectRatioPreset aspect,
}) async {
  final picked = await ImagePicker().pickImage(source: source, imageQuality: 92);
  if (picked == null) return null;
  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatioPresets: [aspect],
    uiSettings: [
      AndroidUiSettings(
        toolbarColor: const Color(0xFF0F172A),
        toolbarWidgetColor: Colors.white,
        statusBarColor: const Color(0xFF0F172A),
      ),
      IOSUiSettings(title: 'CROP'),
    ],
  );
  if (cropped == null) return null;
  final compressed = await FlutterImageCompress.compressAndGetFile(
    cropped.path,
    '${cropped.path}_c.jpg',
    quality: 78,
    minWidth: 1080,
  );
  return compressed;
}
```

Use for: avatar (1:1), company logo (1:1), portfolio (4:3), verification doc (free).

---

## 5 · Cross-Cutting Polish (apply once, benefits every screen)

### 5.1 Page transitions
Replace default GoRouter `MaterialPage` transitions with `animations` package per route group:
- **Tab swaps** (within home_shell): `FadeThroughTransition`.
- **Push to detail** (job → job_detail, conversation → thread): `SharedAxisTransition(transitionType: SharedAxisTransitionType.horizontal)`.
- **Modal full-screen** (post job, profile edit): `SharedAxisTransition.vertical`.

Override in `lib/app/router.dart` via `CustomTransitionPage`.

### 5.2 Accessibility
Current state: 16 `Semantics()` widgets total, **zero** `Tooltip()`. CLAUDE.md mentions `aria-labels` for icon-only buttons but no equivalent enforcement in Flutter.

Fix:
- Every `IconButton` with no visible label → wrap with `Semantics(label: 'DESCRIPTION', button: true)` or add `tooltip:`.
- Audit candidates: `job_detail_page:97` (back), all `home_shell` nav icons (already labelled by route name), filter-clear X in `jobs_page`, sheet-drag handles.
- Add `Semantics(header: true)` around `PageHeader` titles.
- `flutter test` `accessibility_test.dart` using `meetsGuideline(textContrastGuideline)`.

### 5.3 Reduced motion
None of the upgraded animations check `MediaQuery.of(context).disableAnimations`. Add to `JStaggeredList`, `flutter_animate` calls, Lottie loops. One-line wrap:

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;
return reduceMotion ? child : child.animate().fadeIn();
```

### 5.4 Haptics
On filter chip selection, list-item press, slidable action confirm: `HapticFeedback.selectionClick()` / `.lightImpact()`. Aggressive tradie persona benefits from physical feedback. Zero cost.

### 5.5 Caching
Confirm `CachedNetworkImage` used in `JobCard`, `TradieCard`, `AvatarBlock`, `PortfolioStrip`, `MessageThreadPage`. Grep currently shows no `CachedNetworkImage` usage in features (declared in pubspec). Likely raw `Image.network` — replace.

### 5.6 Status bar / nav bar styling
In `main.dart` or `app_theme.dart` ensure:
```dart
SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  systemNavigationBarColor: c.background,
  systemNavigationBarIconBrightness: Brightness.light,
));
```
Currently inconsistent across screens (some use `SystemUiOverlayStyle.light` per page).

---

## 6 · Prioritized Roadmap

Each item is sized so a single PR can land it.

### Sprint UI-1 — "Loading & motion baseline" (P1, ~2 days)
1. Create `JSkeletonList` (recipe 4.1) and adopt in `jobs_page`, `applications_page`, `messages_page`, `profile_page`, `home_page` job list, `verification_page`.
2. Create `JStaggeredList` (recipe 4.2) and apply to the same five list screens.
3. Adopt `LinearPercentIndicator` in `profile_completeness_banner.dart` and `portfolio_strip.dart` upload progress.
4. Pre-commit: validate.sh stays green (no new design anti-patterns).

### Sprint UI-2 — "Empty & success states" (P1, ~2 days)
1. Commission / source 5 Lottie files in `assets/lottie/`.
2. Extend `EmptyState` widget per recipe 4.3.
3. Wire into `jobs_page`, `applications_page`, `messages_page`, `notifications_page`, `reviews_page`.
4. Add success-check Lottie overlay to `job_detail_page` apply and `register_page` verify-email.

### Sprint UI-3 — "Bottom sheets & swipe actions" (P1, ~1.5 days)
1. Add `JBottomSheet` helper (recipe 4.4) and migrate 5 call-sites.
2. Add `flutter_slidable` to `JobCard`, conversation rows, application rows. Slide actions per role spec in §3.4.
3. Update CLAUDE.md UI/UX conventions: "Use `showJSheet` from `j_bottom_sheet.dart`, never `showModalBottomSheet` directly."

### Sprint UI-4 — "Forms" (P1, ~3 days)
1. Migrate `login_page`, `register_page`, `forgot_password_page`, `job_create_page`, `profile_edit_page` to `flutter_form_builder`. One form per PR.
2. Build `JFormField` wrappers that bake in MASTER.md's `InputDecoration`.

### Sprint UI-5 — "Image pipeline & photo viewer" (P2, ~1.5 days)
1. `ImageUploadService` (recipe 4.7) — pick → crop → compress.
2. `photo_view` integration in `portfolio_strip` (gallery), `verification_page` (single), `message_thread_page` (single).
3. Migrate raw `Image.network` → `CachedNetworkImage` everywhere (cross-cutting 5.5).

### Sprint UI-6 — "Pagination & charts" (P2, ~2 days)
1. `infinite_scroll_pagination` adoption in jobs, applications, messages, notifications.
2. Earnings / activity surface for builders + tradies using `fl_chart` (depends on having the data — likely later).

### Sprint UI-7 — "Polish" (P3, ~2 days)
1. `animations` package: route transitions per §5.1.
2. Accessibility pass: Semantics + Tooltip + reduce-motion guards.
3. Haptics on filter chip / slidable confirm / FTUE next.
4. Status bar consistency.

---

## 7 · CLAUDE.md Patch Suggestions

Sync the guidance doc with the reality of the codebase before the next agent runs. Suggested edits to `CLAUDE.md`:

```diff
-- **Icons**: use `Iconsax.*` by default; fall back to `Icons.*` only for Material-specific cases.
++ **Icons**: use `AppIcons.*` from `lib/core/theme/app_icons.dart` (backed by `phosphor_flutter`). Bold = inactive/outline, Fill = active/selected. Nav pairs are `(outline:, filled:)` records.
```

```diff
-- **Bottom sheets**: use `modal_bottom_sheet` (not Flutter's built-in) for consistent iOS-style sheets.
++ **Bottom sheets**: use `showJSheet` from `lib/core/design/widgets/j_bottom_sheet.dart`. Never call `showModalBottomSheet` directly.
```

Add new bullets:
```diff
++ **Loading**: use `JSkeletonList` from `lib/core/design/widgets/`. Never raw `CircularProgressIndicator` for list content.
++ **List entry**: wrap any list of 5+ items in `JStaggeredList` — 200ms fade-slide is the house pattern.
++ **Forms**: every form uses `FormBuilder` + `FormBuilderTextField` (theme defaults via `JFormField`). No raw `TextFormField` in feature code.
++ **Image upload**: pipe `image_picker` through `ImageUploadService.pickCropCompress(...)` before sending to Supabase storage.
```

---

## 8 · What to Remove from pubspec (if you don't adopt)

Only if the team decides a package won't ship within 2 sprints, delete it to keep the dependency footprint honest. Otherwise keep but track adoption via this doc.

Candidate removals if **not** adopting:
- `fl_chart` — no analytics surface scoped yet
- `image_cropper` + `flutter_image_compress` — only matters once verification + portfolio upload UX is finalised
- `flutter_rating_bar` — only matters when reviews ships

Keep regardless (used in roadmap above):
- `flutter_animate`, `flutter_staggered_animations`, `skeletonizer`, `shimmer`, `lottie`, `infinite_scroll_pagination`, `flutter_slidable`, `badges`, `percent_indicator`, `expandable`, `modal_bottom_sheet`, `flutter_form_builder`, `photo_view`, `cached_network_image`.

---

## 9 · How to verify after each sprint

Add to `scripts/validate.sh` (already grep-based):
- Fail if `CircularProgressIndicator` appears in a list context (i.e., outside `j_skeleton_list.dart`, `pinput`, full-screen overlay).
- Fail if `showModalBottomSheet(` appears outside `j_bottom_sheet.dart`.
- Fail if `Image.network(` appears in `lib/features/` (force `CachedNetworkImage`).
- Fail if `TextFormField(` appears outside `lib/core/widgets/inputs/`.
- Fail if `Iconsax.` appears anywhere (catalogue is the only icon source).

This makes the modernization sticky — each upgrade gets enforced going forward.

---

## 10 · Appendix — File-by-File Heatmap

| Screen | Lines | Loading | Empty | List motion | Form pattern | Modal | Verdict |
|---|---|---|---|---|---|---|---|
| `splash_page` | 161 | Spinner | n/a | n/a | n/a | n/a | ✏️ Lottie loader |
| `login_page` | 389 | Inline | n/a | n/a | Raw TFF | n/a | ✏️ FormBuilder + animate CTA |
| `register_page` | 830 | Inline | n/a | n/a | Raw TFF | Built-in | ⚠️ Heavy — biggest form ROI |
| `forgot_password_page` | 188 | — | n/a | n/a | Raw TFF | n/a | ✏️ Lottie success |
| `phone_auth_page` | 600 | — | n/a | n/a | Pinput ✓ | Built-in | ✏️ JBottomSheet for country |
| `verify_email_page` | 268 | — | n/a | n/a | n/a | n/a | ✏️ Lottie success |
| `ftue_page` | 251 | n/a | n/a | n/a | n/a | n/a | ✓ Mostly fine |
| `home_shell_page` | 161 | n/a | n/a | n/a | n/a | n/a | ⚠️ Inconsistent Iconsax usage |
| `home_page` | 1,421 | Spinner | None | None | n/a | Built-in | ⚠️ Biggest screen, biggest upgrade |
| `jobs_page` | 305 | Spinner | None | None | n/a | n/a | ⚠️ Top P1 |
| `job_detail_page` | 539 | n/a | n/a | n/a | n/a | Built-in | ✏️ Expandable + Lottie apply |
| `job_create_page` | 425 | n/a | n/a | n/a | Raw TFF | n/a | ⚠️ Top form ROI |
| `applications_page` | 498 | Spinner | None | None | n/a | n/a | ⚠️ Top P1 |
| `messages_page` | 409 | Linear bar | None | None | n/a | n/a | ⚠️ Top P1 |
| `message_thread_page` | 348 | — | n/a | None | Raw TFF | n/a | ✏️ PhotoView + typing |
| `profile_page` | 671 | Spinner | n/a | n/a | n/a | n/a | ✏️ Skeleton + PhotoView |
| `profile_edit_page` | 550 | Snackbar | n/a | n/a | Raw TFF | Built-in | ⚠️ Top form ROI |
| `verification_page` | 243 | — | n/a | n/a | n/a | n/a | ✏️ PhotoView docs |
| `reviews_page` | 14 | n/a | n/a | n/a | n/a | n/a | 🚧 Stub |
| `notifications_page` | 15 | n/a | n/a | n/a | n/a | n/a | 🚧 Stub |
| `legal_document_page` | 91 | Spinner | n/a | n/a | n/a | n/a | ✏️ Expandable sections |
| `legal_index_page` | 190 | — | n/a | n/a | n/a | n/a | ✓ Fine |
| `logo_compare_page` | 437 | — | n/a | n/a | n/a | n/a | (dev tool) |

Legend: ✓ fine · ✏️ targeted improvement · ⚠️ multiple P1s · 🚧 needs build-out.

---

*Run `python3 .claude/skills/ui-ux-pro-max/scripts/search.py "<topic>" --stack flutter` against this doc to fetch the latest stack guidelines whenever you start a sprint.*
