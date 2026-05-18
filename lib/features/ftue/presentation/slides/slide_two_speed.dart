import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/ftue_analytics.dart';
import '../../data/geo_service.dart';
import '../providers/ftue_geo_provider.dart';
import '../widgets/ftue_map_hero.dart';
import '../widgets/ftue_slide.dart';

// Slide 2 — the wow moment. Reads ftueGeoProvider, swaps in the user's city
// when the IP lookup hits an AU result, and renders the matched suburb
// cluster as chips below the body. Every failure path (timeout, non-AU,
// network, parse, missing city) drops to a generic copy so the user never
// notices.
class SlideTwoSpeed extends ConsumerWidget {
  const SlideTwoSpeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoAsync = ref.watch(ftueGeoProvider);

    return geoAsync.when(
      // Loading + error fall through to the same generic content — we never
      // hold the carousel waiting on the network, and we never surface an
      // error toast for a personalisation nicety.
      loading: () => const _SlideTwoContent.generic(),
      error: (_, _) => const _SlideTwoContent.generic(),
      data: (geo) {
        if (geo == null || geo.city == null) {
          // AU but city missing, or non-AU — render generic but still use
          // the geo-derived suburb cluster when present so AU-without-city
          // users at least see real local-area names.
          return _SlideTwoContent.generic(
            suburbs: geo?.suburbs ?? GeoService.nearbySuburbsFor(null),
          );
        }
        return _SlideTwoContent.personalised(
          city: geo.displayCity,
          rawCity: geo.city,
          suburbs: geo.suburbs,
        );
      },
    );
  }
}

class _SlideTwoContent extends StatefulWidget {
  const _SlideTwoContent.generic({List<String>? suburbs})
    : isPersonalised = false,
      city = null,
      rawCity = null,
      suburbs = suburbs ?? _genericSuburbs;

  const _SlideTwoContent.personalised({
    required this.city,
    required this.rawCity,
    required this.suburbs,
  }) : isPersonalised = true;

  static const _genericSuburbs = ['Parramatta', 'Liverpool', 'Penrith'];

  final bool isPersonalised;
  final String? city;
  final String? rawCity;
  final List<String> suburbs;

  @override
  State<_SlideTwoContent> createState() => _SlideTwoContentState();
}

class _SlideTwoContentState extends State<_SlideTwoContent> {
  @override
  void initState() {
    super.initState();
    // Boss-facing event — % of users on the personalised branch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FtueAnalytics.slideTwoRendered(
        variant: widget.isPersonalised ? 'personalised' : 'generic',
        city: widget.rawCity,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final headlineLine1 = widget.isPersonalised ? 'JOBS IN' : 'JOBS NEAR YOU.';
    final headlineLine2 = widget.isPersonalised
        ? '${widget.city}.'
        : 'APPLY IN THREE TAPS.';
    final bodyLine1 = widget.isPersonalised
        ? '100+ active jobs'
        : 'Sorted by your suburb.';
    final bodyLine2 = widget.isPersonalised
        ? 'within 15km of you.'
        : 'No scrolling through dud jobs.';

    return FtueSlide(
      visual: const FtueMapHero(),
      headlineLine1: headlineLine1,
      headlineLine2: headlineLine2,
      bodyLine1: bodyLine1,
      bodyLine2: bodyLine2,
      footer: _SuburbChips(suburbs: widget.suburbs),
    );
  }
}

// ── Suburb chip row — the visual half of slide 2 ────────────────────────────
// "Map pins" rendered as labelled chips. Three is the sweet spot — fits a
// 360px viewport without wrapping and reads as "a cluster, not a list".
class _SuburbChips extends StatelessWidget {
  const _SuburbChips({required this.suburbs});

  final List<String> suburbs;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Cap at 3 so layouts stay predictable even if the cluster map grows.
    final visible = suburbs.take(3).toList();

    return Wrap(
      spacing: AppSpacing.sm.w,
      runSpacing: AppSpacing.sm.h,
      children: [
        for (final s in visible)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.chip.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.locationFilled,
                  size: AppIconSize.xs.r,
                  color: c.action,
                ),
                Gap(6.w),
                Text(
                  s,
                  style: tt.labelMedium!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
