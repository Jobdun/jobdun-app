import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/design/widgets/j_button.dart';
import 'package:jobdun/core/design/widgets/j_select_chip.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:jobdun/features/home/presentation/widgets/home_quick_action_card.dart';
import 'package:jobdun/core/design/widgets/j_stats_row.dart';

import '_harness.dart';

/// Goldens for the vocabulary introduced by the Figma **Homepage** section
/// (`JobDun-Screens` node 64:2088) — the figure row, the two-up action pair,
/// the pill chip, and the two new [JButton] outline variants.
///
/// These are the pieces the mock adds; the screens that compose them
/// (`/home`, `/jobs/create`, `/jobs/:id`) need live Riverpod state and a map
/// tile server, so they are covered by their own widget tests instead.
void main() {
  group('Figma Homepage goldens (light)', () {
    testWidgets('stats row — Active / Applicants / Posted', (tester) async {
      await pumpGolden(
        tester,
        const JStatsRow(
          stats: [
            JStat(value: '9', label: 'Active'),
            JStat(value: '2', label: 'Applicants'),
            JStat(value: '0', label: 'Posted'),
          ],
        ),
      );
      await expectLater(
        find.byType(JStatsRow),
        matchesGoldenFile('goldens/figma_home_stats_row.png'),
      );
    });

    testWidgets('stats row — unknown values render as em dashes', (
      tester,
    ) async {
      await pumpGolden(
        tester,
        const JStatsRow(
          stats: [
            JStat(value: '—', label: 'Active'),
            JStat(value: '—', label: 'Applicants'),
            JStat(value: '—', label: 'Posted'),
          ],
        ),
      );
      await expectLater(
        find.byType(JStatsRow),
        matchesGoldenFile('goldens/figma_home_stats_row_unknown.png'),
      );
    });

    testWidgets('two-up quick actions', (tester) async {
      await pumpGolden(
        tester,
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: HomeQuickActionCard(
                  icon: AppIcons.search,
                  title: 'Find a Tradie',
                  description: 'Discover jobs near you',
                  onTap: () {},
                ),
              ),
              const Gap(16),
              Expanded(
                child: HomeQuickActionCard(
                  icon: AppIcons.applicantsOutline,
                  title: 'Applicants',
                  description: 'Manage and review applicants',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      );
      await expectLater(
        find.byType(IntrinsicHeight),
        matchesGoldenFile('goldens/figma_home_quick_actions.png'),
      );
    });

    testWidgets('select chips — selected and unselected', (tester) async {
      await pumpGolden(
        tester,
        Wrap(
          spacing: 8,
          children: [
            JSelectChip(label: 'Plasterer', selected: true, onTap: () {}),
            JSelectChip(label: 'Plumber', selected: false, onTap: () {}),
            JSelectChip(
              label: 'Per lineal metre',
              selected: false,
              onTap: () {},
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(Wrap),
        matchesGoldenFile('goldens/figma_select_chips.png'),
      );
    });

    testWidgets('button variants — primary, disabled, outline pair', (
      tester,
    ) async {
      await pumpGolden(
        tester,
        Column(
          children: [
            JButton(label: 'Post a job', icon: AppIcons.add, onPressed: () {}),
            const Gap(12),
            // Step-1 "Next" before the form validates.
            const JButton(label: 'Next', onPressed: null),
            const Gap(12),
            JButton(
              label: 'Explore map',
              variant: JButtonVariant.outline,
              onPressed: () {},
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: JButton(label: 'View applicants', onPressed: () {}),
                ),
                const Gap(10),
                Expanded(
                  child: JButton(
                    label: 'Delete job',
                    variant: JButtonVariant.dangerOutline,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/figma_button_variants.png'),
      );
    });
  });
}
