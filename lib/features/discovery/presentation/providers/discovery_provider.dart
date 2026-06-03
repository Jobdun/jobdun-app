import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../data/datasources/trade_search_remote_datasource.dart';
import '../../data/repositories/trade_search_repository_impl.dart';
import '../../domain/entities/trade_search_filter.dart';
import '../../domain/entities/trade_search_result.dart';
import '../../domain/repositories/trade_search_repository.dart';
import '../../domain/usecases/search_trades.dart';

// ── Data layer providers (public so tests can override) ──────────────────────
final tradeSearchDatasourceProvider = Provider<TradeSearchRemoteDataSource>(
  (ref) => TradeSearchRemoteDataSourceImpl(SupabaseConfig.client),
);

final tradeSearchRepositoryProvider = Provider<TradeSearchRepository>(
  (ref) => TradeSearchRepositoryImpl(ref.read(tradeSearchDatasourceProvider)),
);

final searchTradesUseCaseProvider = Provider(
  (ref) => SearchTrades(ref.read(tradeSearchRepositoryProvider)),
);

// ── Controller ───────────────────────────────────────────────────────────────
final tradeSearchControllerProvider =
    NotifierProvider<TradeSearchController, TradeSearchState>(
      TradeSearchController.new,
    );

/// Owns the trade directory. Mirrors JobsController: one source of truth feeds
/// both the home mini-list (`state.results.take(3)`) and the full discovery
/// page (`pagingController` via PagedListView).
class TradeSearchController extends Notifier<TradeSearchState> {
  late SearchTrades _search;
  PagingController<int, TradeSearchResult>? _pagingController;

  static const _pageSize = 20;

  PagingController<int, TradeSearchResult> get pagingController {
    final existing = _pagingController;
    if (existing != null) return existing;
    final controller = PagingController<int, TradeSearchResult>(firstPageKey: 0);
    controller.addPageRequestListener(_fetchPage);
    _pagingController = controller;
    return controller;
  }

  @override
  TradeSearchState build() {
    _search = ref.read(searchTradesUseCaseProvider);

    // Clear state on logout or account switch to prevent stale data.
    ref.listen(currentUserIdProvider, (previous, next) {
      if (next.value == null ||
          (previous?.value != null && previous?.value != next.value)) {
        state = const TradeSearchState();
        _pagingController?.refresh();
      }
    });

    ref.onDispose(() => _pagingController?.dispose());
    return const TradeSearchState();
  }

  Future<void> _fetchPage(int pageKey) async {
    final result = await _search(
      filter: state.filter,
      limit: _pageSize,
      offset: pageKey * _pageSize,
    );
    result.fold((f) => _pagingController?.error = f.message, (hits) {
      if (pageKey == 0) state = state.copyWith(isLoading: false, results: hits);
      final isLast = hits.length < _pageSize;
      if (isLast) {
        _pagingController?.appendLastPage(hits);
      } else {
        _pagingController?.appendPage(hits, pageKey + 1);
      }
    });
  }

  /// One-shot first page (home mini-list) or refresh of the paged page.
  Future<void> loadFeed() async {
    final paging = _pagingController;
    if (paging != null) {
      paging.refresh();
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    final result = await _search(filter: state.filter, limit: _pageSize);
    result.fold(
      (f) => state = state.copyWith(isLoading: false, error: f.message),
      (hits) => state = state.copyWith(isLoading: false, results: hits),
    );
  }

  Future<void> updateFilter(TradeSearchFilter filter) async {
    state = state.copyWith(filter: filter);
    await loadFeed();
  }

  Future<void> setOrigin(double lat, double lng) =>
      updateFilter(state.filter.copyWith(originLat: lat, originLng: lng));

  Future<void> refresh() => loadFeed();
}

class TradeSearchState {
  const TradeSearchState({
    this.results = const [],
    this.filter = const TradeSearchFilter(),
    this.isLoading = false,
    this.error,
  });

  final List<TradeSearchResult> results;
  final TradeSearchFilter filter;
  final bool isLoading;
  final String? error;

  TradeSearchState copyWith({
    List<TradeSearchResult>? results,
    TradeSearchFilter? filter,
    bool? isLoading,
    String? error,
  }) => TradeSearchState(
    results: results ?? this.results,
    filter: filter ?? this.filter,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}
