import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../providers/admin_verifications_provider.dart';
import '../widgets/admin_verification_queue_row.dart';
import '../widgets/admin_verification_review_sheet.dart';

/// Admin verification queue. Classifies documents by audience (Trade Licence /
/// Builder ABN / Other) via chip filters, surfaces the uploader's name + role,
/// and shows the regulator's failure reason when the upload was a fallback
/// from a failed API check.
class AdminVerificationsPage extends ConsumerWidget {
  const AdminVerificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminVerificationsProvider);
    return AdminScaffold(
      title: 'VERIFICATIONS',
      activeRoute: AdminRoutes.verifications,
      trailing: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () =>
              ref.read(adminVerificationsProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBlock(error: e.toString()),
        data: (s) => _Body(state: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final AdminVerificationsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final items = state.filteredItems;
    final pending = items.where((i) => i.status == 'pending').toList();
    final reviewed = items.where((i) => i.status != 'pending').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterRow(
          state: state,
          onChanged: (f) =>
              ref.read(adminVerificationsProvider.notifier).setFilter(f),
        ),
        const Gap(16),
        Expanded(
          child: state.items.isEmpty
              ? const _EmptyBlock(label: 'No verification documents yet.')
              : items.isEmpty
              ? const _EmptyBlock(
                  label: 'Nothing in this category right now.',
                  hint: 'Try a different filter chip above.',
                )
              : ListView(
                  children: [
                    _SectionHeader(
                      title: 'PENDING',
                      count: pending.length,
                      accent: c.action,
                    ),
                    const Gap(8),
                    ...pending.map(
                      (i) => AdminVerificationQueueRow(
                        item: i,
                        onTap: () => _openSheet(context, i),
                      ),
                    ),
                    const Gap(24),
                    _SectionHeader(
                      title: 'REVIEWED',
                      count: reviewed.length,
                      accent: c.text3,
                    ),
                    const Gap(8),
                    ...reviewed.map(
                      (i) => AdminVerificationQueueRow(
                        item: i,
                        onTap: () => _openSheet(context, i),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _openSheet(BuildContext context, AdminVerificationItem item) {
    return showDialog<void>(
      context: context,
      builder: (_) => AdminVerificationReviewSheet(item: item),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.state, required this.onChanged});
  final AdminVerificationsState state;
  final ValueChanged<AdminVerificationKindFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AdminVerificationKindFilter.values
          .map(
            (f) => _Chip(
              label: _labelFor(f),
              count: state.countFor(f),
              selected: state.filter == f,
              onTap: () => onChanged(f),
            ),
          )
          .toList(),
    );
  }

  static String _labelFor(AdminVerificationKindFilter f) => switch (f) {
    AdminVerificationKindFilter.all => 'All',
    AdminVerificationKindFilter.tradeLicence => 'Trade Licence',
    AdminVerificationKindFilter.builderAbn => 'Builder ABN',
    AdminVerificationKindFilter.other => 'Other',
  };
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.action : c.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: selected ? Colors.white : c.text1,
                ),
              ),
              const Gap(6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : c.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : c.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.accent,
  });

  final String title;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.oswald(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: c.text1,
          ),
        ),
        const Gap(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.label, this.hint});
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: c.text3),
          const Gap(12),
          Text(
            label,
            style: GoogleFonts.openSans(fontSize: 14, color: c.text2),
          ),
          if (hint != null) ...[
            const Gap(4),
            Text(
              hint!,
              style: GoogleFonts.openSans(fontSize: 12, color: c.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Text(
        'Couldn\'t load the queue.\n$error',
        textAlign: TextAlign.center,
        style: GoogleFonts.openSans(fontSize: 13, color: c.urgent),
      ),
    );
  }
}
