import 'package:equatable/equatable.dart';

/// A trade's clock-on/off record for a job (#16). Open until checked out.
class Timesheet extends Equatable {
  const Timesheet({
    required this.id,
    required this.jobId,
    required this.builderId,
    required this.tradeId,
    required this.checkInAt,
    required this.createdAt,
    this.checkOutAt,
    this.checkInLat,
    this.checkInLng,
    this.checkOutLat,
    this.checkOutLng,
    this.note,
  });

  final String id;
  final String jobId;
  final String builderId;
  final String tradeId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final double? checkInLat;
  final double? checkInLng;
  final double? checkOutLat;
  final double? checkOutLng;
  final String? note;
  final DateTime createdAt;

  /// Still clocked on — awaiting check-out.
  bool get isOpen => checkOutAt == null;

  /// Worked duration in minutes once checked out, else null.
  int? get durationMinutes => checkOutAt?.difference(checkInAt).inMinutes;

  @override
  List<Object?> get props => [id, jobId, tradeId, checkInAt, checkOutAt];
}
