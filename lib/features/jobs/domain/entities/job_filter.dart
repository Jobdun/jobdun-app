import 'package:equatable/equatable.dart';

import 'job.dart';

class JobFilter extends Equatable {
  const JobFilter({this.tradeType, this.status, this.searchQuery});

  final String? tradeType; // trade_type_required value
  final JobStatus? status;
  final String? searchQuery;

  bool get isEmpty =>
      tradeType == null &&
      status == null &&
      (searchQuery == null || searchQuery!.isEmpty);

  @override
  List<Object?> get props => [tradeType, status, searchQuery];
}
