import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Structured result of a single place selected by the user. One [JPlaceResult]
/// carries everything we round-trip to the database: human-readable address,
/// canonical AU components (suburb / state / postcode), and the lat/lng pair
/// the home map uses to render the marker.
///
/// Compared to Google Places' two-step suggestion → details flow, MapTiler
/// returns geometry inline in the autocomplete response, so we don't need a
/// separate `JPlaceSuggestion` type — every suggestion the user sees is
/// already a fully-formed [JPlaceResult].
class JPlaceResult extends Equatable {
  const JPlaceResult({
    required this.placeId,
    required this.formattedAddress,
    required this.suburb,
    required this.state,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    required this.mainText,
    required this.secondaryText,
  });

  /// Provider-stable identifier for the place. MapTiler's `feature.id`
  /// (e.g. `"poi.30924224"`). Round-tripped to the DB so a re-save doesn't
  /// require a second autocomplete round-trip.
  final String placeId;

  /// Full human-readable address — what we render once the user has picked.
  /// MapTiler's `feature.place_name` (e.g. "Parramatta, NSW 2150, Australia").
  final String formattedAddress;

  /// AU suburb / locality, title-cased.
  final String suburb;

  /// 2–3 letter AU state abbreviation (NSW, VIC, QLD, WA, SA, TAS, ACT, NT).
  final String state;

  /// 4-digit AU postcode.
  final String postcode;

  /// Latitude of the place centroid. Used for `near you` queries.
  final double latitude;

  /// Longitude of the place centroid.
  final double longitude;

  /// Primary line for the suggestion row — typically just the suburb.
  final String mainText;

  /// Secondary line for the suggestion row — typically `STATE POSTCODE, Australia`.
  final String secondaryText;

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  List<Object?> get props => [
    placeId,
    formattedAddress,
    suburb,
    state,
    postcode,
    latitude,
    longitude,
  ];
}

/// Sealed hierarchy of recoverable errors a [PlacesService] surfaces. Callers
/// switch on the runtime type to render the right UI affordance — only
/// [PlacesNoResults] is a "empty list, not really an error" case; the rest
/// trigger the "Edit manually" fallback toggle on [JPlaceField].
sealed class PlacesException implements Exception {
  const PlacesException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// MAPTILER_API_KEY is missing or empty. Surfaces the legacy 3-field fallback
/// immediately — there's no point retrying.
class PlacesNotConfigured extends PlacesException {
  const PlacesNotConfigured()
    : super(
        'MapTiler API key is not configured. '
        'Set MAPTILER_API_KEY in .env or via --dart-define.',
      );
}

/// HTTP error: timeout, DNS fail, 5xx, etc. Caller should show the fallback
/// toggle but may auto-retry on the next debounced keystroke.
class PlacesNetworkError extends PlacesException {
  const PlacesNetworkError(super.message);
}

/// HTTP 4xx with a body MapTiler returned — quota exhausted, key revoked,
/// bad input. Caller should NOT auto-retry the same query.
class PlacesRequestRejected extends PlacesException {
  const PlacesRequestRejected(super.message, {required this.statusCode});
  final int statusCode;
}

/// Response parsed but contained no usable suggestions for the query. Not
/// strictly an error — the dropdown renders "No matches" copy.
class PlacesNoResults extends PlacesException {
  const PlacesNoResults() : super('No matching places.');
}

/// Response did not match the expected GeoJSON shape. Indicates a vendor
/// change or proxy injection — log and fall back to manual input.
class PlacesMalformedResponse extends PlacesException {
  const PlacesMalformedResponse(super.message);
}

/// Provider-agnostic geocoding interface. The first implementation is
/// [MapTilerPlacesService]; swapping to Google Places / LocationIQ / Photon
/// only replaces the impl class — no call-site changes.
///
/// Every call is AU-restricted at the impl level — callers don't need to
/// pass a country code. Empty/blank queries throw [PlacesNoResults] rather
/// than firing a network request.
abstract class PlacesService {
  /// Up to 5 suggestions for [query]. Biases on [near] when provided
  /// (typically the device's current position, supplied by the caller after
  /// it has already checked permission). Throws on transport errors so the
  /// widget can render the "Edit manually" toggle.
  Future<List<JPlaceResult>> autocomplete(String query, {LatLng? near});

  /// Reverse-geocode a position to its nearest AU address. Used by the
  /// "Use my current location" chip in [JPlaceField]. Returns `null` only
  /// when MapTiler legitimately can't resolve the point (offshore, etc.).
  Future<JPlaceResult?> reverseGeocode(LatLng position);
}
