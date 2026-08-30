import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/map/j_basemap.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../pages/discovery_map_data.dart';
import '../providers/discovery_provider.dart';

/// The "Find tradies near your site." promo card on the builder home
/// (Figma **Homepage** section, node `134:12872`).
///
/// **The mock draws a static Sydney raster; this renders the live map.** A
/// fixed picture of Surry Hills is wrong for a builder in Perth, and the app
/// already owns a real map — so the card keeps the mock's composition
/// (headline, sub-line and an "Explore map" pill over a legibility scrim) and
/// swaps the raster for `flutter_map` with the builder's actual nearby-tradie
/// pins. Tapping anywhere opens the full [DiscoveryMapPage] (`/discovery/map`).
///
/// Self-sources from `tradeSearchControllerProvider` so the home page just
/// drops it in.
class TradeMapPreview extends ConsumerWidget {
  const TradeMapPreview({super.key});

  /// 361 × 174 in the mock. Kept as a ratio so the card scales with width.
  static const _aspect = 361 / 174;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final results = ref.watch(
      tradeSearchControllerProvider.select((s) => s.results),
    );
    final filter = ref.watch(
      tradeSearchControllerProvider.select((s) => s.filter),
    );
    final pins = DiscoveryMapData.pins(results);
    final center = DiscoveryMapData.center(filter);
    // Offline: tiles can't load — show a clean placeholder instead of a grey
    // map. Still tappable (the full map explains the offline state too).
    final offline = !(ref.watch(isOnlineProvider).asData?.value ?? true);

    return Semantics(
      button: true,
      label: 'Find tradies near your site, ${pins.length} nearby',
      excludeSemantics: true,
      child: Material(
        color: c.card,
        clipBehavior: Clip.antiAlias,
        // `shape` carries both the radius and the border side. Do NOT also pass
        // `borderRadius` — Material asserts they're mutually exclusive
        // (!(shape != null && borderRadius != null)).
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/discovery/map');
          },
          child: AspectRatio(
            aspectRatio: _aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (offline)
                  const _OfflinePreview()
                else
                  _MapCanvas(center: center, pins: pins),
                const _CopyScrim(),
                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: const _PromoCopy(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-interactive tile + pin layer. The card owns the tap.
class _MapCanvas extends StatelessWidget {
  const _MapCanvas({required this.center, required this.pins});

  final LatLng center;
  final List<TradiePin> pins;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 10.5,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          const JBasemapLayer(),
          MarkerLayer(
            markers: [
              for (final pin in pins.take(12))
                Marker(
                  point: pin.point,
                  width: 26,
                  height: 33,
                  alignment: Alignment.bottomCenter,
                  child: SvgPicture.asset(
                    'lib/core/assets/map-pin-jobdun.svg',
                    width: 26,
                    height: 33,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Left-to-right wash that keeps the copy legible over arbitrary map tiles.
///
/// A *functional* gradient, not decoration — MASTER's "no gradients" rule
/// targets ornamental fills, and the FTUE hero already ships the same kind of
/// scrim. Stops are the mock's own (`134:12873`, a 180×204 fill rotated 90°),
/// re-expressed left-to-right across 56.5% of the card and painted in
/// `c.surface` so it follows the theme instead of hard-coding white.
class _CopyScrim extends StatelessWidget {
  const _CopyScrim();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            c.surface,
            c.surface.withValues(alpha: 0.916),
            c.surface.withValues(alpha: 0.7),
            c.surface.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.326, 0.448, 0.565],
        ),
      ),
    );
  }
}

/// Headline, sub-line and the "Explore map" affordance.
class _PromoCopy extends StatelessWidget {
  const _PromoCopy();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Find tradies near\nyour site.',
          style: tt.titleLarge!.copyWith(
            fontSize: 20,
            height: 1.2,
            color: c.text1,
          ),
        ),
        Gap(4.h),
        Text(
          'Connect with verified\ntrades in your area',
          style: tt.bodyMedium!.copyWith(height: 1.4, color: c.text2),
        ),
        Gap(16.h),
        const _ExploreMapPill(),
      ],
    );
  }
}

/// 32dp outlined pill. Purely decorative here — the whole card is the tap
/// target, so this carries no gesture of its own and is hidden from screen
/// readers (the card's own label already says what it does).
class _ExploreMapPill extends StatelessWidget {
  const _ExploreMapPill();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return ExcludeSemantics(
      child: Container(
        height: 32.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        // See JSelectChip — `alignment:` would stretch the pill full-width.
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.btn.r),
          border: Border.all(color: c.action),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Explore map',
              style: tt.labelMedium!.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: c.actionInk,
              ),
            ),
            Gap(4.w),
            Icon(AppIcons.chevronRight, size: 12.r, color: c.actionInk),
          ],
        ),
      ),
    );
  }
}

// Shown in place of the map when offline — tiles can't load, so a grey map
// would read as broken. Caution amber, not error red (MASTER).
class _OfflinePreview extends StatelessWidget {
  const _OfflinePreview();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ColoredBox(
      color: c.surfaceRaised,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(right: 24.w),
          child: Icon(
            AppIcons.wifiOff,
            size: AppIconSize.feature.r,
            color: c.warning,
          ),
        ),
      ),
    );
  }
}
