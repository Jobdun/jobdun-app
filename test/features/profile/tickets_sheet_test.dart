import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/site_ticket.dart';
import 'package:jobdun/features/profile/presentation/widgets/edit_sheets/tickets_sheet_rows.dart';

const _whiteCard = SiteTicket(
  slug: 'white_card',
  shortName: 'White Card',
  displayName: 'White Card (Construction Induction, CPCCWHS1001)',
  category: SiteTicketCategory.induction,
  sortOrder: 10,
  docType: 'white_card',
);
const _firstAid = SiteTicket(
  slug: 'first_aid',
  shortName: 'First Aid',
  displayName: 'First Aid (HLTAID011)',
  category: SiteTicketCategory.safety,
  sortOrder: 10,
);
const _driver = SiteTicket(
  slug: 'drivers_licence',
  shortName: 'Driver Licence',
  displayName: 'Australian Driver Licence',
  category: SiteTicketCategory.transport,
  sortOrder: 10,
);

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('SiteTicket.detail', () {
    test('extracts the parenthetical unit code', () {
      expect(_whiteCard.detail, 'Construction Induction, CPCCWHS1001');
      expect(_firstAid.detail, 'HLTAID011');
    });

    test('falls back to the full name when there is no parenthetical', () {
      expect(_driver.detail, 'Australian Driver Licence');
    });

    test('is null when the display name adds nothing', () {
      const t = SiteTicket(
        slug: 'x',
        shortName: 'Dogging',
        displayName: 'Dogging',
        category: SiteTicketCategory.licence,
        sortOrder: 0,
      );
      expect(t.detail, isNull);
    });

    test('is null for empty parentheses rather than blank second line', () {
      const t = SiteTicket(
        slug: 'x',
        shortName: 'Rigging',
        displayName: 'Rigging ()',
        category: SiteTicketCategory.licence,
        sortOrder: 0,
      );
      expect(t.detail, isNull);
    });
  });

  group('TicketRow', () {
    testWidgets('tapping an unticked row selects it', (tester) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _firstAid,
            isSelected: false,
            isVerified: false,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TicketRow));
      await tester.pump();
      expect(got, isTrue);
    });

    testWidgets('tapping a ticked row deselects it', (tester) async {
      bool? got;
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _firstAid,
            isSelected: true,
            isVerified: false,
            onChanged: (v) => got = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TicketRow));
      await tester.pump();
      expect(got, isFalse);
    });

    testWidgets('a verified row is locked on and cannot be unticked', (
      tester,
    ) async {
      var changed = false;
      var explained = false;
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _whiteCard,
            isSelected: true,
            isVerified: true,
            onChanged: (_) => changed = true,
            onLockedTap: () => explained = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TicketRow));
      await tester.pump();
      expect(changed, isFalse, reason: 'verified tickets stay ticked');
      expect(explained, isTrue, reason: 'the tap must say why, not do nothing');
    });

    testWidgets(
      'a verified row renders ticked even when not locally selected',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TicketRow(
              ticket: _whiteCard,
              isSelected: false,
              isVerified: true,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final s = tester.getSemantics(find.byType(TicketRow));
        expect(s.label, contains('selected'));
        expect(s.label, isNot(contains('not selected')));
      },
    );

    testWidgets('the VERIFIED tag shows only on verified rows', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _whiteCard,
            isSelected: true,
            isVerified: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VERIFIED'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _firstAid,
            isSelected: true,
            isVerified: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('VERIFIED'), findsNothing);
    });

    testWidgets('every row meets the 48dp minimum touch target', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _driver,
            isSelected: false,
            isVerified: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(TicketRow)).height,
        greaterThanOrEqualTo(48.0),
      );
    });

    testWidgets('the short name and its unit code are both readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _firstAid,
            isSelected: false,
            isVerified: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('First Aid'), findsOneWidget);
      expect(find.text('HLTAID011'), findsOneWidget);
    });

    testWidgets('the row announces its tier to screen readers', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TicketRow(
            ticket: _firstAid,
            isSelected: true,
            isVerified: false,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final s = tester.getSemantics(find.byType(TicketRow));
      expect(s.label, contains('First Aid'));
      expect(s.label, contains('self-declared'));
    });
  });
}
