import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../config/env.dart';

/// The raster basemap behind every `flutter_map` surface in the app — the
/// builder's "Find tradies near your site" promo card, the full-screen tradie
/// map, and the trades-side jobs map all read from here, so one swap moves all
/// three at once.
///
/// **Why this file exists.** Until 2026-08-30 all three maps pointed straight
/// at CARTO's `basemaps.cartocdn.com` raster tiles on the belief they were
/// free and key-less. CARTO has since started stamping every unauthenticated
/// tile with a diagonal **"API KEY REQUIRED — carto.com/basemaps/apikey"**
/// watermark, so the builder home shipped a map that read, correctly, as
/// broken. `docs/archive/MAP_USAGE_AUDIT.md` called this exact risk back in
/// 2026-06 ("Carto's free basemaps are non-commercial … pick a paid tier
/// before public launch"); this is that swap, forced.
///
/// The replacement is MapTiler, whose key the app **already carries** for
/// address autocomplete (`MAPTILER_API_KEY` — see [AppEnv]): one key, two
/// services, and a licence that actually permits commercial use.
///
/// When that key is absent — CI, a fresh checkout, `flutter test` — every
/// style collapses to [JBasemap.standard], the OpenStreetMap raster, which is
/// genuinely key-less and renders clean. **A basemap is never allowed to fail
/// closed**: a watermarked or blank map is worse than a plainer one.
enum JBasemap {
  /// Desaturated ground, real water and parks. The default: it is the only
  /// style with no orange in it, so safety-orange pins (`c.action`) are the
  /// loudest thing on screen — which is the whole job of these maps.
  quiet(
    label: 'QUIET',
    description: 'Muted ground — orange pins pop',
    maptilerStyle: 'dataviz',
  ),

  /// Full-colour road map with route shields and street names. For when the
  /// user is reading the map as a map ("how do I get to that site?").
  streets(
    label: 'STREETS',
    description: 'Full colour, road names',
    maptilerStyle: 'streets-v2',
  ),

  /// Dark peer of [streets] for low light and the dark theme.
  night(
    label: 'NIGHT',
    description: 'Dark view for low light',
    maptilerStyle: 'streets-v2-dark',
  ),

  /// Classic OpenStreetMap raster. Key-less, so this is both a user choice and
  /// the automatic fallback for any build without a MapTiler key.
  standard(
    label: 'STANDARD',
    description: 'Classic OpenStreetMap',
    maptilerStyle: null,
  );

  const JBasemap({
    required this.label,
    required this.description,
    required this.maptilerStyle,
  });

  /// All-caps name shown in the style picker (MASTER: all-caps controls).
  final String label;

  /// One-line "what this looks like" for the picker row.
  final String description;

  /// MapTiler style id, or `null` for the key-less OpenStreetMap raster.
  final String? maptilerStyle;

  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// `{r}` is flutter_map's retina placeholder — it becomes `@2x` on a
  /// high-density screen and empty otherwise. MapTiler serves both.
  static const String _maptilerUrl =
      'https://api.maptiler.com/maps/%s/{z}/{x}/{y}{r}.png?key=%k';

  /// True when this style needs a MapTiler key this build may not have.
  bool get needsKey => maptilerStyle != null;

  /// Styles this build can actually render. Without a key there is exactly one
  /// honest option, so the picker shows one row rather than three that would
  /// all silently render the same OSM tiles.
  static List<JBasemap> get available =>
      AppEnv.hasMaptilerApiKey ? values : const [standard];

  /// What a surface starts on, and what a removed/unavailable saved preference
  /// falls back to.
  static JBasemap get fallback => AppEnv.hasMaptilerApiKey ? quiet : standard;

  /// Re-hydrate a persisted [name]. Unknown values (a style we deleted) and
  /// keyed styles on a keyless build both land on [fallback].
  static JBasemap resolve(String? name) {
    if (name == null) return fallback;
    for (final basemap in available) {
      if (basemap.name == name) return basemap;
    }
    return fallback;
  }

  /// Tile URL template for this style, already carrying the key.
  ///
  /// Defensive on the key a second time: [available] should have filtered a
  /// keyed style out of a keyless build, but a stale saved preference or a new
  /// call site must degrade to OSM rather than fire requests that 403.
  String get urlTemplate {
    final style = maptilerStyle;
    if (style == null || !AppEnv.hasMaptilerApiKey) return _osmUrl;
    return _maptilerUrl
        .replaceFirst('%s', style)
        .replaceFirst('%k', AppEnv.maptilerApiKey);
  }

  /// True when the rendered tiles came from MapTiler — drives whether the
  /// attribution has to credit them alongside OpenStreetMap.
  bool get servedByMapTiler =>
      maptilerStyle != null && AppEnv.hasMaptilerApiKey;

  /// OSM's raster pyramid stops at z19; MapTiler's goes further. Past this the
  /// layer upscales the last real tile instead of requesting a 404.
  int get maxNativeZoom => servedByMapTiler ? 22 : 19;
}

/// The tile layer for [basemap]. Drop it in as the first child of a
/// `FlutterMap` — `MapCamera` resolves through this wrapper because
/// `FlutterMap` renders its children inside the camera's inherited scope.
///
/// Keyed on the style so flutter_map drops the old tile cache when the user
/// switches — otherwise tiles from both styles flash together during the swap.
class JBasemapLayer extends StatelessWidget {
  const JBasemapLayer({super.key, this.basemap});

  /// Defaults to [JBasemap.fallback] — the non-interactive surfaces (the home
  /// promo card, the tradie map) offer no style picker and just want the
  /// house look.
  final JBasemap? basemap;

  @override
  Widget build(BuildContext context) {
    final map = basemap ?? JBasemap.fallback;
    return TileLayer(
      key: ValueKey<JBasemap>(map),
      urlTemplate: map.urlTemplate,
      maxNativeZoom: map.maxNativeZoom,
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'au.com.jobdun.app',
    );
  }
}
