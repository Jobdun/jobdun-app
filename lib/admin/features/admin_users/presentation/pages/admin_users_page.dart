import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../app/widgets/admin_empty_state.dart';
import '../../../../app/widgets/admin_error_state.dart';
import '../../../../app/widgets/admin_list_skeleton.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../providers/admin_users_provider.dart';
import '../widgets/admin_user_list_row.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller = ref.watch(adminUsersProvider.notifier).pagingController;
    final stateValue = ref.watch(adminUsersProvider);

    return AdminScaffold(
      title: 'USERS',
      activeRoute: AdminRoutes.users,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(active: stateValue.filter),
          const Gap(12),
          _SearchField(initial: stateValue.query),
          const Gap(16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(adminUsersProvider.notifier).refresh(),
              child: PagedListView<int, AdminUserRow>(
                pagingController: controller,
                builderDelegate: PagedChildBuilderDelegate<AdminUserRow>(
                  itemBuilder: (context, row, index) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.go(AdminRoutes.userDetail(row.id)),
                      child: AdminUserListRow(row: row),
                    ),
                  ),
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
                    title: "COULDN'T LOAD USERS",
                    message: controller.error?.toString() ?? 'Failed to load.',
                    onRetry: () => controller.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => const AdminEmptyState(
                    icon: Icons.person_search_outlined,
                    label: 'No users match.',
                    hint: 'Try a different filter or search term.',
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
  final AdminUserRoleFilter active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const filters = [
      (AdminUserRoleFilter.all, 'ALL'),
      (AdminUserRoleFilter.builder, 'BUILDERS'),
      (AdminUserRoleFilter.trade, 'TRADES'),
      (AdminUserRoleFilter.admin, 'ADMINS'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (filter, label) in filters)
          _Chip(
            label: label,
            isActive: filter == active,
            onTap: () =>
                ref.read(adminUsersProvider.notifier).setFilter(filter),
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

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.initial});
  final String initial;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Decoration (fill, resting `borderStrong` edge, 2px orange focus border)
    // comes from the app's themed `inputDecorationTheme` — only the hint +
    // search icon are page-specific, so the field matches every other input.
    return TextField(
      controller: _ctrl,
      onSubmitted: (v) =>
          ref.read(adminUsersProvider.notifier).setQuery(v.trim()),
      textInputAction: TextInputAction.search,
      style: AdminText.input(c.text1),
      decoration: const InputDecoration(
        hintText: 'Search display name…',
        prefixIcon: Icon(Icons.search),
        isDense: true,
      ),
    );
  }
}
