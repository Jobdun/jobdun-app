import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/services/home_analytics.dart';
import 'package:jobdun/core/services/profile_analytics.dart';

void main() {
  test('T2 analytics emit the contracted events + props', () {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);

    HomeAnalytics.cardTapped(jobId: 'job-123');
    HomeAnalytics.refresh();
    ProfileAnalytics.sectionTapped(section: 'portfolio');

    expect(
      logs.any((l) => l.contains('home.card_tapped') && l.contains('job-123')),
      isTrue,
    );
    expect(logs.any((l) => l.contains('home.refresh')), isTrue);
    expect(
      logs.any(
        (l) => l.contains('profile.section_tapped') && l.contains('portfolio'),
      ),
      isTrue,
    );
  });
}
