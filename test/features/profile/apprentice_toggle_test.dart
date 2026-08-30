import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/apprenticeship_stage.dart';
import 'package:jobdun/features/profile/presentation/widgets/edit_sheets/apprenticeship_fields.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('apprenticeshipPatch', () {
    test('turning the toggle on writes the flag and the stage', () {
      final p = apprenticeshipPatch(
        isApprentice: true,
        stage: ApprenticeshipStage.year2,
      );
      expect(p.isApprentice, const Some(true));
      expect(p.apprenticeshipStage, const Some(ApprenticeshipStage.year2));
    });

    test('turning the toggle off clears the stage in the same patch', () {
      final p = apprenticeshipPatch(
        isApprentice: false,
        stage: ApprenticeshipStage.year3,
      );
      expect(p.isApprentice, const Some(false));
      expect(
        p.apprenticeshipStage,
        const Some<ApprenticeshipStage?>(null),
        reason: 'a stale stage must not resurface if they re-enable later',
      );
    });

    test('apprentice on with no stage picked writes null, not a default', () {
      final p = apprenticeshipPatch(isApprentice: true, stage: null);
      expect(p.apprenticeshipStage, const Some<ApprenticeshipStage?>(null));
    });

    test('the patch touches nothing but the apprentice fields', () {
      final p = apprenticeshipPatch(isApprentice: true, stage: null);
      expect(p.primaryTrade.isNone(), isTrue);
      expect(p.hourlyRateMin.isNone(), isTrue);
      expect(p.baseSuburb.isNone(), isTrue);
      expect(p.siteTickets.isNone(), isTrue);
    });
  });

  group('ApprenticeshipFields', () {
    testWidgets('the stage picker is hidden until the toggle is on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ApprenticeshipFields(
            isApprentice: false,
            stage: null,
            onApprenticeChanged: (_) {},
            onStageChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StagePill), findsNothing);
      expect(find.text('STAGE'), findsNothing);
    });

    testWidgets('turning it on reveals all five stages', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ApprenticeshipFields(
            isApprentice: true,
            stage: null,
            onApprenticeChanged: (_) {},
            onStageChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StagePill), findsNWidgets(5));
      expect(find.text('Pre-apprentice'), findsOneWidget);
      expect(find.text('4th year'), findsOneWidget);
    });

    testWidgets('tapping a stage reports it', (tester) async {
      ApprenticeshipStage? picked;
      await tester.pumpWidget(
        _wrap(
          ApprenticeshipFields(
            isApprentice: true,
            stage: null,
            onApprenticeChanged: (_) {},
            onStageChanged: (s) => picked = s,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('2nd year'));
      await tester.pump();
      expect(picked, ApprenticeshipStage.year2);
    });

    testWidgets('stage pills clear the 48dp touch target floor', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ApprenticeshipFields(
            isApprentice: true,
            stage: ApprenticeshipStage.year1,
            onApprenticeChanged: (_) {},
            onStageChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final pill in find.byType(StagePill).evaluate()) {
        expect(
          tester.getSize(find.byWidget(pill.widget)).height,
          greaterThanOrEqualTo(48.0),
        );
      }
    });

    testWidgets('the selected stage is announced, not just coloured', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ApprenticeshipFields(
            isApprentice: true,
            stage: ApprenticeshipStage.year3,
            onApprenticeChanged: (_) {},
            onStageChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selected = tester.getSemantics(
        find.ancestor(
          of: find.text('3rd year'),
          matching: find.byType(StagePill),
        ),
      );
      expect(selected.hasFlag(SemanticsFlag.isSelected), isTrue);
    });
  });
}
