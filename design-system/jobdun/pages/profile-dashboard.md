# Profile / Dashboard Page Overrides

> **PROJECT:** Jobdun
> **Updated:** 2026-05-07
> **Page Type:** Profile View + Earnings Dashboard

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).

---

## Design Intent

Profile is credibility. Dashboard is status. Both should communicate competence fast — not through decoration, but through clear data hierarchy. A trades worker's profile should feel like a résumé that actually gets read.

---

## Layout

**Trades Profile:**
```
[ Avatar | Name (Display Bold) | Trade type chip ]
[ Verification badges row                        ]
[ Stats row: Jobs done | Avg rating | Hrs worked ]
[ Bio (expandable if >2 lines)                   ]
[ Skills chips                                   ]
[ Reviews section                                ]
[ Portfolio images (grid)                        ]
```

**Builder Profile:**
```
[ Company logo | Company name | Industry chip    ]
[ Verified badge                                 ]
[ Stats row: Active jobs | Hires | Member since  ]
[ About company (expandable)                     ]
[ Active jobs list                               ]
[ Review from trades workers                     ]
```

**Earnings Dashboard (Trades only):**
```
[ Period selector: Week / Month / Year           ]
[ Total earnings — large Display text            ]
[ BarChart — earnings by period (fl_chart)       ]
[ Jobs list for selected period                  ]
```

---

## Color Overrides

Dashboard chart colors:
- Bar fill: `#F97316` (primary) or `#64748B` (comparison/secondary)
- Grid lines: `#334155`
- Axis labels: `#94A3B8`
- Selected bar: `#F97316` with white value label on top

---

## Component Overrides

### Avatar
- Size: 72dp circle for feed, 96dp for own profile
- Border: 2dp `#F97316` if verified, `#334155` if not
- Fallback: initials on `#1E293B` background, Inter Bold

### Verification Badges
- Row of small chips: "ID VERIFIED", "LICENSED", "INSURED", "BACKGROUND CHECK"
- Verified chip: `#22C55E` border, green text — `#1E293B` background
- Missing/pending chip: `#334155` border, `#64748B` text
- Size: 28dp height, 8dp horizontal padding, 4dp border radius

### Stats Row
- 3 equal columns, dividers between them (`#334155`, 1dp)
- Number: Inter Black (900), 22sp, `#F1F5F9`
- Label: Inter SemiBold (600), 11sp, `#94A3B8`, all caps, letter-spacing 0.5
- Background: `#1E293B` card

### Rating Display
- `flutter_rating_bar`, star color `#F97316`, empty `#334155`
- Show numeric average bold next to stars: "4.8" in `#F1F5F9`, 16sp Bold
- Review count: `(24 reviews)` in `#94A3B8`, 13sp

### Earnings Total
- Inter Black (900), 36sp, `#F1F5F9`
- Period label above: "THIS MONTH" — `#94A3B8`, 11sp, SemiBold, all caps
- Change indicator: `+12%` in green or `-5%` in red, 14sp SemiBold

### Skills Chips
- Same style as filter chips but non-interactive (no active state)
- Background `#334155`, text `#94A3B8`, 12sp SemiBold
- Wrap layout (not scroll)

### Edit Profile Button
- Positioned top-right on own profile
- `#334155` fill, `Iconsax.edit` icon + "EDIT" text, 36dp height
- No ghost/outline version

### CTA for incomplete profile (Trades)
- Single banner card at top with orange left border (4dp)
- Text: "YOUR PROFILE IS INCOMPLETE." — 14sp Bold, white
- Sub: specific missing item only ("Add your license to get more jobs.")
- CTA button: "ADD NOW" — orange, inline right

---

## Animations

- Stats numbers: count-up animation on screen enter (`flutter_animate`, 600ms)
- BarChart: bars grow from bottom on load (`fl_chart` animation)
- Avatar: no animation
- Skeleton: `skeletonizer` — matches actual layout

---

## What to Avoid

- ❌ Progress rings/percentages for "profile completion" — just show missing items directly
- ❌ Congratulatory copy when profile is complete ("Your profile is looking great!")
- ❌ Charts without axis labels or data values
- ❌ Earnings hidden or deprioritized — it's the primary motivation for trades workers
- ❌ Decorative background patterns or textures
- ❌ Tab bars with more than 3 tabs on profile
