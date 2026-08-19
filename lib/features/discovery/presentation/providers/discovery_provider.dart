import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/providers/account_scoped.dart';
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
class TradeSearchController extends Notifier<TradeSearchState>
    with AccountScoped<TradeSearchState> {
  late SearchTrades _search;
  PagingController<int, TradeSearchResult>? _pagingController;

  // 2026-08-18 audit: generation token — a slow response from a superseded
  // fetch cycle (filter change / refresh / account switch) must not append
  // stale rows or overwrite newer state. Bumped whenever a new cycle starts;
  // in-flight fetches capture it before the await and discard on mismatch.
  int _generation = 0;

  static const _pageSize = 20;

  PagingController<int, TradeSearchResult> get pagingController {
    final existing = _pagingController;
    if (existing != null) return existing;
    final controller = PagingController<int, TradeSearchResult>(
      firstPageKey: 0,
    );
    controller.addPageRequestListener(_fetchPage);
    _pagingController = controller;
    return controller;
  }

  @override
  TradeSearchState build() {
    _search = ref.read(searchTradesUseCaseProvider);

    // Clear state on logout or account switch to prevent stale data.
    resetOnAccountChange((_) {
      _generation++; // discard any fetch still in flight for the old account
      state = const TradeSearchState();
      _pagingController?.refresh();
    });

    ref.onDispose(() => _pagingController?.dispose());
    return const TradeSearchState();
  }

  Future<void> _fetchPage(int pageKey) async {
    // Page 0 starts a new cycle (refresh / filter change) — invalidate any
    // in-flight fetch from the previous one.
    if (pageKey == 0) _generation++;
    final gen = _generation;
    final result = await _search(
      filter: state.filter,
      limit: _pageSize,
      offset: pageKey * _pageSize,
    );
    if (gen != _generation) return; // stale response — discard
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
    final gen = ++_generation;
    state = state.copyWith(isLoading: true, error: null);
    final result = await _search(filter: state.filter, limit: _pageSize);
    if (gen != _generation) return; // stale response — discard
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
