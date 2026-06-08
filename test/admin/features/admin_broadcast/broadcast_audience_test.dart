import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/admin/features/admin_broadcast/domain/entities/broadcast_audience.dart';

void main() {
  group('BroadcastAudience — RPC token + label contract', () {
    test('segment tokens match what admin_broadcast resolves', () {
      // These exact strings are switched on by the SQL RPC (20260609000008):
      // 'all' / 'builders' / 'trades'. A reword here would silently target the
      // wrong segment, so pin them.
      expect(BroadcastAudience.all.value, 'all');
      expect(BroadcastAudience.builders.value, 'builders');
      expect(BroadcastAudience.trades.value, 'trades');
    });

    test(
      'single-user is its own case (its token is the typed id, not value)',
      () {
        // The page sends the typed profile id for this case; `.value` is only a
        // sentinel and must never collide with a segment token.
        expect(BroadcastAudience.singleUser.value, isNot('all'));
        expect(BroadcastAudience.singleUser.value, isNot('builders'));
        expect(BroadcastAudience.singleUser.value, isNot('trades'));
      },
    );

    test('every audience has a non-empty label', () {
      for (final a in BroadcastAudience.values) {
        expect(a.label, isNotEmpty);
      }
    });
  });
}
