import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../app/widgets/admin_empty_state.dart';
import '../../../../app/widgets/admin_error_state.dart';
import '../../../../app/widgets/admin_list_skeleton.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../providers/admin_jobs_provider.dart';
import '../widgets/admin_job_list_row.dart';

class AdminJobsPage extends ConsumerWidget {
  const AdminJobsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller = ref.watch(adminJobsProvider.notifier).pagingController;
    final stateValue = ref.watch(adminJobsProvider);

    return AdminScaffold(
      title: 'JOBS',
      activeRoute: AdminRoutes.jobs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(active: stateValue.filter),
          const Gap(16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(adminJobsProvider.notifier).refresh(),
              child: PagedListView<int, AdminJobRow>(
                pagingController: controller,
                builderDelegate: PagedChildBuilderDelegate<AdminJobRow>(
                  itemBuilder: (context, row, index) =>
                      AdminJobListRow(row: row),
                  firstPageProgressIndicatorBuilder: (_) =>
                      const AdminListSkeleton(),
                  newPageProgressIndicatorBuilder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.text3,
                        ),
                      ),
                    ),
                  ),
                  firstPageErrorIndicatorBuilder: (_) => AdminErrorState(
                    title: "COULDN'T LOAD JOBS",
                    message: controller.error?.toString() ?? 'Try again.',
                    onRetry: () => controller.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => const AdminEmptyState(
                    icon: Icons.work_outline,
                    label: 'No jobs match.',
                    hint: 'Try a different status filter.',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.active});
  final AdminJobStatusFilter active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      (AdminJobStatusFilter.all, 'ALL'),
      (AdminJobStatusFilter.draft, 'DRAFT'),
      (AdminJobStatusFilter.open, 'OPEN'),
      (AdminJobStatusFilter.filled, 'FILLED'),
      (AdminJobStatusFilter.closed, 'CLOSED'),
      (AdminJobStatusFilter.cancelled, 'CANCELLED'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (filter, label) in filters)
          _Chip(
            label: label,
            isActive: filter == active,
            onTap: () => ref.read(adminJobsProvider.notifier).setFilter(filter),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: isActive ? c.action : c.surfaceRaised,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: AdminText.label(isActive ? c.onAction : c.text1),
          ),
        ),
      ),
    );
  }
}
