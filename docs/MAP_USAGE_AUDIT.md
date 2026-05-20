# Map Usage Audit — Jobdun (Flutter)

**Date:** 2026-05-20
**Branch:** `feat/ui-updates`
**Scope:** Every place the app touches a map renderer or map SDK.
**Outcome:** Migrate from `google_maps_flutter` (Google Maps SDK, keyed, commercial) → `flutter_map` (open-source) + **Carto** raster basemap tiles served from OpenStreetMap data.

---

## 0. Executive Summary

Maps in Jobdun are used in **one screen only** — the tradie's jobs feed has a list/map toggle (`HomePage` → `_MapView`) that pins each job's lat/lng on a Sydney-centred Google Map. That single widget pulls in the entire Google Maps SDK on Android + iOS, a manifest API key on Android, `GMSServices.provideAPIKey(...)` on iOS, and a `MAPS_API_KEY` plumbing chain through `--dart-define` / Gradle / Info.plist.

For a workforce app:
- **We don't need turn-by-turn, Street View, traffic, indoor maps, or any of the things Google charges for.** We need: tiles + markers + tap.
- **We don't want a billed Maps API key as a launch blocker.** Releasing the app currently requires a Google Cloud project with the Maps SDK enabled, billing attached, and the key restricted per-platform. That's friction for a pre-revenue product.
- **The map view is the cheapest thing in our SDK budget to swap.** Two functions, one widget, ~50 lines of replacement code.

The migration target is `flutter_map` (the de-facto OSS Flutter map widget) with **Carto Dark Matter** (`dark_all`) tiles, which match Jobdun's dark-slate (`#0F172A`) design system out of the box.

> **Commercial-use note (read before shipping):** Carto's free basemaps service is intended for non-commercial / low-volume use. For a production commercial app, the right long-term posture is either a Carto paid plan, or moving the tile source to a paid provider (Stadia, MapTiler, Mapbox Raster, or self-host via OpenMapTiles). This swap unblocks development and dev/preview builds — pick a paid tier before the public launch. Tracked in the "Open questions" section below.

---

## 1. Where maps are used today

### 1.1 Flutter code

| File | Lines | What it does |
|------|-------|--------------|
| `lib/features/home/presentation/pages/home_page.dart` | L6 | `import 'package:google_maps_flutter/google_maps_flutter.dart';` |
| `lib/features/home/presentation/pages/home_page.dart` | L34 | `enum _ViewMode { list, map }` — toggles list ↔ map for tradies |
| `lib/features/home/presentation/pages/home_page.dart` | L155–158 | Filters `jobsState.jobs` to those with lat/lng before feeding the map |
| `lib/features/home/presentation/pages/home_page.dart` | L162–176 | FAB that flips `_viewMode` — uses `Iconsax.map` / `Iconsax.element_4` |
| `lib/features/home/presentation/pages/home_page.dart` | L177–184 | Renders `_MapView` when `_viewMode == _ViewMode.map` |
| `lib/features/home/presentation/pages/home_page.dart` | L601–650 | `_MapView` widget — wraps `GoogleMap`, builds `Set<Marker>`, holds `GoogleMapController` |

No other feature folder imports `google_maps_flutter`. `Job.latitude` / `Job.longitude` in `lib/features/jobs/domain/entities/job.dart` are pure `double?` fields and are renderer-agnostic.

### 1.2 Android native plumbing

| File | Lines | What it does |
|------|-------|--------------|
| `android/app/build.gradle.kts` | L31–34 | `manifestPlaceholders["MAPS_API_KEY"] = project.findProperty("MAPS_API_KEY") as String? ?: ""` |
| `android/app/src/main/AndroidManifest.xml` | L38–41 | `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${MAPS_API_KEY}" />` |

### 1.3 iOS native plumbing

| File | Lines | What it does |
|------|-------|--------------|
| `ios/Runner/AppDelegate.swift` | L2 | `import GoogleMaps` |
| `ios/Runner/AppDelegate.swift` | L11–13 | `GMSServices.provideAPIKey(Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? "")` |
| `ios/Podfile` | L2 | Comment: `# Minimum iOS 14.0 required by google_maps_flutter_ios` (constraint reason goes away) |

### 1.4 Tests, CI, docs

- **Tests:** No `test/**` file references `GoogleMap`, `LatLng`, `Marker`, or `MAPS_API_KEY`.
- **CI:** `GOOGLE_WEB_CLIENT_ID` / `GOOGLE_IOS_CLIENT_ID` in CLAUDE.md refer to Google **Sign-In**, not Maps. No GitHub Actions secret for `MAPS_API_KEY` exists today — the workflow assumes empty value.
- **Docs:** `CLAUDE.md` lists `google_maps_flutter` only implicitly in the "pinned versions" warning. No design system / page override under `design-system/jobdun/pages/` documents the map screen.

---

## 2. What we're swapping in

### 2.1 Packages (pubspec.yaml)

```yaml
# === Maps ===
# OpenStreetMap data via the flutter_map renderer + Carto raster basemap tiles.
# No API key required for development. See docs/MAP_USAGE_AUDIT.md before
# enabling on production — Carto's free tier is non-commercial.
flutter_map: ^7.0.2
latlong2: ^0.9.1
```

Remove:
```yaml
google_maps_flutter: ^2.9.0
```

### 2.2 Tile source

**Provider:** Carto basemaps (data © OpenStreetMap contributors).
**Style:** `dark_all` (a.k.a. "Dark Matter") — matches our `#0F172A` background.

URL template (with sub-domain rotation):
```
https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png
subdomains: a, b, c, d
```

Other Carto styles worth knowing about if the design ever needs them: `light_all` (Positron), `voyager`, `rastertiles/voyager_labels_under`. We can swap by changing one URL.

### 2.3 Required attribution (legally non-negotiable)

The OSM + Carto tile licence requires a visible attribution string. flutter_map provides `RichAttributionWidget` for this:

```
© OpenStreetMap contributors   © CARTO
```

Both links open in the browser via `url_launcher` (already in our dependency stack).

### 2.4 Replacement widget shape

```dart
FlutterMap(
  options: const MapOptions(
    initialCenter: LatLng(-33.8688, 151.2093), // Sydney
    initialZoom: 11,
    interactionOptions: InteractionOptions(
      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    ),
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'com.example.jobdun',
    ),
    MarkerLayer(markers: _buildMarkers()),
    RichAttributionWidget(
      attributions: [
        TextSourceAttribution('OpenStreetMap contributors', onTap: ...),
        TextSourceAttribution('CARTO', onTap: ...),
      ],
    ),
  ],
)
```

Markers become plain Flutter widgets — we draw our own pin (orange `Iconsax.location5` on a dark circle) instead of relying on the Google InfoWindow popup. Tap handler stays the same (`onJobTap(job)`).

---

## 3. Native plumbing changes

### 3.1 Android

- `android/app/build.gradle.kts` — drop the `manifestPlaceholders["MAPS_API_KEY"] = ...` line and the explanatory comment.
- `android/app/src/main/AndroidManifest.xml` — drop the `<meta-data android:name="com.google.android.geo.API_KEY" ... />` element and the surrounding comment.
- No new permissions required — `INTERNET` is already declared (needed for any tile renderer).

### 3.2 iOS

- `ios/Runner/AppDelegate.swift` — remove `import GoogleMaps` and the `GMSServices.provideAPIKey(...)` line.
- `ios/Podfile` — update the comment on line 2 (`# Minimum iOS 14.0 required by google_maps_flutter_ios`). flutter_map supports iOS 12+, so we keep `platform :ios, '14.0'` but rephrase the reason (we still want iOS 14 for Supabase / Swift concurrency).
- No Info.plist changes — we never added a `GMSApiKey` key there.

### 3.3 CI / env

- `--dart-define=MAPS_API_KEY=...` becomes a no-op. Safe to leave in old scripts; nothing reads it after the swap.
- No new secret needed for Carto tiles.

---

## 4. Risk register

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Carto rate-limits / blocks the app under load. | Medium (long-term), Low (dev). | Pick a paid tier (Carto, Stadia, MapTiler) before public launch. URL template is one constant — swap is trivial. |
| Tile renderer looks too "OSM-default" for a dark UI. | Low. | `dark_all` is designed for dark themes and already matches `#0F172A`. |
| Marker tap UX is different (no native InfoWindow). | Low. | Replaced with a custom widget pin that calls `onJobTap` directly — matches our design system. |
| iOS bundle size drops noticeably, but build cache may not reflect immediately. | Low. | Run `flutter clean` once if a stale GoogleMaps framework appears in builds. |
| Removing the `MAPS_API_KEY` plumbing breaks an old build script. | Low. | No `scripts/*.sh` references it. CI workflow doesn't pass it. Safe. |

---

## 5. Open questions to revisit before launch

1. **Production tile provider.** Carto's free basemaps are non-commercial. Pick one of:
   - Carto paid plan (`basemap-services.carto.com` or self-served with a Carto Cloud account).
   - Stadia Maps (`tiles.stadiamaps.com`) — has a free dev tier + paid commercial tiers; supports a dark "Alidade Smooth Dark" style very close to Carto Dark Matter.
   - MapTiler — generous free tier, supports custom styling.
2. **Marker clustering.** Once we have >50 pins on screen the default `MarkerLayer` will choke. Add `flutter_map_marker_cluster` when the dataset crosses that threshold.
3. **My-location dot.** Today the Google `myLocationButtonEnabled` flag is `false`. If product wants a "near me" affordance, we'll layer `geolocator` + a custom `CurrentLocationLayer`.
4. **Vector tiles vs raster.** Raster is fine for now (one screen, low zoom range). If we ever ship offline map support or want a custom paint, vector tiles via `vector_map_tiles` are the upgrade path.

---

## 6. Migration record (this PR)

- ✅ Removed `google_maps_flutter: ^2.9.0` from `pubspec.yaml`.
- ✅ Added `flutter_map: ^7.0.2` and `latlong2: ^0.9.1`.
- ✅ Rewrote `_MapView` in `lib/features/home/presentation/pages/home_page.dart` to use `FlutterMap` + Carto `dark_all` tiles + custom marker pins + `RichAttributionWidget`.
- ✅ Removed `manifestPlaceholders["MAPS_API_KEY"]` from `android/app/build.gradle.kts`.
- ✅ Removed `com.google.android.geo.API_KEY` meta-data from `android/app/src/main/AndroidManifest.xml`.
- ✅ Removed `import GoogleMaps` and `GMSServices.provideAPIKey(...)` from `ios/Runner/AppDelegate.swift`.
- ✅ Updated the platform comment in `ios/Podfile`.
- ✅ `flutter analyze` passes; no test files referenced map types.
