import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/quotes/domain/entities/quote_request.dart';
import 'package:jobdun/features/quotes/presentation/pages/quote_requests_inbox_page.dart';
import 'package:jobdun/features/quotes/presentation/providers/quote_requests_provider.dart';

Widget _wrap(List<QuoteRequest> data) => ProviderScope(
  overrides: [receivedQuoteRequestsProvider.overrideWith((ref) async => data)],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(
      theme: AppTheme.dark(),
      home: const QuoteRequestsInboxPage(),
    ),
  ),
);

void main() {
  testWidgets('empty inbox shows the empty state', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('No quote requests yet'), findsOneWidget);
  });

  testWidgets('a pending request offers QUOTE + DECLINE', (tester) async {
    final req = QuoteRequest(
      id: 'q1',
      jobId: 'j1',
      builderId: 'b1',
      tradeId: 't1',
      status: QuoteRequestStatus.requested,
      createdAt: DateTime(2026),
      jobTitle: 'Deck build',
      builderCompanyName: 'Acme Builders',
    );

    await tester.pumpWidget(_wrap([req]));
    await tester.pumpAndSettle();

    expect(find.text('Deck build'), findsOneWidget);
    expect(find.text('QUOTE'), findsOneWidget);
    expect(find.text('DECLINE'), findsOneWidget);
  });
}
