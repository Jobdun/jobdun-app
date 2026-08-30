import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/widgets/resume_row.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('ResumeRow', () {
    testWidgets('the locked state offers no way to open the file', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ResumeRow.locked()));
      await tester.pumpAndSettle();
      expect(find.textContaining('after they apply'), findsOneWidget);
      expect(find.text('VIEW RESUME'), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('the locked state does NOT leak the privacy line', (
      tester,
    ) async {
      // That line is owner-facing copy. On a builder's screen it would read as
      // an instruction aimed at them.
      await tester.pumpWidget(_wrap(const ResumeRow.locked()));
      await tester.pumpAndSettle();
      expect(find.textContaining("you've applied to can open"), findsNothing);
    });

    testWidgets('the owner state shows the filename, date and both actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ResumeRow.owner(
            fileName: 'resume-ken.pdf',
            uploadedAt: DateTime(2026, 8, 31),
            onReplace: () {},
            onRemove: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('resume-ken.pdf'), findsOneWidget);
      expect(find.text('Uploaded 31 Aug 2026'), findsOneWidget);
      expect(find.text('REPLACE'), findsOneWidget);
      expect(find.text('REMOVE'), findsOneWidget);
    });

    testWidgets('the owner sees who can read it', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ResumeRow.owner(
            fileName: 'a.pdf',
            uploadedAt: DateTime(2026, 8, 31),
            onReplace: () {},
            onRemove: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Only builders you've applied to"),
        findsOneWidget,
      );
    });

    testWidgets('the empty state states who can see it BEFORE they upload', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(ResumeRow.empty(onUpload: () {})));
      await tester.pumpAndSettle();
      expect(find.text('UPLOAD RESUME'), findsOneWidget);
      expect(
        find.textContaining("Only builders you've applied to"),
        findsOneWidget,
      );
    });

    testWidgets('replace and remove fire independently', (tester) async {
      var replaced = false;
      var removed = false;
      await tester.pumpWidget(
        _wrap(
          ResumeRow.owner(
            fileName: 'a.pdf',
            uploadedAt: DateTime(2026, 8, 31),
            onReplace: () => replaced = true,
            onRemove: () => removed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('REPLACE'));
      await tester.pump();
      expect(replaced, isTrue);
      expect(removed, isFalse);

      await tester.tap(find.text('REMOVE'));
      await tester.pump();
      expect(removed, isTrue);
    });

    testWidgets('the viewer-with-access state opens the file', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        _wrap(ResumeRow.viewer(onView: () => opened = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIEW RESUME'));
      await tester.pump();
      expect(opened, isTrue);
    });

    testWidgets('a busy empty state cannot be tapped twice', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(ResumeRow.empty(onUpload: () => taps++)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPLOAD RESUME'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the owner actions clear the 48dp touch floor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ResumeRow.owner(
            fileName: 'a.pdf',
            uploadedAt: DateTime(2026, 8, 31),
            onReplace: () {},
            onRemove: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['REPLACE', 'REMOVE']) {
        final box = find.ancestor(
          of: find.text(label),
          matching: find.byType(ConstrainedBox),
        );
        expect(
          tester.getSize(box.first).height,
          greaterThanOrEqualTo(48.0),
          reason: label,
        );
      }
    });
  });
}
