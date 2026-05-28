import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
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
                      const Center(child: CircularProgressIndicator()),
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
                  firstPageErrorIndicatorBuilder: (_) => _ErrorBlock(
                    message: controller.error?.toString() ?? 'Failed to load.',
                    onRetry: () => controller.refresh(),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => const _EmptyBlock(),
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
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? c.background : c.text1,
            ),
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
    return TextField(
      controller: _ctrl,
      onSubmitted: (v) =>
          ref.read(adminUsersProvider.notifier).setQuery(v.trim()),
      style: GoogleFonts.openSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.text1,
      ),
      decoration: InputDecoration(
        hintText: 'Search display name…',
        hintStyle: GoogleFonts.openSans(fontSize: 13, color: c.text3),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            "COULDN'T LOAD USERS",
            style: GoogleFonts.oswald(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          const Gap(8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(fontSize: 12, color: c.text2),
          ),
          const Gap(16),
          TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          'No users match.',
          style: GoogleFonts.openSans(fontSize: 13, color: c.text2),
        ),
      ),
    );
  }
}
