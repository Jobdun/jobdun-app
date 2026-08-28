import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/services/ftue_analytics.dart';
import '../../data/geo_service.dart';
import '../providers/ftue_geo_provider.dart';
import '../widgets/ftue_overlay_card.dart';
import '../widgets/ftue_slide.dart';

/// Slide 2 — the wow moment. Reads [ftueGeoProvider], swaps in the user's city
/// when the IP lookup lands on an AU result, and drops the matched suburb
/// cluster onto the map as pins. Every failure path (timeout, non-AU, network,
/// parse, missing city) falls back to generic copy, so the user never sees the
/// seam.
class SlideTwoSpeed extends ConsumerWidget {
  const SlideTwoSpeed({
    super.key,
    required this.controller,
    required this.slideCount,
  });

  static const heroAsset = 'assets/images/ftue/slide_2_nearby.webp';

  final PageController controller;
  final int slideCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoAsync = ref.watch(ftueGeoProvider);

    return geoAsync.when(
      // Loading and error land on the same generic content — we never hold the
      // carousel waiting on the network, and never surface an error for what
      // is only a personalisation nicety.
      loading: () =>
          _SlideTwoContent.generic(controller: controller, count: slideCount),
      error: (_, _) =>
          _SlideTwoContent.generic(controller: controller, count: slideCount),
      data: (geo) {
        if (geo == null || geo.city == null) {
          // AU but city missing, or non-AU — generic copy, but still use the
          // geo-derived cluster when there is one so AU-without-city users at
          // least see real local names on the pins.
          return _SlideTwoContent.generic(
            controller: controller,
            count: slideCount,
            suburbs: geo?.suburbs ?? GeoService.nearbySuburbsFor(null),
          );
        }
        return _SlideTwoContent.personalised(
          controller: controller,
          count: slideCount,
          city: geo.displayCity,
          rawCity: geo.city,
          suburbs: geo.suburbs,
        );
      },
    );
  }
}

class _SlideTwoContent extends StatefulWidget {
  const _SlideTwoContent.generic({
    required this.controller,
    required this.count,
    List<String>? suburbs,
  }) : isPersonalised = false,
       city = null,
       rawCity = null,
       suburbs = suburbs ?? _genericSuburbs;

  const _SlideTwoContent.personalised({
    required this.controller,
    required this.count,
    required this.city,
    required this.rawCity,
    required this.suburbs,
  }) : isPersonalised = true;

  static const _genericSuburbs = ['Parramatta', 'Liverpool', 'Penrith'];

  /// Where each pin sits on the hero, as a fraction of the Figma 393x567 frame
  /// (nodes 60:168, 60:157, 60:174). Scattered, not stacked, so the cluster
  /// reads as "a map" rather than "a list".
  ///
  /// The two right-hand pins are anchored from the right edge (the mock's left
  /// 249 / 220 with a 109-wide card lands 35 / 64 in from the right). These
  /// carry live suburb names of unknown length, so they have to grow inwards.
  static const _pinSpots = [
    (left: null, right: 35 / 393, top: 69 / 567),
    (left: 36 / 393, right: null, top: 199 / 567),
    (left: null, right: 64 / 393, top: 312 / 567),
  ];

  final PageController controller;
  final int count;
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
    // Boss-facing event — % of users who get the personalised branch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FtueAnalytics.slideTwoRendered(
        variant: widget.isPersonalised ? 'personalised' : 'generic',
        city: widget.rawCity,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Cap at three so the layout stays predictable if the cluster map grows.
    final visible = widget.suburbs.take(_SlideTwoContent._pinSpots.length);

    return FtueSlide(
      assetPath: SlideTwoSpeed.heroAsset,
      slideIndex: 1,
      semanticLabel: 'A Jobdun user browsing nearby jobs on her phone',
      lead: widget.isPersonalised ? 'JOBS IN' : 'JOBS NEAR YOU.',
      accent: widget.isPersonalised
          ? '${widget.city}.'
          : 'APPLY IN THREE TAPS.',
      controller: widget.controller,
      slideCount: widget.count,
      overlays: [
        for (final (i, suburb) in visible.indexed)
          FtueOverlay(
            left: _SlideTwoContent._pinSpots[i].left,
            right: _SlideTwoContent._pinSpots[i].right,
            top: _SlideTwoContent._pinSpots[i].top,
            child: FtueOverlayCard.pin(
              label: suburb,
              icon: AppIcons.locationFilled,
            ),
          ),
      ],
    );
  }
}
