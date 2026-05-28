import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_jobs_repository_impl.dart';
import '../../domain/entities/admin_job_filter.dart';
import '../../domain/entities/admin_job_row.dart';
import '../../domain/repositories/admin_jobs_repository.dart';
import '../../domain/usecases/list_admin_jobs.dart';

const int kAdminJobsPageSize = 50;

final adminJobsRepositoryProvider = Provider<AdminJobsRepository>(
  (ref) => AdminJobsRepositoryImpl(),
);

final listAdminJobsProvider = Provider<ListAdminJobs>(
  (ref) => ListAdminJobs(ref.watch(adminJobsRepositoryProvider)),
);

class AdminJobsState {
  const AdminJobsState({required this.filter});
  final AdminJobStatusFilter filter;
  AdminJobsState copyWith({AdminJobStatusFilter? filter}) =>
      AdminJobsState(filter: filter ?? this.filter);
}

final adminJobsProvider =
    NotifierProvider<AdminJobsController, AdminJobsState>(
  AdminJobsController.new,
);

class AdminJobsController extends Notifier<AdminJobsState> {
  late final PagingController<int, AdminJobRow> pagingController;

  @override
  AdminJobsState build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
    return const AdminJobsState(filter: AdminJobStatusFilter.all);
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminJobsProvider);
    final result = await useCase(ListAdminJobsParams(
      limit: kAdminJobsPageSize,
      offset: offset,
      filter: state.filter,
    ));
    result.fold(
      (failure) => pagingController.error = failure.message,
      (rows) {
        final isLast = rows.length < kAdminJobsPageSize;
        if (isLast) {
          pagingController.appendLastPage(rows);
        } else {
          pagingController.appendPage(rows, offset + rows.length);
        }
      },
    );
  }

  void setFilter(AdminJobStatusFilter f) {
    if (f == state.filter) return;
    state = state.copyWith(filter: f);
    pagingController.refresh();
  }

  Future<void> refresh() async => pagingController.refresh();
}
