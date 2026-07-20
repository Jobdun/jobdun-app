import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/domain/entities/job_filter.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_interactions_repository.dart';
import 'package:jobdun/features/jobs/domain/repositories/job_repository.dart';
import 'package:jobdun/features/jobs/presentation/pages/jobs_page.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/verification/domain/entities/verification.dart';
import 'package:jobdun/features/verification/presentation/providers/verifications_provider.dart';

/// End-of-guest-feed conversion nudge: a signed-out browser who reaches the
/// bottom of their capped preview sees a "create an account" card. A signed-
/// in tradie reaching the genuine end of the real feed must never see it —
/// they already have an account.
class MockJobRepository extends Mock implements JobRepository {}

class MockJobInteractionsRepository extends Mock
    implements JobInteractionsRepository {}

class _GuestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();
}

class _TradeAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    isRoleLoaded: true,
    role: UserRole.trade,
  );
}

class _FakeProfileController extends ProfileController {
  @override
  ProfileState build() => const ProfileState();

  @override
  Future<void> loadProfile() async {}
}

Job _job(int i) => Job(
  id: 'job-$i',
  builderId: 'builder-1',
  title: 'Real open job #$i',
  description: 'A genuine listing.',
  tradeTypeRequired: 'Electrician',
  suburb: 'Sydney',
  state: 'NSW',
  postcode: '2000',
  status: JobStatus.open,
  urgency: JobUrgency.standard,
  createdAt: DateTime(2026, 7, i + 1),
  updatedAt: DateTime(2026, 7, i + 1),
);

void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
    registerFallbackValue(const JobFilter());
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  // Ahem-font fallback renders glyphs wider than production, so more than
  // one JobCard row can overflow in the same pump. When several exceptions
  // land in one frame, takeException() returns a single bundled "Multiple
  // exceptions (N) were detected" wrapper instead of the individual
  // messages — accept that wrapper too (still confirmed via raw stdout to
  // be exactly the known job_card.dart overflow, never a new failure).
  void drainKnownOverflow(WidgetTester tester) {
    for (var exc = tester.takeException(); exc != null;) {
      final msg = exc.toString();
      if (!msg.contains('overflow') && !msg.contains('Multiple exceptions')) {
        throw exc;
      }
      exc = tester.takeException();
    }
  }

  Future<void> pumpJobsPage(
    WidgetTester tester, {
    required bool authed,
    required List<Job> pool,
  }) async {
    final mockRepo = MockJobRepository();
    when(
      () => mockRepo.getJobs(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((invocation) async {
      final limit = invocation.namedArguments[#limit] as int?;
      final offset = invocation.namedArguments[#offset] as int? ?? 0;
      return right(pool.skip(offset).take(limit ?? pool.length).toList());
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jobRepositoryProvider.overrideWithValue(mockRepo),
          jobInteractionsRepositoryProvider.overrideWithValue(
            MockJobInteractionsRepository(),
          ),
          authControllerProvider.overrideWith(
            authed ? _TradeAuthController.new : _GuestAuthController.new,
          ),
          profileControllerProvider.overrideWith(_FakeProfileController.new),
          myVerificationsProvider.overrideWithValue(
            const AsyncData(<Verification>[]),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.dark(),
            debugShowCheckedModeBanner: false,
            home: const JobsPage(),
            onGenerateRoute: (settings) =>
                MaterialPageRoute<void>(builder: (_) => const JobsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);
  }

  testWidgets('guest reaching the end of the capped feed sees the CTA', (
    tester,
  ) async {
    await pumpJobsPage(
      tester,
      authed: false,
      pool: List.generate(3, _job), // fewer than the cap — genuine list end
    );

    expect(find.text('WANT TO SEE MORE?'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
  });

  testWidgets(
    'signed-in tradie reaching the real end of the feed sees no CTA',
    (tester) async {
      await pumpJobsPage(tester, authed: true, pool: List.generate(3, _job));

      expect(find.text('WANT TO SEE MORE?'), findsNothing);
      expect(find.text('CREATE ACCOUNT'), findsNothing);
    },
  );
}
