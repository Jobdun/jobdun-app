import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../providers/admin_audit_provider.dart';
import '../widgets/admin_audit_event_row.dart';

class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final controller =
        ref.watch(adminAuditProvider.notifier).pagingController;

    return AdminScaffold(
      title: 'AUDIT LOG',
      activeRoute: AdminRoutes.audit,
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminAuditProvider.notifier).refresh(),
        child: PagedListView<int, AdminAuditEvent>(
          pagingController: controller,
          builderDelegate: PagedChildBuilderDelegate<AdminAuditEvent>(
            itemBuilder: (context, event, index) =>
                AdminAuditEventRow(event: event),
            firstPageProgressIndicatorBuilder: (context) =>
                const Center(child: CircularProgressIndicator()),
            newPageProgressIndicatorBuilder: (context) => Padding(
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
            firstPageErrorIndicatorBuilder: (context) => _ErrorBlock(
              message: controller.error?.toString() ?? 'Try again.',
              onRetry: () => controller.refresh(),
            ),
            noItemsFoundIndicatorBuilder: (context) => Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No audit events yet.',
                  style: GoogleFonts.openSans(
                    fontSize: 13,
                    color: c.text2,
                  ),
                ),
              ),
            ),
          ),
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
            "COULDN'T LOAD AUDIT LOG",
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
