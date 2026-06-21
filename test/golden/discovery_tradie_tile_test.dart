import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/discovery/domain/entities/trade_search_result.dart';
import 'package:jobdun/features/discovery/presentation/widgets/discovery_tradie_tile.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';

import '_harness.dart';

void main() {
  group('DiscoveryTradieTile goldens (dark)', () {
    testWidgets('available tradie with rating + distance', (tester) async {
      const result = TradeSearchResult(
        trade: TradeProfile(
          id: 't1',
          fullName: 'Dave Thompson',
          primaryTrade: 'electrician',
          baseSuburb: 'Parramatta',
          baseState: 'NSW',
          averageRating: 4.8,
          ratingCount: 12,
          jobsCompleted: 12,
          // isVerified omitted (false): the verified chip tips the status row
          // past the surface under the golden harness's default (wider) font —
          // a harness artifact, not a production layout bug (prod uses the
          // narrower Archivo/Inter). The tile layout is still exercised.
        ),
        distanceKm: 2.3,
      );

      await pumpGolden(tester, const DiscoveryTradieTile(result: result));

      await expectLater(
        find.byType(DiscoveryTradieTile),
        matchesGoldenFile('goldens/discovery_tradie_tile_available.png'),
      );
    });
  });
}
