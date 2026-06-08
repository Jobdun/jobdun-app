import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:jobdun/admin/features/admin_broadcast/domain/repositories/admin_broadcast_repository.dart';
import 'package:jobdun/admin/features/admin_broadcast/presentation/pages/admin_broadcast_page.dart';
import 'package:jobdun/admin/features/admin_broadcast/presentation/providers/admin_broadcast_provider.dart';
import 'package:jobdun/admin/features/admin_auth/presentation/providers/admin_session_provider.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/errors/failures.dart';

import '../../support/admin_test_support.dart';

/// Records every broadcast call so the test can assert what (if anything) was
/// sent. Returns a fixed [result].
class _FakeBroadcastRepository implements AdminBroadcastRepository {
  _FakeBroadcastRepository(this.result);
  final Either<Failure, int> result;
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<Either<Failure, int>> broadcast({
    required String title,
    required String body,
    required String audience,
    Map<String, dynamic> data = const {},
  }) async {
    calls.add({'title': title, 'body': body, 'audience': audience});
    return result;
  }
}

Widget _wrap(AdminBroadcastRepository repo) => ProviderScope(
  overrides: [
    adminSessionProvider.overrideWith(
      () => FakeAdminSessionNotifier(kTestAdminSession),
    ),
    adminBroadcastRepositoryProvider.overrideWithValue(repo),
  ],
  child: ScreenUtilInit(
    designSize: const Size(1440, 900),
    builder: (_, _) =>
        MaterialApp(theme: AppTheme.dark(), home: const AdminBroadcastPage()),
  ),
);

void main() {
  testWidgets('renders the compose surface — title, fields, preview, CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(_FakeBroadcastRepository(const Right(0))));
    await tester.pump();

    expect(find.text('AUDIENCE'), findsOneWidget);
    expect(find.text('TITLE'), findsOneWidget);
    expect(find.text('MESSAGE'), findsOneWidget);
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('SEND BROADCAST'), findsOneWidget);
    // Preview placeholder shows before any typing.
    expect(find.text('NEW FROM JOBDUN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('validate on submit — empty fields block the send (no RPC)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeBroadcastRepository(const Right(5));
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    await tester.tap(find.text('SEND BROADCAST'));
    await tester.pumpAndSettle();

    // Validators fired, the confirm dialog never opened, and nothing was sent.
    expect(find.text('A title is required.'), findsOneWidget);
    expect(find.text('A message is required.'), findsOneWidget);
    expect(find.text('Send this broadcast?'), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('happy path — confirm then send shows the recipient count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeBroadcastRepository(const Right(142));
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. New verification flow is live'),
      'Heads up',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What do you want users to know?'),
      'We shipped a thing.',
    );
    await tester.pump();

    await tester.tap(find.text('SEND BROADCAST'));
    await tester.pumpAndSettle();

    // Confirm dialog appears for this high-impact action.
    expect(find.text('Send this broadcast?'), findsOneWidget);

    // Confirm → the RPC is called with the typed copy + the 'all' audience.
    await tester.tap(find.widgetWithText(SizedBox, 'SEND').last);
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single['title'], 'Heads up');
    expect(repo.calls.single['body'], 'We shipped a thing.');
    expect(repo.calls.single['audience'], 'all');
    // Success snackbar shows the count.
    expect(find.text('Sent to 142 recipients.'), findsOneWidget);
  });

  testWidgets('failure path — surfaces the failure message, no success toast', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeBroadcastRepository(const Left(ServerFailure('boom')));
    await tester.pumpWidget(_wrap(repo));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'e.g. New verification flow is live'),
      'T',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'What do you want users to know?'),
      'B',
    );
    await tester.pump();

    await tester.tap(find.text('SEND BROADCAST'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SizedBox, 'SEND').last);
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(find.text('boom'), findsOneWidget);
    expect(find.textContaining('Sent to'), findsNothing);
  });

  testWidgets('single-user audience reveals the USER ID field', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(_FakeBroadcastRepository(const Right(1))));
    await tester.pump();

    expect(find.text('USER ID'), findsNothing);

    await tester.tap(find.text('ALL USERS').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SINGLE USER').last);
    await tester.pumpAndSettle();

    expect(find.text('USER ID'), findsOneWidget);
  });
}
