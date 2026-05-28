import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../data/repositories/admin_users_repository_impl.dart';
import '../../domain/entities/admin_user_filter.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../../domain/usecases/list_admin_users.dart';

const int kAdminUsersPageSize = 50;

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>(
  (ref) => AdminUsersRepositoryImpl(),
);

final listAdminUsersProvider = Provider<ListAdminUsers>(
  (ref) => ListAdminUsers(ref.watch(adminUsersRepositoryProvider)),
);

class AdminUsersState {
  const AdminUsersState({required this.filter, required this.query});
  final AdminUserRoleFilter filter;
  final String query;

  AdminUsersState copyWith({AdminUserRoleFilter? filter, String? query}) =>
      AdminUsersState(
        filter: filter ?? this.filter,
        query: query ?? this.query,
      );
}

final adminUsersProvider =
    NotifierProvider<AdminUsersController, AdminUsersState>(
      AdminUsersController.new,
    );

class AdminUsersController extends Notifier<AdminUsersState> {
  late final PagingController<int, AdminUserRow> pagingController;

  @override
  AdminUsersState build() {
    pagingController = PagingController(firstPageKey: 0)
      ..addPageRequestListener(_fetchPage);
    ref.onDispose(() => pagingController.dispose());
    return const AdminUsersState(filter: AdminUserRoleFilter.all, query: '');
  }

  Future<void> _fetchPage(int offset) async {
    final useCase = ref.read(listAdminUsersProvider);
    final result = await useCase(
      ListAdminUsersParams(
        limit: kAdminUsersPageSize,
        offset: offset,
        filter: state.filter,
        query: state.query.isEmpty ? null : state.query,
      ),
    );
    result.fold((failure) => pagingController.error = failure.message, (rows) {
      final isLast = rows.length < kAdminUsersPageSize;
      if (isLast) {
        pagingController.appendLastPage(rows);
      } else {
        pagingController.appendPage(rows, offset + rows.length);
      }
    });
  }

  void setFilter(AdminUserRoleFilter f) {
    if (f == state.filter) return;
    state = state.copyWith(filter: f);
    pagingController.refresh();
  }

  void setQuery(String q) {
    if (q == state.query) return;
    state = state.copyWith(query: q);
    pagingController.refresh();
  }

  Future<void> refresh() async => pagingController.refresh();
}
