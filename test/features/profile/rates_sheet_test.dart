import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/design/widgets/j_bottom_sheet.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/profile/data/models/trade_profile_model.dart';
import 'package:jobdun/features/profile/domain/entities/profile_patches.dart';
import 'package:jobdun/features/profile/domain/repositories/profile_repository.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/profile/presentation/widgets/edit_sheets/rates_sheet.dart';

class _MockRepo extends Mock implements ProfileRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const TradeProfilePatch());
  });

  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  Widget wrap() => ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      currentUserIdSyncProvider.overrideWithValue('u1'),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showJSheet<bool>(
                context: ctx,
                builder: (_) => const RatesSheet(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(RatesSheet), findsOneWidget);
  }

  testWidgets('max < min blocks save with cross-field error', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), '90');
    await tester.enterText(find.byType(TextField).at(1), '55');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Must be ≥ min.'), findsOneWidget);
    expect(find.byType(RatesSheet), findsOneWidget);
    verifyNever(() => repo.patchTradeProfile(any(), any()));
  });

  testWidgets('dirty drag-down surfaces discard confirm; KEEP EDITING stays', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), '70');
    await tester.pump();

    // Drag the sheet down by its header (outside the scrollable body) far
    // enough to cross the dismiss threshold. The dirty guard must intercept
    // (scoped willPop → confirm sheet).
    await tester.drag(find.text('RATES'), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('KEEP EDITING'));
    await tester.pumpAndSettle();

    expect(find.byType(RatesSheet), findsOneWidget);
    verifyNever(() => repo.patchTradeProfile(any(), any()));

    // DISCARD CHANGES actually closes the sheet.
    await tester.drag(find.text('RATES'), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD CHANGES'));
    await tester.pumpAndSettle();
    expect(find.byType(RatesSheet), findsNothing);
  });

  testWidgets('valid rates patch only the three rate columns and pop', (
    tester,
  ) async {
    when(
      () => repo.patchTradeProfile('u1', any()),
    ).thenAnswer((_) async => right(null));
    when(() => repo.getTradeProfile('u1')).thenAnswer(
      (_) async => right(
        const TradeProfileModel(
          id: 'u1',
          fullName: 'Ken',
          primaryTrade: 'carpenter',
          hourlyRateMin: 55,
          hourlyRateMax: 95,
        ),
      ),
    );

    await openSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), '55');
    await tester.enterText(find.byType(TextField).at(1), '95');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repo.patchTradeProfile('u1', captureAny()),
    ).captured;
    final patch = captured.single as TradeProfilePatch;
    expect(patch.hourlyRateMin, const Some(55.0));
    expect(patch.hourlyRateMax, const Some(95.0));
    expect(patch.hourlyRateVisible, const Some(true));
    // Null-wipe guard at the sheet level: nothing else is touched.
    expect(patch.about.isNone(), isTrue);
    expect(patch.baseSuburb.isNone(), isTrue);
    expect(patch.fullName.isNone(), isTrue);

    expect(find.byType(RatesSheet), findsNothing);
  });
}
