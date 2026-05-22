import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';
import 'maptiler_places_service.dart';
import 'places_service.dart';

/// HTTP client used by [placesServiceProvider]. Public + override-friendly so
/// widget/unit tests can swap in a `MockClient` via
/// `ProviderScope(overrides: [placesHttpClientProvider.overrideWithValue(...)])`.
final placesHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Top-level public per CLAUDE.md → Engineering Standards → "Repo / data-source
/// providers MUST be top-level public". Reads [AppEnv.maptilerApiKey] at build
/// time — an absent/empty key is non-fatal: the service throws
/// [PlacesNotConfigured] on first call, and [JPlaceField] surfaces the legacy
/// 3-field fallback toggle.
final placesServiceProvider = Provider<PlacesService>((ref) {
  return MapTilerPlacesService(
    apiKey: AppEnv.maptilerApiKey,
    httpClient: ref.watch(placesHttpClientProvider),
  );
});
