import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jobdun/app/app.dart';

void main() {
  testWidgets('shows Jobdun splash content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JobdunApp()));

    expect(find.text('Jobdun'), findsOneWidget);
    expect(find.text('Construction workforce platform'), findsOneWidget);
  });
}
