import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/core/design/widgets/map/j_basemap.dart';

// Regression suite for the 2026-08-30 basemap swap.
//
// The bug: all three map surfaces pointed at CARTO's `basemaps.cartocdn.com`
// raster tiles, believing them free and key-less. CARTO now stamps every
// unauthenticated tile with a diagonal "API KEY REQUIRED —
// carto.com/basemaps/apikey" watermark, so the builder home's "Find tradies
// near your site" card shipped a map that read as broken.
//
// These tests lock in the two halves of the fix: tiles come from MapTiler with
// the key the app already carries, and a build WITHOUT that key degrades to the
// genuinely key-less OpenStreetMap raster rather than to something watermarked.

/// dotenv is a global singleton; `loadFromString` calls `clean()` first, so
/// each helper fully replaces the previous env.
void _withKey([String key = 'test-maptiler-key']) =>
    dotenv.loadFromString(envString: 'MAPTILER_API_KEY=$key');

void _withoutKey() => dotenv.loadFromString(envString: 'SOME_OTHER_VAR=1');

void main() {
  tearDownAll(dotenv.clean);

  group('with a MapTiler key', () {
    setUp(_withKey);

    test('keyed styles resolve to MapTiler tiles carrying the key', () {
      final url = JBasemap.quiet.urlTemplate;

      expect(url, startsWith('https://api.maptiler.com/maps/dataviz/'));
      expect(url, contains('key=test-maptiler-key'));
      expect(JBasemap.quiet.servedByMapTiler, isTrue);
    });

    test('template keeps flutter_map placeholders, including retina {r}', () {
      final url = JBasemap.streets.urlTemplate;

      // Without these the layer requests a literal "{z}/{x}/{y}" path; without
      // {r} a high-density screen silently loses the @2x tiles.
      expect(url, contains('{z}/{x}/{y}{r}.png'));
    });

    test('every style is offered in the picker', () {
      expect(JBasemap.available, equals(JBasemap.values));
    });

    test(
      'the house default is the muted style so orange pins stay loudest',
      () {
        expect(JBasemap.fallback, JBasemap.quiet);
      },
    );

    test('the key-less OSM style stays selectable and stays unkeyed', () {
      expect(
        JBasemap.standard.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      );
      expect(JBasemap.standard.servedByMapTiler, isFalse);
      // OSM's raster pyramid stops at z19 — past that the layer must upscale,
      // not request tiles that 404.
      expect(JBasemap.standard.maxNativeZoom, 19);
    });
  });

  group('without a MapTiler key', () {
    setUp(_withoutKey);

    test('every style degrades to the key-less OpenStreetMap raster', () {
      for (final basemap in JBasemap.values) {
        expect(
          basemap.urlTemplate,
          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          reason: '${basemap.name} must not request tiles it cannot authorise',
        );
        expect(basemap.servedByMapTiler, isFalse);
      }
    });

    test('the picker offers only the style this build can honestly serve', () {
      expect(JBasemap.available, [JBasemap.standard]);
      expect(JBasemap.fallback, JBasemap.standard);
    });
  });

  group('resolve()', () {
    setUp(_withKey);

    test('round-trips a saved style', () {
      expect(JBasemap.resolve(JBasemap.night.name), JBasemap.night);
    });

    test('rescues preferences saved under the retired Carto style names', () {
      // Anyone who used the jobs map before this change has 'voyager', 'dark'
      // or 'light' in SharedPreferences under `home.map_style`. Those enum
      // values no longer exist and must not strand the map on a dead style.
      for (final retired in ['voyager', 'dark', 'light']) {
        expect(JBasemap.resolve(retired), JBasemap.fallback);
      }
    });

    test('a null preference (first run) lands on the default', () {
      expect(JBasemap.resolve(null), JBasemap.fallback);
    });

    test('a keyed preference on a keyless build falls back to OSM', () {
      _withoutKey();
      expect(JBasemap.resolve(JBasemap.streets.name), JBasemap.standard);
    });
  });

  test('no style can ever point back at CARTO', () {
    // The whole point of the fix. Checked in both key states because the bug
    // was a URL constant, and a constant does not care whether a key is set.
    for (final loadEnv in [_withKey, _withoutKey]) {
      loadEnv();
      for (final basemap in JBasemap.values) {
        expect(
          basemap.urlTemplate,
          isNot(contains('cartocdn')),
          reason: 'CARTO watermarks unauthenticated tiles "API KEY REQUIRED"',
        );
      }
    }
  });
}
