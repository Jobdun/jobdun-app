import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/home/presentation/widgets/deck_strip.dart';

import '_harness.dart';

void main() {
  testWidgets('tradie stats deck golden (light)', (tester) async {
    await pumpGolden(
      tester,
      const DeckStrip(
        cells: [
          (value: '9', label: 'Applied'),
          (value: '2', label: 'Shortlist'),
          (value: '—', label: 'Rating'),
        ],
      ),
    );
    await expectLater(
      find.byType(DeckStrip),
      matchesGoldenFile('goldens/home_deck_strip.png'),
    );
  });
}
