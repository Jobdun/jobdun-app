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
- `OPEN` → `#22C55E` (green)
- `IN PROGRESS` → `#F97316` (orange)
- `ASSIGNED` → `#94A3B8` (secondary text)
- `COMPLETED` → `#334155` (muted)
- `CANCELLED` → `#EF4444` (red)

---

## Component Overrides

### Search Bar
- Background: `#1E293B`, full-width, 48dp height
- Icon: `Iconsax.search_normal` left-side, `#64748B`
- Text: `#F1F5F9`, 14sp
- Clear button: `Iconsax.close_circle` right-side, only visible when text exists
- No search button — real-time filtering

### Filter Chips
- Horizontal scroll row, no wrap, `#1E293B` background
- Chip: 32dp height, 12dp horizontal padding, 4dp border radius
- Inactive: background `#1E293B`, border `#334155`, text `#94A3B8`, 12sp SemiBold
- Active: background `#F97316`, no border, text white, 12sp Bold
- No "All" chip — absence of filter = all results

### Job Card
```
[ Trade icon | Job title (Bold 16sp) | Status chip ]
[ Company name + location (Secondary 13sp)         ]
[ Pay rate | Trade type | Posted X ago             ]
[ APPLY NOW button — right-aligned, 36dp height    ]
```
- Background: `#1E293B`
- Border: `#334155`, 1dp
- Border radius: 8dp
- No heavy shadow — border only
- Swipeable via `flutter_slidable`: left = Save, right = Hide
- `APPLY NOW` button: 36dp height, orange fill, "APPLY NOW" all-caps Bold 12sp
- Tap card = detail view

### Pay Rate Display
- Bold `#F1F5F9`, 16sp — most prominent data point on the card
- Format: `$45/hr` or `$2,400 flat` — no filler words
- If range: `$40–$55/hr`

### Empty State (no results)
- Lottie animation (construction/search themed)
- Headline: "NO JOBS FOUND." — Display weight, white
- Body: "Try adjusting your filters." — 14sp, `#94A3B8`
- CTA: "CLEAR FILTERS" — filled slate button

### FAB (Builder only — post a job)
- `#F97316` background, `Iconsax.add` white icon, 56dp
- Bottom-right, 16dp from edges
- No label on FAB

---

## Animations

- Card list: `AnimationLimiter + AnimationConfiguration` (staggered, 50ms delay per card)
- Filter chip selection: 150ms fill transition
- Skeleton loading: `skeletonizer` on `#1E293B` base
- Pull-to-refresh: standard Flutter `RefreshIndicator`, indicator color `#F97316`

---

## What to Avoid

- ❌ Map view as default — list is primary, map is an option
- ❌ Cards with large hero images — jobs are data, not lifestyle content
- ❌ "No jobs found" with just text — always pair with Lottie + CTA
- ❌ Auto-playing anything on the feed
- ❌ Pagination with numbered pages — infinite scroll only
- ❌ Filters hidden behind a hamburger or nested menu — filters must be visible
