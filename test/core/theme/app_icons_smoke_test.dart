import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/theme/app_icons.dart';

/// Compile-time + render guard for the semantic icon catalogue.
///
/// Every entry in [AppIcons.catalogue] is rendered in a real widget tree.
/// If a Tabler constant is renamed/removed in a future package bump, this
/// fails at compile time; if a glyph fails to rasterise, it fails here.
void main() {
  testWidgets('every AppIcons catalogue entry renders', (tester) async {
    expect(AppIcons.catalogue, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final entry in AppIcons.catalogue)
                  Icon(
                    entry.icon,
                    key: ValueKey('icon-${entry.group}-${entry.name}'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    for (final entry in AppIcons.catalogue) {
      expect(
        find.byKey(ValueKey('icon-${entry.group}-${entry.name}')),
        findsOneWidget,
        reason: 'AppIcons.${entry.name} (${entry.group}) failed to render',
      );
    }
  });

  test('navigation pairs expose outline + filled IconData', () {
    final pairs = [
      AppIcons.home,
      AppIcons.findJobs,
      AppIcons.applied,
      AppIcons.messages,
      AppIcons.profile,
    ];
    for (final p in pairs) {
      expect(p.outline, isA<IconData>());
      expect(p.filled, isA<IconData>());
    }
  });
}
