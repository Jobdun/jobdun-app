import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('admin typography uses the website Archivo and Inter pairing', () {
    expect(AdminText.display(Colors.white).fontFamily, startsWith('Archivo'));
    expect(AdminText.pageTitle(Colors.white).fontFamily, startsWith('Archivo'));
    expect(
      AdminText.sectionTitle(Colors.white).fontFamily,
      startsWith('Archivo'),
    );
    expect(AdminText.label(Colors.white).fontFamily, startsWith('Archivo'));

    expect(AdminText.body(Colors.white).fontFamily, startsWith('Inter'));
    expect(AdminText.bodyStrong(Colors.white).fontFamily, startsWith('Inter'));
    expect(AdminText.value(Colors.white).fontFamily, startsWith('Inter'));
    expect(AdminText.meta(Colors.white).fontFamily, startsWith('Inter'));
  });
}
