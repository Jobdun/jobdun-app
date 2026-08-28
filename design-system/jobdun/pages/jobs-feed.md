# Jobs Feed Page Overrides

> **PROJECT:** Jobdun
> **Updated:** 2026-05-07
> **Page Type:** Job Search / Feed

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).

---

## Design Intent

The jobs feed is the core product surface. It should feel like scanning a job board on a construction trailer wall — dense, scannable, no fluff. Every card delivers maximum signal. No breathing room wasted on empty aesthetics.

---

## Layout

```
[ Search bar — full width ]
[ Filter chips — horizontal scroll, no wrap ]
[ Job cards — vertical list, infinite scroll ]
[ FAB — only for Builders: POST JOB ]
```

- No hero banner at the top. Go straight to search + filters.
- No empty welcome card when results exist.
- Infinite scroll via `PagedListView` from `infinite_scroll_pagination`.

---

## Color Overrides

None — dark palette from MASTER applies.

Status color overrides for job cards:
- `OPEN` → `c.verified` (green)
- `IN PROGRESS` → `c.action` (orange)
- `ASSIGNED` → `c.text2` (secondary text)
- `COMPLETED` → `c.border` (muted)
- `CANCELLED` → `c.urgent` (red)

---

## Component Overrides

### Search Bar
- Background: `c.surface`, full-width, 48dp height
- Icon: `AppIcons.search` left-side, `c.text3` (`c.text3` equivalent)
- Text: `c.text1`, 14sp
- Clear button: `AppIcons.closeCircle` right-side, only visible when text exists
- No search button — real-time filtering

### Filter Chips
- Horizontal scroll row, no wrap, `c.surface` background
- Chip: 32dp height, 12dp horizontal padding, 4dp border radius
- Inactive: background `c.surface`, border `c.border`, text `c.text2`, 12sp SemiBold
- Active: background `c.action`, no border, text white, 12sp Bold
- No "All" chip — absence of filter = all results

### Job Card
```
[ Trade icon | Job title (Bold 16sp) | Status chip ]
[ Company name + location (Secondary 13sp)         ]
[ Pay rate | Trade type | Posted X ago             ]
[ APPLY NOW button — right-aligned, 36dp height    ]
```
- Background: `c.surface`
- Border: `c.border`, 1dp
- Border radius: 8dp
- No heavy shadow — border only
- Swipeable via `flutter_slidable` (tradies only — already shipped):
  - **End pane (swipe right→left)** = SAVE / SAVED (toggle, `c.action` bg, `AppIcons.star` or `AppIcons.successCircle`)
  - **Start pane (swipe left→right)** = HIDE (`c.surfaceRaised` bg, `AppIcons.eyeClosed`)
  - Every `SlidableAction.onPressed` calls `HapticFeedback.lightImpact()`.
- `APPLY NOW` button: 36dp height, orange fill, "APPLY NOW" all-caps Bold 12sp
- Tap card = detail view

### Pay Rate Display
- Bold `c.text1`, 16sp — most prominent data point on the card
- Format: `$45/hr` or `$2,400 flat` — no filler words
- If range: `$40–$55/hr`

### Empty State (no results)
- Lottie animation (construction/search themed)
- Headline: "NO JOBS FOUND." — Display weight, white
- Body: "Try adjusting your filters." — 14sp, `c.text2`
- CTA: "CLEAR FILTERS" — filled slate button

### FAB (Builder only — post a job)
- `c.action` background, `AppIcons.add` icon on `c.onAction`, 56dp
- Bottom-right, 16dp from edges
- No label on FAB

---

## Animations

- Card list: `JStaggeredList` wrapper (200ms fade-slide, 16dp vertical offset) — never call `AnimationLimiter`/`AnimationConfiguration` directly.
- Filter chip selection: 150ms fill transition (`GvChip` already handles it) + `HapticFeedback.selectionClick()`.
- Skeleton loading: `JSkeletonList` wrapping placeholder `JobCard`s — already shipped via `_FirstPageSkeleton` in `jobs_page.dart`.
- Pull-to-refresh: `RefreshIndicator` wrapping `PagedListView`, indicator color `c.action`.
- Long-list pagination: `infinite_scroll_pagination` + `PagedListView<int, Job>.separated` driven by the controller-owned `pagingController` (page size 20, prefetch threshold default).

---

## What to Avoid

- ❌ Map view as default — list is primary, map is an option
- ❌ Cards with large hero images — jobs are data, not lifestyle content
- ❌ "No jobs found" with just text — always pair with Lottie + CTA
- ❌ Auto-playing anything on the feed
- ❌ Pagination with numbered pages — infinite scroll only
- ❌ Filters hidden behind a hamburger or nested menu — filters must be visible
