import '../../domain/entities/timesheet.dart';

class TimesheetModel extends Timesheet {
  const TimesheetModel({
    required super.id,
    required super.jobId,
    required super.builderId,
    required super.tradeId,
    required super.checkInAt,
    required super.createdAt,
    super.checkOutAt,
    super.checkInLat,
    super.checkInLng,
    super.checkOutLat,
    super.checkOutLng,
    super.note,
  });

  factory TimesheetModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseOpt(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();
    double? toD(Object? v) => (v as num?)?.toDouble();
    return TimesheetModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      builderId: json['builder_id'] as String,
      tradeId: json['trade_id'] as String,
      checkInAt: DateTime.parse(json['check_in_at'] as String).toLocal(),
      checkOutAt: parseOpt(json['check_out_at']),
      checkInLat: toD(json['check_in_lat']),
      checkInLng: toD(json['check_in_lng']),
      checkOutLat: toD(json['check_out_lat']),
      checkOutLng: toD(json['check_out_lng']),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
