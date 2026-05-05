import 'package:equatable/equatable.dart';

import 'job.dart';

class JobFilter extends Equatable {
  const JobFilter({
    this.tradeCategory,
    this.location,
    this.maxBudget,
    this.fromDate,
    this.status,
    this.searchQuery,
  });

  final String? tradeCategory;
  final String? location;
  final double? maxBudget;
  final DateTime? fromDate;
  final JobStatus? status;
  final String? searchQuery;

  bool get isEmpty =>
      tradeCategory == null &&
      location == null &&
      maxBudget == null &&
      fromDate == null &&
      status == null &&
      (searchQuery == null || searchQuery!.isEmpty);

  @override
  List<Object?> get props => [tradeCategory, location, maxBudget, fromDate, status, searchQuery];
}
