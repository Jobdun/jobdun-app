import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../app/placeholders/admin_status_tag.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../../app/widgets/admin_empty_state.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_job_row.dart';
import '../providers/admin_jobs_provider.dart';

/// Read-only Phase-2 moderation surface for a single job.
///
/// **Renders only the [AdminJobRow] handed in via GoRouter `extra`** — it never
/// fetches. The facts card shows the real passed-in values (builder, applicant
/// count, lifecycle status, created date); the moderation card is a muted
/// placeholder (status tags + disabled Hide/Remove) that wires up in Phase 2.
///
/// Deep-linking to `/jobs/:id` without an `extra` (e.g. a pasted URL or a hot
/// reload) lands on the empty state directing the operator back to the list,
/// since there's nothing to fetch here yet.
class AdminJobDetailPage extends StatelessWidget {
  const AdminJobDetailPage({super.key, required this.jobId, this.row});

  final String jobId;
  final AdminJobRow? row;

  @override
  Widget build(BuildContext context) {
    final job = row;
    return AdminScaffold(
      title: 'JOB DETAIL',
      activeRoute: AdminRoutes.jobs,
      child: job == null
          ? const AdminEmptyState(
              icon: Icons.work_outline,
              label: 'OPEN A JOB FROM THE LIST',
              hint:
                  'Job detail is a Phase-2 moderation surface — open it from '
                  'the Jobs list to inspect a row.',
            )
          : _DetailBody(row: job),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.row});

  final AdminJobRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackToJobs(),
          const Gap(16),
          Text(row.title, style: AdminText.dialogTitle(c.text1)),
          const Gap(8),
          _LifecyclePill(status: row.status),
          const Gap(24),
          _FactsCard(row: row),
          const Gap(16),
          _JobModerationCard(jobId: row.id, status: row.status),
          const Gap(40),
        ],
      ),
    );
  }
}

class _BackToJobs extends StatelessWidget {
  const _BackToJobs();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(AdminRoutes.jobs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 16, color: c.text2),
                const Gap(8),
                Text('BACK TO JOBS', style: AdminText.label(c.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live lifecycle status — REAL data from `row.status`, drawn the same way as
/// `AdminJobListRow._StatusPill` (filled pill, not the muted placeholder tag).
class _LifecyclePill extends StatelessWidget {
  const _LifecyclePill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isOpen = status == 'open';
    final Color bg = isOpen ? c.action : c.surfaceRaised;
    final Color fg = isOpen ? c.background : c.text1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: AdminText.eyebrow(fg).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// REAL passed-in values — builder, applicants, lifecycle, created date.
class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.row});

  final AdminJobRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOB', style: AdminText.cardLabel(c.text2)),
          const Gap(12),
          _Fact(label: 'Builder', value: row.builderDisplayName),
          const Gap(8),
          _Fact(label: 'Applicants', value: '${row.applicationCount}'),
          const Gap(8),
          _Fact(label: 'Lifecycle', value: row.status),
          const Gap(8),
          _Fact(
            label: 'Created',
            value: DateFormat('d MMM y').format(row.createdAt),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AdminText.labelMd(c.text3)),
        ),
        const Gap(12),
        Expanded(child: Text(value, style: AdminText.value(c.text1))),
      ],
    );
  }
}

/// Wired moderation (#21a) — current listing status + Close / Cancel / Reopen.
/// Each action calls the audited `admin_set_job_status` RPC, updates the local
/// status, refreshes the jobs list, and confirms via a snackbar. The offered
/// actions depend on the current status (mirrors the user-moderation card).
class _JobModerationCard extends ConsumerStatefulWidget {
  const _JobModerationCard({required this.jobId, required this.status});

  final String jobId;
  final String status;

  @override
  ConsumerState<_JobModerationCard> createState() => _JobModerationCardState();
}

class _JobModerationCardState extends ConsumerState<_JobModerationCard> {
  // A job is "taken down" when closed or cancelled — Reopen is offered then.
  static const _down = {'closed', 'cancelled'};

  late String _status = widget.status;
  bool _busy = false;

  Future<void> _set(String status) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final res = await ref
        .read(adminJobModerationProvider)
        .setJobStatus(jobId: widget.jobId, status: status);
    if (!mounted) return;
    setState(() => _busy = false);
    res.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        setState(() => _status = status);
        ref.read(adminJobsProvider.notifier).refresh();
        messenger.showSnackBar(
          SnackBar(content: Text('Job set to ${status.toUpperCase()}.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final status = _status;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MODERATION', style: AdminText.cardLabel(c.text3)),
          const Gap(12),
          AdminStatusTag(
            label: 'Listing: ${status.toUpperCase()}',
            tooltip: 'Current job status (admin_set_job_status)',
          ),
          const Gap(16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (_down.contains(status))
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'REOPEN',
                    onPressed: _busy ? null : () => _set('open'),
                  ),
                ),
              if (!_down.contains(status))
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'CLOSE',
                    variant: JButtonVariant.secondary,
                    onPressed: _busy ? null : () => _set('closed'),
                  ),
                ),
              if (status != 'cancelled')
                SizedBox(
                  width: 150,
                  child: JButton(
                    label: 'CANCEL',
                    variant: JButtonVariant.danger,
                    onPressed: _busy ? null : () => _set('cancelled'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
