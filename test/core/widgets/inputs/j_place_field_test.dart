import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/services/places_service.dart';
import 'package:jobdun/core/services/places_service_provider.dart';
import 'package:jobdun/core/widgets/inputs/j_place_field.dart';
import 'package:latlong2/latlong.dart';

/// Hand-rolled fake — mocktail wants too much boilerplate for an interface
/// with two methods.
class _FakePlacesService implements PlacesService {
  _FakePlacesService({
    this.autocompleteResults = const [],
    this.autocompleteError,
    this.reverseResult,
  });

  List<JPlaceResult> autocompleteResults;
  PlacesException? autocompleteError;
  JPlaceResult? reverseResult;

  int autocompleteCalls = 0;
  String? lastQuery;

  @override
  Future<List<JPlaceResult>> autocomplete(String query, {LatLng? near}) async {
    autocompleteCalls++;
    lastQuery = query;
    if (autocompleteError != null) throw autocompleteError!;
    return autocompleteResults;
  }

  @override
  Future<JPlaceResult?> reverseGeocode(LatLng position) async => reverseResult;
}

JPlaceResult _result({
  String suburb = 'Parramatta',
  String state = 'NSW',
  String postcode = '2150',
}) {
  return JPlaceResult(
    placeId: 'place.$suburb',
    formattedAddress: '$suburb, $state $postcode, Australia',
    suburb: suburb,
    state: state,
    postcode: postcode,
    latitude: -33.8,
    longitude: 151.0,
    mainText: suburb,
    secondaryText: '$state $postcode, Australia',
  );
}

Widget _wrap(
  Widget child, {
  _FakePlacesService? service,
}) {
  return ProviderScope(
    overrides: [
      placesServiceProvider.overrideWithValue(service ?? _FakePlacesService()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: FormBuilder(
            key: GlobalKey<FormBuilderState>(),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the label and the input box', (tester) async {
    await tester.pumpWidget(
      _wrap(const JPlaceField(name: 'place', label: 'BASE LOCATION')),
    );
    await tester.pumpAndSettle();

    expect(find.text('BASE LOCATION'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('does not call autocomplete below 3-char threshold',
      (tester) async {
    final svc = _FakePlacesService();
    await tester.pumpWidget(
      _wrap(
        const JPlaceField(name: 'place', label: 'LOC'),
        service: svc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'pa');
    // Wait past the 250 ms debounce
    await tester.pump(const Duration(milliseconds: 400));

    expect(svc.autocompleteCalls, 0);
  });

  testWidgets('debounces and calls autocomplete with the typed query',
      (tester) async {
    final svc = _FakePlacesService(autocompleteResults: [_result()]);
    await tester.pumpWidget(
      _wrap(
        const JPlaceField(name: 'place', label: 'LOC'),
        service: svc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'parra');
    // Debounce window
    await tester.pump(const Duration(milliseconds: 100));
    expect(svc.autocompleteCalls, 0);
    // After debounce
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(svc.autocompleteCalls, 1);
    expect(svc.lastQuery, 'parra');
    expect(find.text('Parramatta'), findsWidgets);
    expect(find.text('NSW 2150, Australia'), findsOneWidget);
  });

  testWidgets('tapping a suggestion fills the input and clears the dropdown',
      (tester) async {
    final svc = _FakePlacesService(autocompleteResults: [_result()]);
    await tester.pumpWidget(
      _wrap(
        const JPlaceField(name: 'place', label: 'LOC'),
        service: svc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'parra');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final tile = find.text('Parramatta').last;
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // The TextField now shows the full formatted address.
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(
      textField.controller!.text,
      'Parramatta, NSW 2150, Australia',
    );
    // Dropdown is gone — the secondary line is no longer in the tree.
    expect(find.text('NSW 2150, Australia'), findsNothing);
  });

  testWidgets('renders the "Use my current location" chip', (tester) async {
    final svc = _FakePlacesService(autocompleteResults: [_result()]);
    await tester.pumpWidget(
      _wrap(
        const JPlaceField(name: 'place', label: 'LOC'),
        service: svc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'par');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('USE MY CURRENT LOCATION'), findsOneWidget);
  });

  testWidgets('surfaces error banner when service throws', (tester) async {
    final svc = _FakePlacesService(
      autocompleteError: const PlacesNetworkError('Offline.'),
    );
    await tester.pumpWidget(
      _wrap(
        const JPlaceField(name: 'place', label: 'LOC'),
        service: svc,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'parra');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Offline.'), findsOneWidget);
  });
}
