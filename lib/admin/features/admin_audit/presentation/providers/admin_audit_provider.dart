import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_audit_repository_impl.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../../domain/repositories/admin_audit_repository.dart';
import '../../domain/usecases/list_admin_audit_events.dart';

const int kAdminAuditPageSize = 50;

final adminAuditRepositoryProvider = Provider<AdminAuditRepository>(
  (ref) => AdminAuditRepositoryImpl(),
);

final listAdminAuditEventsProvider = Provider<ListAdminAuditEvents>(
  (ref) => ListAdminAuditEvents(ref.watch(adminAuditRepositoryProvider)),
);

final adminAuditProvider =
    NotifierProvider<AdminAuditController, void>(AdminAuditController.new);

class AdminAuditController extends Notifier<void> {
  late final PagingController<int, AdminAuditEvent> pagingController;

  @override
  void build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminAuditEventsProvider);
    final result = await useCase(ListAdminAuditEventsParams(
      limit: kAdminAuditPageSize,
      offset: offset,
    ));
    result.fold(
      (failure) => pagingController.error = failure.message,
      (rows) {
        final isLast = rows.length < kAdminAuditPageSize;
        if (isLast) {
          pagingController.appendLastPage(rows);
        } else {
          pagingController.appendPage(rows, offset + rows.length);
        }
      },
    );
  }

  Future<void> refresh() async => pagingController.refresh();
}
