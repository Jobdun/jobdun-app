import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/design/widgets/job_card.dart';

import '_harness.dart';

void main() {
  group('JobCard goldens (light)', () {
    testWidgets('standard + urgent, as drawn on Find', (tester) async {
      await pumpGolden(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const JobCard(
              title: '3-phase switchboard install',
              description:
                  'Install new 3-phase switchboard for commercial site. '
                  'Mains upgrade from the street, after-hours access.',
              rate: r'$110/hr',
              startDate: 'Sydney, NSW',
              distanceKm: 0,
              isUrgent: false,
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: const JobCard(
                title: '3-phase switchboard install',
                description:
                    'Install new 3-phase switchboard for commercial site. '
                    'Mains upgrade from the street, after-hours access.',
                rate: r'$110/hr',
                startDate: 'Sydney, NSW',
                distanceKm: 4.2,
                isUrgent: true,
              ),
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/job_card_feed.png'),
      );
    });
  });
}
