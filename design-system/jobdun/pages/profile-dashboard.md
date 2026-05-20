# Profile / Dashboard Page Overrides

> **PROJECT:** Jobdun
> **Updated:** 2026-05-21
> **Page Type:** Profile View + Profile Edit + Verification (+ future Earnings Dashboard)
> **Companion plan:** `docs/PROFILE_IMPROVEMENT_PLAN.md` — five-sprint roadmap for closing field coverage gaps.

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/jobdun/MASTER.md`).
> When a rule here disagrees with the shipped code, **the code wins** and this doc gets patched in the same PR.

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
- `c.surfaceRaised` fill, `AppIcons.edit` + "EDIT" text, 36dp height
- No ghost/outline version

### Avatar Picker (Sprint P1.1)
- Tap the avatar on `/profile/edit` → `showJSheet` with three rows:
  `TAKE PHOTO` / `PICK FROM GALLERY` / `REMOVE` (`REMOVE` only when an avatar exists, uses `c.urgent` label).
- Routes through `ImageUploadService.pickCropCompress(source, aspect: ImageAspect.square)` — never call `ImagePicker()` directly.
- Hero animation: wrap the avatar on both `/profile` and `/profile/edit` in `Hero(tag: 'avatar:<userId>')` so the picker transitions cleanly.
- While uploading: dim the avatar to 45% with a 20dp `CircularProgressIndicator` overlay (`c.action` colour). The thin overlay is one of the few sanctioned uses of a spinner on this surface — the upload is bounded and modal.

### Rate Range Field (Sprint P3.1, tradies only)
- Two side-by-side `JTextField`s labelled "MIN $/hr" and "MAX $/hr".
- Integer-only via `FilteringTextInputFormatter.digitsOnly` + `FormBuilderValidators.integer` + `min: 0`.
- Cross-field validator on submit: max ≥ min, otherwise show "Max must be ≥ min" under the MAX field.
- Render on `/profile` as `$65–95/hr` (en-dash, no spaces). When equal, render `$80/hr`. When `hourly_rate_visible` is false, render `Rate on request` in `c.text3`.

### Rate Visibility Toggle (Sprint P3.2)
- `JSwitch` row beneath the rate range fields.
- Label: "Show my rate to builders" + helper text "Off = builders see 'Rate on request'".
- Writes to `hourly_rate_visible`. Default true on signup.

### Verification Row Wiring
- Each row is a `_StatusRow` with status icon (`AppIcons.successCircle` verified, `AppIcons.closeCircle` pending) + label + inline CTA.
- Wired rows in priority order:
  1. **Email verified** — automatic, always green for authenticated users.
  2. **Phone** — taps to `/profile/verify-phone` (already shipped).
  3. **Trade licence** (tradies) — taps to `/verification` (already shipped).
  4. **Insurance docs** (builders, deferred to a follow-up) — would need a new `verification_documents.kind` value + admin review queue.

### Postcode Field (Sprint P1.5)
- Appended to the suburb/state row as a third compact field.
- Validator: `RegExp(r'^\d{3,4}$')` — covers ACT (`0200`) and Norfolk Island (`2899`) edge cases, not just `^\d{4}$`.
- Optional — empty is valid. Writes to `service_postcode` / `base_postcode`.

### CTA for incomplete profile (Trades)
- Single banner card at top with orange left border (4dp)
- Text: "YOUR PROFILE IS INCOMPLETE." — 14sp Bold, white
- Sub: specific missing item only ("Add your license to get more jobs.")
- CTA button: "ADD NOW" — orange, inline right

---

## Animations

- Stats numbers: count-up animation on screen enter (`flutter_animate`, 600ms).
- BarChart: bars grow from bottom on load (`fl_chart` animation) — once analytics data lands.
- Avatar: no animation on view; Hero transition into the picker sheet (200ms).
- Skeleton loading: wrap the whole profile body in `JSkeletonList(enabled: profileState.isLoading, child: ...)` — already shipped. Never raw `skeletonizer`.
- List rows (verification status, info rows): no per-item stagger on this page — it's a single profile, not a list. Reserve `JStaggeredList` for genuine list surfaces.
- Profile-completeness banner (on `/home`, not `/profile`): `LinearPercentIndicator` with 600ms animated fill. The "no progress rings on profile" rule still applies *inside* the profile page; the banner is a home-screen affordance.

---

## What to Avoid

- ❌ Progress rings/percentages **inside** the profile page — just show missing items directly. (The completeness banner on `/home` is the exception; it uses `LinearPercentIndicator` deliberately.)
- ❌ Congratulatory copy when profile is complete ("Your profile is looking great!").
- ❌ Charts without axis labels or data values.
- ❌ Earnings hidden or deprioritized — it's the primary motivation for trades workers.
- ❌ Decorative background patterns or textures.
- ❌ Tab bars with more than 3 tabs on profile.
- ❌ Direct `ImagePicker()` calls — every upload routes through `ImageUploadService.pickCropCompress`.
- ❌ Raw `CircularProgressIndicator` in the profile body — use `JSkeletonList`. The avatar-upload overlay is the only sanctioned spinner on this page.
- ❌ Two competing "name" fields without distinct labels — if both `display_name` and `full_name` are shown, the labels must read "Display name (public)" and "Legal name (invoices)" or similar (Sprint P5.3).
