# Post-a-Job Form — Audit (RATE placeholder + form state)

_Audited 2026-06-04 · scope: `/jobs/create` (full-screen "NEW LISTING / Post a Job")_

## TL;DR

The **RATE amount field's `$` sign never shows when the field is empty.** It's
set via `prefixText: '$ '`, and Flutter only reveals `prefixText` (and `prefix`,
`suffixText`, `suffix`) **once the field is focused or has text**. The `/hr`
label on the right is a `suffixIcon`, which is **always** visible. So the two
sides are asymmetric:

- **Resting / empty:** `[  85  ················  /hr ]`  ← no `$`; the grey "85"
  reads like a pre-filled amount, not a placeholder.
- **Focused / typing:** `[ $ 1|  ··············  /hr ]`  ← the `$` pops in from
  the left and the "85" hint disappears.

That pop-in + the missing `$` at rest is the "placeholder issue" you're seeing.

**Why it survived the last fix:** commit `52d189f` ("clean up Post-a-Job form —
dup location label, RATE grouping, spacing") regrouped the `RATE` label over the
type chips + amount and fixed spacing. It never touched how the `$` is rendered,
so the prefix-visibility bug was untouched.

## Evidence

| What | Where |
|------|-------|
| RATE amount field (`prefixText: '$ '`, `hint: '85'`, `suffixIcon: /hr`) | `lib/features/jobs/presentation/pages/job_create_page.dart:320`–`354` |
| Shared input decoration (maps `prefixText`/`suffixIcon` onto `InputDecoration`) | `lib/core/widgets/inputs/j_text_field.dart:188`–`200` |
| Theme hint/affix styling (`hintStyle` + `prefixIconColor`/`suffixIconColor` = `text3`) | `lib/app/theme/app_theme.dart:224`–`235` |

## The mechanism (Flutter `InputDecoration`)

Two different visibility rules are in play in the same field:

- `prefixIcon` / `suffixIcon` → **always visible.** Accept any `Widget`.
  `/hr` is passed as `suffixIcon`, so it's always on screen.
- `prefixText` / `prefix` / `suffixText` / `suffix` → **only shown when the
  field is focused or non-empty** (they're wrapped in an opacity animation that
  is transparent at rest so the hint can render from the edge). `$ ` is passed
  as `prefixText`, so it's hidden until you interact.

Mixing an always-on suffix (`/hr`) with a hide-at-rest prefix (`$ `) is what
makes the field look lopsided and the placeholder look like a value.

Secondary nit: even once `$` does appear, it inherits `hintStyle`/`text3` (grey)
while the typed number is `text1` (bright) — so the `$` stays dim relative to
the amount. Minor, but worth aligning when we touch this.

## Recommended fix

Render `$` through an **always-visible** slot so it mirrors the `/hr` suffix.
Flutter's `prefixIcon` is always shown and accepts any widget — but `JTextField`
currently only exposes `prefixIcon` as an `IconData` (it wraps it in `Icon(...)`),
so there's no slot for a `$` text today.

- **Option A — recommended.** Add an always-visible leading-widget slot to
  `JTextField` that maps to `InputDecoration.prefixIcon` (e.g. `Widget? prefix`),
  and pass `prefix: Text('\$')` on the rate field. Symmetric with how `/hr` is
  already passed via `suffixIcon`, reusable for any future currency input.
  Small (~10 lines) change to one shared widget. **Trade-off:** `JTextField` is
  used across many forms, so the change must be additive/optional (no behaviour
  change for existing callers).
- **Option B — local only.** Keep `prefixText` but force the affix to stay
  visible. Hacky in Flutter (requires a floating-always label or a custom
  decorator) — not recommended; fights the framework.
- **Option C — rejected.** Bake `$` into the hint (`hint: '$85'`). It vanishes
  the moment the user types, so the field still has no persistent `$`.

## Rest of the form — quick scan

| Item | Status |
|------|--------|
| Duplicate `LOCATION` label | ✅ **Fixed.** Both branches render a single label — `JPlaceField` owns its `LOCATION` label (places on), `FieldLabel('LOCATION')` once (legacy off). `job_location_field.dart:40`,`58` |
| RATE regrouped under one `RATE` label (chips + amount as one unit) | ✅ Done. `job_create_page.dart:312`–`318` |
| Job title / Description fields (label + hint + reserved error slot) | ✅ Consistent; no placeholder issue |
| Trade picker / Urgent toggle | ✅ Custom `FormBuilderField`s, no affix involved |
| RATE `$` prefix asymmetry | ❌ **Open — this audit's finding** |

## Suggested next step

Apply **Option A**: add an optional always-visible `prefix` widget to
`JTextField`, pass `$` through it on the rate field, and align the `$` colour
with the amount. One shared-widget change + one line on the form. Confirm and
I'll implement.
