import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/auth/presentation/widgets/auth_sso_row.dart';

import '_harness.dart';

void main() {
  testWidgets('sso tiles are one unified circle set (light)', (tester) async {
    await pumpGolden(
      tester,
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final p in SsoProvider.values) ...[
            AuthSsoTile(provider: p, onTap: () {}, isLoading: false),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
    await expectLater(
      find.byType(Row).first,
      matchesGoldenFile('goldens/auth_sso_tiles.png'),
    );
  });
}
