import 'package:equatable/equatable.dart';

import 'job.dart';

/// Sort options for the Find Jobs feed.
///
/// Only [newest] is wired to real data. [relevance] needs a `ts_rank`
/// ordering (RPC / generated column = a migration) and [nearest] needs a
/// PostGIS distance function + device location — both deferred (T3-backend).
/// The sort control shows them as disabled "coming soon".
enum JobSort { newest, relevance, nearest }

class JobFilter extends Equatable {
  const JobFilter({
    this.tradeType,
    this.tradeTypes,
    this.status,
    this.searchQuery,
    this.budgetMin,
    this.budgetMax,
    this.startFrom,
    this.startTo,
    this.sort = JobSort.newest,
    this.page,
    this.pageSize = 20,
  });

  /// Legacy single-trade filter (Home feed / existing chip). Kept for
  /// back-compat; [tradeTypes] is the multi-select used by the T3 sheet.
  final String? tradeType; // trade_type_required value
  final List<String>? tradeTypes;
  final JobStatus? status;
  final String? searchQuery;
  final double? budgetMin;
  final double? budgetMax;
  final DateTime? startFrom;
  final DateTime? startTo;
  final JobSort sort;

  /// Zero-based page index. `null` = unpaginated (Home feed behaviour,
  /// unchanged). When set, the datasource applies `.range()`.
  final int? page;
  final int pageSize;

  /// True when no *filtering* criteria are set (pagination/sort don't count).
  bool get isEmpty =>
      tradeType == null &&
      (tradeTypes == null || tradeTypes!.isEmpty) &&
      status == null &&
      (searchQuery == null || searchQuery!.isEmpty) &&
      budgetMin == null &&
      budgetMax == null &&
      startFrom == null &&
      startTo == null;

  JobFilter copyWith({
    String? tradeType,
    List<String>? tradeTypes,
    JobStatus? status,
    String? searchQuery,
    double? budgetMin,
    double? budgetMax,
    DateTime? startFrom,
    DateTime? startTo,
    JobSort? sort,
    int? page,
    int? pageSize,
    bool clearTradeTypes = false,
    bool clearBudget = false,
    bool clearStart = false,
  }) => JobFilter(
    tradeType: tradeType ?? this.tradeType,
    tradeTypes: clearTradeTypes ? null : (tradeTypes ?? this.tradeTypes),
    status: status ?? this.status,
    searchQuery: searchQuery ?? this.searchQuery,
    budgetMin: clearBudget ? null : (budgetMin ?? this.budgetMin),
    budgetMax: clearBudget ? null : (budgetMax ?? this.budgetMax),
    startFrom: clearStart ? null : (startFrom ?? this.startFrom),
    startTo: clearStart ? null : (startTo ?? this.startTo),
    sort: sort ?? this.sort,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );

  @override
  List<Object?> get props => [
    tradeType,
    tradeTypes,
    status,
    searchQuery,
    budgetMin,
    budgetMax,
    startFrom,
    startTo,
    sort,
    page,
    pageSize,
  ];
}
