import 'package:equatable/equatable.dart';

import 'job.dart';

class JobFilter extends Equatable {
  const JobFilter({
    this.tradeType,
    this.status,
    this.searchQuery,
    this.builderId,
    this.jobKind,
    this.openToApprentices,
  });

  final String? tradeType; // trade_type_required value
  final JobStatus? status;
  final String? searchQuery;
  // When set, scope the feed to this builder's own jobs ("Your listings").
  final String? builderId;
  final JobKind? jobKind;
  final bool? openToApprentices;

  bool get isEmpty =>
      tradeType == null &&
      status == null &&
      (searchQuery == null || searchQuery!.isEmpty) &&
      builderId == null &&
      jobKind == null &&
      openToApprentices == null;

  @override
  List<Object?> get props => [
    tradeType,
    status,
    searchQuery,
    builderId,
    jobKind,
    openToApprentices,
  ];
}
