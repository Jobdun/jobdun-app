import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../pages/discovery_map_data.dart';
import '../providers/discovery_provider.dart';

/// Small, non-interactive map card on the builder home. Plots nearby tradie
/// pins around the builder's area; tapping opens the full-screen
/// [DiscoveryMapPage] (route `/discovery/map`). Self-sources from
/// `tradeSearchControllerProvider` so the bento just drops it in.
class TradeMapPreview extends ConsumerWidget {
  const TradeMapPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
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
      label: 'Find a tradie on the map, ${pins.length} nearby',
      child: Material(
        color: c.card,
        clipBehavior: Clip.antiAlias,
        // `shape` carries both the radius and the border side. Do NOT also pass
        // `borderRadius` — Material asserts they're mutually exclusive
        // (!(shape != null && borderRadius != null)).
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/discovery/map');
          },
          child: AspectRatio(
            aspectRatio: 2.1,
            child: offline
                ? const _OfflinePreview()
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // The map itself is non-interactive — the card owns the tap.
                      IgnorePointer(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: center,
                            initialZoom: 10.5,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: DiscoveryMapData.cartoVoyagerUrl,
                              subdomains: DiscoveryMapData.cartoSubdomains,
                              retinaMode: RetinaMode.isHighDensity(context),
                              userAgentPackageName: 'au.com.jobdun.app',
                            ),
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
                      ),
                      // Label pill (top-left) + open affordance (top-right).
                      Positioned(
                        top: 10.h,
                        left: 10.w,
                        child: _PreviewPill(
                          label: pins.isEmpty
                              ? 'FIND A TRADIE'
                              : '${pins.length} NEARBY',
                        ),
                      ),
                      Positioned(
                        bottom: 10.h,
                        right: 10.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: c.action,
                            borderRadius: BorderRadius.circular(
                              AppRadius.chip.r,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'OPEN MAP',
                                style: tt.labelMedium!.copyWith(
                                  color: c.onAction,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Gap(4.w),
                              Icon(
                                AppIcons.chevronRight,
                                size: AppIconSize.inline.r,
                                color: c.onAction,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Small frosted-free label pill over the map — solid card fill for legibility
// against any tile (MASTER: no blur, flat).
class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.location, size: AppIconSize.inline.r, color: c.action),
          Gap(6.w),
          Text(
            label,
            style: tt.labelMedium!.copyWith(color: c.text1, letterSpacing: 0.5),
          ),
        ],
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
    final tt = Theme.of(context).textTheme;
    return Container(
      color: c.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.wifiOff, size: AppIconSize.feature.r, color: c.warning),
          Gap(8.h),
          Text(
            'MAP NEEDS A CONNECTION',
            style: tt.labelMedium!.copyWith(color: c.text1, letterSpacing: 0.5),
          ),
          Gap(2.h),
          Text(
            'Connect to see tradies near you',
            style: tt.bodySmall!.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}
