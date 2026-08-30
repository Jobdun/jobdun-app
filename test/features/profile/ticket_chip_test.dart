import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/presentation/widgets/ticket_chip.dart';
import 'package:jobdun/features/profile/presentation/widgets/ticket_chip_wall.dart';

Widget _wrap(Widget child, {bool dark = false}) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: child),
  ),
);

void main() {
  group('TicketChip', () {
    testWidgets('a verified chip announces "verified" to screen readers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TicketChip(label: 'White Card', isVerified: true)),
      );
      await tester.pumpAndSettle();
      final s = tester.getSemantics(find.byType(TicketChip));
      expect(s.label, contains('White Card'));
      expect(s.label.toLowerCase(), contains('verified'));
    });

    testWidgets('a self-declared chip says so, it is not just grey', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const TicketChip(label: 'First Aid', isVerified: false)),
      );
      await tester.pumpAndSettle();
      final s = tester.getSemantics(find.byType(TicketChip));
      expect(s.label.toLowerCase(), contains('self-declared'));
    });

    testWidgets('the two tiers use different glyphs, not just colour', (
      tester,
    ) async {
      // The accessibility requirement: state is never conveyed by colour
      // alone. A colour-blind builder must still be able to tell a checked
      // credential from a claim.
      await tester.pumpWidget(
        _wrap(const TicketChip(label: 'White Card', isVerified: true)),
      );
      await tester.pumpAndSettle();
      final verifiedIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      await tester.pumpWidget(
        _wrap(const TicketChip(label: 'White Card', isVerified: false)),
      );
      await tester.pumpAndSettle();
      final selfIcon = tester.widget<Icon>(find.byType(Icon)).icon;

      expect(verifiedIcon, isNot(equals(selfIcon)));
    });

    testWidgets('renders in dark theme without throwing', (tester) async {
      await tester.pumpWidget(
        _wrap(const TicketChip(label: 'Rigging', isVerified: true), dark: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TicketChip), findsOneWidget);
    });
  });

  group('TicketChipWall', () {
    const labels = {
      'white_card': 'White Card',
      'first_aid': 'First Aid',
      'dogging': 'Dogging',
    };

    testWidgets('verified chips sort ahead of self-declared ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TicketChipWall(
            labelsBySlug: labels,
            selectedSlugs: ['dogging', 'first_aid', 'white_card'],
            verifiedSlugs: {'white_card'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chips = tester
          .widgetList<TicketChip>(find.byType(TicketChip))
          .toList();
      expect(chips.first.label, 'White Card');
      expect(chips.first.isVerified, isTrue);
      expect(chips.length, 3);
    });

    testWidgets('the builder disclaimer shows only when asked for', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TicketChipWall(
            labelsBySlug: labels,
            selectedSlugs: ['first_aid'],
            verifiedSlugs: {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('self-declared'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const TicketChipWall(
            labelsBySlug: labels,
            selectedSlugs: ['first_aid'],
            verifiedSlugs: {},
            showDisclaimer: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Sight the card'), findsOneWidget);
    });

    testWidgets('no disclaimer when every ticket is verified', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const TicketChipWall(
            labelsBySlug: labels,
            selectedSlugs: ['white_card'],
            verifiedSlugs: {'white_card'},
            showDisclaimer: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Sight the card'), findsNothing);
    });

    testWidgets('an unknown slug falls back to the slug, it does not vanish', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TicketChipWall(
            labelsBySlug: labels,
            selectedSlugs: ['brand_new_ticket'],
            verifiedSlugs: {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TicketChip), findsOneWidget);
      expect(find.textContaining('BRAND_NEW_TICKET'), findsOneWidget);
    });
  });
}
