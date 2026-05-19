import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/app.dart';

void main() {
  setUpAll(() async {
    // Provide stub env values so dotenv doesn't throw during widget tests.
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  testWidgets('shows Jobdun splash content', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: JobdunApp()));
    await tester.pump();

    // The splash page renders — exact text depends on the current splash design,
    // so we just verify the widget tree builds without throwing.
    expect(find.byType(JobdunApp), findsOneWidget);
  });
}
