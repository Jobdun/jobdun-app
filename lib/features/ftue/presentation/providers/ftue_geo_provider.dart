import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ftue_analytics.dart';
import '../../data/geo_service.dart';
import '../../data/models/geo_result.dart';

/// Service singleton — replaced in tests via `overrideWithValue`.
final geoServiceProvider = Provider<GeoService>((ref) => GeoService());

/// Background IP-geo lookup that drives slide 2's personalised copy. The
/// FTUE fires the provider on mount so the network round-trip overlaps with
/// the user reading slide 1; by the time they swipe to slide 2 the data is
/// usually already there.
///
/// autoDispose: the result is dropped the moment the carousel unmounts so
/// no IP-derived state ever leaks past the FTUE scope. Returns `null` for
/// every failure mode (timeout, non-AU, network, parse) — the slide treats
/// null as "show generic copy" and never surfaces an error to the user.
final ftueGeoProvider = FutureProvider.autoDispose<GeoResult?>((ref) async {
  final service = ref.watch(geoServiceProvider);

  FtueAnalytics.geoLookupStarted();
  final outcome = await service.lookup();

  if (outcome.succeeded) {
    final r = outcome.result!;
    FtueAnalytics.geoLookupSucceeded(
      city: r.city,
      region: r.region,
      country: r.country,
      latencyMs: outcome.latencyMs,
    );
    return r;
  }

  FtueAnalytics.geoLookupFailed(
    reason: outcome.failure!.name,
    latencyMs: outcome.latencyMs,
  );
  return null;
});
