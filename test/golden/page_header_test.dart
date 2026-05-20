import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/design/widgets/page_header.dart';

import '_harness.dart';

void main() {
  group('PageHeader goldens (dark)', () {
    testWidgets('hero — /home only', (tester) async {
      await pumpGolden(
        tester,
        const PageHeader(
          eyebrow: 'WELCOME BACK',
          title: 'Find a tradie',
          size: PageHeaderSize.hero,
        ),
      );
      await expectLater(
        find.byType(PageHeader),
        matchesGoldenFile('goldens/page_header_hero.png'),
      );
    });

    testWidgets('tab — default tab landing', (tester) async {
      await pumpGolden(
        tester,
        const PageHeader(
          eyebrow: 'POSTED JOBS',
          title: 'Your listings',
        ),
      );
      await expectLater(
        find.byType(PageHeader),
        matchesGoldenFile('goldens/page_header_tab.png'),
      );
    });

    testWidgets('sub — pushed sub-page', (tester) async {
      await pumpGolden(
        tester,
        const PageHeader(
          eyebrow: 'NEW LISTING',
          title: 'Post a job',
          size: PageHeaderSize.sub,
        ),
      );
      await expectLater(
        find.byType(PageHeader),
        matchesGoldenFile('goldens/page_header_sub.png'),
      );
    });

    testWidgets('with trailing widget', (tester) async {
      await pumpGolden(
        tester,
        PageHeader(
          eyebrow: 'POSTED JOBS',
          title: 'Your listings',
          trailing: const Icon(Icons.add, size: 24),
        ),
      );
      await expectLater(
        find.byType(PageHeader),
        matchesGoldenFile('goldens/page_header_trailing.png'),
      );
    });
  });
}
