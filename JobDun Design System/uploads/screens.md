# GALVANISED — Screen Inventory
**Australian Tradie Marketplace · v1.0**

This file defines the layout structure and key rules for every screen in the app. Read before designing or building any screen.

---

## Screen Layout Template

Every screen follows this top-to-bottom structure:

```
[Status bar — system, adapts to light/dark]
[Screen content — 20px horizontal padding always]
[Bottom nav — 62px, 4 tabs]
```

Screen horizontal padding: **20px** — no exceptions.

---

## Stage 1 Screens

### 1. Builder Home Feed
**Purpose:** Find available tradies quickly by location  
**Primary CTA:** Post a Job (FAB or header button)

```
Status bar
─────────────────────────────────
[Eyebrow: "Builder"]
[Display heading: "FIND A TRADIE"]
[Location: ↓ Fitzroy, VIC — action colour]     [Notif icon]
─────────────────────────────────
[Search bar: "Search trades or skills..."]
─────────────────────────────────
[Filter chips: All · Electrician · Plumber · Carpenter]
─────────────────────────────────
[Section row: "Nearby" + "4 available now" in verified green]
─────────────────────────────────
[Tradie card] ← available (full opacity)
[Tradie card] ← available (full opacity)
[Tradie card] ← offline (opacity 0.45, no distance highlight)
─────────────────────────────────
Bottom nav (Home active)
```

**Rules:**
- Available tradies always shown before offline
- Offline cards never show the verified strip
- Distance always in action colour
- No FAB on this screen — "Post a Job" is in the top-right if needed

---

### 2. Tradie Discovery / Map View
**Purpose:** GPS view of nearby tradies  
**Primary CTA:** Tap a pin → opens tradie card sheet

```
Status bar
─────────────────────────────────
Full-screen map (Mapbox or Google Maps)
[Filter chips overlay — top, 20px inset]
[Back / search button — top left]
─────────────────────────────────
[Bottom sheet — tradie card]
  Peeks at 120px
  Expands to 60% on pin tap
─────────────────────────────────
Bottom nav (visible below sheet at rest)
```

**Rules:**
- Map pins: foundation colour for available, grey for offline
- Active selected pin: action colour, slightly larger
- Cluster pins: foundation colour + count badge

---

### 3. Tradie Profile
**Purpose:** Full profile — ratings, verification, availability, history  
**Primary CTA:** Invite to Job

```
Status bar
─────────────────────────────────
[Back arrow]                     [Share icon]
─────────────────────────────────
[Large avatar: 72px, 12px radius]
[Name — H1]
[Trade type + location — label, text-2]
[Rating large: stat size] [Job count]
─────────────────────────────────
[Verification strip]
  Licence ✓  |  Insurance ✓  |  ID ✓
  (Grey if not verified)
─────────────────────────────────
[Availability badge] [Distance]
─────────────────────────────────
[Section: About]
[Bio text]
─────────────────────────────────
[Section: Reviews]
[Review cards ×3, "See all →"]
─────────────────────────────────
[Invite to Job — Primary button, full width, sticky bottom]
─────────────────────────────────
Bottom nav
```

**Rules:**
- Verification strip must be first content below the header — not buried
- Unverified items shown greyed out — never hidden
- Sticky CTA button: sits above bottom nav with 16px gap and card shadow

---

### 4. Post a Job
**Purpose:** Builder creates a job posting  
**Primary CTA:** Post Job

```
Status bar
─────────────────────────────────
[Back arrow]
[H1: "POST A JOB"]
─────────────────────────────────
[Form fields — 20px padding]
  Trade type (picker)
  Job title (text input)
  Description (multiline)
  Location (with GPS autofill)
  Start date (date picker)
  Rate type: Fixed / Hourly (segment)
  Rate amount (number input)
  Urgent toggle
─────────────────────────────────
[Post Job — Primary button, full width, sticky bottom]
```

**Rules:**
- Urgent toggle: when ON, show red accent on the toggle + "Tradies will be alerted immediately" copy
- No progress bar — one flat form, not a wizard (keep it simple for builders on site)
- Keyboard avoidance: form scrolls, sticky button stays above keyboard

---

### 5. Job Feed (Tradie view)
**Purpose:** Tradie browses available jobs  
**Primary CTA:** Accept Job (on detail screen)

```
Status bar
─────────────────────────────────
[Eyebrow: "Tradie"]
[Display heading: "JOBS NEARBY"]
[Location — action colour]         [Filter icon]
─────────────────────────────────
[Filter chips: All · Urgent · Today · This week]
─────────────────────────────────
[Job card — urgent, red bar top]
[Job card — standard]
[Job card — standard]
─────────────────────────────────
Bottom nav (Jobs active)
```

**Rules:**
- Urgent jobs always pinned to top regardless of distance
- Job card distance in action colour
- "Urgent" badge shown on card — never just implied by position

---

### 6. Job Detail (Tradie view)
**Purpose:** Full job info before accepting  
**Primary CTA:** Accept Job

```
Status bar
─────────────────────────────────
[Back arrow]
[Urgent bar — full width, if urgent]
[Urgent badge — if urgent]
[H1: Job title — Barlow Condensed 700]
[Posted by + company logo row]
─────────────────────────────────
[Job meta grid: Rate · Start · Duration · Distance]
─────────────────────────────────
[Section: Description]
[Full description text]
─────────────────────────────────
[Section: Location]
[Map snippet — tappable → opens maps]
[Address text]
─────────────────────────────────
[Section: Builder]
[Builder card — mini (name, rating, jobs)]
─────────────────────────────────
[Accept Job — Action button] [Decline — Ghost button]
Sticky bottom, 20px padding
─────────────────────────────────
Bottom nav
```

---

### 7. In-App Chat
**Purpose:** Direct messaging between builder and tradie  
**Primary CTA:** Send message

```
Status bar
─────────────────────────────────
[Back arrow] [Name + trade type] [Call button]
─────────────────────────────────
[Message list — scrollable]
  Sent bubbles: foundation colour, right-aligned
  Received bubbles: surf colour, left-aligned
  Timestamps: caption, text-3, centred on day change
─────────────────────────────────
[Input bar — sticky]
  [Attachment icon] [Text input] [Send button: action colour]
─────────────────────────────────
(No bottom nav on chat — full screen)
```

**Rules:**
- Sent message bubble: foundation colour bg, white text
- Received bubble: surf bg, text-1 text
- No read receipts in MVP — adds complexity without tradie buy-in

---

### 8. Availability Calendar (Tradie)
**Purpose:** Tradie manages when they're available  
**Primary CTA:** Save (implicit — toggle days)

```
Status bar
─────────────────────────────────
[Back arrow]
[H1: "AVAILABILITY"]
─────────────────────────────────
[Month navigator: ← May 2026 →]
─────────────────────────────────
[Calendar grid — 7 col]
  Available day: verified green bg
  Booked day:    action orange bg
  Today:         border highlight
  Past:          text-3, not tappable
─────────────────────────────────
[Legend: ● Available  ● Booked]
─────────────────────────────────
Bottom nav (Profile active)
```

---

### 9. Tradie Earnings Dashboard
**Purpose:** Tradie views income overview  
**Primary CTA:** View timesheets

```
Status bar
─────────────────────────────────
[H1: "EARNINGS"]
─────────────────────────────────
[Period tabs: Week · Month · All time]
─────────────────────────────────
[Large stat: total earnings — Barlow Condensed 700, action colour]
─────────────────────────────────
[Stat row: Jobs done · Hours worked · Avg rate]
─────────────────────────────────
[Section: Recent jobs]
[Job rows — title, date, amount]
─────────────────────────────────
Bottom nav
```

---

### 10. Admin Dashboard
**Purpose:** Internal — manage users, jobs, verifications  
**Audience:** Admin staff, not tradies or builders

Admin screens are separate from the tradie/builder app. They live in a web portal, not the mobile app. Design scope TBD in Stage 2.

---

## Navigation Structure

```
Bottom Nav (4 tabs):
├── Home      → Builder: Find Tradie feed
│              → Tradie: Jobs Nearby feed
├── Jobs      → Builder: Posted jobs list
│              → Tradie: Accepted jobs list
├── Chat      → Conversation list
└── Profile   → User profile, settings, availability
```

The app detects user type at login and renders the appropriate Home and Jobs screens. Navigation structure is identical — content differs.

---

## Gesture Rules

| Gesture          | Action                              |
|------------------|-------------------------------------|
| Swipe down sheet | Dismiss bottom sheet                |
| Swipe left card  | Decline (reveal red decline button) |
| Long press card  | Share profile link                  |
| Pull to refresh  | Refresh feed                        |
| Swipe back       | Navigate back (standard iOS/Android)|

No custom gestures beyond these. Keep it predictable.
