import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/presentation/pages/jobs_page.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

class _Guest extends AuthController {
  @override
  AuthState build() => const AuthState();
}

class _Jobs extends JobsController {
  final paging = PagingController<int, Job>(firstPageKey: 0);
  int requests = 0;

  @override
  JobsState build() {
    paging.addPageRequestListener((_) => requests++);
    ref.onDispose(paging.dispose);
    return const JobsState();
  }

  @override
  PagingController<int, Job> get pagingController => paging;

  @override
  Future<void> loadFeed() async {
    requests++;
  }

  @override
  Future<void> loadInteractionIds() async {}
}

void main() {
  Future<void> mount(WidgetTester tester, _Jobs controller) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_Guest.new),
          jobsControllerProvider.overrideWith(() => controller),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) =>
              MaterialApp(theme: AppTheme.light(), home: const JobsPage()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('initial loading does not claim zero results', (tester) async {
    await mount(tester, _Jobs());
    expect(find.text('0 jobs found'), findsNothing);
  });

  testWidgets('failed first page hides count and keeps a safe retry visible', (
    tester,
  ) async {
    final controller = _Jobs();
    controller.paging.error =
        'ClientException with SocketException: Failed host lookup: '
        'private.example/rest/v1/jobs?select=private_field';
    await mount(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text('0 jobs found'), findsNothing);
    expect(find.textContaining('private.example'), findsNothing);
    expect(find.textContaining('SocketException'), findsNothing);
    expect(find.text('RETRY').hitTestable(), findsOneWidget);
    final before = controller.requests;
    await tester.tap(find.text('RETRY'));
    await tester.pump();
    expect(controller.requests, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful empty page shows zero and refresh clears count', (
    tester,
  ) async {
    final controller = _Jobs();
    await mount(tester, controller);
    controller.paging.appendLastPage(const []);
    await tester.pumpAndSettle();
    expect(find.text('0 jobs found'), findsOneWidget);
    controller.paging.refresh();
    await tester.pump();
    expect(find.text('0 jobs found'), findsNothing);
  });
}
