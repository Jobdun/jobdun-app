import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profiles select does not request email (canonical in auth.users)', () {
    final src = File(
      'lib/features/profile/data/datasources/profile_remote_datasource.dart',
    ).readAsStringSync();
    expect(
      RegExp(r"\bemail\b").hasMatch(
        RegExp(r"\.from\('profiles'\)[\s\S]*?\.select\(\s*'([^']*)'")
            .firstMatch(src)!.group(1)!,
      ),
      isFalse,
      reason: 'profiles .select() must not request email — it lives in auth.users',
    );
  });
}
