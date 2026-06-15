# Notifications Page Overrides

> **PROJECT:** Jobdun
> **Updated:** 2026-06-12 — written against the shipped implementation
> (`lib/features/notifications/presentation/`), replacing the generated
> boilerplate. Code wins where they disagree.

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file
> (`design-system/jobdun/MASTER.md`). Only deviations from the Master are
> documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout

- **Grouped feed, not flat:** `NEW` (unread) section first, then `EARLIER`
  (read). Sections render only when non-empty. Section eyebrows are
  `labelSmall` all-caps in `text3` (`NotificationSectionHeader`).
- **Row anatomy** (`NotificationTile`): leading 40r category glyph in a
  bordered circle → title + 2-line body → trailing relative timestamp.
  Min row height 64h; touch target ≥ 48dp.

### Unread vs read encoding (never colour alone)

- Unread rows: `surface` fill + 3w `c.action` left strip + w700 title +
  `actionInk` timestamp + `surfaceRaised` glyph circle with `text1` icon.
- Read rows: transparent fill, no strip, w600 title, `text3` timestamp,
  `surface` glyph circle with `text2` icon.
- The strip is the orange exception: it marks actionable/unseen state, which
  is the status-as-urgency case MASTER reserves orange for.

### Category glyphs (AppIcons only)

job → `briefcase` · message → `chat` · application → `appliedOutline` ·
quote → `budget` · verification → `policy` · review → `star` ·
announcement → `info` · fallback → `notification` (bell).
Category derives from the raw `notifications.type` string via
`NotificationCategory.fromType` — never hard-code per-type styling elsewhere.

### Actions

- App bar: `MARK ALL READ` text action in `actionInk`, visible only while
  `unreadCount > 0`. (Documented exception to the filled-buttons rule:
  app-bar text actions follow the `actionInk` ink rule instead.)
- Row tap: optimistic mark-read + deep-link via `resolveNotificationRoute`
  (`lib/core/navigation/notification_routes.dart`). No swipe actions on
  notification rows — they are pointers, not managed objects.

### States

- Loading: `JSkeletonList` over 7 placeholder tiles (content-shaped).
- Empty: bell glyph at `AppIconSize.hero` in a bordered circle + declarative
  copy (`NO NOTIFICATIONS YET`). No Lottie on this surface — the glyph
  treatment matches the house zero-state used since the placeholder era.
- Error: headline + truncated message + filled `RETRY` `JButton`.
- List entry: `JStaggeredList` 200ms fade-slide.

### Bell badge (home header pairing)

- Count badge via the `badges` package: `c.action` fill, `c.onAction` dark
  text (never white-on-orange), caps at `9+`, hidden at zero. Bell icon
  steps `text2 → text1` when unread exist. Semantics label carries the count.
