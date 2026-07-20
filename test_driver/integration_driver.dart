import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Host-side driver for integration_test runs. Screenshots taken with
/// `binding.takeScreenshot(name)` land in docs/verification/ so E2E evidence
/// commits alongside the change (same convention as the Android emulator
/// capture pipeline).
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final file = File('docs/verification/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
