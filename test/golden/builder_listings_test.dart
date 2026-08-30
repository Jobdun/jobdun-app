import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/jobs/domain/entities/job.dart';
import 'package:jobdun/features/jobs/presentation/pages/builder_listings_view.dart';
import 'package:jobdun/features/jobs/presentation/providers/jobs_provider.dart';

import '_harness.dart';

ThemeData _goldenTheme() {
  const c = JColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.light(
      primary: c.action,
      onPrimary: c.onAction,
      secondary: c.surfaceRaised,
      onSecondary: c.text1,
      surface: c.surface,
      onSurface: c.text1,
      error: c.urgent,
    ),
    extensions: const [c],
  );
}

Job _job({
  required String id,
  required String title,
  required JobStatus status,
  required String suburb,
  required int applicants,
  required double amount,
  required int minutesAgo,
}) => Job(
  id: id,
  builderId: 'me',
  title: title,
  description: 'Placeholder description for the listing card.',
  tradeTypeRequired: 'Electrician',
  suburb: suburb,
  state: 'VIC',
  postcode: '3000',
  status: status,
  createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
  updatedAt: DateTime.now(),
  budgetAmount: amount,
  applicationCount: applicants,
);

void main() {
  testWidgets('builder listings golden (light)', (tester) async {
    final jobs = [
      _job(
        id: '1',
        title: 'Switchboard update + RCD install',
        status: JobStatus.open,
        suburb: 'Craigieburn',
        applicants: 0,
        amount: 2400,
        minutesAgo: 47,
      ),
      _job(
        id: '2',
        title: 'New software rollout',
        status: JobStatus.closed,
        suburb: 'Melbourne CBD',
        applicants: 5,
        amount: 3200,
        minutesAgo: 120,
      ),
      _job(
        id: '3',
        title: 'Marketing strategy sessions',
        status: JobStatus.filled,
        suburb: 'Southbank',
        applicants: 4,
        amount: 1800,
        minutesAgo: 30,
      ),
    ];

    await tester.binding.setSurfaceSize(kGoldenSurface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          builderListingsProvider.overrideWith((ref) async => jobs),
          currentUserIdProvider.overrideWith((ref) => Stream.value('me')),
          currentUserIdSyncProvider.overrideWithValue('me'),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            size: kGoldenSurface,
            devicePixelRatio: 1.0,
          ),
          child: ScreenUtilInit(
            designSize: kGoldenSurface,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _goldenTheme(),
              home: const BuilderListingsView(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await expectLater(
      find.byType(BuilderListingsView),
      matchesGoldenFile('goldens/builder_listings.png'),
    );
  });
}
