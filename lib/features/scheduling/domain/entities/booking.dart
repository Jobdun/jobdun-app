import 'package:equatable/equatable.dart';

// Matches schema enum public.booking_status exactly.
enum BookingStatus { scheduled, completed, cancelled }

extension BookingStatusX on BookingStatus {
  String get label => switch (this) {
    BookingStatus.scheduled => 'Scheduled',
    BookingStatus.completed => 'Completed',
    BookingStatus.cancelled => 'Cancelled',
  };

  String get dbValue => name;

  static BookingStatus fromDb(String v) => BookingStatus.values.firstWhere(
    (s) => s.name == v,
    orElse: () => BookingStatus.scheduled,
  );
}

/// A scheduled day of work for a hired trade on a builder's job (#15).
class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.jobId,
    required this.builderId,
    required this.tradeId,
    required this.scheduledDate,
    required this.status,
    required this.createdAt,
    this.note,
    // Joined for the schedule list.
    this.jobTitle,
    this.builderCompanyName,
    this.tradeFullName,
  });

  final String id;
  final String jobId;
  final String builderId;
  final String tradeId;
  // Date-only (the work day).
  final DateTime scheduledDate;
  final BookingStatus status;
  final String? note;
  final DateTime createdAt;

  final String? jobTitle;
  final String? builderCompanyName;
  final String? tradeFullName;

  bool get isActive => status == BookingStatus.scheduled;

  @override
  List<Object?> get props => [id, jobId, tradeId, scheduledDate, status];
}
